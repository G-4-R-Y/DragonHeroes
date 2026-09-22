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

## 1. The demand table — every ask, R01 → R81

R01–R43 are the 2026-09-12 quota-outage recovery set, recorded verbatim then
and unchanged since. R44–R55 came in 2026-09-13→19. R56–R71 arrived
2026-09-21, R72–R79 on 2026-09-22 (R78/R79 are harness findings, logged so they are not lost). Detail for any row is in `21-work-journal.md`;
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
| R44 | **DONE 2026-09-22 — fixed as R61** | Bosses still do not spawn like hordes do. | with R36/R29. Cause found: bosses exist only in `main.gd::_spawn_packs`; `_repopulate()` and frontier repop field only `_ground_species`/`_caster_species`. Fix = a rare boss slot in the pressure roll, one live boss cap, distance-ladder gated. The collision block was lifted 2026-09-22 (*"no other agent is currently changing code. You have total autonomy!"*) and the fix landed under **R61** — which also raised the one-live-boss cap to three (R74). |
| R45 | DIAGNOSED 2026-09-19, NOT EDITED (collision) | Still a single biome in play. | with R09/R29. It is a CONTENT gap first: `content/core/biomes/` holds one record (`gloamfen.json`) while `sprites.gd`/`post.gd` already blend two biomes. First deliverable = four more biome records (canon §4) + world_gen's biome field. |
| R46 | **ANSWERED 2026-09-22** | "How are assets gen going?" — a question, owed a status answer, not a task. Re-asked 2026-09-22, verbatim: *"have you already replaced all assets with the new hifi pixel art versions?"* | **No — nothing shipping has been replaced yet, and the blocker is structural, not quality.** Measured by the R81 audit (`docs/research/asset-audit-2026-09-22.md`, re-verified live): **0 of the 10** `game/prototype/art/*/atlas.json` bundles identify as hifi; the hero is still the 52×52-source / 26×26-logical rig with 7 clips of 2–8 frames. Orun v2 is a **rejected** candidate — 6/6 sampled cells fail the real diagnostic (5 on silhouette fill, all 6 on palette/contrast). The blocker: `write_bundle` puts every input into a single looping `idle` row, so the hifi path is a static AUTHORING path, not an action compiler — it cannot emit the named multi-frame clips (`walk`, `attack`, `hurt`, `die`…) a shipping actor needs. The generator itself is green (23 tests, selftest 100/100): the gap is the **export→runtime seam**, which does not exist yet. Still open behind it: 13b/13c, and the local image-gen repo is still not in `reference_repos`. |
| R47 | **DONE 2026-09-14, ledger flipped 2026-09-22** | Document the reward function fully, INCLUDING every version with its rationale — the whole story up to the current one. | `docs/tech/38-reward-model-history.md` (commit `501c537`), indexed in `docs/README.md`. A changelog, not a snapshot, and it states its own rule: a version is never deleted, only superseded, because every ranking in this repo's history was made by one of them. v0 (two functions that disagreed, three defects) → v1 (kept and runnable) → v2 (weights, two enforced invariants, worked ordering) → v2.0.1 the mirror matchup → v2.0.2 the 72× kit hack → v2.0.3 the vocabulary trap → v2.0.4 ground-truth validation. Open items listed as open, including `R_TIME` never re-judged after being zeroed. **The work landed 2026-09-14 and this row was simply never flipped** — journal 2026-09-14. |
| R48 | **DONE 2026-09-14, ledger flipped 2026-09-22** | GenForge console cannot return to the main menu. | The BACK button existed, at the bottom of the RIGHT column under an expand-fill `TabContainer`, so any tab taller than the viewport pushed the only way out off the bottom edge. Moved to the title row (`console.gd::_build_ui`) and `ui_cancel` leaves too — there had been no input handler at all. Why the gate missed it: the layout probe set `_selftest = true`, which was the very flag that skipped building BACK. It is built under selftest now (inert) and the probe asserts BACK exists, is visible in tree and lies on-canvas on both axes, found by ROLE so moving it stays legal. Re-verified 2026-09-22: `GENFORGE LAYOUT OK — 7 canvases x 1204 controls … BACK visible and on-canvas throughout`. |
| R49 | **DONE 2026-09-22** | Arena interface needs polishing to fit everything in. | The whole left column lived inside a `ScrollContainer`, and `console_layout_probe::_walk` deliberately refuses to descend into one (growing past the viewport is what a scroll is FOR) — so the gate printed OK while the run knobs sat below the fold. Measured once the probe could see it: **401 px of content in a 346 px viewport at 800x450**, the canvas `DhConsoleFit._fit_window` picks on a 1080p desktop. Fix is structural, not smaller numbers: the **roster is the only thing that scrolls**, everything the console is operated with (key, gens/pop/eps/jobs, speed, net, the parallelism hint, the mode toggles, the command echo) is pinned in `left_frame`; `TRAINING CONSOLE` moved into the 28 px band already reserved for BACK, buying the column a row; the two `ItemList`s dropped their fixed 88/72 heights for a 28 px FLOOR + `SIZE_EXPAND_FILL`, so the roster is what grows when the canvas does; the command echo is capped at two lines with the full line in its tooltip (`_set_cmd`). New gate `_check_roster` measures content-vs-viewport through the scroll and asserts a 72 px roster floor, exempting only `MIN_CANVAS` 640x360 (console_fit's own "fallback nobody chooses"). `_text_width` also stopped measuring every string with `ThemeDB.fallback_font` when the control overrides its font — it called the big-font title 105 px too wide. Green: `CONSOLE LAYOUT OK — 7 canvases x 5656 controls`; capture `ui_r49_fixed.png` vs the before shot `ui_r49_progress.png`. **R60 overlaps** (the no-wrap rule is respected at the moved title). |
| R50 | BUILT + RUN 2026-09-19 (2/7 pass the gate; the run exposed R55) | Learn from SCRIPTS first, then self-play once reliably winning; then a train_all run with enough steps to converge. | tech/25 §4.2, `tools/train_all.sh`; a real curriculum + a converged run, not a smoke run. |
| ~~R51~~ | DONE 2026-09-22 | Watch a match from the console — current or last-best, for dh-env AND the arena, as a debugging tool. | design/23 §Watching a dh-env match, tech/25 §5.3.2, canon §54. `arena.trace.v1`: dh-env records per tick, `ml/eval/trace_match.py` writes it, `--replay` acts it out in the arena with the recording drawn as ghosts; console **REPLAY ENV** does both in one press. Gate `bash tools/trace_replay_test.sh` (TRACE REPLAY OK). It is also the parity instrument: ranged replays at 0.46 px, contact does not close (gap 21.6 → 90.4) — R55's next lead. |
| R52 | NOW / details received 2026-09-19 | A new asset generator: hi-fi dark-fantasy pixel-art SPRITES in the Dead Cells / Phantom Tower register — master prompt + mandatory negative prompt + five rendering pillars. Benchmarked against "astra". | genforge.hifi (built, commit ab2cd93); art/ style bible; Godot CanvasTexture normal/emissive. Open: real generation once Ricardo picks the image model, the astra bench, pose-by-pose animation, a lit capture, the 13b local backend. |
| R53 | DONE 2026-09-19 | A brief `.md` in the REPO ROOT explaining the hyperparameter changes (masking, greedy eval/promotion, β + move-std annealing, reversible promotion, snapshot reservoir, plateau stop). | `TRAINING_HYPERPARAMETERS.md` at the root. |
| R54 | NOW / standing | Document EVERY experiment with its hyperparameters — a ledger, not prose: run id, knobs, result, verdict, kept or not. Reconstruct past runs too. | `docs/tech/39-experiment-ledger.md`; `tools/train_run.sh` already writes `config.json` per run — the ledger indexes them. |
| R55 | **PARITY FIXED 2026-09-22** (residual narrowed to 2 kiting builds; retrain still owed) | The converged nets win in dh-env and lose in the arena on the SAME greedy decode. Find the divergence, then retrain. | tech/39 §2 (R55-b rows), `ml/eval/env_parity.py`. Four content divergences found by damage-by-source and fixed (Fiery affix absent from the sim; native kit driver on the wrong channel; aim noise on the kit fan; 3.0 px storm bolts) plus one harness bug (two clocks). Matrix worst ratio 3.17 → 1.93. **Residual:** totals agree per channel but fights run ~1.8× longer in dh-env — the endgame, not the exchange. ~~Next: port `creature.gd::_separate` into the sim~~ — **that hypothesis is DEAD (2026-09-21)**: arena bodies are `bot_drive`, so `_chase` never ran there either and neither runtime separated. R59 is now an independent fix, landed, and the residual has no candidate cause. **R55-c 2026-09-22 — the residual had a cause after all, and it was the arena's.** Instrumented first: 1v1 mirrors make the literal wording degenerate (the first death IS the episode end), so the split measured is **EXCHANGE** (spawn → first side below `0.25` hp, the `scripted_policy.gd` retreat trigger) vs **CHASE**. It pointed straight at the tail: exchange 1.08×, chase **2.44×** — 89% of the clock gap. The cause: `creature.gd::_move` refused the WHOLE step when the target was unwalkable, so a body at the ring froze flat and could not slide along the wall it touched, while `Arena::clamp_disc` projects radially and keeps the tangential component — the sim's retreating loser slid and lived, the arena's stood still and died. Fixed by routing through `ArenaWorld::clamp_inside(target, body_radius)` when the world offers it, with `player.gd`'s axis slide as the fallback for the tile grid. **Also a shipping gameplay bug**: a fleeing creature pinned itself in a corner and died to a wall. cinder_drake 32 eps → **PARITY OK** (win-gap 0.219→0.000, seconds 1.51×→1.00×, dps_taken 1.60×→1.01×, chase 2.44×→1.10×). 64-ep matrix run TWICE (HEAD vs fixed, nothing else changed; every dh-env column bit-identical): **`agree` 0/7 → 3/7**, worst ratio 2.08×→1.81×, mean \|chase−1\| 1.098→**0.415**. Three guards added for the relative-`--policy` trap that silently produces a fully inert neural fighter (Godot resolves a bare relative path against `res://`). **Residual, far better posed:** the two KITING bodies (`gloam_wisp` 2.52×, `gloamfen_stalker` 1.46×) overshot past parity and now run longer in the ARENA — opposite sign, so the sim ends their endgame early; that is a driver difference, not a fence. Still owed: the retrain, and the gate's `--episodes` raised above 4. |
| R56 | **DONE 2026-09-21** | GPU processes are not ended properly after training in the console. | `console.gd::_spawn_league` now launches the trainer under `setsid`, so it owns a session — and `_stop()` kills the whole PROCESS GROUP (`kill -KILL -PGID`) instead of `pkill -KILL -P <pid>`, which reached exactly ONE generation and left anything a level deeper alive holding the card. The group kill is gated on `pgid == pid` (`_resolve_pgid`), the proof that setsid took and that the group is ours: Godot's own children inherit GODOT'S group, so signalling an inherited group would kill the editor. `_reap_group()` also sweeps on natural exit, because a crashed trainer orphans its workers to init where nothing reaps them. Gate: `bash tools/trainer_stop_test.sh` → `TRAINER STOP OK` — it asserts both halves against a fixture with a real grandchild (`old path leaked 1, group kill reaped 3/3`). Arenas run on LOCAL GPUs — a leaked trainer costs the next run. |
| R57 | **DONE 2026-09-22** (unblocks R65) | Every captured mob turns into a gloamfen stalker. Wanted: maximum variety — every species keeps its own chassis, AND bosses are capturable as mini-pets with their signature skills, levelling alongside the player. | **The bond now carries the body.** `creature.gd::capture_profile()` exports the species id, archetype, element, tint, scale, level-free base hp/damage and (for legendaries) the authored `kit`; `main.gd::_roll_pet` rolls skills from a three-tier signature pool (legendary kit ▸ hand-written species row ▸ element+archetype tables) instead of the hardcoded `core.creature.gloamfen_stalker`; `pet.gd` dresses itself from the chassis instead of `ProtoSprites.stalker_frames()` + the founding 120/14 block, and re-derives hp/damage at the hunter's current level each tick, keeping its wound fraction. **Every tier is capturable now** — elites and legendaries bond as mini-pets on their own terms (HP gate 0.15/0.10, chance ×0.35/×0.15, pet keeps 25%/20% hp and 50%/45% dmg, drawn at 0.5–0.6 scale), and a capture pays no loot, no rune, no kill credit. Records saved before R57 carry no chassis and stay exactly the founding stalker. Gate: `tests/capture_probe.tscn` → `CAPTURE OK` (40 rolls, species/kit/rig/level/essence/F-path), mutation-verified — reverting the species lookup alone produces 34 FAIL lines. Docs: design/13 §7.1. |
| R58 | DONE 2026-09-22 | The HP potion does not heal over 2 s — it is meant to be a heal-over-time, not an instant top-up. | **The model was right; the HUD was lying.** Reproduced in a real hunt (seed 41487, physics on): `hp` climbed 50.0 → 70.0 linearly over the full 2.00 s, while `hp_bar.size.x` stayed frozen at 90.00 px and `hp_text` at `"50 / 100 HP"` for the whole burn *and after it*. Cause: `main.gd::refresh_hud()` is the sole writer of the HP readout and is event-driven only, so a per-frame HP source is never drawn. Fix: extracted `_refresh_hp_readout()` and drive it from the per-frame `_update_gauges()` behind a staleness check (no redraw when nothing moved), plus a `+N HP` float when the burn completes. `flask_probe` grew a live-drip section — it had been driving `_process_flask()` by hand with physics disabled, which is exactly why it was green through the bug. |
| R59 | **DONE 2026-09-21** | Creatures do not collide with the player — they stand *on top of* him, where he cannot hit them. "Bizarre stuff and a bit annoying." | Separation now runs in `creature.gd::_physics_process` every tick in every state (it used to be a line inside `_chase`, which returns the moment a body is inside `attack_reach * 0.9` — it switched OFF at exactly the distance where bodies pile up). Split into `_separate_player` (rate 12/s) and `_separate_creatures` (rate 4/s, gated by `bot_drive or _state != "idle"`), the same two calls commented out in `wisp.gd`/`terravore_colossus.gd`, and ported to `dh-sim` as `Arena::separate_bodies()` (step 2b) so the four runtimes stay in parity. Test: `test_arena_bodies_separate_instead_of_standing_inside_each_other`. **CORRECTION to the R55 row below: the arena never ran `_separate` either** — arena bodies are `bot_drive`, so `creature.gd` parks `_state` at `"idle"` and `_chase` never executes. Separation was therefore NOT the R55 divergence; that residual is re-opened with no candidate cause. |
| R60 | **DONE 2026-09-22** | The arena console lost its value labels (generation etc. render without captions), and the interface must be legible at 20 M-step values. | **Three independent defects, not one.** (1) `Label.clip_text = true` + any autowrap makes Godot 4.6 return `(1, 1)` from `get_combined_minimum_size()`, so a `VBoxContainer` drew every wrapping caption **1 px tall** — `clip_text` commented out with the measured table beside it. (2) A wrapping Label inside an `HBoxContainer`/`GridContainer` is handed minimum width 1 and renders as a one-letter vertical column — `wrap = false` opt-outs at `key`, `speed`, `net`, `_spin()`, `_vs_count`. (3) Legibility: `_grouped()`/`_si()` on every big number (20 M reads `20M`), named `GPU_PPO_STEPS`/`GPU_PPO_ENVS`, measured-stride legends with `+N` overflow. Then, reading the capture: **9 of 31** benchmark records rendered as `? vs ?  0-0  ?` because `_verdict_kind()` returned `"other"` for `arena.distill` / `arena.env_parity` and `"other"` falls into the head-to-head branch; `_verdict_when()` blind-sliced undated filenames into `arity fe:n_`; `build`-keyed records were unreachable by the creature filter. All fixed, plus a real newest-first sort (`_verdict_at`) — the list header had been untrue for every undated record. **Both gates grew teeth:** the layout probe now fails on collapse on either axis (`MIN_LABEL_W`), the console selftest carries distill/parity/undated fixtures (8 now), and each new assertion was proven by reverting the fix and watching it fail. Capture: `ui_console_versus.png` (VERSUS tab — `ui_capture.gd` gained `UI_TAB`, so all five tabs are now screenshot-verifiable). |
| R61 | **DONE 2026-09-22** (closes R44 too) | Bosses are not spawning randomly among new hordes while exploring — Ricardo expects to meet them out in the map, not only at lairs. | A rare WARLORD slot now rides the pressure roll in `main.gd::_repopulate` (`_roll_roaming_boss` / `_spawn_roaming_boss`), gated by the distance ladder (`danger >= 1`, so the authored 5×5 keeps its authored bosses), by a 45 s cooldown, by `ROAM_BOSS_MAX_ALIVE` (R74) and by the `REPOP_CAP - 8` headroom check. Odds `0.05 + 0.02·danger`, capped at `0.22`. A warlord rides a real `bestiary_legendary` entry on its own chassis (no catalog → Hag), so it inherits hp/dmg/tint/bundle — but it is NOT the hunt legendary: `boss`/`legendary_boss`/`_legendary_name` are untouched and the minimap keeps one marker. **Two latent bugs found on the way:** `on_legendary_died` cleared the hunt's legendary state for ANY legendary-chassis death (now identity-guarded), and the two duo chassis stamp `display_name`/`bar_color` in `_ready()` — which runs at `add_child`, i.e. after main names them — so a colossus-chassis legendary went on the boss bar as "TERRAVORE COLOSSUS" instead of its catalog name (`Syvzarr, Star-Eaten Pillar` in the probe's own boot log). Gate: `roam_boss_probe.tscn`, eight assertions, each with teeth. |
| R62 | NEXT / content | More of every axis: creatures, bosses, loot, skills, pets, mechanics, **and potion enchanting with special effects**. | Data-only by canon §10 — new `pack.type.name` ids validated against `content/schemas/`. Potion enchanting is the one new SYSTEM in this line. |
| R63 | NEXT / design then implementation | Better skill design and playability; probably MORE skills, to make combat more dynamic — the current kit reads as too static. | design/10/11/26; pairs with R37 (skill-tree screen) and R64. |
| R64 | NEXT | Visual cues for skill cooldowns. | design/10/17; HUD work, pairs with R43 (cooldowns need too much attention) and R63. |
| R65 | **DONE 2026-09-22** | Pet levels and pet skills, so a pet scales with the player instead of falling off. | design/13 §7.1. **The scaling half came with R57** (a bond re-derives hp/damage from its own chassis at the hunter's level every tick). **The skills half is R65:** `session.gd::pet_skill_def` resolves a rolled `core.skill.*` id against the 19 snapshots mirrored into `game/prototype/data/` (flat directory → the file counts only when its own `id` matches, so `abyssal.json`, a pet *family*, cannot answer as a skill), and `pet.gd` casts it through a **behavior dispatcher** — `melee_arc`/`projectile`/`aoe_field`/`channel`/`dash`/`buff`/`summon` — reading authored SIM units (`windup_ticks / 30`, `*_m * TILE`), so a new pet skill stays a JSON edit (canon §10). The kit gets first refusal each time the swing comes off cooldown; a skill with no `damage_coeff` does no damage; pet fields are `friendly`, pet bolts carry a real shooter and an empty `skill_def`, summons take `uid -1`. **The pet now has a track of its own:** `bond_xp` +1 per kill it was present for (alive, not resting, inside the leash — a stabled record and a summon bank nothing), `6 + 2*lvl` kills per level, cap 10 at 144 kills, one more rolled skill castable every 3 levels (1 → 4) and +3% hp/damage per level on top of the chassis curve; `_credit_bonds` refreshes the pet in place, so the new skill is live on the next swing, not after a reload. The companion card prints the bond, the progress and `locked · bond N`. Closes the L4 known-issue. Gate: `tests/bond_probe.tscn` → `BOND OK` (19 ids, curve, credit, unlock, potency, all 7 behaviors), mutation-verified — defaulting `damage_coeff` to 1.0 or dropping the leash check each produce exactly one FAIL line. **Design call awaiting Ricardo:** the bond track is not in design/13 §7.1 — it is now written there, flagged. |
| R66 | NEXT | Item scaling pass — asked again against the current numbers (previously audited 2026-09-12). | design/24; with R16/R19. |
| R67 | NEXT / new system | Mob kill counter → streak rewards: bonus gold and XP while it runs, and when the streak ENDS on the timer after a LOT of kills, a chest drops from the sky with legendary loot. Streak length decides the tier. | design/11/15; hooks `on_creature_died` (the same feed the Ember Flask rekindle uses). |
| R68 | SCHEDULED / event content | Multi-boss events (2, 3, 4, 5+). Named: *Giant Graveyard* (seven giants), *Dragon Nest* (baby + adult dragons). | design/13/29; with R36/R29. |
| R69 | SCHEDULED / the headline event | **The DRAGON COUNCIL** — 12 legendary interdimensional dragons join forces to kill you. A dungeon/questline, not an arena fight: 12 councils, some in COUPLES with combo mechanics, some alone with special skill mechanics; the 10+-skill mythical/celestial/demonic tier. Clearing all 12 unlocks special loot + a mechanic + a skill. Near-RAID difficulty, gated behind prior ARTIFACTS that open the council dimension, meant to take real time to unlock. | design/13/29, the living-world generator; the largest single content ask on the ledger. |
| R70 | SCHEDULED | Bot "player" events: bot players hired as MERCENARIES under your bounty, and bot players BOUNTY-HUNTING you — raising and spending your own bounty. | design/15/16; this is the PvE-facing half of the leaderboard system at NEXT #6g, and it lands on R33 (bounty/notoriety economics, anti-farming, gold sinks). |
| R72 | **ANSWER DELIVERED 2026-09-21** (rebirth/docs/02-status.md §3.1); the boss fight is SCHEDULED | *"people are using a pipeline with meshy + blender + unreal for game dev, is it a natural stepup? perhaps that's what we were looking for when testing out the experiments with 3d stuff. Later we will make a boss fight to test out the concept"* (2026-09-21). Two parts: (a) a written judgement on Meshy → Blender → Unreal against what we already have (TripoSR installed locally, `genforge/pipeline/mesh_gen.py` with a provider seam, the parked Cloud Run GPU tier, `rebirth/unreal/`), and (b) **a boss fight built through that pipeline as the test of the concept**. | tech/31 (image-to-3D), rebirth/docs, canon §12.44; R02 is the Rebirth track this lands in, and the concept-render unblock it shares is the same one blocking the TripoSR spike. |
| R71 | SCHEDULED | Questline themes beyond the council: mercenary hunt contracts, political sabotage, underground-city business, political power disputes, wars, conflicting interests, powerful-people scandals. | `docs/design/28-living-world-and-weekly-lore.md` + the weekly-lore generator; with R28/R31. |
| R73 | **ANSWERED 2026-09-22 — already built, byte-identical** | Ricardo re-sent the Dead Cells / Phantom Tower asset-generation brief (five pillars, style matrix, vocabulary, MASTER PROMPT + MANDATORY NEGATIVE PROMPT): *"some guidelines on the new asset generation pipeline (perhaps you already improved, than let's compare stuff)"*. Diffed against the pinned contract: both prompts are **character-identical** (master sha256 `731f520061aa054e…` on both sides) and `spec.verify_against_source()` still passes, so `sprites prompt.md` holds this exact brief and R52 shipped it. Pillar coverage and the three engine-side gaps: journal 2026-09-22. | `genforge/hifi/` (ab2cd93), tech/40, `sprites prompt.md`; gaps feed R72(b) (pillar 3, the 3D→2D render path) and R49/R60. |
| R74 | **DONE 2026-09-22** (design confirmed by Ricardo mid-implementation) | *"Bosses spawning together and fighting multiple at once is actually a pretty fun mechanic, with unexpected crossovers"* (2026-09-22). Reverses the one-live-boss cap I had designed into R61. | Roaming warlords now stack to `ROAM_BOSS_MAX_ALIVE = 3`, and the odds are MULTIPLIED by `ROAM_BOSS_CROSSOVER = 1.35` while one already prowls — the crossover is encouraged, not merely tolerated. The cap is the frame budget (3 boss chassis + hordes under `REPOP_CAP`), not the design. Second and later arrivals get their own banner (`msg_warlord_crossover`). Gated by `roam_boss_probe` assertions (c)/(d). Feeds R68 (authored multi-boss events) — this is its emergent cousin. |
| R75 | DONE | *"clean up the repo when done - i noticed there are some unused whole folders"* (2026-09-22). | Whole directories with no importer, no CI reference and no doc pointer. Method: inventory top-level + second-level dirs, prove each candidate dead (no code import, no path string, no CI/tooling reference, no doc link), then remove in ONE commit with the evidence table in the journal — never a silent delete. Anything merely PAUSED (parked Cloud Run mesh tier, `rebirth/`) stays: §9 BUDGET items are deliberate, not dead. | **DONE 2026-09-22** — evidence table in the journal. Deleted (empty + unreferenced): `sim/bin`, `rebirth/native/shaders`, all `__pycache__`/`.pytest_cache`. Untracked (gitignored yet still in the index): `sim/build-windows/` 137 files, `ml/data/logs/` 7 — the one load-bearing artifact kept at `builds/prebuilt/windows/dh-server.exe`, `tools/package_game.sh` prefers a fresh cross-build over it. Kept, now self-explaining: `art/`, `reference_repos/`, `builds/` gain READMEs and canon §10 lists them. Nothing paused was removed. |
| R76 | DONE | *"can we improve our banner? In github repo's readme. I liked the vibe, but the giant dragon head in the horizon is bizarre and hallucinated lol. Perhaps use our new quests themes to represent stuff! The heroes party and spirit dog vibe was neat, tho, keep that. Reminds me of lord of the rings journeys - companionship and adventure"* (2026-09-22). | Re-art `docs/art/readme-banner/dragon-heroes-banner.png`. KEEP: the party of three + spectral wolf, the blue-hour marsh kingdom, the LOTR fellowship/journey read. KILL: the monumental dragon head on the right third (the hallucinated element). REPLACE with imagery drawn from the living-world quest themes (design/28, `genforge/living/narrative.py`, the released chapter) so the banner advertises the actual weekly-content promise. Constraint: this session has no `image_gen` tool and `OPENAI_API_KEY` is unset, so the deliverable is a DETERMINISTIC in-repo renderer (PIL, reproducible, no API) plus the updated prompt/provenance for the day Ricardo runs the paid path — not a one-off unreproducible image. | **DONE 2026-09-22** — `genforge/pipeline/readme_banner.py`, a deterministic PIL/numpy compositor over the v1 plate; `--check` re-renders and hashes against the committed PNG. Dragon out (wing/head/neck/jaw-waterfalls); bell tower, ferry, Lumen motes and two small distant wyrms in, from `bell_beneath_fen.json`. README alt text rewritten; `prompt.txt` keeps v1 verbatim (offending line marked) and adds a corrected v2 for the paid path. |
| R77 | DONE | *"hey, we are building on top of the code build, right? It really levelled up graphics and solved a lot of roadmap items. I think it's time we fully merge the build and keep our final one! Add that when finishing the roadmap (and consider that for continuing and perhaps fixing the roadmap!)"* (2026-09-22). | **Answer to the question first: the codex SOURCE is already merged** — `246a6a5` landed the parallel session's living-world/residency tree, and `game/export_presets.cfg` has written to `builds/codex/` ever since, so every export since then IS the codex build. What was never merged is the **packaging**, and that is a live bug: `tools/package_game.sh` exports (to `builds/codex/`) and then zips a DIFFERENT directory (`builds/<plat>/`), so `builds/dragon-heroes-*.zip` has shipped a **2026-09-12 client** for ten days — the levelled-up graphics Ricardo is describing were never in the zips. Two rival packagers exist: the legacy `package_game.sh` (3 files, no verification) and `tools/package_codex.py` (smoke test, `verify_package.py`, living-preview + lair-journey gates, icon, launcher installer, hashed `BUILD-INFO.json`, GDExtension `.so`) which aborts rather than ship a bad zip. Merge = ONE packager, the codex one, producing `builds/dragon-heroes-<plat>.zip`; `package_game.sh` retired to a wrapper (commented, not deleted). | **DONE 2026-09-22** (canon §12.53, journal for the evidence). ONE packager: `tools/package_codex.py` → **`tools/package_build.py`**, chosen because it passes an explicit path to `--export-release`, which overrides the preset and makes preset drift impossible; `tools/package_game.sh` is now a 142-line wrapper (`exec python3 tools/package_build.py`) keeping only `DH_FETCH_TEMPLATES=1`, whole old body commented out, not deleted. Carried across from the legacy script: the prebuilt Windows-helper cache, as `helper_candidates()` — fresh local build first, `builds/prebuilt/windows/` second, order load-bearing. Product identity renamed everywhere (`dragon-heroes.x86_64` / `.exe`, save dir `Dragon Heroes`) with `game/tools/user_dir_migration.gd` as the FIRST autoload: additive copy, never clobbers, never deletes — **verified against Ricardo's real saves, 88 files copied, old dir intact**. Gone: `builds/codex/`, `sim/build-codex-windows/` (~365 MB), every `-codex` affix, `--codex-smoke`→`--package-smoke`, `--codex-profile`→`--client-profile`. UNTOUCHED: the in-game CODEX effects/affix registry (§12.12) — different thing. **The ten-day bug is dead:** the zips now hold a client dated 2026-09-22 05:00/05:01 (was 2026-09-12); 37.5→50.8 MB linux, 46.5→59.6 MB windows, every gate OK. Also fixed on the way: the mingw cross-build was broken at HEAD (`-Wunused-const-variable` on R55's orphaned `kWindup`, invisible to gcc), the committed `builds/prebuilt/windows/dh-server.exe` was 97 KB of 2026-09-12 code because the path canon called "the output" is a hand-copy nothing rebuilds (real output: `libs/dh-server/`, 287 KB), and `zip -r` was appending to the old archive instead of replacing it. Two findings logged, not regressions: Windows ships **no GDExtension** (`dh_godot.gdextension` declares only `linux.*`; `neural_policy.gd` falls back to GDScript) and the mingw tree emits a misnamed `libdhgodot.linux.template_debug.x86_64.dll`. **Both closed by R79.** |
| R78 | DONE | Harness finding, 2026-09-22 (R17's push): `builds/dragon-heroes-windows.zip` is **57.16 MB** (59,938,069 B after R79 added the Windows DLL; was 56.82 MB / 59,579,269 B when GitHub warned) and GitHub warned on push — past its 50 MB recommendation, and it gained 13 MB in one merge. | The zips are committed on purpose (canon §10, `builds/README.md`: they ARE the game to anyone downloading), so the fix is not "stop committing them". Decide before the **100 MB per-file hard limit** forces it: Git LFS on `builds/*.zip`, or move the distributable to GitHub release assets and keep only `BUILD-INFO.json` in-tree. Recommendation: release assets — LFS quota is a recurring bill, releases are free and give download counts. Gate: a clean clone must still be able to build and run without the zips. | **DONE 2026-09-22** (canon §12.56, journal for the evidence). **Release assets**, as recommended. The current pair was never the cost: git stores each new ZIP whole and never forgets it, so the history held **8 distinct zip blobs / 357.9 MB**, `builds/` **440.7 MB across 18 blobs**, inside a **698 MB `.git`** — ~63% of the repo was build output, largest object `builds/linux/dragon-heroes.x86_64` at **82.4 MB** (pre-R77, when the export dir was tracked). What stays in-tree is `builds/BUILD-INFO.json`: release tag, URL, `release_commit`, and per platform file/bytes/sha256/built/`base_commit`/`working_tree_dirty`/executable/`download_url`. (Name collision is deliberate: the in-tree index hashes the *packages*; the `BUILD-INFO.json` **inside** each zip hashes that package's *contents*, §12.53.) New `tools/publish_release.py` — refuses one platform without the other, refuses a dirty tree, `--target`s the `base_commit` and refuses until it is on the remote, verifies the **server's** byte counts before writing the index; `--dry-run`/`--check`/`--reindex`/`--allow-dirty`/`--draft`. Two defects found by doing it: (a) `source_info()` counted **untracked** files, pinning `working_tree_dirty` true on every working checkout — now `--untracked-files=no`, with `untracked_files` reported separately; (b) `gh release create` with no `--target` tagged the server's default-branch HEAD (`3c006ac`) instead of the build commit (`3f7b8af`) — repaired by recreating the ref and PATCHing the release out of the draft state it reverts to when its tag is deleted. Released: **`build-20260922-3f7b8af`** (linux 50,885,663 B `252e52e6…`, windows 59,938,072 B `073d6a1d…`), both verified downloadable at their indexed sizes. Gate: `bash tools/clean_clone_gate.sh` — clean clone, no zips, builds `sim/`, `ctest`, `dh-server`, `validate_content.py`, HEAD on each `download_url`. **OPEN FOR RICARDO, not done autonomously:** `git rm --cached` caps growth but does not shrink history; removing the 440.7 MB of old blobs needs a rewrite, which invalidates every existing clone — and he runs concurrent sessions on this tree. |
| R79 | DONE | Harness findings, 2026-09-22 (found while proving R77): the Windows package ships **no GDExtension**, the mingw tree emits a misnamed artifact, and the Windows export prints an unexplained warning. | Three defects, one root — the platform tag was following the HOST, not the toolchain (canon §12.55). (c) was (a): the pre-fix `export-windows.log` line 13 read `WARNING: GDExtension: Biblioteca "x86_64" não encontrada` and the export **finished anyway**, so the shipped Windows build quietly ran the `neural_policy.gd` GDScript fallback; one fix closed both. (b) fixed by deriving `OUTPUT_NAME`'s platform tag from `CMAKE_SYSTEM_NAME` in `sim/libs/dh-godot/CMakeLists.txt`. (a) fixed by the two `windows.{debug,release}.x86_64` rows in `dh_godot.gdextension` plus a guarded llvm-mingw loop in `tools/build_dh_godot.sh`, which now builds **four** libraries (Linux `.so` pair + Windows `.dll` pair; `DH_MINGW_ROOT` overrides the toolchain path, and a clone without it SKIPS the Windows step with a note instead of failing). DLLs gitignored like the `.so`s. Gate: `windows.release.x86_64` declared ✓, built by the cross-build ✓, present in the zip ✓ (`libdhgodot.windows.template_release.x86_64.dll`, 742,400 B, sha256 `f38f4a6a…82c8c2`, byte-identical to the addon copy; export ordinal 1 = `dh_godot_library_init`, imports KERNEL32 + UCRT stubs only, so self-contained). Fourth clause — the arena **reporting** the native path on Windows — NOT observed and not claimed: `uses_native()` is read only by `game/arena/tests/policy_parity_test.gd` and `arena/tests/` is in every preset's `exclude_filter`, so a shipped build cannot self-report; needs a Windows box or a test-carrying preset. Post-fix export log: zero `completed with warnings`. Linux regression check: POLICY PARITY OK, 256 forward passes bit-for-bit. Full packager green (`PACKAGE CONTENTS OK: windows / 17 files`). |
| R80 | **DONE 2026-09-22** | Harness finding, 2026-09-22 (found running the full gate suite for R57): `residency_probe` — a USAGE §10 gate — was **red on master**, and red for two independent reasons, neither of them a game bug. Measured before the fix: HEAD baseline in-place `pass=0 fail=5`; the R57 tree `pass=1 fail=4`. Two failure strings, `RESIDENCY FAIL: water fixture missing` and `RESIDENCY FAIL: flying creature over drawn water did not return`. | (a) **No pinned seed.** `main.gd:176` calls `randomize()` and `world_gen.gd:126` rolls `_hunt_seed = forced_seed if forced_seed != 0 else randi()`, so the probe's water fixture existed only on lucky maps — a 28-seed scan found **3 seeds with no water at all** within ±35 tiles of spawn and several more out at ring 28–35. Now pinned to `41487` via `MpNet.pending_seed` before `add_child` (the same seat `stream_recovery.gd:48` and `residency_capture.gd:28` use), released immediately after; that seed leaves origin walkable, so `spawn_point()` is exactly `(0,0)`. (b) **The fixture search took the wrong tile.** It walked `y` from −35 upward and took the first hit in that row, i.e. the most NORTHERN water rather than the nearest — up to 560 px from spawn, past residency's 512 px `wake_distance()`, so the flyer *correctly* refused to wake and the probe called it a failure. It now rings outwards from spawn and never past `wake_distance()/TILE - 4`. Gate: `RESIDENCY OK`, **5/5 green**, `worst_step_ms` 0.50–0.87. Evidence and the debug line that located it (`dist=615.7 wake_d=512.0`): journal 2026-09-22. |
| R81 | DONE — audit/proposal 2026-09-22; implementation remains on existing art rows | Review current assets and distilled guidelines; identify order-of-magnitude opportunities, accounting for Claude's completed work. Preserve the supplied Dead Cells / Phantom Tower brief. | research/asset-audit-2026-09-22.md; 23 hifi tests pass, real six-pose diagnostic rejects 6/6, shared-scale/duplicate-frame defects reproduced; fresh GL Hunt capture + 5s frame-time receipt. Proposed sequence links R01/R06/R09/R12/R26/R42/R52/R72; journal R81 |

## 2. NOW — in flight, and the strategy behind it (2026-09-21)

**Current user priority (2026-09-22, R81):** audit assets and the new art guidelines, then propose the largest gains. This is a review/proposal task; preserve the concurrent R49 arena edits and do not restart completed R77 packaging or old recovery tasks.

Ricardo's standing order is "finish up all the other tasks in the roadmap",
and his latest batch says bugs first. Order below is the order to work in.

**Closed since this list was last rewritten (2026-09-22):** ~~R56~~, ~~R57~~,
~~R58~~, ~~R59~~, ~~R60~~, ~~R61/R44~~, ~~R65~~, ~~R74~~, ~~R75~~, ~~R76~~,
~~R77~~, ~~R78~~, ~~R79~~, ~~R80~~, ~~R81~~. The old item 1
— *port `creature.gd::_separate` into `sim/`* — is **dead as written**: R59
landed separation in all four runtimes, and the arena never ran it either
(arena bodies are `bot_drive`), so it was never R55's divergence.

1. ~~**R51**~~ — **closed 2026-09-22**, with R47, R48 and R49; all four NOW
   items that had never moved are now done. dh-env records `arena.trace.v1` per
   tick and the arena replays it (`--replay`, or **REPLAY ENV** from the
   console), with the recording drawn as ghosts over the real bodies. Gate:
   `bash tools/trace_replay_test.sh`. It handed R55 its next lead on the way:
   contact-range fights do not replay because the arena's pair never closes.
2. ~~**R55 residual**~~ — **the parity half is closed 2026-09-22 (R55-c).** The
   endgame instrument exists (`low_t_s` → `exchange_s`/`chase_s`, diagnostic,
   never gating), it named the cause in one reading, and the cause was
   `creature.gd::_move` refusing the whole step at the ring — a movement fence
   that killed the arena's fleeing loser against a wall the sim let it slide
   along. cinder_drake is **PARITY OK**; the 64-ep matrix, run twice to prove
   it, moves `agree` 0/7 → 3/7 and mean chase error 1.098 → 0.415. **What is
   still owed on R55:** the retrain — best-greedy checkpoint export in
   `ppo.py`, then `STEPS=60000000 PLATEAU_UPDATES=80 PLATEAU_DELTA=0.02
   PLATEAU_MIN_STEPS=20000000 CLONE=heuristic tools/train_all.sh --ppo`, with
   the gate's `--episodes` raised above 4 (4 cannot separate 0.6 from 0.9) —
   and the narrowed residual: `gloam_wisp` and `gloamfen_stalker` overshot past
   parity with the sign INVERTED (arena chase now the longer one), so the sim
   ends a kiting body's endgame early. Local GPUs only.

3. ~~**R78**~~ — **closed 2026-09-22** with R79. The zips are GitHub release
   assets now (`build-20260922-3f7b8af`); `builds/BUILD-INFO.json` is the
   in-tree index and `tools/clean_clone_gate.sh` is the gate. One thing is
   **waiting on Ricardo, not on work**: the 440.7 MB of dead `builds/` blobs
   already in history can only be removed by a rewrite, which invalidates every
   existing clone — his call, given the concurrent sessions on this tree.
4. Then the content and event lines, **R62 → R71**, largest last.
5. **R72(b)** — the boss fight through Meshy → Blender → Unreal; the written
   judgement is already delivered, the real gap is Blender.

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
- ~~**R46**~~ — **ANSWERED 2026-09-22** (row above), re-asked as *"have you
  already replaced all assets with the new hifi pixel art versions?"*. Short
  answer: no, and the blocker is `write_bundle` emitting one looping `idle`
  row instead of named clips — a seam, not a quality problem.
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

**Long-running, not blocking:** R02 (Rebirth, after the 2D gates). R47, R48,
R49 and R51 are done — the first two had landed and were never flipped, R49 and
R51 landed 2026-09-22.

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
phone". Desktop packaging exists and is now a single gated packager
(`tools/package_build.py`, R77); Windows cross-builds its own mingw
`dh-server.exe`, with `builds/prebuilt/windows/` as the fallback cache.

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
