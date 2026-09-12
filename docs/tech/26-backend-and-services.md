# 26 — Backend & Services

> Part of the Dragon Heroes document set. Canon: [00-canon.md](../00-canon.md) (§8 is binding).
> Siblings: [architecture](20-architecture-overview.md), [netcode & hosting](22-netcode-and-server-hosting.md),
> [content pipeline](23-content-pipeline.md), [creature AI & RL](25-creature-ai-and-rl.md),
> [security](27-security-anticheat-and-economy-integrity.md), [economy design](../design/15-economy-and-marketplace.md),
> [PvP & tournaments](../design/16-pvp-and-tournaments.md), [legal & payments](../business/30-legal-payments-compliance.md).

## Purpose

This document specifies everything that runs server-side *except* combat simulation: the meta-game
platform (Nakama), the economy core that owns all real-money state, the liveops service, the web
marketplace backend, and the infrastructure they live on. The design goal drives every choice
below: **Dragon Heroes has a real-money player-to-player marketplace, so a duplication bug or a
lost item is not a gameplay bug — it is a financial incident.** The backend is therefore a small
fintech system wearing a game on top: one exclusive writer for money state, append-only
double-entry ledgers, idempotent APIs, and nightly invariant checks with alarms. Everything else
(chat, guilds, matchmaking, leaderboards) is deliberately boring, off-the-shelf, and replaceable.

## 1. Service map

| Service | Repo path | Language / stack | Owns | Never does |
|---|---|---|---|---|
| **Nakama** | `backend/nakama/` | Nakama (Apache-2.0) + runtime modules | Accounts/auth, sessions, guilds (groups), chat, matchmaker, leaderboards, tournaments API, soft-currency wallets (Gold, Glory) | Writes real-money tables; simulates combat |
| **Economy core** | `backend/economy-core/` | Go, single static binary | Real-money items, double-entry ledgers, marketplace settlement, escrow, prize pools, PSP adapter | Trusts any caller without idempotency key; UPDATEs ledger rows |
| **Liveops** | `backend/liveops/` | Go (proposal) | Content activation schedules, feature flags, kill switches, config distribution | Holds money or item state |
| **Marketplace backend** | `web/marketplace/` | Thin BFF (TypeScript/Node, proposal) | Web marketplace UI API: browse, list, buy — all mutations proxied to economy core | Writes any economy table directly |
| **Account portal** | `web/account/` | Same stack as marketplace BFF | Age verification (CPF/document-grade), seller KYC onboarding hand-off to PSP, account linking | Stores raw identity documents (PSP/verification vendor holds them) |
| **dh-server (zones/matches)** | `sim/libs/dh-server/` | C++ (see [22](22-netcode-and-server-hosting.md)) | Authoritative combat, drops, replay logs | Writes Nakama storage or economy tables — RPC only (canon §10 coupling rule 3) |

### 1.1 Why Nakama (and why not the alternatives)

The canon (§8) fixes self-hosted **Nakama** as the meta-game backend. The July 2026 research pass is
the basis for that decision, and the reasoning should be on record:

