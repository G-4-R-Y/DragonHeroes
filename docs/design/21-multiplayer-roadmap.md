# 21 — Multiplayer Roadmap

> Part of the Dragon Heroes document set. Canonical names and numbers come from the
> [canon](../00-canon.md) (§1 product identity, "Hard rules", §5 PvP). Status:
> direction set by Ricardo 2026-07-17 — **nothing here is scheduled yet** except that
> infinite-world co-op (M-A) is the first multiplayer milestone. This document sequences
> the arc; [16-pvp-and-tournaments](16-pvp-and-tournaments.md) stays authoritative for
> PvP formats and rules, and [22](../tech/22-netcode-and-server-hosting.md) /
> [26](../tech/26-backend-and-services.md) stay authoritative for the netcode and backend.

## Purpose

The prototype today is **single-player**: one client, a seeded `dh-server` invoked as a
local CLI for world data, no networking. This document lays out how Dragon Heroes goes
multiplayer, in the order Ricardo directed — co-op exploration first, then PvP, then the
combat/skill overhaul PvP demands. It is a sequencing and scoping document; it commits no
dates. Where it touches formats already specified, it defers to the authoritative doc.

## Non-negotiable frame: server-authoritative from day one

There is no "add netcode later, trust the client for now" phase. The canon hard rules are
explicit: **server-authoritative everything** — the client is untrusted by design, and
all combat, loot, inventory, and trade state lives server-side. Every milestone below is
built on that footing from its first line of code. The architecture already assumes it:
the sim is a headless C++ library ([21-simulation-core](../tech/21-simulation-core.md)),
netcode is `dh-net` over an authoritative `dh-server`
([22](../tech/22-netcode-and-server-hosting.md)), and identity/matchmaking/economy run
through Nakama + the Go economy core ([26](../tech/26-backend-and-services.md)).

## M-A — Co-op exploration of the infinite world (first milestone)

**Status: first MP milestone, not yet scheduled.** The one milestone Ricardo has ordered
into first position.

The goal: two-to-a-handful of hunters exploring the same infinite world together, with
Monster-Hunter-grade boss fights as *shared* adventures (canon §1, §4). The technical
spine already exists in single-player form — the streaming window from
[29-infinite-world-streaming](../tech/29-infinite-world-streaming.md) **is** the
multiplayer area-of-interest (AOI) window. What single-player streams around one local
player, the server streams around each connected player:

- **AOI streaming windows:** `dh-server` owns the authoritative world and streams each
  client an interest-managed window (the same 5×5-chunk apron the prototype loads
  locally). AOI, zones, and snapshot cadence are specified in
  [22-netcode-and-server-hosting](../tech/22-netcode-and-server-hosting.md); the shared
  seed makes revisited coordinates byte-identical for every client (generator guarantee,
  §29).
- **Session and matchmaking:** party formation, presence, and relay/handoff run through
  Nakama ([26](../tech/26-backend-and-services.md)); the game server is authoritative for
  simulation, Nakama for identity and social state.
- **Transport:** the shipping path replaces the prototype's subprocess-JSON world dump
  with in-process `dh-godot` GDExtension calls on the client and network snapshots from
  `dh-server` — the window/apply architecture is unchanged, only the transport differs
  (§29 §"the shipping path").

### Interim LAN-party path (a real, cheap step)

Before global hosting/matchmaking is stood up, co-op can be exercised on a LAN with **no
throwaway code**: run one authoritative `dh-server` zone process on a single machine and
have other clients on the same network join it. This is server-authoritative by
construction — it is the *same* server, just reachable over LAN instead of the internet —
so it validates the real netcode path rather than a shortcut.

**Explicit recommendation — do not build a prototype-grade peer co-op harness.** The
prototype is single-player, and any quick peer-to-peer or client-hosted "just let two
copies see each other" harness would violate server-authoritative-everything and would be
**throwaway** the moment `dh-net`/`dh-server` co-op lands. Recommend against it unless
Ricardo explicitly orders a disposable demo. The LAN path above gets a room full of
people into the same world without incurring that debt.

## M-B — PvP: duels → arenas → tournaments

**Status: not scheduled. Folds into an existing spec.** PvP (1v1 duels, then 3v3 arenas,
then tournaments) is already fully designed in
[16-pvp-and-tournaments](16-pvp-and-tournaments.md) — modes, Trophies/Glory, ranked gear
budget, the marketplace-funded prize pools, the legal no-entry-fee rule, and Champion
Ghosts. **This roadmap does not re-specify any of that.** Doc 16 is authoritative; this
entry only fixes PvP's *place in the sequence* — after co-op exploration proves the
server-authoritative combat loop under network conditions, and gated on M-C below.

The dependency is real: doc 16 assumes "the damage model and hitbox rules are identical
to PvE" on the same 30 Hz authoritative sim. That assumption is exactly what M-C exists
to make true and competition-grade.

