# Dragon Heroes — Design Document Set

> **Status:** complete draft, conforms to canon **v0.2.1** (2026-07-08). Written for
> Ricardo's review before/alongside M0 implementation. Every doc ends with an
> "Open questions (for Ricardo)" section — those are the decisions awaiting you.

## How to read

1. **[00-canon.md](00-canon.md)** — the decision log and glossary. Single source of
   truth; every other document defers to it. Read first.
2. **[01-vision-and-pillars.md](01-vision-and-pillars.md)** — what the game is and why.
3. Then by interest: `design/` for game systems, `tech/` for architecture,
   `business/` for legal/roadmap. Cross-links are dense; any entry point works.

## The set

| Doc | One-liner |
|---|---|
| [00-canon](00-canon.md) | Decisions, hard rules, glossary, repo layout |
| [01-vision-and-pillars](01-vision-and-pillars.md) | Pitch, pillars, core loops, positioning, top risks |
| **design/** | |
| [10-classes-and-progression](design/10-classes-and-progression.md) | Base rig, attribute web, 6 classes, skill trees, loadouts |
| [11-combat-and-controls](design/11-combat-and-controls.md) | Combat feel, 7 damage types, hitboxes, fields, inputs per platform |
| [12-world-and-biomes](design/12-world-and-biomes.md) | The Hunt (expeditions), 5 biomes, death rules (owner), POIs |
| [13-creatures-and-bestiary](design/13-creatures-and-bestiary.md) | Tier×rarity, MH-grade bosses (≥5 skills), Legendary duos, pets |
| [14-items-loot-and-affixes](design/14-items-loot-and-affixes.md) | Bases/affixes/stats tables, power cap, sinks, bind rules |
| [15-economy-and-marketplace](design/15-economy-and-marketplace.md) | Faucets/sinks, marketplace UX, anti-RMAH design, pets as assets |
| [16-pvp-and-tournaments](design/16-pvp-and-tournaments.md) | 1v1/3v3/Gloomfall, Trophies/Glory, tournaments, Champion Ghosts |
| [17-art-direction](design/17-art-direction.md) | Pixel-art identity, palettes, telegraph colors (owner), gen-AI pipeline, 60 FPS budgets |
| **tech/** | |
| [20-architecture-overview](tech/20-architecture-overview.md) | System map, one-sim-three-consumers, data flows, decision table |
| [21-simulation-core](tech/21-simulation-core.md) | C++ sim workspace, entity store, tick pipeline, fields, determinism |
| [22-netcode-and-server-hosting](tech/22-netcode-and-server-hosting.md) | ENet protocol, prediction, AOI, zones, Agones/Edgegap |
| [23-content-pipeline](tech/23-content-pipeline.md) | Schemas, validation gauntlet, PCK patches, weekly-drop runbook |
| [24-procedural-world-generation](tech/24-procedural-world-generation.md) | Noise stack, chunks, delta persistence, generator versioning |
| [25-creature-ai-and-rl](tech/25-creature-ai-and-rl.md) | BT/utility profiles, PufferLib self-play, Champion Ghosts, eval gates |
| [26-backend-and-services](tech/26-backend-and-services.md) | Nakama, Go economy core, ledgers, PSP integration, liveops |
| [27-security-anticheat-and-economy-integrity](tech/27-security-anticheat-and-economy-integrity.md) | Threat model, dupes, fraud, kill switches, rollback playbook |
| [28-generation-service](tech/28-generation-service.md) | GenForge: lore-grounded creature/item/skill candidate generation, curation gates |
| **business/** | |
| [30-legal-payments-compliance](business/30-legal-payments-compliance.md) | Brazilian gambling/minors law, PSPs, tax, AML, LGPD — **read before launch decisions** |
| [31-roadmap](business/31-roadmap.md) | M0→M6 milestones, exit gates, parallel tracks, risk register |

## Research digests

The July 2026 web-research pass that grounds these docs (facts, laws, versions,
precedents, sources) lives in [research/](research/):
[rl-creature-ai](research/rl-creature-ai.md) ·
[engine-netcode](research/engine-netcode.md) ·
[pix-marketplace-legal](research/pix-marketplace-legal.md) ·
[live-content-architecture](research/live-content-architecture.md) ·
[backend-platform](research/backend-platform.md)

## Cross-cutting open decisions

The full per-doc lists live in each doc's closing section; the ones that gate the
most work (see also canon §12):

1. **Legal engagement (gates launch):** engage the Brazilian gaming-law firm now —
   the parecer on cash-out, ECA-grade age verification, and PSP written confirmation
   of the RMT vertical are all on the critical path (business/30).
2. **Team shape (gates M1):** confirm the five-role minimum (C++ systems, Godot
   gameplay, Go backend, pixel artist, designer) or recalibrate the roadmap.
3. **Kubernetes vendor** for the Agones fleet: GKE southamerica-east1 vs EKS
   sa-east-1 (tech/20).
4. **Ranked gear policy:** per-slot power budget (current canon) vs normalized
   tournament realm (design/16).
5. **Go economy-core carve-out** under the everything-in-C++ directive (canon §12.7).
6. **M0 benchmark gate numbers** and reference server SKU (tech/21 §9).
7. **Player-made field combos at launch** — the sim supports players triggering
   lava-style combos with their own skills; enable (emergent, on-brand) or restrict
   to Legendary kits until a balance pass (tech/21).
8. **Pet skill-roll shape:** 3–7 skills, ~70:30 signature-to-shared weighting, and
   whether higher-rarity captures roll more skills (design/13 §7.1).