- **Nakama** is [Apache-2.0, actively maintained (v3.39.x, ~12.8k stars, 103 releases)](https://github.com/heroiclabs/nakama),
  runs on plain PostgreSQL, and natively covers exactly the meta-game feature list we need:
  device/email/social auth, groups (our guilds), chat, a server-side matchmaker, leaderboards, and a
  **built-in tournaments API** that maps directly onto the weekly solo/guild tournaments in
  [16-pvp-and-tournaments](../design/16-pvp-and-tournaments.md). One system replaces most of what we
  would otherwise buy.
- **PlayFab** is no longer viable for a PC+mobile studio: on March 11, 2026 Microsoft replaced its
  free Development Mode with ["Foundation Mode" — 1,000 lifetime account creations unless the game ships on Xbox and is linked to Partner Center](https://crux.supercraft.host/blog/playfab-cut-free-tier-99-percent-foundation-mode-fix-2026/),
  and [retired Insights/Event Export on March 31, 2026](https://developer.microsoft.com/en-us/games/articles/2026/04/microsoft-game-dev-release-notes-q1-2026/).
  We are not shipping on Xbox at launch; PlayFab has effectively become an Xbox acquisition channel.
- **AccelByte** is technically solid but [enterprise-priced on peak concurrent users — roughly $0.055–0.11 per PCCU/day across modules](https://accelbyte.io/pricing),
  positioned for funded AAA teams. Wrong cost shape for us.
- **Epic Online Services** stays free but is [thin exactly where we are hard](https://crux.supercraft.host/blog/epic-online-services-vs-custom-backend/):
  no queryable server-side economy, rate-limited player storage. Free EOS *complements* (Easy
  Anti-Cheat on PC, see [27-security](27-security-anticheat-and-economy-integrity.md)) remain an
  option — never for inventory/economy.
- Heroic's paid add-ons (**Hiro** economy, **Satori** liveops) are deliberately **not** adopted:
  closed-source, and they would recreate the vendor dependency we are avoiding (research caveat).
  The economy core and liveops service stay ours.

Nakama's wallet feature is used for the two **soft** currencies only — Gold and Glory, which are
never cashable (canon glossary) — because [Nakama's wallet is server-authoritative with its own transaction ledger](https://heroiclabs.com/docs/nakama/guides/concepts/economy/)
and that is sufficient for state with no real-money exposure. Anything cashable lives in the
economy core, full stop.

### 1.2 Service-to-service authentication

All backend services run in the same Kubernetes cluster (§9). Trust is layered:

1. **Network:** namespace-scoped NetworkPolicies — the economy core accepts connections only from
   Nakama, the marketplace BFF, liveops, and the zone-server namespace; mTLS via cert-manager
   certs (proposal: no service mesh at launch, to keep ops surface small).
2. **Identity:** each service authenticates with a Kubernetes ServiceAccount projected JWT; the
   economy core validates audience + issuer and maps identity to an allowlist of callable RPCs
   (e.g. `dh-server` may call `MintDroppedItem` but never `SettleSale`).
3. **Player context:** calls on behalf of a player carry Nakama-signed proof of that player: the
   marketplace BFF and Nakama runtime modules forward the player's session token, while
   `dh-server` forwards the Nakama-signed session claims from its validated zone ticket (§8 —
   the raw session token never transits the game path). The economy core validates either
   against Nakama's signing key, so player identity is proven end-to-end, not asserted by the
   calling service.

`dh-server` zone processes (Agones pods, see [22](22-netcode-and-server-hosting.md)) get the same
JWT treatment plus a per-fleet credential so a compromised zone binary is revocable as a class.

## 2. Economy core

The economy core is a single Go service and is the **sole writer** of real-money state (canon §8).
It exposes a small gRPC API (proposal) — mint, list, cancel, settle, consume, destroy, credit,
payout — every mutation carrying a client-generated idempotency key. It is the piece of this
project where we import fintech practice wholesale, following the
[double-entry ledger pattern](https://www.pgrs.net/2025/06/17/double-entry-ledgers-missing-primitive-in-modern-software/)
and its [Go/PostgreSQL implementation shape](https://www.freecodecamp.org/news/build-a-bank-ledger-in-go-with-postgresql-using-the-double-entry-accounting-principle/).

The motivating incidents are real and recent. Amazon's *New World* (2021) shipped with gold/item
duplication exploits and had to repeatedly disable **every** wealth-transfer system — trading post,
player trades, guild treasuries — because no narrower lever existed. *Old School RuneScape* hit an
item-duplication bug in October 2024 severe enough that Jagex took trading offline, rolled back,
and mass-banned. Both had play-money economies; ours is cashable. We do not get to learn this
lesson in production.

### 2.1 Schema sketch (PostgreSQL)

```sql
-- Player identity: who can own items. Deliberately separate from the money ledger —
-- `accounts` below stays a closed chart of ledger accounts, never an identity table.
CREATE TABLE players (
  id                 uuid PRIMARY KEY,
  nakama_account_id  uuid NOT NULL UNIQUE,    -- link to the Nakama account
  credit_account_id  uuid NOT NULL UNIQUE REFERENCES accounts(id),
                                              -- this player's 'player_credit' ledger account
  created_at         timestamptz NOT NULL DEFAULT now()
);

-- Item instances: one row per real-money item that exists, ever.
CREATE TABLE items (
  item_guid    uuid PRIMARY KEY,              -- minted once, never reused
  item_def_id  text NOT NULL,                 -- content string ID, e.g. core.item.emberfang_blade
  owner_id     uuid NOT NULL REFERENCES players(id),
  state        text NOT NULL CHECK (state IN
               ('owned','listed','escrowed','settled','consumed','destroyed')),
  provenance   jsonb NOT NULL,                -- drop origin: zone id, world seed, chunk, tick,
                                              -- killer account, creature id, content-pack version
  created_at   timestamptz NOT NULL DEFAULT now(),
  version      bigint NOT NULL DEFAULT 0      -- optimistic concurrency stamp
);

-- Ledger: append-only. UPDATE/DELETE revoked at the role level + BEFORE triggers that RAISE.
CREATE TABLE accounts (
  id       uuid PRIMARY KEY,
  kind     text NOT NULL CHECK (kind IN
           ('player_credit','psp_clearing','escrow','fee_revenue','prize_pool','payout_inflight')),
  currency text NOT NULL DEFAULT 'BRL'        -- integer centavos everywhere; no floats
);

CREATE TABLE entries (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  transaction_id uuid NOT NULL,               -- groups the legs of one logical transaction
  account_id     uuid NOT NULL REFERENCES accounts(id),
  amount_cents   bigint NOT NULL CHECK (amount_cents <> 0),  -- +credit / -debit
  reason         text NOT NULL,               -- 'sale_settlement','fee_split','prize_accrual',...
  item_guid      uuid REFERENCES items(item_guid),
  created_at     timestamptz NOT NULL DEFAULT now()
);
-- Invariant (checked at commit + nightly): SUM(amount_cents) per transaction_id = 0.

-- Idempotency: every mutating RPC records its key before doing work.
CREATE TABLE idempotency_keys (
  key           text PRIMARY KEY,             -- caller-generated, scoped per RPC
  request_hash  bytea NOT NULL,               -- reject same key + different payload
  response      jsonb,                        -- replayed verbatim on retry
  status        text NOT NULL CHECK (status IN ('inflight','committed','failed')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  expires_at    timestamptz NOT NULL          -- 30 days (proposal)
);
```

Ledger accounts of kind `escrow` and `payout_inflight` are the money analogue of the item escrow
state: funds confirmed by the PSP but not yet settled sit in `escrow`; Pix payouts requested but
not yet confirmed sit in `payout_inflight`. Money is never in an untracked limbo.

Identity and money are deliberately separate: items are owned by `players` rows, and each player
maps 1:1 to a `player_credit` ledger account via `credit_account_id`. The `accounts` kind CHECK
stays a closed list of ledger kinds — no identity row can ever hold a balance directly, and no
ledger account can ever own an item.

### 2.2 Item state machine

```
        mint (drop)           list                buyer pays + webhook
  ∅ ──────────────► owned ──────────► listed ──────────────────► escrowed
                     ▲  ▲               │ cancel / expire            │ settle (atomic tx)
                     │  └───────────────┘                            ▼
                     │                                            settled ──► owned (new owner)
                     │ (transient, inside the settlement tx)
                     ├──► consumed   (used as material, e.g. Spirit Essence enchant)
                     └──► destroyed  (player-initiated salvage; terminal)
```

Transitions are the *only* way state changes; each is one SERIALIZABLE transaction that writes the
item row, its ledger legs (if money moves), and the idempotency record together. `settled` is a
transient sub-state inside the settlement transaction — externally an item is never observable
between owners. `consumed` and `destroyed` are terminal; the GUID is never reused, which keeps the
provenance chain intact for fraud forensics ([27](27-security-anticheat-and-economy-integrity.md)).

### 2.3 Concurrency, corrections, reconciliation

- **Isolation:** every mutating transaction runs at `SERIALIZABLE`. Serialization failures are
  retried with jittered exponential backoff, 5 attempts (proposal); the idempotency record makes
  retries safe even across process crashes.
- **Corrections are compensating entries, never UPDATEs.** If a settlement was wrong, we append a
  reversing transaction that re-debits/re-credits; the ledger remains an immutable audit history.
  The same applies to items: a wrongly transferred item is transferred back by a new transition,
  with `reason` linking the two.
- **Nightly reconciliation jobs** (a cron in the economy core, results to the observability stack):
  1. every `transaction_id` sums to zero;
  2. global ledger sums to zero per currency;
  3. no `item_guid` appears with two owners across the items table and settlement history;
  4. every `escrowed` item has a matching open escrow ledger balance, and vice versa;
  5. economy-core `player_credit` balances match the PSP subaccount report (Phase A closed-loop —
     the PSP holds the actual funds, our ledger must mirror it exactly).
  Any violation pages a human (§9.3) and — for invariants 3 and 4 — automatically trips the
  marketplace kill switch (§7). Mint-rate anomaly alerts (canon §8) run continuously, not nightly:
  a rolling per-item-def mint-rate baseline with alerting at 5σ deviation (proposal).

## 3. Marketplace settlement flow

The full flow, end to end. Design constraint from canon §8: **the studio never touches funds** —
the buyer pays the PSP, funds sit at the PSP, and release only after the economy core commits the
item transfer.

```mermaid
sequenceDiagram
    participant S as Seller (web)
    participant M as Marketplace BFF
    participant E as Economy core
    participant P as PSP (Asaas)
    participant B as Buyer (web)
    S->>M: list item (price)
    M->>E: List RPC (idempotency key)
    E->>E: item owned→listed (tx)
    B->>M: buy
    M->>E: InitiatePurchase RPC
    E->>P: create Pix charge (split: seller / fee)
    P-->>B: Pix QR / copia-e-cola
    B->>P: pays via Pix
    P->>E: payment webhook (signed)
    E->>E: item listed→escrowed + escrow ledger entry
    E->>E: SETTLE (one SERIALIZABLE tx): item→buyer,<br/>seller credit, fee split, prize-pool accrual
    E->>P: release escrow to seller subaccount
    E-->>M: settled; both parties notified
```

Step by step, with the failure paths that matter:

1. **List.** Seller lists; economy core transitions `owned → listed`, records asking price. No
   money moves. Cancel or listing expiry (7 days, proposal) transitions back to `owned`.
2. **Buy → Pix charge.** Buyer initiates purchase; economy core asks the PSP for a Pix charge with
   the split pre-configured (seller amount, 10% studio fee per canon §2). The item stays `listed`
   and *remains buyable-locked* to this charge for the Pix expiry window (15 minutes, proposal).
3. **PSP webhook confirms payment.** Webhooks are signed, verified, and idempotent (the PSP
   delivery ID is the idempotency key). On confirmation: item `listed → escrowed`, funds recorded
   in the `escrow` ledger account.
4. **Atomic settlement.** One SERIALIZABLE transaction: item transfers to the buyer
   (`escrowed → settled → owned`), seller `player_credit` is credited, the fee leg posts to
   `fee_revenue`, and **20% of the fee posts to `prize_pool`** (canon §2) — four ledger legs, one
   `transaction_id`, sums to zero. Only after this commit does the economy core instruct the PSP to
   release escrowed funds to the seller's subaccount.
5. **Failure / timeout compensation.**
   - Pix charge expires unpaid → lock released, item stays `listed`. Nothing to compensate.
   - Webhook received but settlement fails permanently (invariant bug; should be near-impossible)
     → item stays `escrowed`, funds stay in escrow, alarm fires, humans decide: complete settlement
     or refund via the PSP with compensating entries. Nothing auto-refunds silently.
   - Settlement committed but PSP release fails → retried from a durable transactional outbox (the
     release instruction is written inside the settlement transaction). Reconciliation invariant 5
     catches anything that slips.
   - Buyer pays after expiry (late Pix) → funds arrive with no purchasable item; auto-refund via
     the PSP, logged with compensating entries.

Phase A is closed-loop (canon §2): "seller credit" is marketplace credit held in the seller's PSP
subaccount, spendable on the marketplace. Phase B (Pix cash-out) adds a `Payout` RPC over the same
ledger — architecture supports it from day 1, activation is a legal gate
([30](../business/30-legal-payments-compliance.md)).

## 4. PSP integration

**Asaas is the primary PSP** (canon §8): white-label subaccounts (sellers get accounts under our
onboarding flow without leaving our UX), delegated KYC/KYB (Asaas verifies seller CPF and identity
— we never hold documents), native payment split, and Pix payout rails for Phase B. Asaas' Pix
pricing is [~0.99% capped, no monthly fee](https://blog.asaas.com/qual-api-oferece-split-de-pagamentos/).
Routing through a marketplace-PSP keeps IntelliGames outside Banco Central payment-institution
licensing, which tightened materially in 2025–2026
([Resolução BCB 506/2025](https://www.legisweb.com.br/legislacao/?id=484161); a May-2026 mandatory
authorization window and [R$15k per-transaction caps for unauthorized institutions](https://www.mattosfilho.com.br/unico/bcb-novas-normas-pix/)).

The PSP is wrapped behind a **`PaymentProvider` interface inside the economy core** (create charge
with split, query charge, webhook verification, subaccount onboarding, escrow release, payout) so
that **OpenPix/Woovi and Efí are swappable alternates** per canon. Two hard rules: no PSP concept
leaks past the interface (ledger reasons and item states are PSP-agnostic), and we ship against
Asaas only after written confirmation that game-item RMT with seller cash-out is an accepted use
case (research caveat; also a canon §8 pending item). Pix only, BRL only.

## 5. Prize pools and tournament payouts

The prize pool is not a config number — it is a **ledger account** (`prize_pool`, per season;
proposal: one account per season ID, e.g. `prize_pool.s01`). Every marketplace settlement posts its
20%-of-fee accrual leg there (§3 step 4), so at any instant the pool's balance is exact, auditable,
and sums against fee revenue. The seasonal grand tournament and weekly tournaments
([16](../design/16-pvp-and-tournaments.md)) draw from it.

Payout flow: tournament results come from Nakama's tournaments API → liveops confirms the bracket
is final and replay review passed ([27](27-security-anticheat-and-economy-integrity.md)) → economy
core moves the prize from `prize_pool` to `payout_inflight` → **KYC gate**: payout executes only to
the verified CPF holder's own Pix key via the PSP (canon §8 PLD/AML) → economy core records the
gross/withheld/net legs and hands the withholding data for **30% IRRF on cash prizes
([DARF code 0916, remitted by the 3rd business day after the decêndio](https://www.portaltributario.com.br/guia/irf_sorteios.html))**
to the PSP/accounting integration, which executes the net Pix payout. The Receita Federal shipped
[dedicated prize-tax tooling for bets and virtual competitions in March 2026](https://www.gov.br/receitafederal/pt-br/assuntos/noticias/2026/marco/receita-libera-ferramenta-para-calcular-ir-de-premios-em-bets-e-fantasy-sport),
so this flow will be scrutinized; exact withholding classification (prize vs remuneration) is a
counsel question tracked in [30-legal-payments-compliance](../business/30-legal-payments-compliance.md).
No entry fees exist anywhere in this flow (canon §5 — hard rule).

## 6. Nakama runtime modules

Game-specific server logic inside Nakama lives in runtime modules — **Go modules (proposal;**
TypeScript is the alternative, see open question 2**)** under `backend/nakama/`. They implement:

- custom RPCs the client calls through Nakama's socket: claim tournament placement, guild
  operations beyond stock groups, loadout metadata, matchmaker property enrichment (input class
  segregation per canon §1);
- before/after hooks: account-link validation, the age-verification gate (§8), chat filters;
- **bridging to the economy core — always via its gRPC API, never by touching its tables.** Nakama
  and the economy core share a Postgres *instance* at most, never a schema, and the economy-core
  role grants are the enforcement (Nakama's DB user has no privileges on economy tables).

Anything combat-adjacent is out of scope by construction: Nakama never simulates, and `dh-server`
talks to Nakama only for session validation and match/tournament bookkeeping
([20](20-architecture-overview.md) coupling rules).

## 7. Liveops service

A small service with three jobs, all consumed by every other component through one low-latency
config API (poll ≤ 30 s or push via watch stream, proposal):

1. **Content activation schedules.** Weekly drops are staged dark and activated on schedule — the
   liveops service flips `pack.2026-w40 → active`, which the content pipeline and servers pick up
   ([23-content-pipeline](23-content-pipeline.md) owns the artifact flow; liveops owns *when*).
2. **Feature flags.** Percentage and cohort rollouts for non-combat features (marketplace UI
   variants, onboarding flows). Combat balance is *not* flagged here — it is content data (canon §7).
3. **Kill switches.** Canonical requirement (§8): every wealth-transfer vector — **trade,
   marketplace, mail, drop** — has a one-click, independently toggleable kill switch that exists
   *before* the marketplace opens. Semantics are fail-closed: `dh-server` caches the last-known
   switch state and, on liveops unreachability beyond 60 s (proposal), freezes wealth-transfer
   actions rather than assuming "on". Tripping any switch pages on-call and is audit-logged with
   actor + reason. Reconciliation invariant violations trip the marketplace switch automatically
   (§2.3). The full incident playbook lives in [27](27-security-anticheat-and-economy-integrity.md).

We deliberately build this instead of adopting Heroic's Satori: Satori is paid and closed, and our
liveops needs (schedules, flags, switches) are a week of Go, not a platform (research caveat on
vendor dependency).

## 8. Auth and session flow, end to end

1. **First launch:** client authenticates to Nakama with **device auth** (installation-scoped ID).
   The player can play nothing yet — Dragon Heroes is 18+ with real age verification as a launch
   blocker (canon §1, [Lei 15.211/2025](../business/30-legal-payments-compliance.md)).
2. **Account link:** device account is linked to email or social (Google/Apple/Steam via Nakama's
   built-in providers) so the account survives device loss.
3. **Age-verification gate (account level):** the player completes CPF/document-grade verification
   on the web account portal (`web/account/`); the verification vendor/PSP attests, and the portal
   sets a signed `age_verified` flag on the Nakama account via a server-to-server call. A Nakama
   before-hook blocks session issuance into gameplay for unverified accounts. Marketplace and
   seller onboarding additionally require the full KYC tier (§4).
4. **Session:** Nakama issues its signed session token (JWT). Refresh handled by the Nakama client
   SDK inside our GDScript UI layer.
5. **Entering a zone/match:** matchmaker or world-router assigns a `dh-server` endpoint and
   Nakama mints a **short-lived, single-use signed zone ticket** bound to that server address and
   embedding the session claims (account ID, entitlements, expiry) — the model defined in
   [20 §6.2](20-architecture-overview.md) and [22 §11](22-netcode-and-server-hosting.md). The
   client presents the ticket — never its raw session token — in the ENet connect handshake;
   `dh-server` validates the ticket signature locally (shared verification key, rotated via K8s
   secret) and reads account ID + entitlements from the embedded claims, without a per-connect
   Nakama round-trip.
6. **In-session economy actions** (e.g. a Legendary drop mints a real-money item): `dh-server`
   calls the economy core with its service identity *plus* the Nakama-signed player claims from
   the validated zone ticket (§1.2 — `dh-server` never holds the raw session token), so every
   mint is attributable to a verified account and a specific zone process.

## 9. Data, telemetry, and infrastructure

### 9.1 Database strategy

One **managed PostgreSQL** (cloud-provider managed, sa-east-1) with **PITR and a synchronous
replica** — canon §8. Two logical databases on separate instances (proposal): `nakama` (loss
tolerable to minutes) and `economy` (loss tolerable to zero; the synchronous replica and PITR are
non-negotiable here, and the economy instance gets its own maintenance and access policy).
Explicitly **not CockroachDB**: per the research, distributed SQL only pays off with multi-region
active-active writes, which we do not need at small-studio scale in one region — and
[Nakama speaks the Postgres wire protocol](https://github.com/heroiclabs/nakama), so migrating
later stays possible if Phase B growth ever demands it.

### 9.2 Telemetry and analytics

Two pipelines, different owners, different guarantees:

- **Product/economy events** (logins, sessions, drops, listings, settlements, prices): services
  emit structured events to a lightweight collector (OTel collector → object storage in
  Parquet, hourly batches, proposal) and load into a warehouse (managed ClickHouse in-region,
  proposal — open question 4) for dashboards, economy-health monitoring (mint/burn rates, price
  indices per [15](../design/15-economy-and-marketplace.md)), and fraud analytics. Best-effort
  delivery; the ledger, not telemetry, is the accounting truth.
- **Replay logs** (server-side obs+action pairs from `dh-server`, logged from the first playtest —
  canonical requirement §9): written straight to object storage in the ML bucket layout that
  [25-creature-ai-and-rl](25-creature-ai-and-rl.md) defines, since they feed behavioral cloning and
  tournament review. These are gameplay-complete and versioned by build + content hash. Retention
  windows and their LGPD scoping are owned by [25](25-creature-ai-and-rl.md) — no figures are
  duplicated here.

### 9.3 Infra layout

- **Kubernetes in sa-east-1 / southamerica-east1** (canon §6 fixes the region for the game fleet;
  the backend co-locates). One cluster at launch with **namespaces per environment — `dev`,
  `staging`, `prod`** — plus separate namespaces for the Agones fleet vs backend services;
  graduating `prod` to its own cluster is an M-later hardening step (open question 5).
- **Secrets:** external secrets operator backed by the cloud secrets manager; no secrets in git;
  PSP webhook signing keys and the Nakama token key on 90-day rotation (proposal).
- **Observability:** Prometheus-compatible metrics + Grafana, Loki for logs, OTel traces across
  Nakama → economy core → PSP adapter (one trace per settlement is the debugging superpower).
  **Ledger-invariant alerting is first-class:** reconciliation results and the continuous mint-rate
  monitor are exported as metrics with paging alerts — an invariant violation is a page, never a
  dashboard curiosity.
- **Environments and data:** `staging` runs against a sandbox PSP account and synthetic ledgers;
  production economy data is never copied down (LGPD + blast radius).

### 9.4 Cost reality and the managed fallback

Self-hosting Nakama is not free even though the license is: realistic launch-scale baseline —
managed Postgres pair, 2-node Nakama, the three small services, observability — is on the order of
**US$ 1,000–1,500/month infra (proposal)** *plus* roughly **0.5 FTE of DevOps/SRE attention**,
which at this team size is the real cost (research caveat: monitoring, upgrades, DB operations are
the hidden line items). If ops load overwhelms the team, the designated fallback is **Heroic
Cloud** (managed Nakama, DAU-priced — [quote directly before deciding](https://crux.supercraft.host/blog/nakama-open-source-vs-managed-backend/));
because the economy core is a separate self-owned service, moving Nakama to Heroic Cloud would not
move a single centavo of money state out of our control. That separation is the insurance policy.

## Open questions (for Ricardo)

1. **PSP written confirmation:** authorize outreach to Asaas (and OpenPix/Efí as backups) now for
   written confirmation that game-item RMT with seller credit/cash-out is an accepted merchant use
   case — this gates the whole §3/§4 build and canon §8 lists it as pending. Who signs the ask?
2. **Nakama runtime module language:** Go (one backend language, in-process performance) vs
   TypeScript (faster iteration, larger hiring pool). This doc proposes Go — confirm or flip, it's
   cheap now and expensive later.
3. **Self-host vs Heroic Cloud at launch:** do we commit ~0.5 FTE DevOps to self-hosted Nakama, or
   get a Heroic Cloud quote now and decide on numbers? (Economy core stays self-owned either way.)
4. **Warehouse choice and data residency:** managed ClickHouse in-region (proposed) vs BigQuery
   (southamerica-east1) — LGPD posture prefers in-region; pick one before telemetry schemas ossify.
5. **Cluster topology:** accept single cluster + namespaces at launch (proposed) with prod-cluster
   split as a post-launch hardening milestone, or pay for the separate prod cluster from day 1?
6. **Phase A credit truth:** canon holds seller credit at PSP subaccounts with our ledger
   mirroring. Confirm the stance that the **PSP balance is legally authoritative and our ledger is
   the reconciled mirror** (proposed), so disputes resolve against PSP records — this shapes the
   reconciliation job and support tooling.

## Sources

- [heroiclabs/nakama — GitHub (Apache-2.0, v3.39.x, Postgres wire protocol)](https://github.com/heroiclabs/nakama)
- [Nakama docs — Creating an Economy (server-authoritative wallet)](https://heroiclabs.com/docs/nakama/guides/concepts/economy/)
- [PlayFab Foundation Mode analysis (free tier cut, March 2026)](https://crux.supercraft.host/blog/playfab-cut-free-tier-99-percent-foundation-mode-fix-2026/)
- [Microsoft Game Dev — Q1 2026 release notes (Foundation Mode, Insights retirement)](https://developer.microsoft.com/en-us/games/articles/2026/04/microsoft-game-dev-release-notes-q1-2026/)
- [AccelByte pricing (PCCU-based)](https://accelbyte.io/pricing)
- [EOS vs custom backends — economy limitations](https://crux.supercraft.host/blog/epic-online-services-vs-custom-backend/)
- [Double-Entry Ledgers: The Missing Primitive in Modern Software](https://www.pgrs.net/2025/06/17/double-entry-ledgers-missing-primitive-in-modern-software/)
- [Build a Bank Ledger in Go with PostgreSQL](https://www.freecodecamp.org/news/build-a-bank-ledger-in-go-with-postgresql-using-the-double-entry-accounting-principle/)
- [Asaas — split de pagamentos / Pix pricing](https://blog.asaas.com/qual-api-oferece-split-de-pagamentos/)
- [Resolução BCB nº 506/2025](https://www.legisweb.com.br/legislacao/?id=484161)
- [Mattos Filho — novas normas BCB sobre Pix (limites, autorização)](https://www.mattosfilho.com.br/unico/bcb-novas-normas-pix/)
- [Portal Tributário — IRF sobre prêmios (30%, DARF 0916)](https://www.portaltributario.com.br/guia/irf_sorteios.html)
- [Receita Federal — ferramenta de IR para prêmios em bets e competições virtuais (mar/2026)](https://www.gov.br/receitafederal/pt-br/assuntos/noticias/2026/marco/receita-libera-ferramenta-para-calcular-ir-de-premios-em-bets-e-fantasy-sport)
- [Nakama open source vs managed backend (Heroic Cloud calculus)](https://crux.supercraft.host/blog/nakama-open-source-vs-managed-backend/)

## 9. Self-host quickstart (2026-09-12 — LANDED)

`tools/nakama.sh up` — postgres:16 + heroiclabs/nakama via
`tools/nakama/docker-compose.yml` (migrate-up entrypoint, dev server key
`dh_local_dev_key`, session tokens 24 h). Verified live on the dev box:
console http://localhost:7351, HTTP API :7350, game port 7349. Down/wipe via
the same script. No cloud, one command; the economy core + marketplace still
follow §2/§3 — this stack is their runtime home. Game-side client (auth →
device, leaderboards, tournaments) is the next spike (roadmap 6b).
