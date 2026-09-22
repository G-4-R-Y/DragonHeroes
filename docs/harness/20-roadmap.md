# Roadmap — the one demand ledger (2026-09-10 → 2026-09-21)

Ricardo decides DIRECTION (which lever, when); harnesses execute inside it.
Every item points at its law doc.

**The roadmap rule (CLAUDE.md, 2026-09-12):** this file is the single demand
ledger. EVERY new ask lands here the moment it arrives, verbatim enough to be
unambiguous; at interruptions the new demands *and* the current strategy state
are appended BEFORE work continues. Nothing asked is ever forgotten.

**Split on 2026-09-21.** This file had grown to 3,352 lines because every
investigation wrote its whole narrative into it, so the live surface — what is
actually open — was buried under closed work. The narrative moved, verbatim and
complete, to `21-work-journal.md`. Nothing was summarized away or deleted. What
remains here is the ledger: one row per demand, what is in flight, what is
queued, what waits on Ricardo.

| file | what it holds | when to read it |
|---|---|---|
| `20-roadmap.md` (this) | every demand as one row; NOW / NEXT / ON RICARDO; the standing buckets | first, every session |
| `21-work-journal.md` | the full narrative: verbatim prompts, interruption checkpoints, investigation write-ups, closed-item detail | when you need the *why* behind a row |
| `10-systems-map.md` | every system's status, files and gate | before touching a system |
| `README.md` | durable harness memory: invariants, gates, doctrine, environment | before running anything |
| `../../HANDOFF.md` | the volatile delta from the last session | when resuming |

