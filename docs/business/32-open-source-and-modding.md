# 32 — Open source, anti-piracy, and the modding posture

> **Status:** decision draft for Ricardo's confirmation (he called it on
> 2026-09-02: "make it full open source — extensible and extremely moddable").
> Canonical summary: [canon §12.37](../00-canon.md). Business frame:
> [15-economy](../design/15-economy-and-marketplace.md), legal:
> [30-legal](30-legal-payments-compliance.md).

## 1. The piracy question, answered honestly

Client-side cryptography against piracy does not exist. Any shipped binary can
be dumped, decompiled, and repacked; commercial DRM delays cracks by days-to-
weeks, costs real performance (against our locked-60-FPS mandate), and
degrades the paying customers' experience while doing nothing to non-customers.
The industry answer that *does* work: **make the valuable part of the product
server-resident**, so a pirated client is a demo, not a business.

Dragon Heroes is already built that way — this decision ratifies, not changes,
the architecture:

| What's valuable | Where it lives | Pirate gets |
|---|---|---|
| Combat/loot/trade truth | Authoritative servers (canon §6) | a client that can lie to itself only |
| Real-money items & balances | Go economy core, sole writer (§8) | nothing — tables are unreachable |
| The marketplace | Web-only surface (§1) | nothing in any client, legit or not |
| RL policy weights (bosses, Ghosts) | Server CPU only (§9) | nothing to run a farming bot with |
| Cosmetics & season entitlements | Account-bound, server-issued | local texture swaps only |
| Weekly content drops | Server-gated by account | solo/offline play of whatever is public anyway |

Remaining real risks are **cheating**, not piracy — see §4.

## 2. The open-source decision

**The client, sim workspace, tools, content schemas, and docs are open
source.** Rationale: (a) anti-piracy-by-DRM was never available, so openness
costs ~zero; (b) "extensibility is the product" is a standing directive — an
open, moddable game is the strongest form of it; (c) community trust matters
doubly in a real-money game: auditable drop rates, auditable client, auditable
fairness claims (canon already requires publishing drop-probability tables —
Lei/TJDFT posture in business/30).

**License split (CONFIRMED by Ricardo, 2026-09-02):**
- **Code (game/, sim/, tools/, ml/, genforge/): MIT.** Maximum adoption,
  server operators and toolsmiths welcome.
- **Art & content (art/, content/, sprites, lore): PROPRIETARY — all rights
  reserved** (LICENSE-ASSETS). Modders/shard operators distribute their own
  code and data; players fetch the proprietary assets from an official build.
  Blocks any clone from reskinning the game with our own art, commercial or
  not, without written permission.
- **Secrets and live config:** never in the repo, ever (PSP keys, age-verification
  vendor keys, server credentials). Open-sourcing the code exposes none of them
  by construction — audit `.gitignore` + history before the first public push.
- **Backend/economy-core:** open too (MIT) — the double-entry ledger *benefits*
  from public audit; fraud detection parameters that must stay non-public live
  in config, not code (economy-integrity, tech/27).

Steam/hosting AI-asset disclosure (canon §7) is unaffected; the Gen-AI
production note ships in the repo README as well.

## 3. Modding: the content-pack system IS the mod API

We already built the sandbox — canon §7: content is pure data with stable
`pack.type.name` IDs, validated against `content/schemas/` in CI, and **never
scripts in downloaded content**. Formalize it as the modding contract:

1. **A mod = a content pack** (`mymod.item.*`, `mymod.creature.*`, …) plus
   assets, validated by the same `tools/validate_content.py` gauntlet. Mods
   that fail validation don't load — loudly, with line numbers.
2. **Runtime loading:** the same `load_resource_pack` path used for weekly
   drops (data-only PCKs, Godot 4.6 partial-resource patches).
3. **Support matrix:**
   - **Solo/offline:** anything goes. Modders own their sandbox; no support
     burden beyond the validator.
   - **P2P co-op (tech/33):** the host's content-version hash is the table
     stakes — clients must match it (canon §7's login check, applied to the
     lobby). Mixed-mod co-op = host distributes its pack list.
   - **Ranked / marketplace-adjacent play:** official packs only. Mod-tagged
     items/creatures can never enter the economy (ID namespace enforcement:
     economy core accepts `core.*` + whitelisted drop packs only).
4. **What mods can never do:** scripts/logic (data only), economy writes
   (RPC surface unchanged), server behavior (server is ours).

## 4. Cheating posture with an open client

An open client makes cheat *development* easier but changes nothing about
what cheats can achieve, because authority never moved: server-side combat
truth, AOI interest management (the wallhack defense, §6), input validation,
economy invariants with nightly reconciliation (§8). Ranked adds, in order:
replay/obs-action anomaly detection (the R0 dataset doubles as a cheat
signature feed), behavioral-regression alarms (tech/25 §8), and — only if
ranked integrity demands it — light attestation (signature checks on official
builds) **without** kernel-level anything. Modded clients are welcome in solo
and P2P; they simply can't queue ranked (§3.3).

## 5. Consequences checklist

- [x] LICENSE (MIT code) + LICENSE-ASSETS (proprietary) at repo root.
- [ ] Secret-history audit before the repo goes public (PSP, vendors, tokens).
- [ ] README: build-from-source, mod authoring guide (start from
      `content/schemas/` + the arena roster as the worked example), AI-asset note.
- [ ] Content-version-hash enforcement in the P2P lobby (tech/33 follow-up).
- [ ] Economy-core: namespace allow-list for item/creature IDs (mod quarantine).
- [ ] Drop-rate tables published (already a legal posture item, business/30).

## Open questions (for Ricardo)

1. ~~License split~~ → **CONFIRMED: code MIT, art/content proprietary.**
2. Public repo timing: now (prototype honesty) or at M1 (first playable polish)?
3. Contributor posture: accept PRs (needs CLA/DCO) or read-only mirror?