## M-C — The combat/skill-system overhaul PvP requires

**Status: not scheduled. Prerequisite for competitive M-B.** Ricardo's direction,
verbatim (2026-07-17):

> "the current one is too sketchy with messy hitboxes and too simple combat mechanics —
> we'll need an overhaul to include a wider set of more complex skills and builds"

Expanded honestly into workstreams. None of these are started; they are scoped here so
the size of the bet is visible before it is scheduled.

### 1. Deterministic server-side hitboxes/hurtboxes

The prototype currently derives collision from sprite scale — "hitboxes follow sprites
(bestiary scale multiplies collision radius)" (canon §12.20). That is a presentation-scale
hack: fine for a single-player feel pass, **unacceptable for PvP**, where two clients must
agree bit-for-bit on whether a hit landed. The overhaul moves hitboxes and hurtboxes into
the **sim core as first-class deterministic shapes** — the precise 2D primitives the canon
already specifies (circles, capsules, swept arcs, with scalar z-height for flight/jumps,
canon §1) — authored per skill/creature and independent of sprite pixels. Combat
correctness lives in `dh-sim`, not in the renderer.

### 2. Skill archetypes beyond stat-sticks

Today's executor covers a solid but simple set (projectile / nova / cone / melee-arc /
dash-strike / buff / field / chain, canon §12.21). "More complex skills and builds" means
new archetypes, all expressed as **data in the content-pack schema** so weekly drops never
need engine work (canon directive 4):

- **Channels** — sustained skills with tick cadence, interrupt rules, and movement cost.
- **Combos** — sequenced inputs / follow-ups with timing windows (the Veilblade Combo
  charge stacks are a first hint of this shape, §12.21).
- **Movement skills** — dashes, blinks, leaps as *combat* tools with i-frames and
  positioning payoffs, deterministic against the sim hitboxes above.
- **Auras** — persistent radius effects on self/allies/enemies.
- **Triggers / synergies** — on-hit / on-crit / on-status / on-kill payoffs expressed as
  data (extending the existing data-expressed synergies: Ignite spread/detonate, Shatter,
  Expose, Bleed stacks, §12.21), so builds emerge from combinations rather than a bigger
  stat pile.

All of the above must be schema-validated in CI against `content/schemas/` (canon
directive 4) so the wider skill set stays pure content.

### 3. Build identity

A wider skill set is only meaningful if choices are legible and committal:

- **Keystones** — high-impact nodes with real tradeoffs (the tree already ships one
  keystone per class, §12.21; the overhaul widens this into build-defining choices).
- **Respec economy** — how (and how expensively) players re-spec, tuned so builds are
  identity, not disposable loadouts — a design/economy question, cross-referencing
  [10-classes-and-progression](10-classes-and-progression.md) and
  [15-economy-and-marketplace](15-economy-and-marketplace.md).

### 4. Netcode implications

A richer, faster combat model raises the bar on the network model
([22](../tech/22-netcode-and-server-hosting.md)):

- The sim stays at a **30 Hz fixed authoritative tick** (canon §1); the client
  interpolates to a locked 60 FPS.
- **Rollback vs. delay-based netcode for duels** is an **open question flagged for the
  sim team** — 1v1 duels are the mode most sensitive to input latency, and the choice
  (deterministic rollback, favoring precise low-latency duels, versus delay-based with
  lag compensation as doc 16 currently assumes) is a foundational sim/netcode decision,
  not a tuning knob. It should be resolved before M-C combat is built, not after.

## Milestone status summary

| Milestone | What | Status |
|---|---|---|
| M-A | Co-op exploration of the infinite world (AOI = the streaming window) | **First MP milestone** — directed, not yet scheduled |
| M-A (interim) | LAN-party: one self-hosted `dh-server` zone, clients join over LAN | Available cheaply; recommend over any throwaway peer harness |
| M-B | PvP duels → arenas → tournaments | Not scheduled; folds into [doc 16](16-pvp-and-tournaments.md) (authoritative), gated on M-C |
| M-C | Combat/skill-system overhaul (deterministic hitboxes, new archetypes, build identity, netcode model) | Not scheduled; prerequisite for competitive M-B |

## Open questions (for Ricardo)

1. **M-A scope:** confirm co-op exploration (shared infinite world + shared boss fights)
   as the target for the first multiplayer milestone, and the party-size ceiling to
   design toward.
2. **LAN interim:** approve the self-hosted-`dh-server`-over-LAN path as the interim
   co-op step, and confirm no throwaway peer harness is wanted.
3. **M-C timing:** confirm the combat/skill overhaul (M-C) must land before competitive
   PvP (M-B), rather than shipping duels on the current combat model first.
4. **Duel netcode (for the sim team):** rollback vs. delay-based netcode for 1v1 — this
   is the foundational open question that gates M-C combat architecture.