**Statuses:** NOW (in flight) · NEXT (queued, decided) · PICK (awaiting
Ricardo's call) · SCHEDULED (decided, sequenced) · DESIGN (research first) ·
BUDGET (blocked on money) · ANSWER (a question owed a reply, not a task) ·
DONE.

## 1. The demand table — every ask, R01 → R72

R01–R43 are the 2026-09-12 quota-outage recovery set, recorded verbatim then
and unchanged since. R44–R55 came in 2026-09-13→19. R56–R71 arrived
2026-09-21, R72 latest. Detail for any row is in `21-work-journal.md`;
search it by id.

| ID | Status | Recovered demand | Law / gate |
|---|---|---|---|
| R01 | NOW | Audit and improve movement, attack and skill animations; make melee skills visually/mechanically distinct with satisfying arcs. | canon §12.45, design/17/18/24/26; real action captures and combat outcomes |
| R02 | SCHEDULED after 2D | Review rebirth files, build an Unreal-quality boss fight and improve the "plebs" model; get the 3D asset pipeline running. | canon §12.44, rebirth/docs; local GL capture and real fight/asset gates; determine intended model from files |
| R03 | DONE | Add Return to Main Menu alongside Quit in Haven. | UI/Session flow; renewal_probe real Haven button → saved gold → title |
| R04 | DONE | Show companion sprites and editable nicknames in stables. | design/13; renewal_probe nickname edit/save/reload + stables/mounts GL captures |
| R05 | SCHEDULED | Overhaul the UI fully; replace ugly character-menu arrows; simplify mount information into organized cards. | design/17/26, typography doctrine; EN/PT fitting, input and capture gates |
| R06 | SCHEDULED | Make Orun's design/concept contract the default creature-generation standard; rework ALL existing creatures and automate it. | design/26, tech/34, content schemas; complete catalog coverage, animation/atlas/style/budget gates |
| R07 | DONE | Improve visibility/brightness/contrast and add an options setting. | design/17/19; renewal_probe settings round-trip + actual bright/dark GL captures |
| R08 | DONE | Unload distant hordes from active memory/cap, then restore them when revisited. | tech/29 prototype residency; actual identity/HP/death/pair/cap/co-op/water gate + streamed GL return |
| R09 | SCHEDULED | Fix distant map-generation stalls and missing biome variety; overhaul biome textures and atmosphere to match the shrine aesthetic. | tech/24/29, design/17/26; long-distance streaming/biome gates and captures |
| R10 | SCHEDULED | Redesign HP/dodge HUD and make the Ember Flask clearly visible. | design/11/17; cooldown/resource readability and gameplay captures |
| R11 | SCHEDULED | Turn Haven into a place with NPCs; enrich forge/enchanting and related facilities; salvage items into crafting materials; craft improved/unique/fixed-rarity randomized gear. | design/14/15, no paid randomness; inventory/material conservation, persistence and UI outcomes |
| R12 | SCHEDULED | Upgrade all particle families to the dark-VFX quality bar; add wings, auras and cosmetic items earned through boss drops, hunting, quests, crafting, forge and enchanting. | design/18, economy boundaries; bounded VFX, acquisition/equip/save outcomes |
| R13 | SCHEDULED | More classes, build choices, meaningful skill synergies, aesthetic customization and distinct equipment visuals; reflect them in the asset pipeline. | design/10/11/26, stable data IDs; real skill/build effects and visual coverage |
| R14 | SCHEDULED | Explain and provide a sustainable local asset pipeline; avoid permanent dependence on cloud credits. | tech/23/34, canon local-compute directive; offline generation and explicit optional-provider costs |
| R15 | DONE | Fix the PNG/application-icon attachment or packaging problem reported for the binary. | tech/34 packaging; real GIO custom-icon URI + validated host launcher + three installer/action tests |
| R16 | SCHEDULED | Hunter levels improve equipment-rarity odds; add something that scales indefinitely. | progression audit in design/24; design an endless PvE/mastery track with bounded numeric combat and validated rarity curves; preserve saves |
| R17 | NOW / recurring | Push ALL changes, including those completed after quota resumed, resolving upstream conflicts; regenerate playable Codex binaries. | harness suite, exact source manifests, GitHub remote equality |
| R18 | NOW / design then implementation | Weekly item enchantments are the strongest moat: on-hit chain lightning, ignite, lifesteal, meteors/showers, impact thunder, AI clones, granted actives and class-tree synergies. Rarity increases behavioral identity, not an endless power ladder; preserve old item value. | canon §12.47; design/27; bounded native trigger graph and real equipped effects |
| R19 | NOW / replaces R16's endless-power interpretation | Endless XP awards exclusive cosmetic reward caches; no paid random access. Investigate an asymptotic rarity-luck bonus, including new-player fairness and supply inflation; characters/equipment never season-reset. | canon §12.47; design/27; XP rollover, acquisition and bounded rarity simulations |
| R20 | SCHEDULED with R13 | PvP needs deliberate counterplay, defenses, readable commitments and elemental interactions inspired by Magicka/Wizard Wars; stop rewarding button speed alone. | design/27; native duel outcome and reaction-window gates |
| R21 | SCHEDULED | Open-source/mod ecosystem; community voting nominates mods for official promotion; define curated compatibility/security/art/balance/license gates and contribution credit. | canon §12.47; design/27; validate one mod submission through promotion tooling |
| R22 | DESIGN / research | Proposed contributor pool 10% of distributable profit, weighted by accepted contributions (dungeons/items etc), plus 10% for event prizes. Compare current marketplace fee model with subscriptions/direct Pix; preserve uncertain alternatives and superseded allocations explicitly. | business/33; researched accounting/legal/PSP boundary; no unreviewed money movement |
| R23 | SCHEDULED | Separate modded/local and official character provenance while preserving beloved character identity; validate offline→official boundaries. Research full anti-cheat, including the blockchain question, impossible casts/kills, authoritative drops/stats, replay and abuse detection. | tech/36; adversarial protocol/provenance tests; reject forged client loot |
| R24 | SCHEDULED | Guilds/allegiances, territorial map and wars, contested legendary loot, allied raids and raid-contribution competition; research/load-test a 100v100 ambition. | design/27, tech/36; staged native 20/50/100v100 budgets, no unsupported capacity claim |
| R25 | SCHEDULED | Named neural bot opponents during thin queues, coherent weekly item builds/meta exploration and leaderboard participation; explicit bot identity; rating based on skill/uncertainty rather than match-count farming; assess bounties/soft MMR seasons without character resets. | design/27, tech/36; rating simulations, bot eligibility and matchmaking gates |
| R26 | NOW / recurring | Preserve ALL pending messages, comments and prompts verbatim as well as roadmap summaries; continue execution. Explicitly improve the PLAYER sprite along with all environments/textures/particles. | requests/2026-09-12-recovery.md; R06/R09/R12; captures and durable handoff |
| R27 | DONE / prototype | Dropped loot and projectiles survive travel offscreen; preserve original item rolls and finite flight, prevent duplicate collection/impacts, and free distant loot nodes. | tech/29; GROUND STATE OK: full bag/cap, repeat visit/collection, removed-caster offscreen hit and cleanup |
| R28 | NOW with R06/R14/R18 | Every generated content set needs lore, archetypes, interwoven stories and links to previous releases; support political events and an evolving universe. | canon §12.48; design/28; locally validated narrative manifest with stable cross-release references |
| R29 | SCHEDULED with R09/R11 | Rich procedural roaming: visibly distinct biomes, dungeons, details, quests, NPCs, villages, events and rare roaming legendary bosses; legendary/mythic/divine/demonic loot fantasy. | design/12/28, tech/24/29; native generation/encounter gates and actual exploration captures; demonic theme is not silently a new numeric rarity |
| R30 | NOW / recurring with R06/R14/R26 | Explain the enhanced local generation pipeline; bring ALL existing creatures to the new aesthetic; keep file-specific documentation and continuation context current. | tech/34, design/26/28; catalog coverage, local reproducibility and source-file documentation checks |
| R31 | SCHEDULED / future world continuity | Player decisions and guild actions influence political events and upcoming season stories, visibly shaping the world without resetting characters. | canon §12.48; design/28, tech/36; attributed world-outcome ledger and reviewed story branches |
| R32 | DONE | Investigate intermittent Hunt-only exit leak: MultiMesh, mesh, material, shader and resource-in-use warning (~1/4 boot gates); preserve other session's work. | world_gen off-tree water cleanup; forced-staging GROUND STATE OK + 12/12 verbose HUNT EXIT OK |
| R33 | SCHEDULED / design | Connect player/[AI] mercenaries and notoriety to bounties claimed once; prevent bounty farming/inflation, add useful gold sinks and assets retaining value through death penalties. Preserve the supplied CipSoft/Forge comparison for research. | design/15/27/28, tech/36; escrow/idempotent claim and anti-collusion/supply simulations; explicit Hunt PvP policy before activation |
| R34 | URGENT NOW — user priority | User reports 14 FPS in Codex build on RTX 4080, possibly while train_all runs. Profile actual exported Hunt, sustain 60 FPS, make training/play coexist efficiently and document measured limits. | canon performance directive, tech/29/32; actual GL/export frame-time capture with/without training; do not loosen budgets or stop existing training implicitly |
| R35 | URGENT NOW after R34 | Flask sometimes does not heal on press and appears to heal later/on recharge. Reproduce against the exact Codex build and fix input/charge/heal timing with clear feedback. | design/11, R10; actual button/key → immediate heal outcome, empty/full/dead/recharge cases and export test |
| R36 | NOW with R01/R06/R29 | Souls-like learnable boss animation combos; repeated/old animations and sprites remain. Make roaming random bosses and mercenaries with enchanted builds real, overhaul dungeon gameplay beyond an arena/mob test with guaranteed rare conclusion loot; use the approved Orun boss aesthetic everywhere. | design/13/26/28, tech/35; animation/contact/recovery captures, native encounter outcomes and exploration spawn coverage |
| R37 | NOW with R05/R13 | Skills UI is cluttered and oversized; rune socketing is hard to understand; provide a dedicated readable skill-tree screen requiring less scrolling. | design/10/17/26; real rune selection/socket/remove feedback, tree navigation and EN/PT captures |
| R38 | NOW | Fix glitched arena Back button and provide Train All in the arena/training interface. | design/23, tech/37; real navigation outcome and explicit user-triggered all-roster training dispatch |
| R39 | DESIGN / research | Give gold exciting purchases: mounts, items/special items and mythical/legendary/angelic/demonic pet eggs; evaluate player-market gold packages and asset-saving incentives. | design/15, canon no paid randomness, business/30/33; gold flow/sink simulation; no cash→gold→random egg/reroll path; disclosed fixed outcomes or earned-only noncashable RNG routes need design resolution |
| R40 | DONE / diagnosis limited | User reports session quota reset and questions the out-of-credits rejection. Retry a harmless previously rejected call; distinguish approval-service report from verified account balance. | Sept 13 read-only escalation retry succeeded; actual balance/cause unknown, no affinity/process change made |
| R41 | NOW with R17 | Explain the Codex build command and why the main binary lacks changes; rebuild current source and make package/source identity obvious so the reviewed work is playable. | tech/34 packaging, USAGE; clean source receipts, Linux actual export, main/Codex parity audit |
| R42 | NOW with R06/R28 | Audit Orun's missing provenance and five missing animation clips; either explicitly backfill unverifiable historical provenance or regenerate through the current pipeline, then supply the six required clips before calling it the creature quality reference. | design/26, tech/34; provenance/hash/clip coverage, source-to-runtime animation gates and actual frames |
| R43 | NOW with R10/R37 | Cooldowns require too much attention in fast combat; improve skill readiness UI and peripheral visual cues so players need not constantly watch timers. | design/11/17/26; real cooldown→ready state transition, no false-ready/cue spam, EN/PT GL captures and bounded draw work |
| R44 | DIAGNOSED 2026-09-19, NOT EDITED (collision) | Bosses still do not spawn like hordes do. | with R36/R29. Cause found: bosses exist only in `main.gd::_spawn_packs`; `_repopulate()` and frontier repop field only `_ground_species`/`_caster_species`. Fix = a rare boss slot in the pressure roll, one live boss cap, distance-ladder gated. Left to the other session's stream (`encounter_residency.gd` is live work in this seam). **R61 is the same bug, re-reported.** |
| R45 | DIAGNOSED 2026-09-19, NOT EDITED (collision) | Still a single biome in play. | with R09/R29. It is a CONTENT gap first: `content/core/biomes/` holds one record (`gloamfen.json`) while `sprites.gd`/`post.gd` already blend two biomes. First deliverable = four more biome records (canon §4) + world_gen's biome field. |
| R46 | ANSWER owed | "How are assets gen going?" — a question, owed a status answer, not a task. | 13b/13c; the local image-gen repo is still not in `reference_repos`. |
| R47 | NOW | Document the reward function fully, INCLUDING every version with its rationale — the whole story up to the current one. | tech/25 §5.2, tech/37; a versioned changelog, not a snapshot. Open inside it: `R_TIME` was never re-judged after being zeroed. |
| R48 | NOW | GenForge console cannot return to the main menu. | genforge console scene; real Back navigation evidence (same class as R38's arena Back). |
| R49 | NOW | Arena interface needs polishing to fit everything in. | design/23/17; COLLISION RISK — the other session owns `game/arena/console.gd`, check before editing. **R60 overlaps.** |
| R50 | BUILT + RUN 2026-09-19 (2/7 pass the gate; the run exposed R55) | Learn from SCRIPTS first, then self-play once reliably winning; then a train_all run with enough steps to converge. | tech/25 §4.2, `tools/train_all.sh`; a real curriculum + a converged run, not a smoke run. |
| R51 | NOW with R50 | Watch a match from the console — current or last-best, for dh-env AND the arena, as a debugging tool. | design/23. Answered half-yes: the Godot arena is watchable today; dh-env is headless C++ with no renderer, so it needs a per-tick TRACE dump replayed in the arena. That trace is also the instrument the parity work needs. |
| R52 | NOW / details received 2026-09-19 | A new asset generator: hi-fi dark-fantasy pixel-art SPRITES in the Dead Cells / Phantom Tower register — master prompt + mandatory negative prompt + five rendering pillars. Benchmarked against "astra". | genforge.hifi (built, commit ab2cd93); art/ style bible; Godot CanvasTexture normal/emissive. Open: real generation once Ricardo picks the image model, the astra bench, pose-by-pose animation, a lit capture, the 13b local backend. |
| R53 | DONE 2026-09-19 | A brief `.md` in the REPO ROOT explaining the hyperparameter changes (masking, greedy eval/promotion, β + move-std annealing, reversible promotion, snapshot reservoir, plateau stop). | `TRAINING_HYPERPARAMETERS.md` at the root. |
| R54 | NOW / standing | Document EVERY experiment with its hyperparameters — a ledger, not prose: run id, knobs, result, verdict, kept or not. Reconstruct past runs too. | `docs/tech/39-experiment-ledger.md`; `tools/train_run.sh` already writes `config.json` per run — the ledger indexes them. |
| R55 | LARGELY CLOSED 2026-09-21 | The converged nets win in dh-env and lose in the arena on the SAME greedy decode. Find the divergence, then retrain. | tech/39 §2 (R55-b rows), `ml/eval/env_parity.py`. Four content divergences found by damage-by-source and fixed (Fiery affix absent from the sim; native kit driver on the wrong channel; aim noise on the kit fan; 3.0 px storm bolts) plus one harness bug (two clocks). Matrix worst ratio 3.17 → 1.93. **Residual:** totals agree per channel but fights run ~1.8× longer in dh-env — the endgame, not the exchange. ~~Next: port `creature.gd::_separate` into the sim~~ — **that hypothesis is DEAD (2026-09-21)**: arena bodies are `bot_drive`, so `_chase` never ran there either and neither runtime separated. R59 is now an independent fix, landed, and the residual has no candidate cause. Next: instrument the endgame specifically (time-to-first-death vs time-from-first-death-to-episode-end), then re-run at 64 eps, retrain, raise the gate above 4 episodes. |
| R56 | **DONE 2026-09-21** | GPU processes are not ended properly after training in the console. | `console.gd::_spawn_league` now launches the trainer under `setsid`, so it owns a session — and `_stop()` kills the whole PROCESS GROUP (`kill -KILL -PGID`) instead of `pkill -KILL -P <pid>`, which reached exactly ONE generation and left anything a level deeper alive holding the card. The group kill is gated on `pgid == pid` (`_resolve_pgid`), the proof that setsid took and that the group is ours: Godot's own children inherit GODOT'S group, so signalling an inherited group would kill the editor. `_reap_group()` also sweeps on natural exit, because a crashed trainer orphans its workers to init where nothing reaps them. Gate: `bash tools/trainer_stop_test.sh` → `TRAINER STOP OK` — it asserts both halves against a fixture with a real grandchild (`old path leaked 1, group kill reaped 3/3`). Arenas run on LOCAL GPUs — a leaked trainer costs the next run. |
| R57 | NOW / bug | Every captured mob turns into a gloamfen stalker. Wanted: maximum variety — every species keeps its own chassis, AND bosses are capturable as mini-pets with their signature skills, levelling alongside the player. | design/13 §7.1; root of NEXT #6 (bond with ALL creatures) and R65 (pet levels/skills). |
| R58 | NOW / bug | The HP potion does not heal over 2 s — it is meant to be a heal-over-time, not an instant top-up. | **Re-scope needed (2026-09-21):** `flask_probe` already passes green with `FLASK OK — real R/click, 20% now + 20% over 2s, exact budget, recharge never heals`. So the heal-over-time IS implemented and gated at the flask. What Ricardo saw is something else — candidates: the HoT is cancelled on damage/dodge, the HUD bar shows only the instant tick so the drip is invisible, or it is a *different* potion (R62's enchanted potions, or the pet's). Reproduce in a real hunt before touching code. |
| R59 | **DONE 2026-09-21** | Creatures do not collide with the player — they stand *on top of* him, where he cannot hit them. "Bizarre stuff and a bit annoying." | Separation now runs in `creature.gd::_physics_process` every tick in every state (it used to be a line inside `_chase`, which returns the moment a body is inside `attack_reach * 0.9` — it switched OFF at exactly the distance where bodies pile up). Split into `_separate_player` (rate 12/s) and `_separate_creatures` (rate 4/s, gated by `bot_drive or _state != "idle"`), the same two calls commented out in `wisp.gd`/`terravore_colossus.gd`, and ported to `dh-sim` as `Arena::separate_bodies()` (step 2b) so the four runtimes stay in parity. Test: `test_arena_bodies_separate_instead_of_standing_inside_each_other`. **CORRECTION to the R55 row below: the arena never ran `_separate` either** — arena bodies are `bot_drive`, so `creature.gd` parks `_state` at `"idle"` and `_chase` never executes. Separation was therefore NOT the R55 divergence; that residual is re-opened with no candidate cause. |
| R60 | NOW / bug | The arena console lost its value labels (generation etc. render without captions), and the interface must be legible at 20 M-step values. | design/23; thousands separators / SI suffixes and wider boxes. Overlaps R49; same collision warning on `console.gd`. |
| R61 | NOW / bug | Bosses are not spawning randomly among new hordes while exploring — Ricardo expects to meet them out in the map, not only at lairs. | **Same bug as R44**, already diagnosed; the fix is the boss slot in the pressure roll. |
| R62 | NEXT / content | More of every axis: creatures, bosses, loot, skills, pets, mechanics, **and potion enchanting with special effects**. | Data-only by canon §10 — new `pack.type.name` ids validated against `content/schemas/`. Potion enchanting is the one new SYSTEM in this line. |
| R63 | NEXT / design then implementation | Better skill design and playability; probably MORE skills, to make combat more dynamic — the current kit reads as too static. | design/10/11/26; pairs with R37 (skill-tree screen) and R64. |
| R64 | NEXT | Visual cues for skill cooldowns. | design/10/17; HUD work, pairs with R43 (cooldowns need too much attention) and R63. |
| R65 | NEXT | Pet levels and pet skills, so a pet scales with the player instead of falling off. | design/13; depends on R57 landing first. |
| R66 | NEXT | Item scaling pass — asked again against the current numbers (previously audited 2026-09-12). | design/24; with R16/R19. |
| R67 | NEXT / new system | Mob kill counter → streak rewards: bonus gold and XP while it runs, and when the streak ENDS on the timer after a LOT of kills, a chest drops from the sky with legendary loot. Streak length decides the tier. | design/11/15; hooks `on_creature_died` (the same feed the Ember Flask rekindle uses). |
| R68 | SCHEDULED / event content | Multi-boss events (2, 3, 4, 5+). Named: *Giant Graveyard* (seven giants), *Dragon Nest* (baby + adult dragons). | design/13/29; with R36/R29. |
| R69 | SCHEDULED / the headline event | **The DRAGON COUNCIL** — 12 legendary interdimensional dragons join forces to kill you. A dungeon/questline, not an arena fight: 12 councils, some in COUPLES with combo mechanics, some alone with special skill mechanics; the 10+-skill mythical/celestial/demonic tier. Clearing all 12 unlocks special loot + a mechanic + a skill. Near-RAID difficulty, gated behind prior ARTIFACTS that open the council dimension, meant to take real time to unlock. | design/13/29, the living-world generator; the largest single content ask on the ledger. |
| R70 | SCHEDULED | Bot "player" events: bot players hired as MERCENARIES under your bounty, and bot players BOUNTY-HUNTING you — raising and spending your own bounty. | design/15/16; this is the PvE-facing half of the leaderboard system at NEXT #6g, and it lands on R33 (bounty/notoriety economics, anti-farming, gold sinks). |
| R72 | **ANSWER DELIVERED 2026-09-21** (rebirth/docs/02-status.md §3.1); the boss fight is SCHEDULED | *"people are using a pipeline with meshy + blender + unreal for game dev, is it a natural stepup? perhaps that's what we were looking for when testing out the experiments with 3d stuff. Later we will make a boss fight to test out the concept"* (2026-09-21). Two parts: (a) a written judgement on Meshy → Blender → Unreal against what we already have (TripoSR installed locally, `genforge/pipeline/mesh_gen.py` with a provider seam, the parked Cloud Run GPU tier, `rebirth/unreal/`), and (b) **a boss fight built through that pipeline as the test of the concept**. | tech/31 (image-to-3D), rebirth/docs, canon §12.44; R02 is the Rebirth track this lands in, and the concept-render unblock it shares is the same one blocking the TripoSR spike. |
| R71 | SCHEDULED | Questline themes beyond the council: mercenary hunt contracts, political sabotage, underground-city business, political power disputes, wars, conflicting interests, powerful-people scandals. | `docs/design/28-living-world-and-weekly-lore.md` + the weekly-lore generator; with R28/R31. |

## 2. NOW — in flight, and the strategy behind it (2026-09-21)

Ricardo's standing order is "finish up all the other tasks in the roadmap",
and his latest batch says bugs first. Order below is the order to work in.

1. **Port `creature.gd::_separate(delta)` into `sim/` and give it the player
   body too.** This is R59 and R55's residual at once: the arena separates
   overlapping bodies, the sim does not, which is why dh-env fights run ~1.8×
   longer with identical per-channel damage totals, and why creatures stand on
   top of Ricardo where he cannot hit them. Then re-run the parity matrix at 64
   episodes and retrain — best-greedy checkpoint export in `ppo.py`, then
   `STEPS=60000000 PLATEAU_UPDATES=80 PLATEAU_DELTA=0.02
   PLATEAU_MIN_STEPS=20000000 CLONE=heuristic tools/train_all.sh --ppo`, with
   the gate's `--episodes` raised above 4 (4 cannot separate 0.6 from 0.9).
2. **R56** — reap the trainer's process group and free VRAM on console stop.
3. **R58** — the potion's heal-over-time.
4. **R60** — the console's missing value labels and 20 M-step legibility.
5. **R61 / R44** — a rare boss slot in the horde pressure roll. Check
   `encounter_residency.gd` first: the other session owns that seam.
6. **R57** — captured-species variety, then boss mini-pets (unblocks R65).
7. Then the content and event lines, R62 → R71, largest last.

**Standing, always open:** R17/R26/R30 (push everything, preserve every
prompt verbatim, keep the docs current in the same change), R54 (every
experiment in the ledger).

**Owed answers — questions, not tasks.** These are replies Ricardo is waiting
on, and they cost minutes, not days:
- **The asset pipeline and the model question** (*"we aren't generating
  through any api, are we? if so, use gpt luna instead of any other… as it's
  cheap"*). The hifi pipeline has never called an API — it is offline end to
  end. GPT-5.6 Luna is OpenAI's cheap TEXT tier and does **not** do image
  generation, so it cannot be the sprite model; it is the standing default for
  any future TEXT call in GenForge. The cheap OpenAI image tier is
  `gpt-image-1-mini`. The image model is now a knob
  (`GENFORGE_HIFI_IMAGE_MODEL` / `--model`) — **which id to point it at is
  Ricardo's decision.**
- **R46** — "how are assets gen going?" still owed a written status.
- **R72** — is Meshy → Blender → Unreal the natural step up? Owed a written
  judgement against the local TripoSR spike, the `mesh_gen` provider seam and
  the parked Cloud Run tier, and then a boss fight built through whichever
  pipeline wins, as the concept test. **ANSWERED 2026-09-21** in
  `rebirth/docs/02-status.md` §3.1: Meshy is a provider swap behind a seam we
  already have, Unreal is blocked on an Epic install and not on tooling, and
  the only real gap is **Blender** (no retopo/UV/rig/LOD/bake station exists).
  The step up that pays into the SHIPPING 2D game is mesh → Blender → render to
  sprite sheets, the way Dead Cells was made. Boss fight goes in `godot3d/`
  unless UE gets installed. Remaining work: install Blender, add the
  `blender_clean` stage, then the fight.
- **`builds.json` kit ranges mix units** (CONTENT, not parity): cinder_drake's
  `bolt_volley range 10.0` and `field_cast 9.0` against bog_golem's `112.0`
  (= `7.0 * TILE`). The 7–10 values were almost certainly meant as TILES. Both
  runtimes read the same raw number, so it is not a divergence — but a 10 px
  range makes bolt cadence a knife-edge. Changing it is a balance decision plus
  a full retrain: **Ricardo's call.**

**Blocked on a question, do not guess:** 13b (the local image-gen repo comes
from Ricardo AFTER the rest of the roadmap, to be adapted behind the
`ImageBackend` seam, not built from nothing) — and his cut-off sentence *"does
it have anyway of recovering any past logs from alternatio"* is ambiguous.
Ask before acting on it.

**Long-running, not blocking:** R02 (Rebirth, after the 2D gates), R51 (the
dh-env trace dump + replay viewer), R47 (the reward-function changelog), R48
(GenForge console Back), R49 (arena interface polish, collision risk).

## 3. NEXT — queued, decided

Numbering is historical — items 1–5 and the lettered DONE entries closed on
2026-09-12/13 and their receipts are in `21-work-journal.md`. Kept as written
so Ricardo's own references to "#6" and "#6g" keep pointing at the same thing.

6. **Bond works with ALL creatures** (design/13 §7.1; Ricardo: creatures are
   core to builds) — capture/bond currently limited; extend to every species.
6b. **Nakama backend adoption** (tech/26; Ricardo: heroiclabs/nakama link —
   "clone from it and use when needed"). Nakama (Go, Apache-2.0) is ALREADY
   the canon backend pick; its Go runtime aligns with the Go economy-core
   carve-out. Track: vendor it for auth/social/matchmaker/storage; dh-server
   stays the authoritative sim; economy core = Go module called via RPC
   (canon §8 hard rules unchanged).
6e. **P2P + LAN stay first-class FOREVER** (Ricardo: "we want to keep the
   option to play peer-to-peer and in lan parties!"). Three play modes, by
   design: (1) solo offline — no account ever; (2) P2P/LAN direct connect —
   no Nakama, no internet: host-authoritative (mp/), content-hash match, no
   economy writes (canon §12.37); (3) Nakama online — auth, matchmaking with
   strangers, marketplace/economy. Nakama ADDS the online track; it never
   gates play. LAN discovery (UDP broadcast instead of typing IPs) = future
   polish inside mode 2.
6c. **Pix checkout for the marketplace** (design/15; Ricardo: "checkout = a
   simple pix to us, redirect to the player with taxes out"). Brazil-native
   rails for the WEB-ONLY marketplace: buyer Pix -> escrow -> server-side
   item transfer -> payout to seller minus rake. No paid randomness (hard
   rule) — Pix changes settlement, not the anti-RMAH design.
6d. **Blockchain gamecoin?** (Ricardo's open question) — PICK awaiting his
   call after reading the trade-offs (regulatory LC 14.478/2022, bot/grind
   abuse pressure, vs Pix+BRL which already closes the loop).
3e. ~~Arena console IN the main game + docs~~ DONE 2026-09-12: title-menu
   ARENA button opens console.tscn in-process; console got a BACK button
   (selftest-hidden); commands documented in docs/USAGE.md §arena. Gates:
   CONSOLE SELFTEST OK, MENU OK (11 buttons).
6f. ~~Nakama self-host, easily launchable~~ DONE 2026-09-12: tools/nakama.sh
   [up|down|status|logs|wipe] + tools/nakama/docker-compose.yml (postgres:16
   + heroiclabs/nakama, migrate-up entrypoint, dev server key). VERIFIED
   LIVE: console http://localhost:7351 (200), api 7350 healthcheck {}, game
   port 7349. First console boot asks for an admin login.
6g. **Leaderboards -> ranked rewards** (Ricardo: stats, PvP records, ranking
   -> legendary items, pets, cosmetics; auras, wings, legendary-creature
   mounts as top-tier cosmetics) — design note in design/15/16; starts when
   Nakama lands (6b/6f).
7. **Every creature ≥3 skills with combos** (design/13; Ricardo: "not boring
   attacks") — game-side kits (arena has 2/species + conduct); synergy pairs.
8. **Difficulty/reward curve** (Ricardo: "1-hit KO late or ultra-mogged early")
   — after #1/#2: revisit scaling so strategy decides, not stats.
9. **Graphics OM** (design/24): elemental VFX lab pack + Radiance Cascades lab.
10. **macOS package** — needs a Mac/CI runner (preset ready).

## 4. ON RICARDO
- **UE 5.4 install** (~45 GB + Epic account) → `rebirth/unreal/INSTALL.md`.
- **`sudo apt install python3.10-venv`** (workaround active).
- **Play the slices for feel** — gates prove loops, not fun.


## 5. PICK — the order-of-magnitude levers (design/24 §2; Ricardo's call)

L1 data-driven AI profiles for the 1000-species bestiary (arena `bot_drive`
seam is the executor socket) · L2 run structure (in-run boon picks, night-fall
escalation) · L3 bosses as system-play (generalize field combos) · L4 pets as
a second build axis (rolled skills never cast today) · L5 the dh-sim C++ port
(server authority + 100× RL throughput — the strategic one) · L6 Radiance
Cascades (below) · L7 reactive audio layer.

## 6. SCHEDULED — visual program (design/19 catalog, canon §12.30)

Landed: media-grade VFX (v0.1.12), 2D lighting model + capture loop
(v0.1.13), atmosphere layers (v0.1.14), SDF shadows + light registry + Bayer
(v0.1.15), normals/dual-grid/LUT/pixel-type (v0.1.16), sprite N·L (v0.1.17),
pixel-grid UI (v0.1.18). Remaining, in order: **Radiance Cascades** (Phase 3
— fragment-only, 320×180 light field on the baked SDF; MUST profile
mid-Android first, no published benchmark) → master-palette discipline
(OKLAB quantize in CI) → 3D-to-sprite pipeline (rides the mesh spike: true
baked normals replace bevel+Sobel) → VFX anatomy doctrine + trauma-shake/
tiered-hitstop (2-3 days) → faux-verticality decision BEFORE the C++ procgen
port hardens (canon flag) → water/shore transition pair, decor Poisson
doctrine, god-ray cards, chunk stamps.

## 7. SCHEDULED — multiplayer arc (design/21)

M-A co-op on the infinite world, server-authoritative (Nakama + dh-net; the
streaming window IS the AOI) — P2P v1 is the friends/LAN stopgap → M-B PVP
(duels → arenas → tournaments; formats in design/16) → M-C the combat/skill
overhaul PVP requires (deterministic sim-side hitboxes, skill archetypes as
data, build identity, rollback-vs-delay open question). L5 is the
prerequisite for M-A proper.

## 8. SCHEDULED — platforms

Android: export walkthrough exists (tech/30); needs touch controls (virtual
stick) + an on-device 60 FPS profiling pass before it is "playable on a
phone". Desktop packaging exists (`tools/package_game.sh`); Windows needs a
mingw `dh-server.exe`.

## 9. BUDGET — re-enable when money allows

(canon §12.38, "use full quality when budget is sufficient")

- **Cloud Run GPU mesh tier** (tech/31 §7): the PREFERRED full-quality
  image-to-3D path (TRELLIS / Hunyuan3D full on nvidia-l4). Parked code is
  intact and guarded; re-enable checklist in
  `genforge/service/mesh_cloudrun/PARKED.md`.
- Any cloud training for the arena league (tech/32 scales locally today).

## 10. Polish backlog (design/24 §3 — do anytime, small)


Pet rolled skills executing (L4), pre-death meteors vs telegraph beams, bolts
through walls, Spirit Essence stack pickup, hitstop scene-time, HUD buff
icons, pet HP chips, DoT number aggregation, sell confirmation, panel pause,
boss bar persistence, telegraph shapes, respawn-near-fight, first-time toasts,
mount dismount lockout, HUD stats → icon chips, skill-bar label clipping.

---

Full narrative, verbatim prompts and closed-item detail: `21-work-journal.md`.
