# Work journal — the roadmap's evidence trail (2026-09-10 → 2026-09-22)

**This file is the ARCHIVE, not the ledger.** The ledger is
`docs/harness/20-roadmap.md`: one row per demand, what is in flight, what is
queued, what waits on Ricardo. It is what a session reads to know what to do.

This file is what a session reads to know *why* — every verbatim Ricardo
prompt, every interruption checkpoint, every investigation write-up and every
closed item's full narrative, in the order it happened. Nothing here was
summarized or deleted when the ledger was split out on 2026-09-21; the text
below is the roadmap file exactly as it stood at that moment.

Search it by demand id (`R55`), by date (`2026-09-14`) or by system name.

---

# Roadmap — the one consolidated list (2026-09-10)

Ricardo decides DIRECTION (which lever, when); harnesses execute inside it.
Every item points at its law doc. Statuses: NOW (in flight) · PICK (awaiting
Ricardo's call) · SCHEDULED (decided, sequenced) · BUDGET (blocked on money).

## NOW — Resume every request queued during the quota outage (Ricardo, 2026-09-12)

The user restored quota and explicitly requested execution of ALL pending work.
The publication itself succeeded at e036a7c; automatic approval review rejected
only the subsequent documentation-record command because workspace credits were
exhausted. That command never ran. All messages below arrived during the outage
and are recovered here before implementation. Work remains inline per CLAUDE.md.
Finish the 2D work before the Rebirth follow-up; commit/push completed slices
on the authorized mainline, preserve unrelated work, and rebuild Codex packages.

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


Interruption checkpoint (latest Codex-build playtest + quota reset, 2026-09-13):
preserve both exact prompts in the archive. R34 performance and R35 Flask now take
priority, then skills/arena/boss/dungeon issues and all older work. The user's
playtest was of builds/codex, still clean b622aa6; newer residency/narrative/Snap
changes are uncommitted and modern hunter art remains a candidate. Do not confuse
source changes with a delivered binary. 127 Python tests and 4 native suites pass;
functional Godot gates pass (console has two intentional malformed-log fixtures).
Streaming budget FAILS under concurrent 20-worker training: measured ~8–19 ms,
despite row-cache optimization preserving terrain. Record this honestly. A planned
read-only CPU topology check was rejected by automatic approval review as workspace
credits exhausted. No affinity change occurred. User then confirmed reset; the
same harmless escalated read succeeded. Cause/account balance unverified; work can
resume. Reassess process/test sessions after the interrupted turn before launching
anything else. Source-file notes and handoff must reflect this new priority.

Interruption checkpoint (2026-09-13): latest full prompt archived before work.
Recovered two newer mainline commits from the other session (0d075a8, ab14e32),
including the ML cockpit and native PPO batching; preserve them and rerun shared
gates against this integrated HEAD. Existing R08 implementation and receipts remain
intact. Extend residency to ground loot and finite-lived projectiles before its
next publication, inspect the reported teardown leak, then continue native biome
variety and local Orun-standard art with narrative manifests. All earlier R01–R26
remain active as listed; finish 2D before Rebirth. Loot never expires merely from
distance. Projectile visibility is separate from simulation: keep motion/lifetime
and exactly-once impacts coherent, and document the chosen dormant-time semantics.

Recovery slice receipt (2026-09-13): R27 actual ground-state gate passes; original
loot survives travel/level changes and full creature cap/bag, collects once and
never reappears. Shots move/hit offscreen after shooter removal and expire normally;
reachable targets stay awake. R32 forced off-tree water teardown passes plus 12/12
verbose Hunt boot/quits without RID/ObjectDB/resource warnings. R28 narrative schema,
typed archetype/thread/faction/event links, pinned prior-release hashes and local
brief/build grounding implemented; 35 narrative/living tests pass. Story events
are candidates, not playable politics. Long dependency chains need future reviewed
history-anchor tooling (current eight-depth/32-visit gate); all-creature art remains
open. Full integrated suite is running before commit/push and Codex packaging.

Execution strategy: inspect current code/tools and preserve every demand; complete
cohesive 2D slices with shared data/presentation seams, regression outcomes and
actual GL frames. Start with the existing animation/action contracts and UI/state
flows, repair long-Hunt streaming/visibility foundations, then expand the same
art contract across creatures/biomes/equipment/VFX and progression/Haven systems.
Use local deterministic generation and reusable caches wherever possible; do
not pretend static concepts are finished action animation or uncompiled engine
code is a tested game. Rebirth comes after the 2D acceptance gates. Every item
stays open until its implementation and concrete gate are complete.

Interruption detail (R15, Ricardo): the PNG is present beside the binary but
the executable still shows the generic file-manager icon. Investigate Linux
desktop integration and launcher trust/icon paths, not missing in-game art.
Current implementation state: distinct locally baked hero action clips,
correctly oriented/ranged slash presentation and recycled-VFX reset are in
flight; Haven return/save and shared companion portrait/nickname UI are being
integrated. Finish their outcome gates, then visibility/world/UI foundations.

Interruption detail (R02/R14, Ricardo): "plebs" means the GPU-poor LOCAL 3D
asset-generation pipeline, not a named creature model. Target the available
6 GB RTX 4050 and CPU fallback; inspect existing local model/cache support,
make reusable meshes/materials/rigs actually load in Rebirth, and keep optional
cloud providers explicit. The 2D-first execution order remains unchanged.

New direction checkpoint: full latest prompts are archived in
`requests/2026-09-12-recovery.md`; earlier outage requests are also archived verbatim.
R18/R19 settle the ambiguity about endless progression: XP/cosmetics and new
build possibilities continue; permanent numerical item power does not inflate.
The rarity-luck idea is a concern to simulate, not permission to flood markets.
Keep the 2D-first order, integrate the weekly enchantment/progression seam with
the pending item/VFX/Haven work, then Rebirth's local 3D path. Community/server
features require concrete specs, tools and native tests; no fiction that local
prototype saves, uncompiled UE code or blockchain provide production trust.
Current slice: renewal outcome gate passes (actions, save isolation, nicknames,
visibility, real Haven return); existing click/flask/level-up pass. First GL
captures expose remaining texture repetition, small hero and HUD hierarchy;
fix these in the art/world pass and take steady-state performance samples.

Recovery checkpoint: 115 Python tests pass with the required local runtime
access; the sandbox-only attempt could not complete. Godot renewal/navigation/
companion/visibility gates pass. R03/R04/R07 are complete; the wider art, melee,
UI and world demands stay open. R09 streaming repair now discards obsolete
loads, prioritizes nearby ground, closes unfinished-terrain movement fences,
retries helper failures without moving, reconciles unload reversals, bounds
active chunks at 49 and shadow masks at 7×7, and removes scratch dumps. Real
stream_recovery passes far/negative travel, unload reversal, failed-helper
recovery and deterministic return; worst apply 1.07 ms (ordinary stream 1.10 ms).
Actual GL frames expose the remaining small hero/repetitive floor. Full updated suite: all 19 Godot outcomes pass, with spawn placement rechecked
after correcting its eight-second live-pursuit false failure. CTest 4/4 and
validator pass. Full-run stream 0.93 ms / recovery 2.15 ms / FX 2.99 ms (zero pool growth);
recovery exceeds the 2 ms target in that sample but stays below 4 ms hard ceiling.
Upcoming: per-Hunt dormant encounter state, native biomes/art contract, weekly enchanted
builds/cosmetic XP/Haven stations; keep Rebirth after all 2D gates.

Warmed actual GL receipt: 300 gameplay frames at reported 60 FPS; frame median
16.668 ms / p95 16.911 ms, CPU process median 3.813 ms / p95 4.218 ms. PNG readback stalls
are excluded. Full captures and reproduction: docs/art/ui-renewal/README.md.
This is a short desktop sample, not a sustained/mobile guarantee. First playable
recovery milestone is being committed/pushed and packaged; all remaining R-items
stay scheduled/in progress.

Interruption checkpoint (Ricardo, 2026-09-13): "resume work" — exact prompt
appended to the archive. Continue R01–R26, 2D first, preserving all earlier
requests. Commit 3f52b35 is pushed to origin/master. Linux/Windows packages built
and exported gameplay/icon checks passed; staging correctly updated the tracked
chapter texture-budget count for the larger hero atlas, so those initial manifests
are dirty-source. Commit that generated metadata and the publication record,
rebuild clean-source packages and associate the Linux executable icon, then
continue encounter hibernation/biomes/art/Haven/enchantment systems. No other
agent/worktree changes or stashes were touched.

Interruption 2026-09-13: recover ALL messages AND the in-progress work from
before the session ran out; full wording appended to the request archive.
Audit branches/worktrees/stash references and saved candidates, not only the
latest chat. Preserve existing work; do not drop the older 2D or Rebirth demands.
Current source milestone b622aa6 (prior 3f52b35 pushed); clean-source package
job is running. This documentation-only interruption can dirty its manifest;
verify actual source records before claiming a clean export. Continue the active
R08/R09 investigation after completing the binary/icon handoff. The preserved
Codex branch and unrelated stash remain untouched.

Recovery audit receipt: the old Codex branch has zero commits absent from master;
its temporary checkout directory is gone but Git history survives. The preserved
stash contains the earlier icon/export/save-directory changes now superseded by
mainline equivalents; do not reapply or drop it. Candidate assets, provenance,
Rebirth assets and prior test logs remain in the repository. Both rebuilt packages
record clean b622aa6 source and pass their exported gates. Actual Linux icon
association now verified through GIO: executable points at the installed PNG;
host .desktop syntax passes. Installer now strips incompatible Snap IDE GIO
module overrides and targets the host application directory (three tests pass).

R08 implementation strategy: a prototype presentation residency adapter persists
primitive creature snapshots to per-Hunt, per-chunk files; no retained dormant
scene nodes or unbounded visited-chunk dictionary. Preserve identity, spawn stats,
HP/statuses and paired-boss linkage, restore before timed spawning, require drawn
terrain and respect the active cap. Fresh/unvisited and killed encounters remain
distinct; re-entry grants no loot or heal and restarts a readable recovery tell.
Co-op considers every host-owned hunter. The current prototype state remains local,
never proof for official cashable/ranked servers (tech/36). Gate actual wounded
ordinary/boss unload→return, killed persistence, pairing and cap pressure.

R08 checkpoint: residency adapter now integrated, with per-frame disk/scene
work, stable IDs, dormant stats/status snapshots, no retained dormant nodes,
per-chunk rolled markers replacing the unbounded visited dictionary, cap checks
on new packs and summons, and symmetric paired-boss links. First actual probe
passes wounds/stats/pairing/death/cap/cleanup (worst step 0.87 ms); added co-op
proximity and capped-summon assertions are running. Full suite and GL travel
sample still required. Pending modern hero/biome source-art candidates must be
inspected before replacing runtime assets; no static-concept quality claims.

R08 actual GL receipt: 81 original actors became dormant on outward travel
(7 frontier actors remained active). Returning restored the wounded target with
identical HP; final 66 active/22 dormant includes the 7 new frontier creatures.
300 warmed return frames report 60 FPS; process median 4.573 ms / p95 9.167 ms,
residency worst 0.707 ms, chunk apply worst 1.253 ms. Captures reviewed in
prototype/tests/captures/residency. R08 is complete for the current prototype;
native official entity storage and slow/mobile-storage budgets remain separate
production gates. Full 20 Godot/Python/native checks running before commit.

Hunter image cleanup attempt rejected: provider baked an opaque checkerboard
(alpha 255 everywhere). Keep valid transparent source-v1; it has 32 separate
major sprite components, but the last running sword is clipped at the image edge.
Record rejection/provenance and do not ship the bad edit. Next art step: robust
local component/pivot ingest and a separately repaired missing-edge pose, then
actual pixel-scale animation captures. No invented in-between animation or
claim that this candidate already replaces the runtime hunter.

## DONE — Commit and push all completed work (Ricardo, 2026-09-12)

Demand: commit everything and push the changes, resolving any merge issues.
Law: harness integration gates; this explicitly authorizes publishing the
completed work to the existing GitHub main branch, `origin/master`.
Strategy: inspect both worktrees, record this demand, fetch every remote,
merge any new upstream commits without rewriting remote history, verify the
result, commit the publication record, and push `master`. Verify the remote
commit matches local HEAD and leave a clean tree. Preserve ignored generated
artifacts and the existing review branch; no force push or unrelated cleanup.

Publication receipt recovered: GitHub accepted 08f92d6 → e036a7c on master.
The quota rejection happened after that successful push, during the attempt to
record completion. Live remote ancestry will be refreshed at this resumed pass.

## DONE — Audit infinite hunter, monster and item scaling (Ricardo, 2026-09-12)

Demand/question: do items and monster levels/stats scale indefinitely alongside
supposedly infinite hunter levels? Law: canon §3 and §§12.16/12.20/12.45,
design/14 §4, design/26 and tech/29. Strategy: inspect actual progression caps,
monster spawn scaling, item-level/affix formulas and the separate boss-rush
limits; distinguish implemented behavior from proposals and document any drift.
This is an audit and design clarification, not authorization to remove the
power ceiling, rebalance existing gear, or migrate saves automatically.

Findings: hunter progression caps at 100; monsters scale once at spawn;
ordinary gear rolls at hunter level with +4% of its starting band per level;
forge caps at +5. Frontier distance caps elite-affix odds rather than granting
extra monster levels. The separate rush stops HP growth at 1.5× (round six),
uses fixed artifact values and has bounded counters. The item's rolling helper
accepts higher inputs but does not create an infinite progression loop.
Design/14 retains the permanent-power ceiling and older ilvl-60 proposal;
playable 1–100 is recorded in canon §12.16. Full sources/formulas and design
implications: design/24, Progression scaling audit. Corrected tech/29's
implementation description while retaining the intended level-bias proposal.
Gate: source/formula audit + documentation diff check; no runtime changes.
An endless mastery/depth design is a possible follow-up, not an implemented
system or an approved change to the permanent item-power ceiling.

## DONE — Refresh Hunt stats and replenish resources on level-up (Ricardo, 2026-09-12)

Demand: when the hunter levels up during a Hunt, refresh stats and replenish
HP and the relevant combat resources immediately. Law: canon §3, the existing
prototype progression contract in design/24, and the harness outcome gates.
Strategy: trace the current kill/progression and stat-application path, identify
which resources actually exist, refresh derived values before refilling them,
and prevent ordinary equipment/stat changes from granting free healing. Add
an outcome regression for real Hunt level-up, update the docs in the same
change, commit on the approved mainline, and refresh the Codex test binaries.

Inspection: existing level-up only healed HP after VFX. The Hunt's other
consumable resources are dodge and Ember Flask charges; there is no mana pool.
Apply the stat/resource refresh before feedback and share it with host-owned
remote hunters, retaining equipment, cooldowns, earned stacks and death state.
The new real-death probe passes ordinary/duplicate/multi-level/dead-player and
party cases. The exported smoke also exercises the refill through an actual
creature death so the binary, not just the editor, proves this behavior.

Delivered and gated: `ProtoPlayer.refresh_on_level_up()` recomputes stats,
refills living hunters' HP/dodges/flasks and discards obsolete refill timers.
The Hunt applies it before VFX; the co-op host also refreshes living allies.
All 17 Godot outcomes pass, including the new real-death regression and co-op;
113 Python tests, CTest 4/4, validator and whitespace gates pass. Streaming
worst apply 1.39ms; FX stress 5.53ms with no pool growth. Fresh Linux and Windows
Codex packages record clean `master` source **e570acc**. The actual Linux export
passes the new kill → level-up → HP/dodge/flask refill gate (94-creature Hunt),
practice and the full saved lair/rush journey. ZIP/hash and both Windows six-size
icon checks pass; Windows gameplay remains untested natively. The final package
record changes documentation only.

## DONE — Land the approved Codex work and give the UI a stronger identity (Ricardo, 2026-09-12)

Demand: the UI needs more personality; commit the reviewed graphics/content work
onto the main branch. Main is named `master` in this repository. Law: canon
§12.45, design/26, and the harness integration/visual gates. This explicitly
supersedes the earlier review-branch-only landing constraint.

Strategy at this interruption: preserve the clean Codex review branch, inspect
the existing UI/theme and canon, define a bounded presentation pass around the
world's bronze, Lumen and Gloom motifs, and keep gameplay and readability intact.
Fetch all remotes again, integrate over the latest committed mainline without
overwriting concurrent work, verify the UI in actual GL captures and run the
required compatibility gates. Commit the finished work and fast-forward `master`
when ancestry permits; retain the Codex branch and produce tested Codex packages
from the landed source. UI work beyond the bounded pass remains explicitly
tracked rather than being represented as finished.

Delivered UI pass: shared bronze/ivory/Lumen theme, cut-metal corners,
keyboard focus, rune volume sliders, shrine-backed menu/Haven/collection,
and authored artifact cards with two-line names and bounded lore excerpts.
EN/PT menu copy fits; normal login, quick start, co-op, arena and options remain.
Gates: 113 Python tests, CTest 4/4, validator and all 16 Godot outcomes; stream
1.48ms, FX stress 4.85ms. Actual GL UI captures report 60 FPS at 1280×720.
Landed all six Codex commits on `master` by fast-forward to **70e8b4f**, after
another fetch confirmed `origin/master` 08f92d6 and clean worktrees. No conflicts,
no upstream commits missing, no changes to rebirth or tracked Windows artifacts.
Fresh Linux and Windows packages in `builds/codex/` both record clean `master`
source **70e8b4f**. CRCs/file hashes and both Windows six-size executable icons
pass. Exported Linux normal Hunt (86 creatures), practice (eight atlas frames,
chain + ward) and complete lair → saved reward → same-world return → rush →
second artifact → round two pass. Windows gameplay remains untested natively.
Final practice GL capture: 60 FPS, 1.942ms process CPU, 85 draws (prior: 60 FPS,
1.52ms, 85 draws); short desktop samples, not a sustained/mobile guarantee.
The later landing-record commit changes documentation only. Commits are local;
no remote push was requested or performed. The Codex branch remains available.

## SCHEDULED — Extend the UI identity into the production HUD and bestiary

Demand: carry Ricardo's stronger UI personality direction beyond the first
menu/collection pass. Law: design/26 UI identity and design/17 §8; prototype
typography doctrine canon §12.31. Next slices: class/Bestial Skill sigils,
connected bestiary, production gear cards with signature/lore hierarchy,
readable HUD ornaments and touch/controller navigation. Gates: actual busy-Hunt
frames, input/focus outcomes, production inventory compatibility and target-device
frame budgets. Keep weekly content authored through existing stable-ID fields.

## DONE — Synchronize GitHub and verify compatibility (Ricardo, 2026-09-12)

Demand: fetch all GitHub changes and ensure the isolated Codex branch is current
without merge conflicts or incompatibilities. Law: harness/README gate suite;
preserve the other workspace and work on the latest committed mainline.
Fetched every configured remote (`origin`) and rebased all Codex commits onto
`origin/master` **08f92d6**, including 674d57b (HUD/hordes/Nakama/launchers) and
the rebirth import. Final fetch still reports that revision; ancestry check
proves zero upstream commits missing. The original workspace remains untouched.

Resolved the one menu conflict by keeping quick play, ARENA and Codex content.
Grouped navigation rows + scrolling/focus support retain access at 640×360.
Updated the real-click probe to scroll upstream's new skill detail card before
learning/assigning; all original outcome assertions remain. Codex Windows builds
use `sim/build-codex-windows`, avoiding upstream's tracked absolute-path cache.
Windows helper arguments and file paths support Unicode explicitly.

Gates: **113 Python tests; CTest 4/4; all 16 game outcome checks**, including
upstream ESC/flask/repopulation and co-op. Console's expected malformed-JSON
fixture remains qualified. Stream 2.25ms in the full run, **1.12ms** isolated
with doorway-lifetime assertions (2ms target / 4ms hard cap). Native Windows
cross-build and both embedded six-size icons pass; actual Linux exports pass
normal Hunt, practice and the complete lair/reward/rush journey. No unmerged
paths or whitespace errors; rebirth and upstream Windows artifacts unchanged.
Both Codex packages verified; re-export after this commit for clean BUILD-INFO.
Named stash 06cffd7 protected the interruption and can be dropped after commit.

## DONE — World entrances, boss lairs and earned boss-rush farming (Ricardo, 2026-09-12)

Demand: generated-world dungeon entrances, special bosses with their own lairs,
and earned boss-rush unlocks for item farming. Law: canon §§1,4,7,12.45,
design/26 and tech/35. Originally started over 8321356; integrated over 08f92d6.

Delivered: v2 data-authored lair catalog (up to eight supported guardians),
separate versioned C++ POI metadata on clear walkable pads, visual bell arches
and bearings, G interaction, exact-Hunt pause/return, native eligibility,
ordinary-input boss victories, once-per-victory artifact rewards, saved local
collection, owned artifact effects, and repeatable unlocked-roster boss rush
with bounded difficulty and intermission healing. Orun is the first guardian.
Practice exposes every preset without awarding items or unlocks. All progression
belongs to the C++ host and stays outside cashable tables. The full production
gear/class/pet migration and P2P/public-server lairs remain separate follow-ups.

Gates: native real-fight/replay/lock/death/retry/pause/advance cases; deterministic
clear-pad generation across positive/negative chunks; atomic saves, exclusive
writers, Unicode paths and corrupt/unknown/duplicate record preservation;
authoring and real transport rejection cases. Exported Godot journey proves
entry → native victory → first artifact/unlock → same-world return → helper
restart → rush victory → second artifact → scaled round two. Discrete inputs
are retained until acknowledgement and across host packet batches/pause/save
retry (a windowed test caught the original missed continue pulse).

Actual GL frames inspected in `docs/art/lair-journey/`: 1280×720, **60 FPS**,
2.033ms process CPU, 89 draws, peak doorway draw CPU 277µs in the journey sample.
Final practice capture: 60 FPS, 1.52ms process CPU, 85 draws, draw CPU 745µs.
Texture working set remains 7,573,376 bytes / 8 MiB per encounter. These are
short desktop samples, not sustained worst-case or mobile claims. Codex archives
include the offline review and controls; Windows gameplay needs a native run.

## DONE — Playable living-content preview binary (Ricardo, 2026-09-12)

Demand: show where pending content can be reviewed and generate a binary
that makes the candidates playable. This explicitly prioritizes the previously
scheduled integration slice. Law: design/26, tech/34, canon §12.45; preserve
C++ simulation authority and the Codex branch/save/package isolation.
Plan: expose a main-menu playable Bell Beneath the Fen trial with the generated
Orun sprite, candidate artifacts/lore and working skill/effect interactions;
keep simulation/effect application in C++, presentation/input in Godot, and
compile candidate definitions from the existing authoring data. Add outcome
and packaging gates, rebuild Codex desktop binaries, and document exactly
which preview systems are playable and which remain production follow-ups.
The offline review remains at genforge/candidates/living/fen_bells-73778038d652aed7/index.html.

Delivered: main-menu PLAY NEW CONTENT entry; generated Orun atlas and new
shrine plate; a C++ 30-Hz five-phase boss fight, four artifact presets with
real echo/chain/refund/ward application, Wet setup, dodge i-frames, companion
commands, lore/pause, retry/victory/defeat and temporary Orun-following bond.
Authoring/schema/stager → generated C++ tables + display metadata; unsupported
verbs and unsupplied combat conditions fail staging. Local owned helper with
loopback-only endpoint/token, finite bounded input, monotonic sequencing,
content parity, pause-on-silence and clean exit. Runbook: tech/35.

Gates: CTest 2/2 (new living outcome/replay suite); **106 Python tests pass**,
including authoring rejection and real transport checks; full headless
game outcome suite passes with the existing intentional console JSON-error
fixture qualification. Stream: 2.62ms in the full run, 1.15ms isolated
(2ms target / 4ms hard cap). Real exported Linux trial: 180 native ticks,
264.516 damage, chain + ward procs, eight animation frames; normal exported
Hunt streaming smoke also passes. Windows client/helper cross-build and both
embedded six-size icons verified; native Windows gameplay remains untested.
Actual GL trial/menu frames inspected; 1280×720 capture reports 60 FPS,
2.086ms process-frame CPU, 85 draw calls, peak draw CPU 3.076ms. Trial texture
estimate 7,573,376 bytes / 8 MiB cap. Full action animations, normal Hunt /
class-tree / save migration and public-server deployment remain scheduled;
the trial is a playable review slice with temporary progression.
Rebuild binaries after committing so their BUILD-INFO identifies clean source.


## DONE — GitHub README banner (Ricardo, 2026-09-12)

Demand: create a beautiful banner for the GitHub README, continuing on
`codex/modern-pixel-content-engine`. Law: design/26 modern pixel-art direction
and design/17; brand source: `genforge/art_sources/app_icon/`.
Plan: generate original wide dark-fantasy key art with the Dragon Heroes title,
inspect readability/composition, save the artwork and prompt/provenance under
`docs/art/readme-banner/`, embed a relative image link with descriptive alt text
at the top of README, validate the asset and link, and commit this documentation
change. Existing Codex binaries continue to identify their tested code commit.
Delivered: `docs/art/readme-banner/dragon-heroes-banner.png` (2172×724,
3:1, 2,824,106 bytes), exact generation prompt and SHA-256 provenance;
root README embeds the repository-relative image with descriptive alt text.
Gate: original artwork visually inspected for title spelling, composition and
readability; PNG decoding/dimensions/hash and local Markdown links validated.
Documentation/art only: existing runtime test evidence and packaged binaries
remain those of code commit `60764dc`; no binary regeneration needed.

## NOW — Ricardo's isolated review branch (2026-09-12)

New priority: modern 2D pixel-art production and an extensible weekly content
engine. Branch `codex/modern-pixel-content-engine`, isolated worktree
`/tmp/dragon-heroes-codex-content-engine`, originally based on `b3d41e9`, now rebased onto committed `08f92d6`.
The original workspace's uncommitted gameplay/training changes remain untouched.
Law: `docs/design/26-living-pixel-world.md`, canon §§1, 4, 7 and §12.45.

1. **DONE — Review moats and existing art/combat/content systems.** Translate
   the requested modern, luminous dark-fantasy direction into measurable art
   standards while retaining readable action, creature buildcraft and 60 FPS.
2. **DONE (authoring/review scope) — Redesign asset generation.** Style-locked briefs, animation/material
   contracts, quality gates, reproducible manifests and a visual review surface.
3. **DONE (candidate + proposal) — Story-bearing rarity and skill evolution.** Legendary, Relic,
   Mythic and Divine artifacts receive lore and bounded gameplay/VFX identity;
   review skill systems and propose fast, expressive class/pet/rune synergies.
4. **DONE (offline engine) — Automated weekly expansion.** Validated, data-only creature/item/
   effect/lore packs, reusable tooling, example release, regression gates and
   documented review/test commands. No claim of live integration until proven.

Strategy: inspect canon and implementation first; extend existing GenForge
seams and content validation; keep authoring offline and combat authority in C++;
ship a concrete reviewable example with automated gates. This demand takes
priority in this isolated branch; existing NOW work remains in the original tree.

Interruption checkpoint (2026-09-12): isolated branch created; generated and
saved Gloamfen keyframe + Bellwether eight-frame idle source. Implemented
`genforge/living/` draft/generate/build/atlas/validation/review tooling,
`content/schemas/expansion.schema.json`, authored `fen_bells` release (five-skill
boss, four artifact rarities, connected lore), C++ bounded effect evaluator and
`dh-effect-lab`, CI integration. Initial 22 new tests + CTest + content validator
passed; expanded Python suite was running (session 41152). Raw atlas inspected:
128px frames, 48-color palette, 8 unique frames, 1.064 MiB albedo+emissive.
Remaining: finish design/canon/usage/handoff updates, finish regression gates,
inspect final diff and commit this branch. Browser capture blocked by Firefox
Snap profile isolation; Godot import completed but sandbox blocked editor
settings/socket access. Neither is a successful visual runtime gate. Candidate
is explicitly non-publishable; movement/attack/hit/death animation and live Hunt
integration are not implemented and must stay visible as follow-up work.

Final review-branch evidence: design/26 + tech/34, generated source art and
palette-constrained atlas inspected; full Python suite **93 passed**, including
**24 living-pipeline tests**; content validator **46 legacy definitions + one
candidate / zero problems**; CTest and the four-effect compiled C++ probe pass.
Headless outcome checks pass: import, menu, Hunt ×3, spawn, stream, click,
FX stress, arena, console, cosmetics, co-op. The console deliberately feeds
`not json at all` (`console.gd:876`), which logs an expected parse error while
all selftest assertions pass. Stream initially measured 2.22ms apply (above
the 2ms target, below its 4ms hard limit); preserve that qualification.
An isolated rerun measured 2.16ms, also within the hard cap and above target;
there is no evidence that this offline change altered the live streamer.
Firefox Snap could not access the isolated profile, so the HTML screenshot
gate remains unverified. Review JavaScript syntax passed; the artwork and
compiled atlas were inspected directly. No whole-game visual gain is claimed.

### DONE — Codex binaries and executable icon (Ricardo, 2026-09-12)

New demand: regenerate the review branch's distributable binaries with a
`codex` affix and create an icon for the executables. Law: tech/34 (packaging
section), design/26 art direction; existing export contract in docs/USAGE.md.
Plan: generate an original dragon/Lumen icon, derive native icon sizes,
configure project and Windows resources plus a Linux desktop launcher;
rebuild Linux and Windows in isolated `builds/codex/` paths, with explicitly
named `dragon-heroes-codex` executables/archives. Validate packaged contents
and exported Linux startup, preserve original workspace and normal builds.
The prior pipeline review remains delivered; its pending live integrations
are not implicitly included in this packaging request.

Steering (Ricardo, 2026-09-12): the other agent has been asked to commit;
rebase this Codex work onto the latest committed mainline before continuing,
so the regenerated binaries include that work and conflicts are resolved here.
Checkpoint: dragon/Lumen icon source, PNG/ICO conversion, project/export icon
settings and Windows C++ icon resources are in progress. Packaging-script
replacement has not landed yet. Preserve these local edits during the rebase,
then complete the Codex-named packages and validation from the updated base.

Rebase checkpoint: `8568d26` is included; canon and C++ tests retain both
upstream arena work and the Codex effect probe. Icon/packaging edits restored
from stash `73d6dfa65a06b313d4fd931522521fbd86d64738`. Dedicated
`tools/package_codex.py` now rebuilds clients/helpers and checks manifests.
Python suite: 93 passed after rebase. Linux first export passed contents gate;
Windows icon verification caught a resource mismatch, under diagnosis. Check
mainline once more before final packaging; other workspace still has uncommitted
changes, which are not safe to import until their agent commits them.

Packaging defect discovered by the real exported-game outcome gate:
**DONE — exported streaming helper lookup** (law tech/29 + tech/34). The
package contains the helper, but `can_stream()` still checks only the dev
`sim/build` path; exported Hunts silently fall back to seed-404 island.
Use the resolved adjacent executable in the capability check and identify
exports by absence of the editor feature. Gate: actual release PCK boots menu
then a populated Hunt with `_streaming == true`, using its packaged helper.
Release templates disable external `--script`; an explicit `-- --codex-smoke`
probe is included and otherwise dormant. No interactive menu change required.

Final packaging evidence: original dragon/Lumen source + PNG/six-size ICO;
Linux and Windows clients/helpers rebuilt, actual embedded Windows icons
verified byte-for-byte (all six sizes, game and helper), default-template
negative check rejects the Godot icon; package manifests and ZIP CRCs pass.
Actual Linux release smoke: menu built, PNG/ICO present, separate Codex saves,
streaming world from the adjacent C++ helper, 95 creatures. Optional Linux
launcher verified in isolated XDG data with escaped special-character paths.
Python 93 passed; CTest + content validation pass. Final full headless suite:
all outcomes pass with qualifications — spawn failed once (streaming=true,
nearest 0px), then isolated rerun passes (91 creatures, nearest 135px); console
keeps its expected malformed-JSON fixture error. Full-run raw failure remains
in results.json and spawn-first-rebase.log; recheck-results.json proves rerun.
Stream measured 1.51ms (2ms target / 4ms hard limit). Windows gameplay/shell
appearance and desktop visual capture are not claimed. Latest checked mainline:
`8568d26`; source HEAD/dirty state are included in each archive's BUILD-INFO.json.
Rebuild after the packaging commit for clean provenance; archives remain in
`builds/codex/` and are ignored rather than adding binaries to source history.

### SCHEDULED — production follow-ups

- Complete Orun's movement, directional/action, contact, hit/death animation
  and manual cleanup; verify native-scale Hunt captures (design/26, tech/34).
- Connect effect commands to authoritative world targeting/damage/resources,
  status ownership, pet kit execution and animation events; add integration
  and replay gates (tech/34). The C++ probe currently tests commands only.
- Integrate new item rarities into live item/save/UI/loot schemas with stable
  IDs and a migration; map class/resource/rune/companion proposal onto the
  current prototype and C++ port (design/26). Existing live items are unchanged.
- Profile the crowded composite on desktop and mid-mobile; apply global
  VFX/light/texture budgets; promote only curated assets and reviewed lore
  through signed data-only client/server packs with canary/rollback (tech/34).

## NOW — finish what is open

- **Arena training console + speed lever** (design/25, canon §12.39) — LANDED
  2026-09-11: `game/arena/console.tscn` (roster with jobs/speed + parallelism
  hint, Train/Stop, progress tail → fitness chart + match-score strip + ETA,
  Gate, Watch), the progress JSONL seam, `arena --speed max|N` (CPU-bound
  training: one worker ≈ 24× the old wall-locked fast mode, bit-identical
  results; 16 workers ≈ 870× real time). Gates: CONSOLE SELFTEST OK, ARENA
  SELFTEST OK, pytest ml 18. OPEN: the learning signal — candidates take 0 wins
  vs native fen_boar every match, fitness moves only on hp margin; next is an
  opponent curriculum (scripted → past self → native) and/or shaping (tech/25
  §4.2), now ~3 s per generation to iterate.
- **Image-to-3D spike, draft tier** (tech/31 §4-5): TripoSR is INSTALLED at
  `~/tools/TripoSR` (torchmcubes patched for CUDA 12.8 — recipe in tech/31 §4;
  runner adapter versioned at `genforge/pipeline/runners/dh_runner_triposr.py`).
  Next: real concept renders for fen_boar + gloamfen_stalker (52 px sprites are
  NOT valid conditioning), `python -m genforge.pipeline.mesh_gen --actor
  fen_boar --image <concept.png> --provider triposr`, judge in hunt3d + as
  sprite re-renders (§5 gates). Then Hunyuan3D-2mini for the shape-quality delta.
- **Play co-op with real eyes** (tech/33): client feel, puppet interpolation,
  world parity across two machines. Then confirm CC BY-NC for assets
  (business/32) and fetch export templates (~1 GB) to package for friends.
- **Watch item**: spawn_probe flaked once after `--import`; rerun-then-judge.

- **Rebirth engine experiments — Ricardo's three picks** (rebirth/docs/02-status.md
  §4–5): (1) layout — root-level UE scaffold from the parallel session vs
  `rebirth/unreal/`, siblings `rebirth-native/` + `rebirth-unity/` vs folders
  inside `rebirth/`; (2) flip `rebirth/godot3d` to Forward+ on your window and
  judge the graphics honestly; (3) install UE 5.4 (Epic account, ~45 GB) and
  run the compile-fix pass + R0–R3 gates in `rebirth/unreal/INSTALL.md`. Then
  R4: PLAY the Godot slice — the gates prove the loop closes, not that it is fun.
  A real Gen-AI mesh through `rebirth/assets/tools/gen_assets.py` rides the same
  concept-render unblock as the image-to-3D spike below.

- **DONE 2026-09-13 — command ledger, arena → game** (Ricardo: "document all
  commands: from arena starting to game starting - all give them to me").
  `docs/USAGE.md` rewritten as the single verified reference: every command
  re-run against this tree that day, with the real pass lines in the gate
  table; only long training runs, packaging (needs the ~1 GB templates),
  Nakama's containers and the Ricardo-only Vulkan path are marked *not run*.
  New since the old doc: the OPTIONS modal, the PPO/GPU tier in `ml/.venv`,
  dh-env + bench, dh-server's living-preview/lair-profile/dump modes, the
  Lairs & Legends trial tools, the Codex packaging set, `dump_specs`, and the
  rebirth slices.

- **Isolated, cumulative training runs (Ricardo, 2026-09-13: "can't we have a
  test backup so i can test freely and cumulatively without overwriting stuff?
  perhaps if theres an active one we put the new registry inside a folder with
  the configs used and date as name (with date first as to order it proper
  chronologically in the folder)").** Every trainer writes the SHARED
  `ml/serving/registry.json` + weights, so two sessions (or two experiments)
  overwrite each other. Wanted: per-run folders named date-first with the
  config in the name, seeded from the current registry so runs accumulate,
  promoted back to `ml/serving/` only on purpose.

- **Deep ML documentation (Ricardo, 2026-09-13: "deeply detail our
  documentations. Specially for our ML files, I want details on every parameter
  and hyperparameter, as well as artifacts produced and how they are later
  consumed and benchmarked").** One reference covering every knob of
  league.py / ppo.py / evolve.py / gpu_guard / torch_policy / policy_net /
  dh-env: what each parameter means, its default, what it costs, what it
  changes; every artifact (weights JSON/npz/.pt, registry entries, progress
  JSONL, episode records, logs) with its schema, producer and consumer; and the
  benchmark/gate path each artifact travels.

- **DONE 2026-09-13 — Training console = the ML cockpit (Ricardo: "Is the train_run
  included in arena console? can we run it there instead? as well as manage
  active and deployed nets, and even put one against the other for benchmarking
  (best of N)").** The console still shells out to `league train` against the
  deployed registry. Wanted, in the console: (a) start runs through
  `tools/train_run.sh` so every experiment is isolated + cumulative; (b) a runs
  browser (date-first folders, config, gate verdicts) with promote; (c) manage
  the registry — see candidates vs deployed pins, deploy/retire; (d) head-to-head
  **best-of-N** benchmarking between any two nets (or native/scripted), with the
  result written somewhere durable. Plus: document all of it.
  **Landed:** the right pane is a TabContainer — PROGRESS / RUNS / NETS /
  VERSUS; an "isolated run" switch routes TRAIN through `tools/train_run.sh
  --run-dir` (new flag, so the console names the folder and knows where to
  tail); a "GPU (PPO)" switch runs the CUDA tier the same way; `league versus`
  is the new best-of-N seam (schema `arena.versus.v1` into
  `ml/data/benchmarks/`, streamed on the progress feed under key `versus`).
  `CONSOLE SELFTEST OK` now also covers the cockpit against `user://` fixtures,
  so the gate never touches the real registry, runs or benchmarks. Documented
  in design/25 §3b, USAGE §4, tech/37 §5 and ml/README.

- **DONE 2026-09-13 — The terminal is part of the game (Ricardo: "make sure to make
  logs constant and pretty in those files. I'll run `GENERATIONS=200 POP=10
  EPISODES=6 tools/train_run.sh --all` now and i want to keep track of it and
  have it beautifully exhibited and themed in the terminal. Are you able to
  create some art? GPT Astra created our current repo banner, show who is the
  best creating our terminal artistically now").** `tools/train_run.sh` pipes
  each trainer through `tail -2`, and the ES trainer is spawned without
  `python3 -u`, so a 200-generation run prints NOTHING for ten minutes per key.
  Wanted: (a) constant per-generation output, unbuffered; (b) a Dragon Heroes
  terminal theme — original ASCII/ANSI art, ember palette, shared by every ML
  script; (c) a live run dashboard to watch a long run.
  **Landed:** `tools/dh_term.sh` (palette + banner + rules + bars, colour
  dropped for non-TTY so logs stay greppable), `tools/art/make_dragon.py` (the
  sigil is rasterised from Bezier outlines into half-block glyphs, not
  hand-pasted, so it is re-tunable) writing `tools/art/dragon.txt`,
  `tools/dh_trainfmt.py` (live bar + fitness sparkline + s/gen + ETA per
  generation, PPO iterations too; candidate lines animate on a TTY and vanish
  in a pipe), `python3 -u` in `train_run.sh` (the actual cause of the silence),
  and `tools/train_watch.py` — a read-only dashboard over any run folder, with
  a sweep-wide ETA that counts the keys still queued.

- **DONE 2026-09-13 — Kill the PPO Python bottleneck + GPU training in the console (Ricardo,
  2026-09-13: "do it! ALso, can we run this gpu training in the console, as
  well?").** Measured: raw `libdh-env.so` does 527,665 steps/s, PPO end-to-end
  does 32,343 — the gap is the Python loop stepping each env one at a time
  through ctypes. Wanted: a batched `dh_env_step_many` across all envs (~16x
  headroom), and the PPO/GPU tier startable from the training console like the
  ES tier.

- **DONE 2026-09-13 — Interruptible ES runs — checkpoint + resume (Ricardo: "do
  it!", after a 10.4-hour run turned out to have nothing on disk).** `train_es`
  registers its net only AFTER the whole generation loop, so killing a
  1000-generation run discards every hour of it. Wanted: a checkpoint written
  every N generations (theta, the generation index, the RNG state) and a
  `--resume` that restarts a killed run from the last one instead of from
  scratch, without breaking the per-generation seed derivation that makes a run
  replayable.
  **Landed:** `--checkpoint-every` (default 25, so even a run started without
  the flag is protected) writes ONE `_ckpt_<key>.npz` into the run's own
  weights dir — theta, the next generation, and the RNG bit-generator state —
  temp-then-rename so a kill cannot leave half a file. (The first cut used two
  files; each rename was atomic but the pair was not, so a kill between them
  could pair theta from generation N with metadata claiming N-k. Folded into a
  single file so one rename commits the whole checkpoint.) `--resume` restores all
  three, so the resumed run is BIT-FOR-BIT the run that would have happened
  (`ml/tests/test_league.py::test_resume_reproduces_the_uninterrupted_run`
  asserts it against a simulated mid-generation kill). A completed run clears
  its checkpoint; a stale one of the wrong parameter count or already past the
  requested generation is refused rather than half-applied.
  `tools/train_run.sh --resume ml/runs/<run>` needs no other flags: config.json
  now records the key/build pairs and the knobs, so the folder describes itself.
  **Verified end to end 2026-09-13 17:31** on a real 6-generation run: killed the
  process group after the g4 checkpoint, then `--resume` ran g4 and g5 ONLY,
  emitted `resumed g=4`, registered `fen_boar_alpha@v2`, and cleared its
  checkpoint. The resume was launched with deliberately wrong environment knobs
  (`GENERATIONS=999 POP=99 EPISODES=99`) and ignored all three — it reads them
  back from config.json, because knobs that disagree with the killed run would
  make the checkpoint inapplicable. `ml/serving/` stayed untouched throughout.
  **Note:** the sweep running since 2026-09-13 06:40 predates this and has NO
  checkpoint — killing it still loses its hours.

- **Method tournament, the console, JOBS, and the C++ forward pass — Ricardo,
  2026-09-13 (latest+1).** Four demands in one message:
  1. *"add that to fight over in the other training methods, as to compete
     intra-training when train-all, as to optimize for the best methods"* — when
     `--all` runs, the methods (ES-in-Godot, PPO-on-dh-env, and whatever comes
     next) should COMPETE per key, head to head, so the sweep picks the winner
     per creature instead of assuming one method is best everywhere. The
     `versus` command and `arena.versus.v1` already exist as the comparison
     primitive; what is missing is running it as part of `--all` and recording a
     per-key verdict. STATUS: designing.
  2. *"is this shown in the arena interface as an options? never ran that and
     would very much like to try"* — Ricardo has never launched the training
     console. It is `game/arena/console.tscn`. STATUS: answer + a launcher.
     NOTE: the other session is actively editing `console.gd`, so any console
     work here must not collide — read, do not edit.
  3. *"perhaps we should cap at 16? ... can't we run another creature key on the
     1-4 remaining cores? ... we are compute bound, not parallel worker bound"* —
     Ricardo is right, and the measurement agrees: jobs 16 and 20 are both
     6.4 s/gen, so **capping at 16 costs nothing and frees 4 threads** for the
     desktop. That is strictly better than `TRAIN_PROFILE=desktop` halving it.
     And his reasoning about parallel keys is exactly right: total work is
     unchanged because the box is compute bound, so running keys concurrently
     does not add throughput — but it does let every key progress at once
     instead of key 7 waiting days for key 1, which matters for comparing keys
     and for surviving an interruption. STATUS: cap landing; concurrent keys
     to design.
     **COLLISION, unresolved by design:** the jobs default lives in TWO files
     that the other Claude session owns right now — `tools/train_run.sh`
     (`TRAIN_PROFILE=desktop` -> `min(nproc/2, 4)`, so **4 jobs on a 20-thread
     box**, measured at 9.6 s/gen against 6.4 at 16) and `game/arena/console.gd`
     (`clampi(OS.get_processor_count() / 2, 1, 4)`, the same cap in the UI
     spinbox). Both are dirty in the working tree from that session. Flagged,
     not edited. The one-line change when they land: desktop default becomes
     `min(nproc - 4, 16)` instead of `min(nproc/2, 4)`.
  4. *"the biggest remaining win is C++ ... well, let's execute that right
     now"* — build `dh-godot` and move the neural forward pass into it.
     **DONE 2026-09-13, commit `6a46279`.** godot-cpp has no 4.6 branch;
     `godot-4.5-stable` is the newest tag and GDExtension is forward
     compatible, so the extension targets 4.5 headers and declares
     `compatibility_minimum = "4.5"`. `DhPolicyNet` holds flat
     `std::vector<double>` layers and runs GDScript's exact accumulation order
     (double accumulator, libm `tanh`, `-ffp-contract=off`) so fights stay
     bit-identical and no trained weight is invalidated. **566 -> 105 us/tick,
     5.39x** — but end-to-end only ~1.06x per generation, inside the noise.
     `neural_policy.gd` falls back to GDScript when `ClassDB` has no
     `DhPolicyNet`, so an unbuilt tree trains slower, not broken. Build with
     `tools/build_dh_godot.sh`.
     **NEXT PROFILING TARGET (this is now the bottleneck):** per-episode scene
     teardown/rebuild in `arena.gd::_start_episode` plus per-match overhead.
     With the tick cheap and the engine resident, that is where a generation's
     time actually goes.

- **"perhaps we should better model our reward model" — Ricardo, 2026-09-14
  (latest+15). TWO DEMANDS IN ONE MESSAGE, logged verbatim before any work.**

  **15a. Re-model the reward.** *"perhaps we should better model our reward
  model. What is currently considered? we can get each one of the columns
  values, weight out which is the most importante performance metric, and
  attribute weights to each variable, sclaing values to what is most impactful.
  Numbers magnitudes must be scaled tho, as to not compare 40 seconds with 0.087
  dmg_dealt. If winner, the shorter the better. If loser, the longest the
  better. "dmg_taken" is always "lower is better", "dmg_dealt" is always "higher
  the better", hp_foe lower the better, hp_self higher the better, win_rate the
  higher the better."*
  HIS SPECIFICATION, and it is a complete one — these are requirements, not
  suggestions:
    * every parity column becomes a scored TERM, each with a weight;
    * magnitudes are NORMALISED first (his example: 40 seconds must not be
      compared against 0.087 bars of damage);
    * directions, stated by him: `win_rate` higher better, `hp_self` higher
      better, `hp_foe` LOWER better, `dmg_dealt` higher better, `dmg_taken`
      LOWER better, and duration is CONDITIONAL — **shorter is better when you
      win, longer is better when you lose.**
  He is right that duration is conditional, and it exposes a live defect: PPO
  currently subtracts `R_TIME` every tick REGARDLESS of outcome, so a losing
  agent is paid to die sooner. See the answer below for what is scored today.

  **INTERRUPTION 2026-09-14 (latest+16) — R51, recorded VERBATIM before work.**
  *"can i visualize dh-env vs arena? or none is watchable? I would like to click
  in the console to render the current match (or last best) and watch it - this
  can help with debbugging as well"*

  | R51 | NOW with R50 | Watch a match from the console — render the current or last-best match, for dh-env AND the arena, as a debugging tool. | design/23; arena is already watchable, dh-env is headless C++ with no renderer; needs a trace dump + a replay viewer |

  ANSWER, and it is half yes: the **Godot arena is watchable today** (the
  console already has Watch, and `arena.tscn` has a spectator path and HUD).
  **dh-env is not, and cannot be** — it is headless C++ with no renderer at all;
  it produces state, not pixels. The way to make it watchable is a TRACE: dump
  per-tick positions/actions/hp from dh-env and replay them in the Godot arena.
  That is not a detour from R50 — it is the exact instrument the parity work
  needs, because the two environments can then be watched side by side on the
  same seed with the same policy.

  **INTERRUPTION 2026-09-19 — R52/R53/R54 + the R50 decision, recorded VERBATIM
  before work.**
  *"do it!"* — on the plan "curriculum + greedy eval (ppo.py only), masking in
  all five runtimes with a parity test, annealing, then the 60M run with plateau
  stop", after two turns of explanation (see the train/deploy block below).
  *"and /goal on all remaining roadmap itens! We want a new asset generator with
  hifi dark fantasy pixel art sprites! I'll give further details in the
  following prompt. Make sure to give it your best, as you'll be put against
  astra"*
  *"also, give me a brief explanation of those hyperparameter changes in a .md
  file in the root, please! and make sure to properly document all our
  experiments, with different hyperparameters!"*

  | R52 | NOW / details RECEIVED 2026-09-19 (block below) | A NEW asset generator: hi-fi dark-fantasy pixel-art SPRITES in the Dead Cells / Phantom Tower register — master prompt + mandatory negative prompt + five rendering pillars, recorded verbatim below. Benchmarked against "astra". | genforge; art/ style bible; Godot CanvasTexture normal/emissive channels; queued AFTER the R50 build order (Ricardo's stated order) |
  | R53 | NOW | A brief `.md` in the REPO ROOT explaining the hyperparameter changes (masking, greedy eval/promotion, β + move-std annealing, reversible promotion, snapshot reservoir, plateau stop). | `TRAINING_HYPERPARAMETERS.md` at the root |
  | R55 | **LARGELY CLOSED 2026-09-21** (tech/39 §2, R55-b rows): four divergences found by DAMAGE-BY-SOURCE in the first 10 s — (1) the **Fiery elite affix** was absent from the sim (`_strike` lands a second packet of half the swing as a "fire" element string, booked as BOLT: 25 of the 27 bolt points cinder_drake was missing per 10 s), (2) the **native kit driver** wrote into the single `act` slot instead of running on its own channel, so it was silent for the 55% of frames a body spends frozen in windup/recover, (3) the kit bolt fan carried **aim noise** `cmd_aim` never applies to a creature, (4) **storm bolts were 3.0 px** where `projectile.gd` says 4.0. Plus a harness bug: `env_parity` ran the arena on a 45 s clock and dh-env on 68.3 s. Matrix worst ratio **3.17 → 1.93**; the ranged-kit natives that drove the finding are closed (cinder_drake taken/s 2.31 → **1.01**, mire_serpent 2.06 → **1.02**, grave_shade 3.17 → 1.48). **Residual:** vs a SCRIPTED opponent the totals agree per channel but the fight runs ~1.8× longer in dh-env — the endgame, not the exchange (96% of the damage lands in the first 10 s, the last 4% takes another ten). Next: port `creature.gd::_separate(delta)` body separation (the arena has it, the sim does not), re-run the matrix at 64 eps, then retrain | LOCALIZED 2026-09-19 (tech/39 §2 matrix): physics at parity (melee/wisp natives and the policy's own bolts agree); the two OPPONENT DRIVER ports in `arena.cpp` diverge — `native_tick` under-uses ranged kits on ground bodies (drake/serpent/shade take 2–3× less in dh-env), `scripted_tick` engages at half the arena's exchange rate on every body. Fix both ports against `fighter.gd`/`scripted_policy.gd`, re-run the matrix, retrain | The converged nets win in dh-env and lose in the arena on the SAME greedy decode (cinder_drake greedy 0.94 in training vs 0.25 in the 4-episode arena gate; bog_golem 0.86 vs 0.25). Measure the dh-env→arena outcome gap per creature with ≥32 episodes (an `env_parity`-style harness over OUTCOMES, not policy terms), find the divergence, then best-greedy checkpoint export and a second documented run. Also raise the gate's episode count — 4 cannot separate 0.6 from 0.9. | tech/39 (2026-09-19_1015 bullet), tech/25 §5.1.5, `ml/eval/env_parity.py`, `ml/eval/gate.py --episodes` |
  | R54 | NOW / standing | Properly document EVERY experiment with its hyperparameters — a ledger, not prose: run id, knobs, result, verdict, kept or not. Every past run that can still be reconstructed goes in too. | `docs/tech/39-experiment-ledger.md`; `tools/train_run.sh` already records `config.json` per run — the ledger indexes them |

  **R50 DECISION (2026-09-19): Option A with masking, measured against B at the
  end.** In RL terms, the same πθ trained the same way; the choice was the
  EXECUTION rule (mode vs sample). Ricardo's own additions, adopted verbatim:
  interleave scripts and self-play rather than a one-way promotion ("until we
  are constantly winning scripted, as to not exploit some strategy"), and more
  stochasticity in training where there is no counterpoint (opponents and
  environment — not the policy, which is the gap itself). Build order:
    1. `ppo.py` only: greedy-eval envs riding in the batch (excluded from the
       update), dual reporting J(πθ) / J(πθ^greedy), promotion driven by the
       GREEDY number, promotion REVERSIBLE (demote below a floor), scripts
       never dropped to zero, self-play opponent drawn from a RESERVOIR of past
       snapshots rather than only the latest.
    2. Action MASKING in all five runtimes (torch trainer, numpy twin, GDScript,
       C++ `mlp_act`, `env_parity`) — unavailable actions to −∞ before the
       softmax, derived from the observation alone so it is bit-identical
       everywhere — plus a parity test that pins it.
    3. Anneal β 0.01 → 0.001 and move std 0.3 → 0.1 over the run.
    4. The converged run: 60 M steps per creature as the BUDGET, stopped early on
       a plateau of the greedy eval win rate vs scripted+native. Then a post-hoc
       sampled-vs-greedy measurement on the converged nets decides whether B's
       runtime change is ever built.

  **R52 DETAILS ARRIVED (2026-09-19, mid-turn, while step 1 of R50 was being
  written) — recorded VERBATIM in substance before continuing; the spec is
  Ricardo's, the generator is to be built against it.** The brief is a
  conversation (Portuguese) on "the technical pillars of Dead Cells and
  Phantom Tower", using a moss-covered guardian stag boss as the worked
  example. It fixes FIVE rendering pillars, a style matrix, a vocabulary, a
  MASTER PROMPT and a MANDATORY NEGATIVE PROMPT:
  1. **Real-time 2D normal-map lighting** — every sprite ships a hidden normal
     map (XYZ of each surface plane in RGB); dungeon lights (torches, elemental
     spells, blades) cast specular + dynamic shadow on the sprite at 60 FPS
     with the pixel texture intact.
  2. **Emissive channel + HDR bloom stacking** — the glowing core (the stag's
     turquoise chest) is an EMISSION channel, not a light colour; the engine
     blooms it and it lights floor and enemies as it moves in the dark.
  3. **3D→2D / bone-rig animation pipeline** — models built and animated in 3D
     at 60 FPS (cloth/weapon physics), rendered to native low resolution
     through an INDEXED-PALETTE filter so the result reads as hand-drawn pixel
     art: cinematic fluidity, anatomical weight, zero hand-drawn frames.
  4. **GPU particles at 60 FPS over DISCRETE sprites** — the creature cycles
     12–16 crisp heavy key poses per cycle (combat impact preserved); spores,
     leaves, smoke, dust, magic rays are GPU particle systems at true 60 FPS.
  5. **Solid fast-read outline (high-contrast dark ink)** — a continuous dark
     perimeter line, 1–2 px, unbreakable; selective outlining or lineless edges
     make a monster invisible among dozens of enemies + elemental VFX. It is a
     GAMEPLAY requirement (hitbox + posture read in a tenth of a second).
  **Style matrix (retro 90s → Dead Cells/Phantom Tower):** lighting static
  hand-drawn → dynamic 2D via normal maps + point lights; bioluminescence
  static light pixels → active emissive channel + HDR bloom; edges soft
  sel-out/irregular black → solid unbreakable 1–2 px dark outline; animation
  pure frame-by-frame 8–12 FPS → hybrid discrete key poses + 60 FPS VFX/lights;
  depth flat/simple parallax → directional volumetric shading, normal-shader
  ready.
  **Vocabulary to specify the style:** *Normal-Map Ready Geometry* (faceted
  surfaces at clear angles), *Emissive Channel Mask* (eyes/runes/crystals
  separated for dynamic light), *Volumetric Cluster Shading* (dense anatomical
  masses as big colour blocks with rich tonal transitions, no point noise),
  *Ink-Hold Perimeter* (continuous dark outer contour anchoring the silhouette
  regardless of room lighting), *Sub-Pixel Lighting Modulation* (inner glow
  varying smoothly — breathing, magic flow).
  **MASTER PROMPT (verbatim):** `[Creature/boss description, e.g.: Ancient
  moss-covered guardian stag boss with massive petrified wood antlers carrying
  a hanging bronze bell, shelf mushrooms on back, glowing crystal core in
  chest], hi-bit modern dark fantasy pixel art sprite, Dead Cells and Phantom
  Tower visual benchmark. 256x256 pixel grid, profile combat stance. Thick
  continuous solid dark-ink perimeter outline, strictly zero selective
  outlining (sel-out), zero lineless edges. Volumetric cluster shading with
  deep 8-shade color ramps, pronounced directional hue-shifting, and
  normal-map-ready planar depth. Dedicated high-contrast emissive core with
  sharp unshaded glow highlights ready for engine HDR bloom. Crisp native 1:1
  pixel grid, strictly zero mixels, no algorithmic interpolation blur, no
  noisy dithering, no pillow shading, isolated game asset on a clean
  transparent background.`
  **MANDATORY NEGATIVE PROMPT (verbatim):** `selective outline, sel-out,
  lineless, 90s low-res arcade, flat retro colors, blurry anti-aliasing, soft
  airbrush, 3D smooth mesh render, vector art, mixels, pillow shading, noisy
  dithering, faint edges, washed-out colors, compression artifacts.`
  **What this implies for the generator (strategy, not yet built):** prompt
  assembly from a creature description + this fixed style block + the fixed
  negative; post-processing that ENFORCES the pillars the model cannot be
  trusted on — 1:1 pixel-grid snap (no mixels), indexed palette with 8-shade
  ramps, perimeter-outline verification/repair, emissive mask extraction as a
  separate channel, normal-map derivation from the shaded sprite (for Godot
  `CanvasTexture` normal + specular), transparent-background enforcement — plus
  a gate that measures each of those and refuses assets that fail. It plugs
  into genforge next to the existing curated pipeline (canon §3 gen-AI is
  "style-locked, palette-enforced, human-directed"). Benchmark opponent:
  "astra". Ricardo may add more details; keep recording them here.
  **2026-09-19, minutes later:** Ricardo: *"keep working and just add consider
  this. I've just added it to sprites prompt.md in the project's root
  directory."* — the brief is ALSO the file **`sprites prompt.md`** at the repo
  root (Ricardo's file; read it in full when R52 starts, treat it as the
  source, this block as the index).

  **2026-09-19, later, while R52 was being built (two mid-turn messages,
  VERBATIM):** *"how does the asset pipeline rework works? we aren't
  generating thorugh any api, are we? if so, use gpt luna instead of any
  other"* — *"as it's cheap"*. ANSWER + STATE: nothing in R52 has called any
  API; the generator is provider-independent up to the `ImageBackend` seam
  and a `generate` command only reaches a provider when a key is exported and
  the command is run by hand. FINDING (web, 2026-09-19): "GPT-5.6 Luna" is
  OpenAI's cheap TEXT tier (launched 2026-07-09; $0.20/M in, $1.20/M out
  after the 2026-07-30 cut; 1.05M context) and **does not support image
  generation** (vision input only). So Luna cannot be the sprite model; the
  hifi generator's image model is a knob (`GENFORGE_HIFI_IMAGE_MODEL`,
  default the seam's `GENFORGE_OPENAI_MODEL`, i.e. gpt-image-1), to be set to
  whatever cheap image tier Ricardo confirms. If GenForge ever makes a TEXT
  call (lore/metadata drafting), Luna is the model to use — recorded as the
  standing default for text. DECISION OWED BY RICARDO: which image model id
  (OpenAI mini image tier vs the local repo of 13b).

  **R52 BUILT — 2026-09-19.** `genforge/hifi/` (13 modules): `spec.py` (master
  + negative prompt VERBATIM, pinned to `sprites prompt.md` by a test),
  `creatures.py` (Orun + the arena roster, each with its glow hue),
  `pipeline.process` = alpha (checkerboard/solid backdrop flood + matte-fringe
  eat + binary alpha + specks) → grid (lattice estimate by difference-mass
  concentration, harmonics by recursion, requested grid as prior; median snap;
  integer-only fit) → palette (hue-family ramps × 8 shades, cool-shadow /
  warm-highlight hue shift, shared ink, OKLab quantise) → emissive channel
  (declared hue, intensity) → dedither → Ink-Hold repair (never over the core)
  → normal map (`normal_gen` + ramp relief via new `height_bias`, emissive
  PACKED in B<128) ; `scorecard.py` gate (9 hard + 4 advisory checks, 0–100
  score, before/after) ; `write_bundle` (bundle_art.gd contract + `sheet_n`,
  `sheet_e`, palette/scorecard/provenance `dragon-heroes.art-source.v1`,
  review.html) ; `generate` best-of-n through the `ImageBackend` seam (model
  knob `GENFORGE_HIFI_IMAGE_MODEL`; negative folded when the backend has no
  slot) ; CLI `prompt · process · generate · score · bench · selftest ·
  creatures`. `sprite_lit.gdshader` reads the packed emissive (flat-lit, HDR
  push; parse-checked headless). Tests: `genforge/tests/test_hifi.py`
  (offline; synthetic model-like candidate: delivered FAIL → shipped PASS,
  silhouette IoU > 0.99). Docs: `docs/tech/40-hifi-sprite-generator.md`.
  NOT done: a real generation (no API called, per Ricardo's question — the
  model id is his call), pose-by-pose animation (KEY_POSES planned), the
  bench against astra (harness ready: `bench --label ours DIR --label astra
  DIR`), a lit capture of a hifi bundle in the prototype.

  **R50 BUILT — status at 2026-09-19 (steps 1–3 of Ricardo's order done and
  gated; step 4 launching).** (1) `ppo.py`: `--eval-envs 64` greedy probes in
  the same `step_many`, excluded from the update, `greedy=` beside `scripts=`;
  promotion on the greedy number, reversible (`--demote-wr 0.45`), scripts never
  dropped (⅓/⅓/⅓ after promotion, probes always on scripts), `--reservoir 8`
  snapshot pool round-robin (+ `ml/data/ppo_snapshots/`). (2) `arena.mask.v1`
  in all five runtimes — `ml/env/dh_env.py` rule, `torch_policy.mask_heads`,
  `policy_net.decode`, `neural_policy.gd::decode`, `Arena::action_mask` in
  `mlp_act`, `env_parity.act_from`, plus `distill.py`'s driver — pinned by one
  18-case fixture: `ml/tests/test_action_mask.py` (7 tests), `godot --headless
  res://arena/tests/mask_parity_test.tscn` → MASK PARITY OK, `sim-tests` (rule
  + frozen-opponent integration) all green. (3) β 0.01→0.001, move std
  0.3→0.1 linear (`--entropy-final/--move-std-final`). Plateau stop
  (`--plateau-updates/-delta/-min-steps`). Knobs plumbed through
  `tools/train_run.sh` into each run's `config.json`. SMOKES (fen_boar mirror):
  step-2 (3.28 M, mask on) promoted at it=40 on greedy, plateau-stopped at
  it=50, `greedy=` 0.32 vs sampled 0.59; `env_parity` on the exported net:
  PARITY OK, **win 1.00 in dh-env and the arena** vs native. 165–175 k sps →
  60 M ≈ 6 min/creature. **R53 DONE**: `TRAINING_HYPERPARAMETERS.md` at the
  root. **R54 DONE + standing**: `docs/tech/39-experiment-ledger.md`, table
  generated by `tools/experiment_ledger.py --write` from `ml/runs/*/config.json`
  (9 past runs indexed with context; scratch smokes by hand). NEXT: step 4 —
  `STEPS=60000000 PLATEAU_UPDATES=80 PLATEAU_DELTA=0.02 PLATEAU_MIN_STEPS=20000000
  CLONE=heuristic tools/train_all.sh --ppo` (all creatures, from scratch, local
  GPU), then the post-hoc sampled-vs-greedy on the converged nets decides
  whether Option B is ever built; then R52 (spec in `sprites prompt.md`).

  **AND IT ARRIVES ON TOP OF THE ROOT CAUSE, found minutes earlier.** Ricardo's
  decision this turn was "Close dps_taken first" (over running train_all now)
  and "20M steps per creature" for the eventual run. Chasing it found something
  larger than a damage-rate gap:
  **THE FAIRNESS LAYER EXISTS ONLY IN THE ARENA, NOT IN dh-env — the exact
  inverse of canon §9 §6, which says it is "baked into TRAINING, not patched at
  inference".**
    * `game/arena/policy.gd`: every policy observes through a sampled 150-250 ms
      DELAY buffer, aims through gaussian noise, and commits under
      `ACTION_BUDGET = 6` commits per second.
    * `sim/libs/dh-sim/src/arena.cpp`: `delay_s_` is SAMPLED on reset and then
      **never read anywhere** — grep confirms exactly two occurrences, the
      assignment and the declaration. The comment above `build_obs` claims "The
      learner's obs (dh_env_step out-param) is delayed the same way so training
      matches the eval gate's information state." That sentence is false.
      There is no obs log, no delay, and NO action budget of any kind.
  So PPO trains a policy that acts **60 times a second on zero-latency
  information**, and the gate then measures it acting **6 times a second on
  200 ms-stale information**. A 10x action-rate difference and a 12-tick
  information difference between training and serving. `dps_taken` 1.70-2.28x
  is the SYMPTOM: nothing throttles anyone in dh-env.
  STATUS: proven by grep; the confirming experiment (impose the arena's budget
  and delay on the heuristic inside dh-env and watch win 1.00 collapse) is next.

  **FAIRNESS LAYER BUILT, AND IT WAS NOT THE WHOLE STORY (2026-09-14, later).**
  The layer is now in `dh::sim::Arena` on BOTH sides, with ablation knobs so it
  can be measured rather than argued about:
    * a 24-frame ring PER SIDE; `obs()` returns the frame at `now - delay_s_`,
      and `obs_now()` is the undelayed truth for probes/tests/replay only;
    * the built-in minds (`scripted_act`, `native_act`, `mlp_act`) decide on a
      delayed `Percept` — foe position, distance, foe windup, own hp — keeping
      own cooldowns/position live, exactly the split `scripted_policy.gd` makes
      between `delayed_obs()` and the live `cmd_*` calls;
    * `ACTION_BUDGET = 6` commits/s enforced in `apply_action` for both sides
      (the learner's action arrives from outside, so it cannot live in the
      minds as it does in GDScript); only an ACCEPTED command spends budget;
    * `set_obs_delay(s)` / `set_action_budget(n)` ablate either knob, and the
      delay is DRAWN then overridden so an ablation does not also shift the
      policy RNG stream.
  MEASURED, and this is the part that matters: **the fairness layer alone moved
  `dps_taken` from 2.24x to 2.23x.** It was necessary — training on zero-latency
  information while grading on stale information is indefensible — but it is
  not what made dh-env's opponent deadlier. The deployed net barely moves
  (|move| 0.110), and a stale view of a nearly-stationary target is the same
  view. The budget likewise never binds for the scripted mind, whose cooldowns
  already hold it far below 6 commits/s (measured: it binds hard on a gatling
  build, 200 commits -> 60).

  **WHAT `dps_taken` ACTUALLY WAS: four content divergences, each checked
  against the shipping GDScript rather than reasoned about.**
    1. **Ranged basic attacks could not fire.** `melee_hit` gated the bolt
       behind MELEE reach (~2.5 tiles) while both minds only ever shoot from a
       4-7 tile band, and refused the shot outright if the target was dodging.
       A scripted ranged drake landed ZERO basic damage on a standing target in
       15 s. Its twin, `player.gd::_cast_bolt`, has no range gate at all.
    2. **A swing was a circle, not a cone.** `creature.gd::_strike` and
       `player.gd::_arc_hit` both test an arc (90 deg creature, 110 player)
       around the direction locked at windup start; the sim had no arc and no
       aim, so every swing connected. Now `FighterSpec::attack_arc_deg` plus a
       `Fighter::aim` locked at commit — deliberately NOT a `DhFighterSpec`
       field, because that struct crosses the C API by value and a silently
       widened struct against a stale `.so` is precisely what the
       optional-symbol rule exists to prevent; `dh_env` derives it from
       `is_player`, already in the struct.
    3. **The attack cooldown started at the wrong end.** `creature.gd` sets
       `_cd` inside `_strike`, AFTER the windup; the sim set it at the commit.
       Attack period 1.20 s against the arena's 1.55 s — 29% more swings per
       second out of identical content. Fixed: the cooldown starts when the
       strike lands. `kWindup` also corrected 0.25 -> 0.35 (`windup_time`),
       which is 100 ms of dodge window the learner never had to find.
    4. **Creatures had a whirlwind they do not own.** `fighter.gd::cmd_special`
       sends a geared body to `_whirlwind`/`_frost_nova`/`_fan_of_knives` and a
       CREATURE body straight to `bot_attack` — one more ordinary swing. The
       sim gave everyone the geared version: an instant, arc-free, 1.2x-damage
       AoE every 6 s. Every arena build shipping today is `kind: creature`, so
       that was a phantom damage source in every match dh-env has ever run.
  Gated by `test_arena_obs_is_delayed_for_fairness`,
  `test_arena_minds_read_the_delayed_world`,
  `test_arena_action_budget_binds_both_sides` and
  `test_arena_swing_is_a_cone_not_a_circle` in `sim/tests/test_main.cpp`.

  **AND THEN FOUR MORE, because the first four did not close it (2026-09-14).**
  After the fairness layer and the four content fixes above, `dps_taken` was
  still 1.71x. Chasing the rest found four more divergences, every one of them
  settled by reading the shipping GDScript:
    5. **dh-env trained against LEVEL-1 creatures.** `creature.gd::_apply_entry`
       scales hp by `1 + 0.02*(level-1)` and damage by `1 + 0.01*(level-1)` off
       `Session.level`, read once at spawn. `arena.gd` pins that to 20 for every
       rated match — but `game/arena/tools/dump_specs.gd` did not, so
       `ml/env/specs.json` froze level-1 bodies: `fen_boar_alpha` at 339.72 max
       hp against the 468.8 the arena actually fields (x1.38 hp, x1.19 damage).
       The tool now pins `ARENA_LEVEL = 20` and writes `"level"` into the JSON;
       `ml/tests/test_specs.py` (4 tests) fails loudly if either goes missing.
       NOTE while re-dumping: the five geared builds roll their equipment from
       the match seed, so their spec rows are ONE sample of a per-seed roll.
       Harmless today (every trained build is `kind: creature`) and recorded
       here so it is not rediscovered as a bug.
    6. **No knockback.** `creature.gd::take_damage` ends with
       `_move(from_dir * 6.0)`, and the arena's proxy passes the direction
       straight through, so every landed hit shoves the victim 6 px and the
       attacker must re-close. The sim had none, so its duellists stayed glued
       together and traded faster. `hurt()` now takes the blow direction.
    7. **4.8 px of reach nobody has.** `melee_hit` tested
       `attack_reach + radius + 0.3*kTile`; `creature.gd::_strike` tests
       `attack_reach + body_radius`, full stop — and `_strike_recoil`, the only
       forward motion in that path, is a sprite tween that never moves
       `global_position`. 11% of a boar's envelope. Slow multiplier also
       corrected (0.65 -> 0.7 for creature bodies; the player path keeps 0.65,
       which is what `pre_tick` actually uses).
    8. **THE MOVE MAGNITUDE WAS NEVER READ BY THE GAME.** `fighter.gd::pre_tick`
       spends a move command two different ways: a player body gets
       `_move_dir.limit_length(1.0) * speed`, but a CREATURE body gets
       `if len > 0.05: _move_dir.NORMALIZED() * _speed()` — the magnitude is
       thrown away, so any command longer than 0.05 moves at FULL speed. The sim
       scaled by magnitude for everyone. The deployed net's `|move|` is 0.110:
       it crawled at 11% speed through every training step and ran at 100% in
       the arena with the same weights. **PPO spent its whole budget tuning a
       number the shipping runtime never reads.** Same function also fixed:
       policy-driven bodies keep walking through their own windup (`pre_tick`
       does not look at `_state`), while a NATIVE body freezes (its movement
       lives in `creature.gd`'s state machine, whose "windup" branch only ticks
       the timer).
    9. **Enrage was a damage buff it never was.** `_enrage_t` appears in exactly
       four places in `creature.gd` — declaration ("failed snare: +30% speed"),
       timer, `_speed()`'s 1.3x, and the setter. No damage multiplier anywhere.
       The sim applied 1.5x to every packet while enraged.

  **RESULT — `dps_taken` IS CLOSED, which is what Ricardo asked for.**

  | term, fen_boar pin | before | after |
  |---|---|---|
  | heuristic vs scripted in dh-env (arena says 0-12) | win **1.00** | win **0.00** |
  | `dps_taken` vs scripted | 2.24x | **1.25x** (tol 1.25x) |
  | `dps_taken` vs native | 1.57x | **1.01x** |
  | `dps_dealt` vs scripted | 1.12x | **1.22x** |
  | episode length vs scripted | 1.97x | **1.12x** |
  | `dmg_dealt` gap vs native | 0.249 | **0.030** |

  (24 episodes, seed 7777, both matchups. **Every RATE term now passes in both
  matchups** — seconds, `dps_dealt` and `dps_taken` all inside 1.25x.)

  STILL OPEN, and ONLY the absolute outcome terms: `dmg_dealt`/`hp_foe` vs
  scripted (0.215, tol 0.15) and `win_rate` vs native (0.50 vs 0.96). Both are measured on the DEPLOYED
  fen_boar net, which is degenerate (it barely moves and is worse than a
  statue), so its outcomes sit on a knife edge and swing with the seed. The
  rate terms — which describe the combat rather than who happened to survive —
  now agree. Re-measure with a policy that actually plays once one exists.

  **THE STANDING CONSEQUENCE FOR R50:** every net trained before today was
  trained in a materially different game. The converged `train_all` run must
  start from scratch here, not warm-start from those weights.

  **AND WITH THE ENVIRONMENT CLOSED, A SECOND DIVERGENCE IS NOW VISIBLE — PPO
  DOES NOT OPTIMIZE THE POLICY THE GAME DEPLOYS (2026-09-14, R50 BLOCKER).**
  First: with a net that actually plays, **`env_parity` PASSES for the first
  time** — every term, absolute and rate, inside tolerance (the 1 M-step smoke
  candidate, 16 episodes vs scripted). The residual gaps in the table above
  were the degenerate deployed pin, not the sim. So the environment question is
  settled.
  What that made visible: a 1 M-step smoke printed `win_rate 0.94` while its
  gate read `suite_scripted 0.00` and `suite_native 0.00`. Same weights, same
  build, same opponent. The cause is not the environment:
    * `ml/training/ppo.py` rolls out and scores a STOCHASTIC policy —
      `Categorical(logits).sample()`, `Normal(move, MOVE_STD=0.3).sample()`,
      `Bernoulli(dodge).sample()`.
    * EVERY serving runtime is GREEDY — `np.argmax` in `policy_net.py::act` and
      `ml/eval/env_parity.py`, the max loop in `game/arena/neural_policy.gd`,
      and `Arena::mlp_act` in C++. Move is the raw mean; dodge is a threshold.
  MEASURED, same weights, 16-24 episodes, two independent nets:

  | net | vs scripted | vs native |
  |---|---|---|
  | smoke v7.0, GREEDY (what the gate runs) | 0.00 | **0.04** |
  | smoke v7.0, SAMPLED (what PPO reports) | 0.21 | **0.96** |
  | deployed v6.0, GREEDY | 0.00 | 0.50 |
  | deployed v6.0, SAMPLED | 0.25 | 0.88 |

  So PPO's objective, its printed win rate, AND the R50 curriculum's promotion
  gate all describe a policy that never ships. The argmax of a high-entropy
  categorical is close to arbitrary — the entropy bonus is actively keeping the
  distribution broad, and the deployed policy reads one number off it.
  **This blocks the converged run**: 20 M steps per creature would promote on a
  sampled win rate and be graded on a greedy one, which is the same class of
  mistake as training in the wrong environment. Two coherent fixes, and they
  are materially different work — Ricardo's call:
    (A) DEPLOY WHAT YOU TRAIN — make the four runtimes SAMPLE (seeded, so the
        arena stays reproducible). Faithful to the objective; bots become
        non-deterministic and harder to exploit; touches all four runtimes and
        the "four runtimes must agree" contract.
    (B) TRAIN WHAT YOU DEPLOY — keep greedy serving; make PPO's reported win
        rate and its promotion gate GREEDY, and anneal entropy/MOVE_STD so the
        greedy policy converges to the stochastic one. Standard practice,
        smaller blast radius, but throws away the sampled policy's edge.

  **R47/R48/R50 PROGRESS 2026-09-14, in the order they were taken.**

  **R47 DONE — `docs/tech/38-reward-model-history.md`.** His ask was for the
  VERSIONS with their rationale, not a snapshot, so the file is a changelog and
  states its own rule: a version is never deleted, only superseded, because
  every ranking in this repo's history was made by one of them. v0 (two
  functions that disagreed, three defects), v1 (kept and runnable), v2 (weights,
  the two enforced invariants, worked ordering), then v2.0.1 the mirror
  matchup, v2.0.2 the 72x kit hack, v2.0.3 the vocabulary trap, v2.0.4 the
  ground-truth validation. Open items listed as open: R_TIME never re-judged,
  dps_taken parity unresolved, weights reasoned about but never tuned,
  hp_foe/hp_self partly double-counting damage. Indexed in docs/README.md.

  **R48 DONE — and the interesting half is why it was invisible.** The BACK
  button EXISTED, at the bottom of the console's RIGHT column under a
  TabContainer set to expand-fill, so any tab whose contents wanted more height
  than the viewport had pushed the only way out off the bottom edge. Moved to
  the title row (left column, fixed 236 px, first row) and Esc now leaves too —
  there was no input handler at all, so a button that depended on there being
  room for it was the ONLY exit. THE REASON NOBODY CAUGHT IT: the layout probe
  measures 1204 controls across 7 canvases and 4 tabs and set `_selftest = true`,
  which was exactly the flag that skipped building the BACK button. The one
  control that went missing was the one control the gate could not see. It is
  built under selftest now (inert) and the probe asserts a BACK button exists,
  is visible in tree and lies inside the canvas on both axes — found by ROLE, so
  moving it stays allowed and losing it does not. Teeth proven: removing the
  button fails all 28 canvas/tab combinations.

  **R50 IN FLIGHT — the curriculum is built and smoke-verified; the converged
  train_all run is NOT started yet.** Three stages, each gated on the last:
  clone (`distill --teacher heuristic`) -> scripts -> self-play.
  WHAT WAS WRONG BEFORE: a third of the envs were self-play FROM STEP 0. Given
  15d (the move head never trained), that is two policies which both stand
  still teaching each other nothing, for a third of every rollout.
  PHASE 1 is BOTH scripts, not one, because the gate requires beating
  `scripted` AND `native` — training on one and gating on two is how a net
  passes half a gate. PROMOTION is HELD (`--promote-hold 3`), resets to zero on
  any update below `--promote-wr 0.60`, and refuses to consider fewer than 40
  script episodes: "once reliably wiining", not "won once". It reads the SCRIPT
  envs only — a pooled win rate rises on its own as self-play gets easier
  against a frozen snapshot of yourself, which would let a policy promote on
  its own reflection.
  MECHANISM: `Arena::set_opp_policy` -> `dh_env_set_opp_policy` -> `DhEnv.set_opp`,
  a NEW C symbol so a stale .so raises instead of leaving a run silently stuck
  in phase 1 forever (which looks exactly like a policy that never learns).
  Promoting into an unset self-play net is REFUSED. Determinism unaffected and
  PINNED: `sim-tests::test_arena_opponent_mind_can_change_between_episodes`
  proves the two minds produce different state_hashes AND that switching
  reproduces each one exactly. MEASURED while writing it: the minds are
  IDENTICAL at 200 ticks (both just closing distance) and diverge only by 600
  — native settles into a 0.449/0.449 standoff where scripted reaches
  0.316/0.669. A shorter test would have passed for the wrong reason.
  SMOKE: 13 updates on cinder_drake, phase 1 announced, `scripts=0.69(1/2)`
  tracked separately, PROMOTED at iteration 2 with 10 of 32 envs switched.
  **CAVEAT, stated now rather than discovered later: the threshold is measured
  in dh-env, and the unresolved `dps_taken` divergence means dh-env's scripted
  is NOT the arena's scripted. 0.60 in dh-env is not 0.60 in the gate.** The
  gate remains the only verdict. That is also why the smoke's 0.69 against
  scripts sits beside a measured 0.00 arena win rate without contradiction.
  STILL TO DO for R50: run the clone stage for real, chain it into PPO via
  `--warm-start`, then the train_all experiment at a budget that converges —
  his words, "make sure to get enough steps as so the model actually
  converges", which is a direct correction of every 11-update smoke run today.

  **INTERRUPTION 2026-09-14 (latest+15) — seven new demands, recorded VERBATIM
  before any of them is worked. Prompt, in his order:**
  *"bosses still don't spawn like hordes, and there's still a single biome. How
  are assets gen going?*
  *How's our final reward function? make sure to document everything, including
  the reward function versions as we update it with new rationale (trace the
  whole story up to the current one)*
  *genforge console interface is MUCH better now, we just can't go back from it
  to the main menu. Also, in the arena interface, can we get a little polishing
  to better fit everything in there, as well?*
  *finally: after tuning the arena training as to learn from scripts first and,
  once reliably wiining against it, self playing, run a train_all experiment
  (even with PPO only) - make sure to get enough steps as so the model actually
  converges"*

  | R44 | DIAGNOSED 2026-09-19, NOT EDITED (collision): bosses exist only in `main.gd::_spawn_packs` (packs 8/11/12/farthest of the origin 5×5); the continuous spawn pressure `_repopulate()` and the frontier repopulation only field wandering packs from `_ground_species`/`_caster_species`, so no boss ever arrives by pressure. The other session's untracked `encounter_residency.gd` (dormant boss records, `_wake_near_boss`) is live work in exactly this seam and `main.gd`/`world_gen.gd` are dirty in their tree — leave the fix to that stream; the fix is a boss slot in the pressure roll (rare, one live boss cap, distance-ladder gated). | Bosses still do not spawn like hordes do. | with R36/R29; encounter spawn parity between boss and horde paths, actual in-world spawn evidence |
  | R45 | DIAGNOSED 2026-09-19, NOT EDITED (collision): it is a CONTENT gap before it is a generator gap — `content/core/biomes/` holds ONE biome (`gloamfen.json`); `sprites.gd`/`post.gd` already blend two biomes' pixels and crossfade per-biome LUT grades, `world_gen.gd` (dirty in the other session's tree) picks tiles from the one biome it has. First deliverable is four more biome records (canon §4 list) validated by the schema, then world_gen's biome field. | Still a single biome in play. | with R09/R29; distinct biome generation reaching the played world, not only the generator |
  | R46 | ANSWER | "How are assets gen going?" — a question, owed a status answer, not a task. | 13b/13c; local image-gen repo still not delivered to reference_repos |
  | R47 | NOW | Document the reward function fully, INCLUDING every version with its rationale — trace the whole story up to the current one. | tech/25 §5.2, tech/37; a versioned changelog, not a snapshot of the current weights |
  | R48 | NOW | GenForge console cannot return to the main menu. | genforge console scene; real Back navigation evidence (same class as R38's arena Back) |
  | R49 | NOW | Arena interface needs polishing to fit everything in. | design/23/17; COLLISION RISK — the other session owns game/arena/console.gd, check before editing |
  | R50 | BUILT + RUN 2026-09-19 (2/7 PASS the gate; the run exposed R55) | Tune arena training to learn from SCRIPTS first, then self-play once reliably winning; then run a train_all experiment (PPO is fine alone) with enough steps that the model actually converges. | tech/25 §4.2, tools/train_all.sh; a real curriculum + a converged run, not a smoke run |

  **R50 IS ALREADY HALF UNDER WAY and his instruction sharpens it.** 15e's
  decision (clone the heuristic, then PPO) is the same shape as his curriculum
  and slots in ahead of it: heuristic -> scripted -> self-play. The evidence
  that the curriculum is the right frame is in 15d — the nets never learned to
  MOVE, so self-play from noise had two policies that both stand still teaching
  each other nothing. "enough steps as so the model actually converges" is a
  direct correction of every smoke run in this session (11 updates); no
  conclusion may be drawn from a short run again.
  STRATEGY AT THIS INTERRUPTION, so nothing is lost: gate controls (statue floor
  + heuristic yardstick) are LANDED in ml/eval/gate.py, game/arena/statue_policy.gd
  and heuristic_policy.gd, with two tests proven to have teeth. The heuristic
  TEACHER (ml/training/heuristic.py) is written and smoke-tested. Next: wire
  `--teacher heuristic` into distill.py, then the curriculum, then train_all.

  **15e — RICARDO'S TWO DECISIONS ON THE COLLAPSE (2026-09-14), taken on the
  15d evidence. Both are now the work.**
  1. **Creature AI: clone the heuristic, then PPO.** *"Clone the heuristic,
     then PPO"* — behaviour-clone the five-line heuristic into the net so the
     move head starts alive and the policy starts from something that can win,
     then let PPO improve a fighter instead of searching from noise. The net
     stays a net and may surpass its teacher; this is a starting point, not a
     ceiling. `ml/training/distill.py` already has the machinery.
  2. **The gate must refuse a net that loses to a statue.** *"Add the
     statue/heuristic controls to the gate"* — the statue is a hard floor
     (refuse deployment below it) and the heuristic is a reported yardstick.
     This is deliberately independent of decision 1: it stops this class of
     regression shipping again whatever produces the nets.
  NOT chosen, and kept per the standing rule rather than deleted: (b) fix
  exploration only and keep policies fully self-discovered (learned `log_std`,
  temporally correlated move noise, entropy floor) — still the right SECOND
  step after cloning, and the 15d measurements are its brief; (c) ship the
  heuristic as creature AI with RL for bosses only.
  ALSO NOT chosen: unpinning `fen_boar` v6.0 today. The pin stays until a
  replacement actually beats the controls, so live behaviour stays known and
  stable while this is fixed.
  ORDER: the gate controls first — they are the safety net, they are smaller,
  and they protect every net produced after them.

  **15d DONE 2026-09-14 — the diagnosis, and it is NOT the reward model. A
  five-line heuristic beats every net we have trained.**
  Method: give the failure a CONTROL. Three policies, same build, same seeds —
  the trained net, a statue (act 1 forever, never moves), and a heuristic that
  is literally "walk at the foe; attack in reach; spend each kit the moment it
  is off cooldown". 12 episodes each, `core.arena.cinder_drake` mirror:
      vs scripted   heuristic  win 0.00  foe hp 0.018    reward 0.526
                    net v5.0   win 0.00  foe hp 0.557    reward 0.402
                    STATUE     win 0.00  foe hp 0.559    reward 0.401
      vs native     heuristic  win 1.00  foe hp 0.000    reward 0.859
                    net v5.0   win 0.33  foe hp 0.060    reward 0.421
                    STATUE     win 0.00  foe hp 0.008    reward 0.238
  **Against scripted the trained net is statistically indistinguishable from a
  statue** (0.557 vs 0.559 foe hp). Against native the heuristic wins 12/12
  where the net wins 4/12. This is not a gate that is too strict and not a
  reward that is mis-specified — the reward model ranks the three in exactly
  the right order, which is the first independent confirmation that 15a works.
  It is the LEARNER.

  **AND IT IS NOT ONE KEY. The DEPLOYED net is worse than a statue.** Same
  controls against `fen_boar` v6.0 — the pin that actually ships, the one
  driving creatures players fight:
      vs scripted   heuristic  win 1.00  foe hp 0.000   reward 0.839
                    net v6.0   win 0.00  foe hp 0.579   reward 0.113
                    STATUE     win 0.00  foe hp 0.463   reward 0.140
      vs native     heuristic  win 1.00  foe hp 0.000   reward 0.869
                    net v6.0   win 0.00  foe hp 0.348   reward 0.176
                    STATUE     win 0.00  foe hp 0.156   reward 0.218
  The statue takes MORE health off the opponent than the trained net does, in
  both matchups, and outscores it on the reward model in both. The deployed
  creature AI is measurably worse than doing nothing. That is a SHIPPING
  finding, not only a training one. Registry untouched — this is a measurement,
  and pulling a pin is Ricardo's call.

  WHY, measured in the weights rather than guessed. Softmax over real
  observations, drake v5.0:
      logit means  +0.24  +11.40  +11.40  -2.96  -2.51  -4.13  -4.01
      entropy      0.693 nats  (= ln 2 exactly; uniform would be 1.946)
      |move| head  mean 0.110   std 0.006   max 0.168   (scale is +-1)
      dodge        sigmoid 1.000
  Two separate deaths:
    1. **The pick head collapsed to a coin flip between attack and slam.** The
       gap to the kits is ~15 logits, e^15 = 3.3 MILLION to 1. Softmax gradient
       at p = 3e-7 is nil, so the kits can never come back — the collapse is
       irreversible, not merely current. `ENTROPY = 0.01` on a 7-way head
       contributes at most 0.0195 and cannot hold logits away from +-11.
       It does rank correctly INSIDE the collapse: the drake owns two kits, and
       the net puts the two real slots (-2.96, -2.51) above the two empty ones
       (-4.13, -4.01). It learned the build; it just cannot act on it.
    2. **The move head is dead.** std 0.006 across thousands of real
       observations means it emits nearly the SAME tiny vector regardless of
       where the enemy is. Not collapsed onto a bad direction — never trained.
       The suspected reason is exploration, not the loss: `MOVE_STD = 0.3` is
       undirected per-tick Gaussian noise, i.e. a random walk, and closing
       distance needs a SUSTAINED direction over ~60 ticks. Net displacement
       from per-tick noise is ~0, so the advantage signal for "walk at the
       enemy" is never generated for the gradient to find. The heuristic's
       entire margin is that it walks.
    ALSO FOUND, an asymmetry in the loss: the entropy bonus is applied ONLY to
    the Categorical. The move Normal (harmless — fixed std, constant entropy,
    zero gradient) and the dodge Bernoulli (NOT harmless) get none, and the
    dodge logit duly sits at +13.0, fully saturated with nothing opposing it.
    Not changed unilaterally: it is a hyperparameter decision, and for this
    build `dodge_max = 0` so it costs nothing here. Reported, not tuned.

  **A REAL DEFECT IN 15a's OWN CODE, caught by this probe and fixed.**
  `episode_terms` reads `winner_is_self`/`seconds`; the arena row says
  `winner_side`/`duration_s`. Hand it an arena row directly and BOTH of the
  heaviest terms silently defaulted to 0.5 — `win` and `duration` — so a LOSS
  scored **0.528 instead of 0.238**: above several genuine wins, and above the
  0.45 ceiling `assert_sane_weights` exists to guarantee. Its own docstring
  claimed it "uses the arena's own episode-row vocabulary so nothing has to
  translate", which is exactly false and is what misled me. Same failure class
  as the mirror-matchup bug earlier today: a plausible number instead of an
  error. Now REFUSED with a message naming `from_arena_row`, docstring
  corrected, gated by `test_an_arena_row_is_refused_rather_than_scored_as_a_draw`
  (which also pins that a row with no outcome evidence at all is still an
  honest draw, not an error). 122 ml tests pass.
  I found this because my own probe printed a statue outranking a net that won
  a third of its fights, and that contradicts an invariant I had just written —
  so the invariant was right and the probe was wrong. Worth keeping: the
  enforced invariant is what made the bug visible.

  **THE FORK, for Ricardo — this is a product decision, not a tuning knob.**
  The heuristic is already a better creature than anything training has
  produced, and `ml/training/distill.py` already has the machinery to learn
  from a teacher. Options: (a) warm-start PPO by behaviour-cloning the
  heuristic, so the move head starts alive and PPO improves a fighter instead
  of searching from noise — standard, and the fastest route to creatures that
  fight; (b) fix exploration instead and keep policies fully self-discovered —
  learned `log_std` and/or temporally correlated move noise, plus an entropy
  floor on the pick head; (c) ship the heuristic as the creature AI and keep RL
  for the bosses only. RECOMMENDED: (a) then (b) — clone to get off the floor,
  then let PPO explore from somewhere worth exploring from. NOT started; the
  answer changes what creature AI IS.

  **15c DONE 2026-09-14 — "stills errors (perhaps no new build?)", and his
  hunch was half right: the build was fine, but TWO real bugs were hiding
  behind that gate, and one of them was mine.**
  ANSWERING THE QUESTION FIRST, with timestamps rather than reassurance: his
  run started 07:57:31 and DID carry the dodge fix and the reward model (its
  own log line 89 prints `reward model v2`). The 15b native fix landed at
  07:59:29 — about two minutes LATER — so `suite_native` in that screenshot was
  genuinely stale. `dh-godot`'s .so (21:41) is NOT stale: it exposes only the
  policy forward pass and never touches `sim::Arena`, so no arena change can
  age it. But a stale suite does not explain `suite_scripted FAIL wr 0.00`, and
  chasing that turned up the two bugs below.

  **BUG 1, MINE, and Ricardo's screenshot is what caught it — the mirror
  matchup.** His console showed `fitness 0.607` sitting next to `win_rate
  0.00`. Both cannot be true: the reward model's own enforced invariant is that
  no loss can outrank a win, which caps a 0-win policy at 0.45. So either the
  invariant was broken or the parse was. It was the parse. In self-play BOTH
  fighters carry the SAME `build_id`, so `winner == e["a"]` is true no matter
  who actually won — every mirror episode read as a WIN for whichever side was
  being scored. A net that lost 4 of 4 scored 0.672.
  FIX at the source, not in the reader: `game/arena/arena.gd` now writes
  `winner_side` ("a"/"b"/"draw") into the episode row, because a side letter
  cannot be ambiguous the way a build id can. `reward._winner_is_self()`
  resolves in a declared order — `winner_side`, then an explicit draw, then
  build ids ONLY when they differ, then hp (the side at zero lost), then draw —
  so old rows without the field still parse and mirrors no longer lie.
  VERIFIED on the same data: the losing side now scores 0.102, not 0.672.
  4 new tests in `ml/tests/test_reward.py` (21 total), one per resolution step.

  **BUG 2 — a textbook reward hack, and it was worth 72x winning the fight.**
  With the parse honest, the retrained net's action histogram was absurd:
  **kit slot 1 + dodge on 100.000% of ticks**, `|move| mean 0.059` on a +-1
  scale. A creature standing still, casting one thing forever.
  THE ARITHMETIC: `R_KIT = 0.02` paid for SELECTING a kit — the intent — and
  `field_cast` has an 8 s cooldown, i.e. 480 ticks during which selecting it
  does NOTHING. 3600 ticks x 0.02 = **72 per episode**, against a terminal
  worth `R_TERMINAL * (score - 0.5)`, at most 1. The optimal policy under that
  reward is exactly the degenerate one we were looking at. It was not a
  learning failure; the learner was right and the reward was wrong.
  FIX, paying for EFFECT instead of intent, and it needed a new signal from the
  sim because nothing downstream knew what actually fired: `Arena::last_commit`
  records the action that was ACCEPTED (-1 when refused), `dh_env_step_many_commit`
  carries it out through the C ABI as a NEW symbol (the old entry point now
  forwards with `nullptr`, so a stale .so announces itself instead of reading an
  unset register), `VecDhEnv.commit` surfaces it, and ppo.py masks the dodge bit
  off before testing the kit range:
      pick = vec.commit & (ACT_DODGE - 1)
      kit  = (vec.commit >= 0) & (pick >= 3) & (pick <= 6)
  MEASURED, directly: 600 kit selections produce **1** actual cast. The signal
  that was paying 600 now pays 1.
  Golden `state_hash` matrix re-verified IDENTICAL — commit tracking is
  observation only and changes no simulation outcome.
  GATE: `sim-tests::test_arena_reports_what_actually_committed` pins all of it —
  600 requests yield at most 3 commits at an 8 s cooldown, a cooldown-blocked
  request reports -1, an empty kit slot reports -1, and a noop is never a
  commitment.

  **HONEST RESULT, because the fix did NOT finish the job.** After retraining
  (`smoke_kit`, 11 updates) the collapse is REDUCED, not cured: kit spam fell
  from 100.000% to 91.2% vs scripted and is still 100% vs native, `|move| mean`
  is still ~0.05, and the net still dies in both matchups. Self-play win rate
  did hold near 0.69 instead of decaying to 0.21 as the pre-fix run did, which
  is a real signal but a weak one. 11 updates is far below `MIN_UPDATES`-scale
  training, so this smoke run is not evidence either way about the remaining
  collapse. Removing the 72x exploit was necessary and is not sufficient.
  NEXT, in order: (1) a real-budget retrain now that the reward is honest,
  before drawing any conclusion about entropy; (2) if it survives that, the
  suspects are `ENTROPY = 0.01` (too weak to keep the move head alive) and the
  near-zero `|move|` itself, which is the same "creature standing still"
  symptom seen before; (3) only then the last parity divergence, `dps_taken`
  (opponents deal damage 1.70-2.28x faster in dh-env than in the arena).
  The registry was NOT touched: `smoke_kit`'s entry, weights and progress
  artifacts were removed after measuring, as `smoke_reward`'s were.
  SUITES: 121 ml tests + 4 native suites pass.

  **15b DONE 2026-09-14 — and it was an AGGRO RANGE, which is a game number,
  not a training one.** The arena's `native` is not a port of anything: it means
  NO policy driver (`ai_defaults.gd`: *"inert: the body's own AI runs"*), so the
  real `creature.gd` brain from the Hunt drives the fighter. dh-env's
  `Arena::native_act` is a hand-port of its "essence" and chases from any
  distance. `creature.gd` does not:
      creature.gd  aggro_range = 7 * TILE, TILE = 16.0   ->  112 px
      boss.gd 12 tiles, hag 11, wisp 9, terravore 13, pyre 13  ->  144-208 px
      arena spawns the two fighters at +-150 px           ->  300 px APART
  **Every species in the arena spawns OUTSIDE its own aggro range.** A native
  fighter therefore starts idle and WANDERS, waking only if the opponent walks
  into it — and `_chase` gives the pursuit up again past `aggro_range * 1.8`
  (202 px), still inside the spawn gap. Against another native or the scripted
  baseline that never shows, because those close the distance themselves.
  Against a policy that keeps its distance, native never wakes at all.
  MEASURED FIRST, THEN FIXED. The baseline matrix, fen_boar mirror, 6 episodes,
  bars per second each way — native is NOT passive in general:
      native vs native    0.0220 / 0.0220      scripted vs native  0.0349/0.0256
      native vs scripted  0.0255 / 0.0348      scripted vs scripted 0.0181/0.0179
  ...but the DEPLOYED NET vs native in the arena was 0.083 bars dealt in 44.7 s
  (0.002 bars/s), a 44-second near-standstill, against 0.981 bars when native
  fights native. So the earlier reading "the arena's native is a standoff" was
  wrong as stated: it is a standoff only against something that keeps away.
  FIX: `creature.gd` gains `arena_duel`, set ONLY by `game/arena/fighter.gd` on
  arena bodies. It skips the aggro gate in `_idle` and the give-up in `_chase`
  (and in `wisp.gd`, the one subclass with its own). It does not change
  `aggro_range`, the Hunt, or any creature outside the arena — a duel is two
  committed combatants placed to fight, and a duel has no disengage. `_idle` is
  defined only in the base class, so one change covers every species.
  MEASURED AFTER, same key, same 12 episodes, vs native:
      term        before -> after (arena)      dh-env    verdict now
      win_rate     0.083 -> 0.917               0.000
      dmg_dealt    0.083 -> 0.992               0.662
      dps_dealt    0.002 -> 0.024               0.021    1.16x  ok
      dps_taken    0.002 -> 0.020               0.034    1.70x  DIVERGES
  `dps_dealt` went from **11.37x divergent to 1.16x — agreeing**. Together with
  the scripted case (1.01x) that is the second baseline to confirm the same
  thing: **the learner's own damage rate now matches across both runtimes.**
  The baselines barely moved (native-vs-native 44.7s -> 39.4s, they already
  closed on each other; scripted-vs-scripted unchanged, scripted is a policy
  with no aggro concept), which is the control this needed.
  WHAT IS LEFT, and it is now ONE thing in ONE direction for BOTH baselines:
  **`dps_taken` — the OPPONENT deals damage faster in dh-env** (2.28x vs
  scripted, 1.70x vs native). Everything else about the learner agrees.
  WORTH SAYING PLAINLY: a kiting policy graded against a sleeping native scores
  draws, and a draw is not a win, so the `suite_native` band ([0.30, 1.00]) was
  being failed by nets that could not provoke a fight. The deployed fen_boar net
  moves from 0.083 to 0.917 on exactly that suite. This does NOT retroactively
  validate any net and nothing was re-gated or re-deployed — but every league
  number ever recorded against `native` was measured against a creature that
  may have been asleep, and that has to be said out loud rather than quietly
  fixed.
  GATES after the change: ARENA SELFTEST OK (4 matchups, damage flowed, results
  unchanged), CONSOLE SELFTEST OK, and the Hunt side proven untouched —
  SPAWNTEST OK, REPOP OK, LEVEL UP OK, RESIDENCY OK. `arena_duel` defaults false
  and is referenced only from game/arena/fighter.gd.

  **15a DONE 2026-09-14 — `ml/training/reward.py`, and answering his question
  first because the answer is most of the justification.**
  WHAT WAS SCORED BEFORE: two different functions, neither seeing most of what
  a fight produces.
    * `league.fitness()` (ES ranking + the gate): `wins + 0.1 * (hp_self -
      hp_foe)`. Two terms. Duration NOT scored. Damage NOT scored.
    * `ppo.py` per tick: `1.0 * (foe_hp_lost - self_hp_lost) - 0.002`, plus
      `+0.02` per kit and `+0.05` per chained kit, plus `+-1.0` terminal.
  THREE DEFECTS, one of them Ricardo's own catch in the asking:
    1. **TIME WAS SIGNED WRONG FOR A LOSER.** `- R_TIME` applied EVERY tick
       regardless of outcome, so a losing agent was paid to die sooner. His
       rule ("If loser, the longest the better") is a CORRECTION, not a
       refinement.
    2. **IT WAS ALSO MIS-SCALED 7x.** `0.002 * 3600 ticks = 7.2` over a full
       episode against a win bonus of `1.0`. The clock outweighed the result.
       This is exactly the magnitude problem he named ("not compare 40 seconds
       with 0.087 dmg_dealt") sitting inside our own trainer.
    3. **DEALING AND AVOIDING DAMAGE SCORED IDENTICALLY** — one symmetric hp
       delta, weight 1.0 each way. That IS the avoidance local optimum, in
       code, and PPO seed 7 found it (`mean_loser_hp 0.967`).
  BUILT, to his specification: every parity column is a term, normalised to
  [0,1] against its OWN reference scale before any weight applies (one health
  bar; the 60 s cap), directions declared in one table rather than implied by a
  buried sign, duration CONDITIONAL on outcome (shorter winning, longer losing,
  NEUTRAL on a draw — the loser's rule on a draw would pay an agent to stall).
  WEIGHTS (data, `ml/training/reward_weights.json`, canon directive 4):
      win 0.55 | dmg_dealt 0.15 | dmg_taken 0.11 | hp_foe 0.08 | hp_self 0.06
      | duration 0.05
  Two invariants ENFORCED ON LOAD, not merely intended: they must sum to 1.0
  (so a score is always on one scale) and `win` must EXCEED the sum of all the
  others (so no pretty loss outranks an ugly win — "lose beautifully" is not a
  hypothetical failure mode here). `dmg_dealt > dmg_taken` deliberately, so
  avoidance is no longer a tie.
  WORKED ORDERING, from `--explain`: fast clean kill 0.965 > slow bloody win
  0.801 > timeout stall 0.472 > long brave loss 0.246 > instant death 0.003.
  The stall sits ABOVE the losses because a draw genuinely is half an outcome;
  what STOPS stalling is the gate's hard sanity check, not a weight, and the
  tool says so rather than pretending otherwise.
  ONE MODEL, BOTH CONSUMERS: `league.fitness()` ranks ES candidates with it and
  ppo.py pays `R_TERMINAL * (score - 0.5)` at the episode boundary, so ES and
  PPO can no longer optimise different things. `fitness_v1` is KEPT and
  selectable (`"model": "v1"`) per the standing rule — every ES ranking in this
  repo's history was made with it, and reproducing those means being able to
  run it, not just describe it.
  PPO per-tick shaping now: `R_DEAL 1.0` / `R_ABSORB 0.73` (asymmetric),
  `R_TIME 0.0` with the old constants commented above it, not deleted.
  GATES: `ml/tests/test_reward.py`, 17 tests, ONE PER CLAUSE of his
  specification — each direction, the winner/loser duration split, the draw
  neutrality, the [0,1] normalisation under absurd inputs, "a 100x longer
  episode moves the score by at most its weight", "any win outranks any loss",
  and the refusal of weight sets that break either invariant.
  FULL SUITE 240 passed, 1 skipped. PPO smoke ran end to end on the new
  reward (11 updates, self-play win rate 0.00 -> 0.76) and its registry entry
  was removed afterwards so nothing polluted the shipped registry.
  TWO BUGS FOUND BY THE TESTS, both real, neither in the new model's maths:
    * `from_arena_row` read every episode as a LOSS when the row carried no
      `a`/`b` build keys, because it compared the winner id against a missing
      field. A whole match set would have scored as a policy that never won —
      which looks like a bad policy, not a bad parse. It now falls back to the
      side letter. This was ALSO what broke `test_progress`.
    * my own regression from the dodge-bit commit earlier today: `ppo.py`'s
      combo bonus tested `acts >= 3 & acts <= 6` against the ENCODED action, so
      once bit 3 carried the dodge flag (kit 3 + dodge = 11) the kit and chain
      bonuses silently stopped paying on every tick the agent dodged. Now masks
      the pick out first.
  **CORRECTION TO THIS MORNING'S CLAIM, and it changes the diagnosis.** I wrote
  that after the dodge fix "episode length now matches EXACTLY (40.0 vs 40.0)".
  It did not. `ml/eval/env_parity.py` divided ticks by a hardcoded 30 while
  `dh::sim::kArenaDt` is 1/60 — MEASURED, not assumed: an idle episode runs
  3600 ticks to the 60 s cap. Every dh-env duration was reported at TWICE its
  real length, so "40.0 vs 40.0" was really 20.0 vs 40.0, a 2x gap I read as a
  perfect match. FIXED at the source: `dh_env_tick_hz()` is now exported from C
  and the Python asks the sim instead of holding a copy — a constant that has
  to agree with C is a constant that will eventually disagree with C.
  WITH THAT FIXED, the remaining divergence is ONE term and it is much sharper
  than "2.02x dmg_dealt":
      term         dh-env   arena     gap   verdict
      win_rate      0.000   0.000  0.0000   ok
      hp_self       0.000   0.054  0.0542   ok
      hp_foe        0.597   0.184  0.4126   DIVERGES
      dmg_dealt     0.403   0.816  0.4126   DIVERGES
      dmg_taken     1.074   0.943  0.1313   ok
      seconds      19.986  39.967   2.00x   DIVERGES
      dps_dealt     0.020   0.020   1.01x   ok
      dps_taken     0.054   0.024   2.28x   DIVERGES
  **The learner's own damage RATE now agrees to 1%.** The whole `dmg_dealt`
  gap is that dh-env episodes end in half the time, and they end in half the
  time because the OPPONENT deals damage 2.28x faster there. Incoming DPS is
  the one remaining divergence against scripted, and it feeds straight into 15b.
  The probe learned the general lesson too: rates are now compared SEPARATELY
  from totals, because a total and a rate can disagree in opposite directions
  when episodes differ in length — `dmg_taken` totals agreed (1.074 vs 0.943,
  inside tolerance) while the rate was off 2.28x, and the old report would have
  called that term fine. Report is now term-major with a ratio tolerance
  (1.25x) alongside the absolute one.
  NOTE, not staged: `ml/serving/registry.json` is shared-dirty and the PPO
  smoke run round-tripped it, so its key ORDER changed. Verified semantically
  against HEAD — nothing lost: all 17 HEAD entries present, the other session's
  `bog_golem` v2/v3 and its `fen_boar` v6 `deployed` pin intact. Left dirty and
  unstaged for that session.

  **15b. Chase the native divergence — APPROVED.** *"go through with it!"*,
  quoting back my own stated next step: *"Next I'll chase the native
  divergence, since it affects what players actually fight."* This is now a
  DECISION. `Arena::native_act` (C++) and the Godot arena's native policy were
  written independently for the same name, and the parity probe measured the
  arena's native as a near-total standoff (0.083 bars dealt / 0.077 taken in
  44.7 s, both fighters near full health at timeout) where dh-env has a real
  fight (0.662 / 1.071). It is a GAME finding, not only a training one: native
  is the in-game creature AI.

- **"crashed entering the dungeon while mounted" — Ricardo, 2026-09-14
  (latest+14). ROOT CAUSE FOUND, AND IT WAS THIS SESSION'S DOING. Not the
  mount.** The mount was a coincidence; the crash would have happened at the
  next `load()` of anything.
  THE EVIDENCE, from his own log (`~/.local/share/Dragon Heroes Codex/logs/`,
  the real user dir — `use_custom_user_dir` renames it, which is why the obvious
  `app_userdata/Dragon Heroes` looked stale):
      ERROR: Parameter "getcwd(real_current_dir_name, 2048)" is null.
         at: DirAccessUnix (drivers/unix/dir_access_unix.cpp:739)
      ERROR: Cannot open file 'res://living/trial.tscn'.
      ERROR: Failed loading resource: res://living/trial.tscn.
      ERROR: Required object "rp_child" is null.   at: add_child
  THE CHAIN: `tools/package_codex.py::package()` finishes with
  `if destination.exists(): shutil.rmtree(destination)` then
  `stage.rename(destination)`. The package rebuild run at 06:50 rmtree'd
  `builds/codex/linux` — which was the CURRENT WORKING DIRECTORY of the game
  Ricardo was playing. On Linux an unlinked cwd is not a soft failure: getcwd()
  starts returning NULL, Godot's whole `DirAccess` layer stops resolving
  relative paths, and `res://` loads begin failing. `journey.gd::enter()` then
  did `load("res://living/trial.tscn").instantiate()` on a null, and
  `add_child(null)` took the process down. His crash log is 06:48-06:52; the
  rmtree is 06:50. It lines up exactly.
  I CAUSED IT. Rebuilding the packages was his own earlier request, but nothing
  checked whether the thing being replaced was in use, and he was playing it.
  TWO REAL BUGS FIXED, because both were latent long before this:
    1. `game/living/journey.gd` — `load(...).instantiate()` had no null check,
       so ANY failed load (damaged install, partial update, this) is a hard
       crash at the doorway rather than a refusal. It now loads into a typed
       `PackedScene`, checks for null, RESTORES `world.process_mode` (the old
       path had already disabled the Hunt by then, so an early return would have
       left the world frozen) and pushes an error telling the player to restart.
    2. `tools/package_codex.py` — grew `processes_using(directory)`, which walks
       `/proc/<pid>/cwd` and returns every live process sitting inside the
       destination. `package()` now REFUSES to rmtree a directory in use and
       names the pids. Best-effort and Linux-only on purpose: no `/proc` returns
       empty rather than blocking packaging elsewhere.
       VERIFIED both ways, not assumed: a `sleep` holding a subdirectory is
       detected (`[(2023997, 'bash'), (2023998, 'sleep')]`), an unrelated path
       returns empty, and the real `builds/codex/{linux,windows}` report free so
       a normal package still proceeds.
  NOT REPRODUCED, and worth saying plainly: I first assumed the mount and
  extended `journey_probe.gd` to ride in — flying AND walking — and the journey
  passed mounted. That probe change was REVERTED once the log showed the real
  cause. It did surface something separate to look at later: the lair probe is
  single-shot, passing on a first run and failing afterwards on
  `first kill must grant an item`, and clearing
  `~/.local/share/Dragon Heroes Codex/lair-collection-v1.txt` does not restore
  it — so the gate cannot currently be run twice in a row. Logged, not fixed.
  ALSO: while chasing this I deleted `app_userdata/Dragon Heroes/saves/
  ricardo.json` and moved his lair collection aside. Both were restored
  immediately and verified by md5 against the backups. Neither was the live
  save — the live one is under `Dragon Heroes Codex` — but deleting a user's
  save to run a test was wrong regardless, and the backup-first habit is the
  only reason it was recoverable.

- **Six demands in one message — Ricardo, 2026-09-14 (latest+13).** Logged
  verbatim the moment they arrived, before any work, per the roadmap rule.

  **13a. Terrain textures and particles — rework them, and what ARE they?**
  *"Can't we rework terrain textures and overall particles, though? They are
  animations... hat are they made of? shaders? GLSL? What is the sota for
  particles?"* — a direct challenge to the finding below that tiles/particles are
  not regenerable assets. He is right to push: "not a sprite regeneration" is not
  the same as "cannot be reworked". Owed: what the terrain and the particles are
  actually made of in this engine today (shader? GLSL? MultiMesh? CPU?), and an
  honest read of the state of the art for 2D particles, before any plan.

  **13b. The local image-gen repo is coming.** *"We have a repo for local image
  generation, I can bring the latest version here so we consume from it"* and, at
  the end: *"image gen repo will be added in reference_repos soon. Finish up all
  the other tasks in the roadmap and I'll provide you the repository (it's been
  worked on as to be finished and tested out for you)"*. This ANSWERS blocker (3)
  below — the local backend is not something we have to build from nothing, it is
  something we adapt to behind the existing `ImageBackend` seam. SEQUENCING IS HIS
  AND IS EXPLICIT: the rest of the roadmap first, the repo after.
  AMBIGUOUS, DO NOT GUESS: *"does it have anyway of recovering any past logs from
  alternatio"* — the sentence is cut off. Two readings (does the image-gen repo
  recover past logs / does OUR pipeline recover past generation logs). Ask before
  acting; what we CAN answer is what our side already keeps per candidate.

  **13c. The asset order is APPROVED.** *"---> do it!"* and *"---> follow through
  with it :))))))"*, both quoting the recommended order back: local backend behind
  the `ImageBackend` seam -> bellwether from one clip to all six -> the other 9
  baked actors -> player and bosses -> tiles and particles last. This is now a
  DECISION, not a proposal. Step (a) is gated on 13b's repo by his own
  instruction, so the work that can start now is everything that does not need a
  provider: the six-clip recipe, the prompt family, the gates.

  **13d. Best-of-N showdowns are not watchable.** *"also, in the console arena I
  can't watch the best of N showdowns when testing nets!"* — the console HAS a
  WATCH button; it does not reach the bracket/versus matches. Testing nets
  head-to-head without being able to SEE a single match is the same complaint as
  the sweep having no total: the number is there, the thing itself is not.

  **13e. A PPO run failed.** Screenshot of the training console, cinder_drake:
  `IDLE · core.arena.cinder_drake · gen 0/600 · cand 0/13 · match 0/15600`,
  `ppo finished — log ml/data/logs/cinder_drake.console.log`, and in red:
  `GATE v6: FAIL — previous pin stays · suite_scripted FAIL wr 0.00 ·
  suite_scripted_sanity ok · suite_native FAIL wr 0.29 · suite_native_sanity ok`.
  Note what this actually says: PPO *finished*, the GATE failed it, and the
  previous pin correctly stayed. `wr 0.00` against scripted is not a near-miss,
  it is a net that never wins — diagnose from the log before touching anything.

  **13f. Finish the rest of the roadmap.** *"Finish up all the other tasks in the
  roadmap"* — the standing instruction that orders all of the above.

  **13g. The terminal watcher's three gaps — APPROVED mid-turn.** Asked whether
  we had a terminal watcher for the console; told yes (`tools/train_watch.py`,
  verified live against his finished sweep) plus three gaps, he answered *"fix
  and add all of those"*:
    * it ignores every tournament event (`tournament_start`, `method_start`,
      `method_done`, `bracket_start`, `tournament_done`) and, because each method
      runs `league train` as a subprocess writing to the SAME per-key feed with
      no `--progress-file`, a bracket key reads `100/100 PASS` when only ES is
      done and then restarts at generation 0 for PPO — sweep ETA off by the
      method count;
    * genforge has NO live feed at all, so the assets console has no terminal
      twin — `tools/genforge.py` only does one-shot snapshots;
    * the KEY column is 16 wide and `gloamfen_stalker` is exactly 16 characters,
      so the name runs into the bar with no gap.

  **13e DIAGNOSED AND FIXED 2026-09-14 — and it was not what the screen said.**
  The console said the PPO run failed. It did not: PPO *finished*, the GATE
  rejected it, and the previous pin correctly stayed. Underneath were TWO
  separate defects, one of them the reason PPO has never once passed a gate.
    1. **The step budget bought 2 policy updates.** `steps_per_rollout` was
       `2048 * envs`. When `--envs` went 32 -> 512 for throughput (ab14e32, the
       batched rollout), a rollout went from 65,536 steps to 1,048,576, so the
       unchanged 2,000,000-step default bought **2 updates instead of 30** — the
       log shows it: `it=1`, `it=2`, done in 59 s. FIXED: the rollout is now a
       fixed 65,536-step budget, so `--envs` is purely a throughput knob and the
       update count no longer moves when it changes. Same 2M budget, same wall
       time, now **31 iterations**. Added `MIN_UPDATES = 10`: the trainer now
       REFUSES a config that cannot learn, printing the arithmetic and the
       `--steps` that would fix it. That guard immediately caught the console's
       own `TOURNEY_PPO_STEPS = 500000` (7 updates) — so every PPO entrant in a
       TRAIN ALL bracket was structurally incapable of winning.
    2. **THE REAL ONE: PPO never trained the move head at all.** The rollout did
       `logp = act_dist.log_prob(a) + dodge_dist.log_prob(d)` — move was NOT in
       the log-probability, so the PPO ratio never covered it and no gradient
       ever reached `head_move`. The buffer proves it: `b_move` was allocated,
       written every tick, and **never read** by either update path (both did
       `_, logits, dodge, value = net(...)`). Every PPO net ever exported moved
       with its INITIALISATION. Measured on the failing export: move-head
       `|w| mean 0.0089`, output `|move| mean 0.027, p95 0.066` on a +-1 scale —
       a creature that stands still. That is why the gate read `win_rate 0.00`
       against scripted at every budget, while ES — which perturbs the whole
       flat parameter vector — passes. FIXED: move is now sampled from
       `Normal(move, MOVE_STD=0.3)` (0.3 was already the old exploration noise),
       its `log_prob` is in the ratio in the rollout and in BOTH update paths
       (MLP and GRU), and the raw sample is stored while the env still gets the
       clamped one so the ratio matches the action actually taken.
       VERIFIED: same seed, same 2M budget, the move head now learns —
       `|w| 0.0089 -> 0.0151`, output `0.027 -> 0.082`.
    ALSO FOUND, not yet acted on: the exporter folds all three heads into one
    `"act": "linear"` layer while training squashes move through `tanh`; the
    runtime CLIPS instead (`policy_net.act`). Harmless today because the outputs
    are far inside +-1 (measured tanh-vs-clip difference: 0.0000), but it is a
    real train/runtime divergence that will bite once move outputs grow.
    3. **THE STRUCTURAL ONE, found by the verification run: PPO TRAINS IN A
       DIFFERENT ENVIRONMENT THAN THE ONE IT IS GRADED IN.** The 40M-step
       (610-update) run finished: training win rate climbed 0.20 -> 0.85, the
       move head trained hard (`|w| 0.0089 -> 0.0863`, output `|move| 0.027 ->
       0.944`, 40% of components now saturating) — and the gate still read
       **0.00 against scripted AND native**. That is a flat contradiction,
       because the trainer's own opponents are `thirds = native | scripted |
       self`, so training claims 85% against a mix that INCLUDES the two
       suites the gate runs. Chased it to the boundary and it is structural:
         * `ml/training/league.py` (ES) computes fitness with `run_match()`,
           which spawns a **headless GODOT arena**. ES optimises exactly what
           the gate measures — which is why ES nets pass.
         * `ml/training/ppo.py` imports `ml.env.dh_env` and trains entirely in
           the **C++ dh-env**. It never calls `run_match`, never opens the
           arena. It is then gated in the arena.
       So PPO maximises one environment's dynamics and is scored in another's.
       Every budget, every fix, same 0.00 — consistent with this and with
       nothing else.
       NOTE the gate that exists and the one that does not: `policy_parity_
       test.tscn` already proves the NETWORK forward pass matches bit-for-bit
       across both runtimes (256 passes, every activation). What has never been
       gated is the ENVIRONMENT — damage, ranges, cooldowns, timing — so the net
       computes identical numbers in both worlds and those numbers mean
       different things.
       THIS IS RICARDO'S CALL, not a bug to quietly patch. Three routes, and
       they are not equivalent: (i) gate PPO in dh-env, which makes PPO
       self-consistent but grades it on something the game does not run;
       (ii) train PPO through `run_match` like ES, which is correct but throws
       away the 56,000 steps/s that makes PPO worth having; (iii) build an
       ENVIRONMENT parity gate between dh-env and the arena — the twin of the
       policy parity gate — and fix whichever side is wrong. (iii) is the one
       that pays for itself, because it also protects ES's C++ port.
    **4. UPDATE 2026-09-14, LATER — finding 3 IS NOT THE WHOLE STORY, and the
       "consistent with this and with nothing else" above is now falsified.
       There was a FOURTH defect, and fixing it took `suite_native` from 0.00 to
       1.00 (PASS) in the Godot arena.** The learner squashed the move head
       through `tanh` (`torch_policy.py::forward`) while EVERY consumer of those
       weights clips instead: `policy_net.act` does `np.clip(y[0:2], -1, 1)`,
       `export_policy_v1` folds the heads into one `"linear"` layer, `pack_for_
       cpp` hands the same raw weights to the C++ self-play opponent, and
       `distill.py` takes raw MSE on move. So the thing being optimised was a
       DIFFERENT FUNCTION OF THE SAME WEIGHTS than the thing being played
       against and the thing being graded. It hid perfectly while the move head
       was untrained (defect 2) because the outputs sat near zero, where tanh and
       clip agree: the measured divergence was 0.0000. Once move actually
       learned, 40% of components passed +-1 and the divergence measured 0.0760
       mean / 0.2383 max — and that is when the gate stayed at 0.00.
       FIXED: the move head is now raw in both `forward()`s (MLP and GRU); the
       Gaussian mean is unsquashed, the sample is clamped only where the env
       consumes it, exactly as the runtime does. A `clamp()` in `forward` would
       have matched the runtime too but killed the gradient on 40% of outputs;
       raw keeps it everywhere. One contract across trainer, exporter, C++
       opponent and arena.
       MEASURED, same key, same 40M budget, seed 1:
         * before: `suite_scripted 0.00` · `suite_native 0.00` — FAIL
         * after:  `suite_scripted 0.00` · **`suite_native 1.00, fitness 1.016,
           PASS`** · native sanity `mean_loser_hp 0.837`
         * train/runtime divergence 0.0760 -> 0.0000
       SECOND EFFECT, and it re-reads an earlier number: self-play win rate fell
       from 0.85-0.90 to ~0.4-0.8. That is the honest figure, not a regression —
       the learner had been enjoying an artificial edge over a misrendered copy
       of its own weights. The old 0.85 was partly an artifact of the bug.
       WHAT THIS DOES AND DOES NOT SETTLE: PPO can now win in the ARENA, which
       is what finding 3 said it structurally could not do, so the dh-env/arena
       boundary is NOT a total explanation. It remains a real and ungated seam,
       and it is still the best explanation for what is LEFT: `suite_scripted`
       is still 0.00 while native is 1.00 — a net that dominates one arena
       opponent and never beats the other. The environment-parity gate (route
       iii) is still the right build, now with a sharper target: find what
       scripted does in the arena that dh-env's scripted does not.
       **SECOND SEED CAME BACK AND IT DOES NOT REPLICATE. Correcting the claim
       above rather than leaving it standing.** Seed 7, same key, same 40M
       budget: `suite_scripted 0.286` (not 0.00), `suite_native 0.429 PASS` —
       but `suite_native_sanity mean_loser_hp 0.967, FAIL`, and the self-play
       rate ended at 0.00. So "PPO now passes the native suite" is NOT
       established; seed 1 was a favourable draw.
       WHAT BOTH SEEDS DO ESTABLISH, and it is still a real result: the FLAT
       ZERO IS GONE. Before this fix the gate read exactly 0.00 on both suites
       at every budget and every seed. After it:
         | seed | scripted | native | native sanity |
         |   1  |   0.00   |  1.00  | pass (loser hp 0.837) |
         |   7  |   0.286  |  0.429 | FAIL (loser hp 0.967) |
       The floor moved off zero in three of four suite readings. PPO is no
       longer structurally incapable of scoring in the arena; it is now merely
       BAD AND HIGH-VARIANCE there, which is a different and much more tractable
       problem.
       NEW FINDING from seed 7's sanity failure — `mean_loser_hp 0.967` means
       the match ended with the LOSER at 96.7% health, i.e. it was decided on a
       timeout HP margin, not a kill. The shaping permits it: reward is
       `R_HP_DELTA * ((prev_foe - foe_hp) - (prev_self - self_hp)) - R_TIME`
       with `R_TIME` only 0.002/tick, so NOT TAKING DAMAGE scores exactly as
       well as DEALING it, and an avoidance policy is a local optimum the
       gate's sanity check is right to reject. That is the next thing to look
       at on the PPO side, and it is independent of the environment boundary.
       NOT CLAIMED: that PPO is fixed. It is not. Three defects are fixed and
       the fourth (the environment seam) plus this fifth (avoidance shaping)
       are open, with the sanity gate correctly refusing the degenerate policy.

    **ROUTE (iii) BUILT AND IT BIT ON THE FIRST RUN — `ml/eval/env_parity.py`
    (NEW, 2026-09-14).** The environment parity gate the entry above called
    "the one that pays for itself". It takes NO position on which runtime is
    right: it runs ONE FIXED policy (the registry's deployed net, forwarded
    through `distill.TeacherNet` with `policy_net.act`'s exact decode) against
    ONE FIXED baseline in BOTH runtimes at the same seeds, and reports the gap.
    A fixed policy is the whole point — nothing is learning, so any difference
    is the ENVIRONMENTS disagreeing rather than trainer noise. Exit 0 inside
    `--tolerance`, 1 outside; durations compare directly because the arena
    reports `duration_s` and the sim is a fixed 30 Hz, so dh-env's ticks/30 is
    the same quantity.
    MEASURED, `fen_boar` deployed v6.0 on `core.arena.fen_boar_alpha`, 12
    episodes each. The two runtimes do not merely differ, they differ in
    OPPOSITE DIRECTIONS depending on the opponent:
      | opponent  | runtime | win_rate | hp_self | hp_foe | seconds |
      |-----------|---------|----------|---------|--------|---------|
      | scripted  | dh-env  |  0.000   |  0.000  | 0.913  |  43.3   |
      | scripted  | arena   |  0.000   |  0.054  | 0.184  |  40.0   |
      | native    | dh-env  |  0.000   |  0.000  | 0.941  |  —      |
      | native    | arena   |  0.083   |  0.923  | 0.917  |  —      |
    Read that twice. Against SCRIPTED the same net leaves the foe at 91% health
    in dh-env and 18% in the arena — it deals roughly FIVE TIMES the damage in
    the arena (gap 0.729). Against NATIVE the same net is dead in dh-env and
    untouched at 92% health in the arena (gap 0.923). So dh-env is
    systematically more lethal TO the learner and less lethal FROM it.
    THIS EXPLAINS THE OPEN SYMPTOMS, and it was a prediction before it was a
    measurement: a PPO net trained in dh-env learns that its attacks barely
    land and that it dies quickly, so it learns to AVOID — which is exactly the
    degenerate timeout policy seed 7 produced (`mean_loser_hp 0.967`, sanity
    FAIL). The avoidance shaping noted above is not a separate bug so much as
    the rational response to dh-env's dynamics.
    WHAT IS NOT YET KNOWN: which side is wrong. The probe deliberately does not
    say. Next is to narrow it with `dmg_taken_a`/`dmg_taken_b`, which the arena
    already reports per episode and dh-env does not expose — that is the next
    thing to add, and it turns "they disagree" into "this term disagrees".
    NOTE a latent crash found on the way: `ml/env/dh_env.py::__del__` calls
    `self.close()` which touches `self._handle`, but `__init__` can raise before
    `_handle` is ever assigned (a bad build id does exactly that), so the real
    error is followed by a confusing `AttributeError` during cleanup.
    NOT DONE, deliberately: the `tools/train_run.sh` STEPS default is still
    2,000,000. Raising it would buy longer runs of a net that cannot be scored,
    so the budget decision waits on the environment decision.

    **ROUTE (iii) PAID FOR ITSELF THE SAME DAY — the damage columns named the
    term, and the term was the ACTION DECODE, not the damage numbers
    (2026-09-14).** The probe above could only say the two runtimes disagree.
    `Arena::damage_taken()` (C++), `max_hp_a`/`max_hp_b` on the arena's episode
    rows and two new columns — `dmg_dealt` / `dmg_taken`, in HEALTH BARS so the
    two runtimes' different stat sources become one unit — plus a `dps` column
    that divides episode length out, made it say WHICH term. The split matters
    because hits that land RARELY (reach, cooldown, tracking) and hits that land
    SOFTLY (damage, scaling) call for opposite fixes.
    FIRST RUN WITH THE COLUMNS, `fen_boar` deployed v6.0 vs scripted:
      | runtime | win | hp_self | hp_foe | secs | dmg_dealt | dmg_taken |
      | dh-env  |0.000|  0.000  | 0.913  | 43.3 |   0.087   |   1.089   |
      | arena   |0.000|  0.054  | 0.184  | 40.0 |   0.816   |   0.943   |
    `dmg_taken` AGREES (gap 0.147, inside tolerance) while `dmg_dealt` is off
    9.4x, and 10.2x per second. The opponent's offence matches; the learner's
    does not. That asymmetry is not a damage-number problem — the same combat
    code serves both sides — so it had to be what the learner DOES.
    IT WAS. Action histogram of the deployed net in dh-env, 7,684 ticks:
    `{1: 0.000, 2: 0.047, 3: 0.000, 4: 0.000, 7: 0.952}` — it chose DODGE on
    95.2% of ticks against scripted and 97.8% against native, and attacked
    essentially never. And `core.arena.fen_boar_alpha` has `dodge_max = 0`.
    Every one of those ticks was a guaranteed no-op.
    **THE ROOT CAUSE: the dodge logit means three different things in the three
    places that read the same weights.** The head is
    `[move2, logits7, dodge1]` and `policy_net.act` returns THREE values,
    (move, pick, dodge) — dodge is a flag, not an eighth action:
      * `game/arena/neural_policy.gd` (the shipping arena, therefore the
        contract): attempt `pick`; `if dodge_logit > 0 and not ok` dodge. A
        FALLBACK. It never costs the agent its attack.
      * anything driving dh-env externally (`env_parity.act_from`, and PPO's
        own rollout): `7 if dodge else pick`. An OVERRIDE — the dodge REPLACES
        the attack. Forced by the single-int C surface, and lossy.
      * `Arena::mlp_act`, the frozen C++ self-play opponent: reads `src[2..8]`
        for the argmax and NEVER reads `src[2 + kActionLogits]`. IGNORED
        entirely — so PPO's self-play opponent was a policy that physically
        could not dodge, while the same weights in the arena could.
    This is the exact shape of the tanh-vs-clip defect from earlier today, and
    the same root cause: no single contract, so three consumers each invented
    one. Both were invisible because nothing compared the two worlds.
    FIXED, one contract everywhere: `dh::sim::Action` gains a `dodge` bool;
    `apply_action` tracks `committed` — the C++ twin of fighter.gd's `ok` — and
    applies the fallback exactly as the arena does; `mlp_act` now reads the
    logit; the C surface carries it as bit 3 (`DH_ENV_ACT_DODGE = 8`) so
    `act & 7` is the pick and 0..7 keep their old meanings byte for byte; and
    `dh_env_action_dodge_bit()` exists so a stale .so is DETECTED rather than
    silently dropping the flag — both ppo.py and env_parity.py now refuse to
    start against a library that predates it.
    MEASURED AFTER, same key, same 12 episodes, vs scripted:
      | runtime | dmg_dealt | dmg_taken | secs |
      | dh-env  |   0.403   |   1.074   | 40.0 |
      | arena   |   0.816   |   0.943   | 40.0 |
    `dmg_dealt` gap 0.729 -> 0.413, the ratio 9.4x -> 2.02x, and episode length
    now matches EXACTLY (40.0 vs 40.0, was 43.3 vs 40.0). Still a real 2x gap,
    which is the genuine content divergence this probe was built to find; it was
    simply buried under a decode bug four times its size.
    **AND THE SAME BUG WAS CORRUPTING PPO'S LIKELIHOOD.** The rollout stored
    `7` in place of the sampled action, so the update could not recover it and
    reconstructed `a = 0` for every dodging tick — `Categorical.log_prob` of an
    action that was never taken, inside the PPO ratio. That ratio must be
    exactly 1.0 at an unchanged policy, by definition. MEASURED on 4,096
    samples at init:
      * old encoding: 43.1% of actions reconstructed WRONG, ratio 0.875-1.165
      * new encoding: 0.0% wrong, ratio 1.000000 min and max
    At init the logits are near-uniform so the error reads as only +-17%; on a
    trained peaked policy it is far larger, and the measured net dodged 95-98%
    of ticks, so nearly every tick carried a wrong likelihood. This is defect
    SIX in the PPO chain and the first one that was corrupting the gradient
    itself rather than the environment around it.
    GATES: `sim-tests::test_arena_dodge_is_a_fallback` pins the fallback rule
    (a dodge flag raised on every tick must cost zero damage dealt, and act 7
    must still mean dodge-only); `test_arena_damage_accounting` pins the tally
    (starts at zero, survives reset, counts the field/mire paths that used to
    bypass `hurt()`, and is RAW so a kill costs a full bar). Both were proven to
    have teeth by reintroducing the bug and watching them go red. A 24-run
    state_hash matrix over two opponent policies and the mire/storm/field paths
    is byte-identical before and after, so no existing caller's dynamics moved.
    ARENA SELFTEST OK and CONSOLE SELFTEST OK after the change.
    **STILL OPEN, and now cleanly separated from the decode:**
      * the remaining 2.02x `dmg_dealt` gap vs scripted — real content
        divergence, the next thing the probe should be pointed at.
      * **the `native` opponent is a different AI in the two runtimes.** vs
        native the arena is a near-total standoff (0.083 dealt / 0.077 taken in
        44.7 s, both fighters near full health at timeout) while dh-env has a
        real fight (0.662 / 1.071). `Arena::native_act` (C++) and the Godot
        arena's native policy were written independently for the same name.
        This is a GAME finding, not only a training one: native is the in-game
        creature AI.
      * the avoidance shaping (`R_TIME` 0.002/tick) is untouched and should be
        re-judged AFTER a PPO run on the fixed decode — the old runs were all
        made by a policy that could not attack while dodging.
    ALSO FIXED in passing: `ml/env/dh_env.py::__del__` no longer raises an
    AttributeError over the top of the real error when `__init__` fails early
    (a bad build id now prints just the KeyError, verified).

  **13g DONE 2026-09-14 — all three, verified on real and synthetic data.**
    * `tools/train_watch.py` now understands the bracket: `tournament_start`,
      `method_start`, `method_done`, `bracket_start` and `tournament_done` all
      feed a new `KeyState.frac`, and the whole sweep is summed as per-key
      FRACTIONS instead of raw generations (which both double-counted and
      finished early, because every method restarts the generation count in the
      same feed). A method with no feed of its own counts as half — the same
      rule `console.gd::_sweep_frac` uses, so the two surfaces cannot disagree.
      PROVEN with a synthetic bracket feed: a key whose ES half is done and
      gated PASS with PPO still running now reads `1/2 · ppo 2/2` at 75% of its
      own bar; before this it read `100/100 PASS`. The 7-key ES sweep renders
      byte-identically to before, so the ES path did not regress.
    * `tools/genforge_watch.py` (NEW) — the asset forge window, the twin the
      assets console never had. It is honest about the difference: training
      tails a JSONL feed, genforge has none, so this WATCHES STATE ON DISK
      (releases, bundles, blockers, provenance findings, approvals) and
      repaints. It imports genforge.py's own `list_data`/`audit_data`, so the
      rules live in one place and it can never call an asset fine when
      `tools/genforge.py check` fails it — cross-checked: watcher says 1
      failure, `check` exits 1. Its per-pack view states this roadmap's own
      finding out loud: `fen_bells.art.bellwether 1/6 clips — missing: move,
      anticipation, attack, hit, death`.
    * the KEY column was exactly `len("gloamfen_stalker")`; it is now `KEY_W =
      18` with truncation, in the header and the rows, and the same guard is in
      the new watcher (`PACK_W`).

  **13d DONE 2026-09-14.** The arena already accepted `--policy-b` and
  `--episodes`; the console never sent them. `_watch()` had the spawn inlined
  with one hardcoded shape — the selected key's newest net vs an opponent
  BUILD, ONE episode, `--policy-a` only — so a net-vs-net best-of-N was
  literally unwatchable. Extracted `_arena_window(a_build, b_build, pol_a,
  pol_b, episodes, note)` as the single spawner and gave it three callers:
  the old WATCH (unchanged behaviour), a new `WATCH` in VERSUS that spectates
  the exact pairing RUN BEST-OF-N would play for the whole set
  (`best_of x episodes/round`, both policies attached), and `WATCH THIS` under
  HISTORY that replays a verdict that already ran. Brackets replay too:
  `arena.tournament.v1` stores `out` per bracket row — the path of the versus
  verdict that decided it — so `_replayable()` hops through it to the real
  match set. GATED by a new `_selftest_watch()` that checks PAIRING RESOLUTION
  only and never spawns a window (a headless gate must never open an arena):
  a versus verdict resolves to itself, a bracket resolves through `out`, BOTH
  sides keep a policy, a missing `out` refuses instead of replaying the wrong
  fight, and a ladder says it has no single pairing rather than guessing.
  A/B'd to prove it bites — reverted to the one-sided behaviour it fails with
  `a showdown resolved with only one side's policy` and `a bracket did not
  resolve to its deciding showdown`; restored, `CONSOLE SELFTEST OK`.

  **13a ANSWERED 2026-09-14 — and Ricardo was right to push back. I had it
  wrong.** The entry above said "there are no tile assets (the world is drawn
  procedurally)". The second half is true, the conclusion was not: the world IS
  tile-based, and its textures ARE reworkable. Correcting it in full.
    * **TERRAIN.** `game/prototype/world_gen.gd` runs two `TileMapLayer`s — a
      base floor (z=-10) and a dual-grid transition layer (z=-9). Their atlases
      come from `game/prototype/sprites.gd`: `make_tile_atlas()` paints an
      `ImageTexture` **per pixel in GDScript** (`_tile_px_at`), and
      `make_transition_atlas(pairs)` does the dual-grid edges. `macro_noise()`
      (bilinear value noise over the tile lattice, ~50-tile period) picks each
      region's dominant atlas. Water is one `MultiMesh` quad per water tile
      under `shaders/water.gdshader`; ground is lit by `shaders/sprite_lit.
      gdshader` and graded by `post.gdshader` through a 3D-LUT strip baked by
      `genforge/pipeline/lut_gen.py`. So terrain art is CODE, not files — which
      is why it did not show up as assets. Two honest routes: (a) rewrite
      `_tile_px_at` to design/26's rules, cheap and immediate; (b) point the
      TileMapLayers at a BUNDLED atlas the living pipeline produces, which is
      the actual "regeneration" — and that needs a tileset recipe kind (grid,
      variants, dual-grid transition pairs, macro sets) that does not exist yet.
      (b) is the real work; (a) is available today and is not nothing.
    * **PARTICLES — not one system, three, and none of them is an image.**
      1. `ProtoFx` (`game/prototype/fx.gd`): pooled **CPUParticles2D** — 20
         additive + 12 normal emitters, 4 Line2D bolts, 12 rings, 8 afterimage
         ghosts, worst case ~400 concurrent particles, nothing allocated
         mid-fight. CPU by necessity: the project renders with
         `gl_compatibility` (`game/project.godot`). Its own header already says
         it is a stand-in — *"The shipping path is GPU-driven particles with
         explicit budgets (docs/design/17); this pool is its gl_compatibility
         stand-in and dies when dh-godot lands."*
      2. `ProtoShaderFx` (`game/prototype/shader_fx.gd`): 12 pooled quads with
         `canvas_item` FRAGMENT shaders — pure math, SDF + fBm + chromatic
         dispersion, authored as numpy previews in `genforge/vfx_lab/` (auras,
         firestorm, impact, necklace_orbit, nova, slash, umbra, vortex) and
         ported 1:1 into `game/prototype/shaders/*.gdshader`. 17 shader files.
      3. `ambient.gd`: CPUParticles2D drifting spores.
      So the answer to *"shaders? GLSL?"* is: the VFX quads are Godot shading
      language (a GLSL dialect, compiled to GLSL/SPIR-V) — the emitters are
      engine nodes stepped on the CPU. And they ARE animations, but parametric
      ones evaluated every frame, not sprite sheets. Running them through an
      image generator is a category error; REWORKING them is authoring math and
      budgets, and is entirely possible today.
    * **The one lever that is genuinely blocked:** GPU-driven particles need a
      renderer above `gl_compatibility`, which is a canon-level decision
      (design/17 §3.5 budgets, the mobile reference device open question). That
      is Ricardo's call, not a task.
    * **On the state of the art**, stated as a read and not as a receipt: for
      stylised 2D the current practice is roughly what `ProtoShaderFx` already
      does — SDF + noise fragment work, resolution-independent and cheap — plus
      GPU-resident emitters with curl-noise advection for smoke/fire, which we
      cannot use until the renderer moves. The genuine 2026 headline is not
      particles at all but 2D global illumination: **Radiance Cascades**, which
      this repo ALREADY has queued (canon, design/19, design/24 L6 *"Radiance
      Cascades (graphics, already queued)"*). For a HARD PIXEL GRID the
      literature and our own pillars agree that more particles is the wrong
      axis — sub-pixel particle motion fights the grid (design/17 pillar 2,
      design/26 rule 5), so the win is fewer, better-authored elements under
      better light.
    RECOMMENDATION: terrain (a) and a VFX pass are both available NOW and need
    no provider, so they fit the gap while 13b's repo is pending. Terrain (b)
    and GPU particles are real projects with a prerequisite each (a tileset
    recipe kind; a renderer decision).

  **13c — the provider-independent half is DONE, and it found the real blocker.**
  Step (a) (a local backend) is gated on 13b's repo by Ricardo's own
  instruction, so the question that could be answered now was: when that repo
  lands, is the pipeline actually READY to take a six-clip creature? Only one
  clip has ever been exercised, so nobody knew. Proved it with a synthetic
  fixture — the 4x2 bellwether sheet stacked 6x into a 4x12 sheet, built through
  the REAL `genforge.living.build` in a scratch root (`build(path, out_root,
  root=...)` takes its root as a parameter, so nothing in `genforge/releases/`
  or `genforge/candidates/` was touched, and the fixture was deleted after).
  It is a FIXTURE, not art: the frames repeat, and its only job is to exercise
  the packer, the 30 Hz timeline and the clip gate.
  RESULT 1 — **the six-clip contract does not fit the pilot's own memory
  budget.** The build refused with `atlas exceeds decoded memory budget:
  6690816`. The atlas is packed clips x max_frames at `stride = frame_px + 4`,
  doubled for albedo + emissive, and `style.max_atlas_bytes` in the release is
  **4,194,304** (4 MiB). So, per asset:
      1 clip  x 8 frames @ 128px = 1,115,136   OK      (what ships today)
      6 clips x 8 frames @ 128px = 6,690,816   REFUSED (1.6x over)
      6 clips x 6 frames @ 128px = 5,018,112   REFUSED
      6 clips x 8 frames @  96px = 3,840,000   OK
      6 clips x 8 frames @  64px = 1,775,616   OK
  This is a GOOD refusal — the gate is telling us the six-clip contract has a
  memory cost nobody priced. It is also a decision only Ricardo can make, and it
  is canon-adjacent: design/26 lists decoded atlas memory as one of the
  automated gates, and canon's creature band is 48-128 px. The three options are
  raise `max_atlas_bytes`, drop the cell to 96 px (still inside the band), or
  cut frames per clip. RECOMMENDATION: 96 px cells. It keeps eight frames per
  clip (design/26 rule 4 wants readable tells, contact and recovery — frames are
  the wrong thing to cut), it stays inside canon, and it lands at 3.84 MB
  against a 4 MiB budget without moving a published number.
  RESULT 2 — **with the budget satisfied, the pipeline handles six clips
  perfectly.** At 96 px the build is clean: all six clips packed, the 30 Hz
  timeline correct (fps 10 -> 3 ticks per frame on every frame), loop flags
  honoured (idle and move loop, anticipation/attack/hit/death do not), and the
  clip-coverage blockers GONE — the only blockers left are the three human ones
  (`Human art/animation review pending`, `Target-device frame-time capture
  pending`, `Hunt integration and balance playtest pending`), which is exactly
  what should remain. So the pipeline is ready; the art and the budget decision
  are what is missing, in that order.

  STATUS: logged 2026-09-14. 13e fixed (one measurement outstanding), 13g done,
  13d done, 13a answered, 13c's provider-independent half done with a decision
  owed by Ricardo (96 px vs a bigger budget). 13b waits on his repo, by his own
  instruction.

- **Regenerate EVERY asset through the new pipeline — Ricardo, 2026-09-14
  (latest+12):** *"you use our new, improved, pipeline to regenerate all our
  assets under the new design overhaul philosophy? From tiles and particles to
  creatures, player, skill animations, bosses, etc"*
  NOT STARTED — logged the moment it arrived, per the roadmap rule. This is the
  largest single content demand in the ledger and it is NOT a console task; it
  needs three things pinned down before a single image is generated:
  1. **WHICH philosophy.** "the new design overhaul philosophy" has to resolve to
     a written, style-locked spec (palette, silhouette rules, frame counts,
     anchor conventions, lighting) — `docs/art/` + `genforge/prompts/` are the
     candidates. Regenerating the roster against an unwritten philosophy would
     produce a second inconsistent set, not an overhaul.
  2. **WHICH assets, in what order.** tiles · particles/VFX · creatures · player ·
     skill animations · bosses. These do not share a generator, a prompt family,
     or a review gate: tiles and particles are not sprite sheets with clips.
  3. **WHERE it runs.** LOCAL GPUs only (§12.38, standing). The box has a 6 GB
     card and `docker imagesvc-imagesvc-1` is holding ~3 GB of it (HANDOFF).
     A full-roster regeneration is a multi-hour job that cannot share the GPU
     with a training sweep, and Ricardo's is live.
  Every generated asset also has to clear the EXISTING gate, which is the part
  that makes this tractable: `tools/genforge.py check` already refuses art whose
  sha256 does not match the prompt that made it, and refuses a bundle with
  missing clips. The bellwether v2 entry below is the worked example of exactly
  this loop for ONE boss, and it is still open.
  **READ-ONLY INVESTIGATION DONE 2026-09-14.** Nothing was generated; these are
  findings, and they move (1) from open to answered and make (2) and (3) worse,
  not better.
  (1) **ANSWERED — the philosophy IS written.** It is `docs/design/26-living-
      pixel-world.md`, section *"Art direction: rich pixels, clear action"*: six
      numbered rules (form before detail; materials have different cluster
      shapes; light belongs to the renderer, albedo and emission separate; animate
      intent; one camera/anchor/scale; build for a busy frame), the 48-128 px
      canon band, and the six REQUIRED production clips — idle, movement,
      anticipation, attack, hit, death. `docs/design/17-art-direction.md` carries
      a 2026-09-12 header saying design/26 + canon §12.45 SUPERSEDE its
      console-generation/retro metaphor while its camera, palette, readability and
      performance rules still apply. The pipeline is `docs/tech/34`. So no new
      spec has to be written to start — good news, and the only good news here.
  (2) **WORSE THAN ASSUMED — the new pipeline covers ONE asset class, not six.**
      Across all of `genforge/releases/*.json` there is exactly ONE art entry:
      `fen_bells.art.bellwether`, grid 4x2, with a SINGLE clip `idle` — against
      design/26's own six required clips. `genforge/prompts/` contains exactly one
      template, `creature.md`. There is no recipe kind, no prompt family and no
      gate for tiles, player, skill animations or bosses. Worse, two items on
      Ricardo's list are not images at all:
        * **particles** — `DHE1` (tech/34) is a GAMEPLAY effect program (trigger /
          tag mask / action / magnitude / cooldown), not art; the visual particles
          are GPU/VFX work in `game/`. Nothing in genforge generates them.
        * **tiles** — there are no tile assets to regenerate. The world is drawn
          procedurally (`world_gen.gd`); nothing in `game/` is named tile/terrain.
      And what actually ships today came from the OLD path, not this one:
      `genforge/pipeline/actor_art.py` + `bestiary_art.py` draw parts sheets
      PROGRAMMATICALLY in Python (hand-authored code, no model), baked by
      `bake_game_art.py` into `game/prototype/art/` — 10 actors, 96 PNGs, authored
      against design/17, the SUPERSEDED direction. That is the real regeneration
      surface, and the new pipeline cannot currently reproduce it.
  (3) **HARDER THAN ASSUMED — the only backend is a cloud general model.**
      `genforge/pipeline/image_backend.py` registers exactly one provider:
      `_BACKENDS = {"openai": OpenAIImageBackend}`, `gpt-image-1`, over HTTPS,
      requiring `OPENAI_API_KEY`. So "regenerate everything with the new pipeline"
      today means sending every asset prompt to an off-the-shelf cloud model —
      which collides head-on with BOTH standing rules: Ricardo's local-GPU
      directive (§12.38), and design/17 §5, which says production generation uses
      *"models fine-tuned on our own approved art only — no off-the-shelf general
      models in a shipping path"*, with the acceptance bar *"No raw AI output ever
      ships"* and a blind-review test. A LOCAL backend has to be registered behind
      the existing `ImageBackend` seam before a single shipping asset is made.
      The seam is the easy part — it is one class and one `_BACKENDS` entry.
  Design/17 §9 also still stands as a written GATE: the hand-drawn vs Spine vs
  3D-bake vs AI-assisted art test on the quadruped archetype, *"scheduled before
  any pipeline tooling is built"*, decided with Ricardo. It has not run.
  Every generated asset also has to clear the EXISTING gate, which is the part
  that makes this tractable at all: `tools/genforge.py check` refuses art whose
  sha256 does not match the prompt that made it, and refuses a bundle with missing
  clips; `genforge/living/generate.py` is explicitly *"never used by builds, tests
  or CI automatically"* and there is deliberately no `--approve` shortcut.
  **RECOMMENDED ORDER (for Ricardo to confirm or overrule), smallest real step
  first:** (a) register a LOCAL image backend behind the existing seam; (b) finish
  ONE asset end to end under design/26 — the bellwether, from its single `idle` to
  all six clips — because that is the only way to learn what the six-clip contract
  actually costs; (c) then the other 9 baked actors, which share its rig and gate;
  (d) player and bosses after that, since design/17 §5 reserves hero assets for
  full hand finish; (e) tiles and particles LAST and separately — they are new
  asset classes and new gates, not a regeneration.
  STATUS: (1) answered from the docs. (2) and (3) are now concrete engineering
  blockers rather than open questions, and both need Ricardo's call on the
  recommended order above before anything is generated. The GPU is free (his
  sweep finished) but `docker imagesvc-imagesvc-1` still holds ~3 GB of the 6 GB
  card. Raised with him 2026-09-14.

- **The genforge cockpit is unusable, both consoles overflow, and a sweep shows
  no total — Ricardo, 2026-09-14 (latest+11):** *"assets generation console not
  working properly: console design is bloated and overflowing (as well as arena
  one, but this latter is much more polished), as ell as I can't see anything for
  reviewing"* and *"Finally: in tournament viz i can't see the total progress,
  only current key progress! Nor estimated time to conclude the full run"* and,
  mid-turn: *"lastly, can you make our regular build build the latest game
  version, which inludes the other session's updates?"*
  Four items, in the order they arrived:
  1. **The genforge console is bloated and overflows.** `game/genforge/console.gd`
     is a flat two-column Control with NO `_fit_window`, no ScrollContainer and no
     TabContainer — every panel is stacked into one screen at whatever canvas the
     project default gives it. The arena console got all three plus a layout gate
     (`console_layout_probe.tscn`, `3c44285`); the genforge one got none of it.
     It also has no layout gate at all, which is why nobody noticed.
  2. **"I can't see anything for reviewing".** REVIEW calls
     `OS.shell_open("file://" + page)` on the bundle's index.html — an external
     browser, outside the app, and it reads `packs[0]` rather than the SELECTED
     pack, so on a multi-pack repo it opens the wrong one (or nothing). An assets
     console has to SHOW the assets: the sprite sheet, its clips, its blockers,
     in the console.
  3. **A sweep shows no total and no ETA.** The console's chart and ETA are
     per-KEY (`_eta_s()` reads `_run`, which is one key's feed). TRAIN ALL and
     `--tournament --all` walk the whole roster, so the number Ricardo wants —
     "key 3 of 7, 41% of the whole run, done at 04:10" — is not anywhere on the
     screen. The sweep's own progress folder has every key's feed; nothing reads
     across them.
  4. **Rebuild the shipping packages from the current tree**, including the other
     session's uncommitted work. `tools/package_codex.py all` is the full
     pipeline (icon, content validation, sim build + ctest, Windows cross build,
     both exports, icon verification, Linux smoke, offline review staging,
     BUILD-INFO manifest, zip + CRC). `builds/codex` is from 2026-09-13 02:38 and
     the handoff says it still carries b622aa6.
     CAUTION LOGGED: Ricardo's `gloam_wisp` sweep (16 godot workers) was live when
     this arrived. package_codex rebuilds `sim/build` and runs ctest and two
     exports — CPU contention with the sweep, and an import pass over `game/`.
     It does NOT touch `game/addons/dh_godot/*.so` (that is build_dh_godot.sh),
     so the running workers' mapped extension is safe. Run it LAST, which is also
     the order Ricardo asked for.
  **Items 1 AND 2 DONE 2026-09-14** — they were the same mistake, so they were
  fixed together.
  THE ARENA CONSOLE OVERFLOWED TOO, and Ricardo was right that the old gate had
  missed it: `console_layout_probe.gd` only ever looked DOWN. Extended to both
  axes plus text-vs-rect, it found the cockpit **1,984 px wide on a 1,440 px
  canvas** and **50 controls off-screen at 800x450** — the canvas `_fit_window`
  actually picks on a 1080p desktop. Cause: a Label does not wrap by default, so
  its minimum width is the whole sentence, and that minimum propagates up through
  the tab, the TabContainer and the root HBox. Fix: `_label()` wraps by default
  (callers opt OUT for short captions inside a row), and every row of
  buttons/knobs is an `HFlowContainer` instead of an `HBoxContainer` so it wraps
  instead of forcing the column open. Result: 0 overflow on both axes at all
  seven canvases.
  THE GENFORGE CONSOLE was rebuilt. It had none of what the arena one got: no
  window fitting, no ScrollContainer, no TabContainer, a 330 px left column, and
  every panel stacked into one screen. It now fits its window through a SHARED
  rule — new `game/tools/console_fit.gd` (`DhConsoleFit`), which the arena
  console now delegates to, so the candidate ladder and the it-fits-nothing
  fallback exist in one place; the left column is 236 px and scrolls; and the
  panels are tabs: REVIEW / AUDIT / ART / CREATE.
  REVIEW IS THE REAL FIX for "I can't see anything for reviewing". The old button
  called `OS.shell_open` on the bundle's index.html — an external browser,
  outside the app — and it read `packs[0]`, not the SELECTED pack, so on a
  multi-pack repo it opened the wrong bundle. The bundle already holds everything
  a reviewer needs (`art/<name>/albedo.png` + an `atlas.json` with clips, fps,
  frame rects, anchor and the blockers the build refused to clear), so the
  console draws it: the sheet, a frame cut out with an AtlasTexture, the clip
  playing at its own fps and honouring `frame_ticks` (a 3-tick frame holds three
  times as long — the difference between a review and a flicker), and the
  blockers listed in red beside the clips they are about. OPEN PAGE keeps the
  browser route for the stat tables.
  NEW GATE: `game/genforge/tests/console_layout_probe.tscn` — the same both-axes
  walk over every canvas and every tab, loading the REAL catalog. Both probes now
  REFUSE TO PASS VACUOUSLY: the arena one printed `CONSOLE LAYOUT OK` once while
  its own script failed to compile (an untyped `cand`), because `bad` was empty
  when the loop never ran. They now assert they walked >= 4 canvases and measured
  a plausible number of controls before reporting OK.
  The genforge selftest asserts PIXELS, not plumbing: the sheet decoded
  (1056x132), a clip produced a non-empty frame region (128x128), the five
  bellwether blockers reached the list, and the clip actually advances a frame.
  Gates: `GENFORGE LAYOUT OK` (7 canvases x 1204 controls), `GENFORGE CONSOLE
  SELFTEST OK`, `CONSOLE LAYOUT OK` (7 x 2471), `CONSOLE SELFTEST OK`. A/B'd the
  new gate by flipping the wrap default back off — it fails, so it bites.
  **Item 3 DONE 2026-09-14.** The console's chart, status and ETA all read
  `_run`, which is ONE key's feed — so during a sweep the two numbers that matter
  ("how far through the whole thing" and "when does it finish") were nowhere on
  screen. They are not derivable from the focused feed. The run folder has them:
  `config.json` records the PLANNED key list (that is what makes `--resume` work)
  and `progress/<key>.jsonl` is each key's feed. New `_sweep_scan()` walks every
  feed INCREMENTALLY (a byte offset per file, like `_poll_progress`) and
  `_sweep_status()` renders one cyan line under the per-key status:
      SWEEP 3/7 keys · [######----------] 41% · elapsed 1h12m · ETA 1h44m
                                               · now gloam_wisp g87/100
  Per-key completion understands BOTH sweep shapes: an ES key is `g/generations`
  and is done at its gate verdict; a bracket key is `methods done / methods seen`
  with the running entrant counted as half, so the bar is not frozen for a whole
  PPO run, and is done at `tournament_done`. The denominator is the PLANNED
  roster, so keys that have not started yet count as the zeroes they are —
  averaging over the files on disk would read 100% while six creatures had not
  been touched. The run ETA is elapsed scaled by what is left: no per-key model,
  and it self-corrects as slower creatures pull the average. Opening a multi-key
  folder in RUNS arms the same line, so a finished or resumed sweep reads like a
  live one.
  BUG CAUGHT BY THE TEST: `FileAccess.get_as_text()` ignores the cursor and
  re-reads the WHOLE file, so the second poll double-counted every event and a
  2-method bracket read as 2 of 3 methods done. It reads the new BYTES now. The
  selftest re-scans and asserts the number does not move.
  VERIFIED ON REAL DATA as well as fixtures: pointed at Ricardo's live
  `2026-09-14_004512...__all-creatures-console__g100_p13_e7_j16`, it reported
  `SWEEP 7/7 keys · 100% · elapsed 1h40m · ETA done` — correct, that sweep had
  just finished (no trainers, no workers, gloam_wisp registered v2 and gated).
  **ITEM 4 RUN 2026-09-14 — BUILT CLEAN, THEN STOPPED BY A RED GATE THAT IS NOT
  MINE.** Two failures, in order; the first is fixed, the second is the other
  session's live work and was deliberately left alone.

  1. **The Windows cross build stopped compiling** (it last succeeded 09-13
     02:38). `godot-cpp/src/godot.cpp` calls `realloc()`/`free()` but includes
     only `<stdio.h>`. glibc's libstdc++ drags `<stdlib.h>` in transitively, so
     the Linux build never noticed; llvm-mingw's libc++ does not, so the cross
     build died with *use of undeclared identifier 'realloc'*. It appeared now
     because the checkout was re-vendored 09-13 20:00, AFTER the last good
     package. FIXED in `tools/vendor_godot_cpp.sh`, not in the checkout: the
     vendored tree is untracked and re-clonable, so a working-tree-only patch is
     lost on the next vendor. The script grew an idempotent `patch_godot_cpp()`
     that runs on BOTH paths (fresh clone and already-vendored) and is the place
     every future upstream carry-patch goes. Verified: re-running it twice leaves
     exactly one `#include <stdlib.h>`, and `sim/build-codex-windows` now reaches
     100% with 0 errors (dh-server.exe, dh-effect-lab.exe, libdhgodot...dll).

  2. **Then the exported Linux smoke failed:** *"exported R press did not heal
     immediately"*. This is the OTHER SESSION'S in-flight Flask work (this
     roadmap's own R34/R35 checkpoint: *"Replace it with real R/mouse events,
     exact total healing, full/empty/dead/recharge cases... 20% immediately and
     20% over two seconds"*). Their feature is GREEN — `flask_probe.tscn` prints
     *FLASK OK - real R/click, 20% now + 20% over 2s, exact budget, recharge
     never heals*. What is red is only their new gate in `game/tools/
     package_smoke.gd`: the new R-press block (lines ~66-79) was added BELOW the
     pre-existing line 52 `hunt.process_mode = Node.PROCESS_MODE_DISABLED`, and
     R is routed by `main.gd::_unhandled_input` -> `_use_flask()`. A disabled
     node gets no input callbacks, so `drink_flask()` is never reached.
     PROVEN, not guessed — a throwaway headless probe (written, run, deleted)
     sent the same synthetic R at both process modes:
         process_mode=0 (INHERIT)   _unhandled_input fired=true
         process_mode=4 (DISABLED)  _unhandled_input fired=false
     The rest of their chain already agrees with the new `player.gd`
     (0.4 + FLASK_IMMEDIATE 0.2 = 0.6; `_process_flask(5.0)` clamps elapsed to
     the 2 s burn for 0.8; 6 kills = FLASK_KILLS_PER_CHARGE restores charge 2 at
     unchanged HP), so this one line is the whole blocker.
     THE ONE-LINE FIX IS THEIRS TO MAKE, NOT MINE: the smoke already disables
     physics per node at lines 67-69, so line 52's blanket disable can move below
     the input assertions (or become `PROCESS_MODE_INHERIT` for that window).
     NOT APPLIED HERE — `package_smoke.gd` is shared-dirty and the other session
     is editing it right now; stomping a file mid-edit is the concurrent-session
     rule this repo already learned the hard way.
  EVERYTHING ELSE IN THE PIPELINE PASSED: app icon, content validation, Linux
  sim build + full ctest, the Windows cross build (after fix 1), the `game/`
  import pass, and the Linux export itself (the smoke runs INSIDE the exported
  PCK, so the export is sound). `builds/codex/*.zip` therefore still date from
  09-13 02:38 — no new zips were written, and none were claimed. The build tree
  is warm, so the rerun after that one line moves is minutes, not an hour.

- **Training console: the graph, TRAIN ALL tournaments, a benchmark browser, and
  a global rank — Ricardo, 2026-09-14 (latest+10):** *"to the trianing onsole:
  graph overflows from the rendered screen. Add tournament mode for the train all
  method, as well. Also, a better benchmark interface, filtered by creature"* and,
  mid-turn: *"and a global rank for the all vs all, where every model net compete
  for the top in a balance fight"*.
  Four items, in the order they arrived:
  1. **The fitness graph overflows.** MEASURED, not guessed
     (`game/arena/tests/console_layout_probe.tscn`, new): no container overflows
     at any canvas `_fit_window` can pick (800x450 through 1440x810) — the bug is
     the chart's own DRAWING. Two findings: (a) `_chart` is pinned at its 120 px
     minimum at EVERY canvas, because the PROGRESS column never asked for
     vertical fill, so ~100 logical px sit unused BELOW the strip while the plot
     is squeezed into 96 px of band; (b) `clip_contents` is false on both the
     chart and the strip and `draw_string` is not clipped to a Control's rect, so
     the x-tick row (baseline `b + 12`, plus descent) bleeds past the bottom edge
     — 1 px today, and unbounded the moment a tick range or a label grows.
     FIX: let the column fill, clip both canvases, keep the ticks inside the box,
     and make the probe a permanent gate so this cannot come back.
  2. **Tournament mode for TRAIN ALL.** `league tournament --all` already exists
     (`ml/training/tournament.py`, `aa35f2b`); the console's TRAIN ALL still goes
     through `tools/train_run.sh --all`, i.e. ES only. Wanted: the sweep runs the
     METHOD BRACKET per creature.
  3. **A better benchmark interface, filtered by creature.** Today VERSUS shows a
     flat `ml/data/benchmarks/` history with no filter, so a roster of creatures
     produces one undifferentiated list.
  4. **A global rank — all vs all, every net, balanced.** *"every model net
     compete for the top in a balance fight"*. `league round-robin` exists but
     fights only DEPLOYED policies, and across different builds — which ranks the
     CREATURE, not the net. A fair ranking needs the mirror: both sides on the
     SAME build so the only variable is the policy.
  **Item 1 DONE 2026-09-14.** The overflow is real and reproducible, and it is
  ONE canvas: **640x360**, the project default. `_fit_window` walks a candidate
  list from 1600x900 down to 960x540 and every entry needs `usable.size.y >= 636`
  — if none fits, the loop simply ENDED, leaving `content_scale_size` at the
  project default, a canvas 90 logical px shorter than the console's own content.
  There the chart collapsed to its floor and the strip, the gate verdict and the
  column bottom ran off the screen (measured: 6-9 px past the edge at every level
  of the tree). Fixes: `_fit_window` now always lands on a real canvas derived
  from the usable rect; the chart's floor drops 120 -> 64 so a short canvas costs
  the CHART height instead of pushing its neighbours off-screen; `clip_contents`
  goes on the chart and the strip (`draw_string` is not clipped to a Control's
  rect, and the x-tick row was already bleeding 1 px); the x-tick baseline is
  computed from the font's ascent/descent instead of a hard-coded `b + 12`; and
  the y-tick step is chosen from a ladder so a run whose shaping reaches -3 draws
  a readable axis instead of eighteen labels smeared through a 96 px band.
  Gate: `game/arena/tests/console_layout_probe.tscn` walks all 7 canvases x all 4
  tabs with a loaded 200-generation run and asserts (a) nothing visible leaves
  the canvas, (b) the chart absorbs every pixel the canvas grows by, (c) the tick
  text lands inside, (d) clipping is on. `CONSOLE LAYOUT OK`.
  **A correction worth recording:** the first version of this probe parented the
  console to a Node2D, which gives a Control no rect to anchor against, so the
  whole cockpit laid out at its content minimum and the probe "found" a chart
  stuck at 120 px on an 810 px canvas. I added a `size_flags_vertical` line to
  "fix" that, then A/B'd it and found it a no-op — the harness was the bug. The
  line was removed rather than left in with a wrong explanation.
  **Item 2 DONE 2026-09-14.** TRAIN ALL has a second gear. `tools/train_run.sh`
  gained `--tournament`: the same isolated run folder, the same `$DH_SERVING_DIR`
  isolation and the same per-key progress feed as the ES sweep, but each key goes
  through `ml/training/tournament.py` instead of `league train` + `league gate` —
  every method trains that creature, each is gated against the same
  pre-tournament pin, and the candidates fight best-of-N for the pin. New env
  knobs `METHODS` (es,ppo) `BEST_OF` (5) `BRACKET_EPISODES` (1) `GATE_EPISODES`
  (= EPISODES, 0 skips) `METHOD_TIMEOUT` `TEACHER`; the existing ES and PPO dials
  feed the bracket's es and ppo entrants, so one set of knobs drives everything.
  `--resume` is REFUSED on a tournament run rather than silently retraining: a
  method is a whole subprocess and the fight only means anything once every
  entrant finished, so there is no per-generation checkpoint to continue from.
  In the console it is one checkbox, `bracket`, next to `isolated run` / `GPU
  (PPO)`; ticked, TRAIN ALL reads `TRAIN ALL ⚔` and dispatches
  `--tournament --all`. The decision is a pure function (`_sweep_flags`) so the
  selftest checks the dispatch without launching a sweep: unticked it must be
  byte-for-byte the old command line, ticked it must carry `--tournament` plus
  the bracket knobs, and a single-creature TRAIN must never bracket (the
  TOURNAMENT button is that path — it needs a chosen matchup).
  Verified: `--tournament --key bog_golem` end to end into a throwaway run dir —
  bracket ran, pin moved, `summary.txt` and the verdict JSON written, `ml/serving`
  untouched. Gates: `CONSOLE SELFTEST OK`, `CONSOLE LAYOUT OK`.
  **Item 3 DONE 2026-09-14.** `ml/data/benchmarks/` holds TWO schemas and the
  history rendered both through the versus fields, so every bracket verdict read
  `? vs ?  0-0  ?` — the filter was the ask, but the wrong-schema rendering was
  the bigger bug. Now: `arena.versus.v1` and `arena.tournament.v1` each get their
  own row and their own detail panel (a bracket shows entrants, points, rounds,
  episode win rate and gate result, and whether the pin moved); the list filters
  by **creature** and by **kind** (everything / head to head / brackets), and the
  two compose. The creature dropdown is built FROM the folder with counts, not
  from the roster, so a key nothing was benchmarked against is never offered as a
  filter that shows nothing. A verdict's creatures are its bracket `key` plus
  either side's registry spec and arena build — that last part is what makes a
  native/scripted row filterable. A verdict with NO creature (older or hand-made)
  still appears under "all creatures" instead of vanishing, and the selftest
  asserts exactly that. Parsing is incremental (name + mtime) so a filter click
  re-reads nothing. Selecting a row puts that verdict in the panel above.
  Gates: `CONSOLE SELFTEST OK`, `CONSOLE LAYOUT OK`.
  **Item 4 DONE 2026-09-14.** New module `ml/training/ladder.py`, also reachable
  as `league ladder`, plus a RANK tab in the console. `league round-robin` was a
  STUB — it printed the deployed keys and returned — and even finished it would
  have ranked the CREATURE, because it fights across different builds. The
  ladder ranks the NET by removing the body from the comparison: (a) both sides
  play the SAME arena build, so the only variable is the policy — a bog_golem net
  driving a fen_boar is the point, not a mistake; (b) every pairing plays BOTH
  ORIENTATIONS with different seeds, because spawn position and the aim-noise
  stream are not symmetric between sides and a shared seed would make the second
  orientation the mirror of the first; (c) every entrant meets every other in
  every arena. Entrants: every registry net with exported weights (a GRU/squad
  net with no game_json is skipped with a reason, not a crash) plus native and
  scripted as the floor. Scoring: 3/1/0 per pairing, episode win rate, mean HP
  margin, and a Bradley-Terry strength fitted by MM iteration and printed on the
  Elo scale — order-independent, uses every episode rather than only who won a
  pairing, and survives a pair that never met. Every entrant carries half a win
  and half a loss against a phantom of average strength, or an unbeaten net has
  no finite maximum-likelihood rating and the whole column blows up.
  FIRST REAL RUN (4 entrants, bog_golem body, 12 matches, 7.2s):
      1. scripted                 9 pts  6-0-0  100%  hp +0.381  rating  287.0
      2. grave_shade v1           4 pts  3-0-3   50%  hp +0.107  rating    0.0
      3. gloam_wisp v1            4 pts  3-0-3   50%  hp +0.103  rating    0.0
      4. native                   0 pts  0-0-6    0%  hp -0.591  rating -287.0
  — the scripted baseline beats both trained nets in a body neither was trained
  for. That is a real finding about transfer, and exactly the question the
  ladder exists to ask. Worth a look before the next sweep, Ricardo.
  Gates: 14 tests in `ml/tests/test_ladder.py` (the fairness invariants first —
  same build both sides, both orientations, different seeds — then the table
  maths, the finite rating, jobs-independence and the refusals), 98 passed in
  `ml/tests`, `CONSOLE SELFTEST OK`, `CONSOLE LAYOUT OK` across all 5 tabs.
  STATUS: all four items of the 2026-09-14 console request are DONE.

- **Are the open branches finished enough to merge? — Ricardo, 2026-09-13
  (latest+9):** *"check whether current open branches are finished in their work
  to merge into main. It finished some sprite animations for the boss, but
  credits ended mid flight."*
  **ANSWERED. There is nothing to merge — the work is not on a branch.**
  - `codex/modern-pixel-content-engine` @ `d1dbc91` is an **ancestor of master**
    (0 commits ahead, master 15 ahead; merge-base == the branch tip). Its
    worktree `/tmp/dragon-heroes-codex-content-engine` is gone — /tmp was
    cleared — so git marks it `prunable`. Nothing was lost: everything on it is
    already in master.
  - `stash@{0}` "codex-icon-packaging-before-rebase" (2026-09-12) is **fully
    superseded**: `.gitignore` has `builds/codex`, `export_presets.cfg` has both
    the codex exe path and `application/icon`, and `package_codex.py` +
    `dragon-heroes.ico` are tracked. Safe to drop — Ricardo's call.
  - **The in-flight work is UNCOMMITTED in the master working tree**, which is
    why it looks like a branch and is not one. The boss sprite sheet is the
    bellwether v2 entry below: generated, rejected for missing alpha, cleanup
    never run.
  - Tree state at the time of the check: `content OK`, ctest 4/4, both console
    selftests OK, `POLICY PARITY OK` — and **one red test**, caused by the
    other session's provenance backfill, retargeted (see below).

- **Configurable net hyperparameters — Ricardo, 2026-09-13 (latest+8):** *"net
  hyperparams should be configurable, as to test new architectures."*
  `--hidden` landed with distillation; everything else about the architecture is
  still hard-coded: tanh on every hidden layer, `INIT_SCALE = 0.1`, and the
  optimiser knobs are a scatter of per-trainer flags. Wanted: an architecture
  that is one NAMED thing you can point every trainer at, and new ones that can
  actually be gated and shipped — which means the two runtimes must support them
  too. FOUR SURFACES, and a net is only real if all of them agree:
    1. `ml/training/policy_net.py` (numpy, ES + distill student)
    2. `ml/training/torch_policy.py` (PPO learner)
    3. `game/arena/neural_policy.gd` + `sim/libs/dh-godot` `DhPolicyNet` — these
       two must stay BIT-IDENTICAL or every trained weight is invalidated
    4. `sim/libs/dh-sim` `Arena::mlp_act` — PPO's frozen self-play opponent,
       which hard-codes tanh for hidden layers today
  **DONE 2026-09-13.** `ml/training/arch.py` + `ml/training/architectures.json`:
  one `Arch` (hidden / activation / init / init_scale), named presets, and the
  SAME five flags on every trainer — `--net --hidden --activation --init
  --init-scale` on `league train`, `ppo`, `distill` and `tournament`, plus
  `NET=` on `tools/train_run.sh` and a **net** row in the arena console read
  straight from `architectures.json`. Presets shipped: `default` (64,64 tanh,
  7,744 MACs — what ships), `tiny`, `relu`, `wide`, `relu-wide`, `deep`.
  All four surfaces landed:
    1. `PolicyNet(arch=)`, forward/save/load/export carry the activation; a net
       saved before `arch` existed still loads as tanh.
    2. `TorchPolicyNet(arch=)` — trunk activation + he/xavier init; the exporter
       now writes `"linear"` instead of `"logits"` for the folded head.
    3. `DhPolicyNet::add_layer` takes an activation CODE (0 linear, 1 tanh,
       2 relu, 3 leaky_relu) instead of a bool — numbered so an old
       `true`/`false` still means what it meant — and `neural_policy.gd`
       branches on the same code in its hot loop.
    4. `Arena::set_opp_mlp` gains an optional `acts` array, reached through a
       NEW C symbol `dh_env_set_opp_weights_acts` rather than a sixth argument
       on the old one: ctypes against a stale `.so` would have read a register
       nobody set, and "the self-play opponent quietly ran the wrong policy" is
       invisible in every metric PPO prints. A missing symbol is not.
  **The activation set is deliberately four.** Surfaces 3a and 3b must agree
  BIT FOR BIT; `max(0,x)` and a hard-coded 0.01 leaky slope do, `gelu`/`silu`
  would need an erf/exp equivalence proof nobody has written.
  **A regression this nearly caused:** the strict activation check would have
  REFUSED `cinder_drake_ppo_v2..v5`, which carry `act: "logits"` from the old
  exporter. Kept as a read-side alias for linear, everywhere.
  Gates: `POLICY PARITY OK — 256 forward passes matched bit-for-bit across
  linear, tanh, relu, leaky_relu` (new,
  `game/arena/tests/policy_parity_test.tscn`); `ml/tests/test_arch.py` 28 tests
  including a per-activation finite-difference check of the student's backward
  pass and a real `libdh-env` episode proving the frozen opponent runs the
  activation it was handed (and that no-acts still reproduces tanh exactly);
  `CONSOLE SELFTEST OK` with the NET row asserted to read the real JSON and to
  pass NO `NET=` for `default`; ctest 4/4. End-to-end: a relu net trained
  through the real Godot arena (`--net relu` → `['relu','relu','linear']` on
  disk).
  **STILL OPEN:** the GRU stack keeps its fixed shape (`--net` is mlp-only, and
  `ppo` says so); no wide teacher has been TRAINED yet — that is Ricardo's GPU
  run and the real test of whether width beats ES.

- **An asset generation console — Ricardo, 2026-09-13 (latest+7):** *"And how
  about the asset generation console?"* — asked right after `tools/genforge.py`
  landed as a CLI. He wants the content pipeline to have the cockpit the arena
  has: a scene you open, not commands you remember. Shape it mirrors:
  `game/arena/console.tscn` (PACKS list, per-art provenance/clip status, CHECK /
  CREATE / BUILD / APPROVE / REJECT, and a button that opens the bundle's
  `index.html` review page). The seam is the same one the training console uses:
  the GUI shells out to the python tool and reads STRUCTURED output, so the logic
  lives in one place — hence `tools/genforge.py --json` first, then the scene.
  **DONE 2026-09-13, commit `f3c866f`.** `game/genforge/console.tscn`, reachable
  from the title menu's GENFORGE button (MENU OK — 13 buttons) or standalone.
  Packs with approval state on the left; on the right the pack verdict, one ART
  row per asset (provenance verified? clips complete?), every finding coloured,
  and CHECK / BUILD / REVIEW (opens the bundle's index.html) / APPROVE / REJECT /
  CREATE. It shells out to `tools/genforge.py --json` (new `audit_data` /
  `list_data` seam) and renders the answer — the GUI never re-implements the
  rules, so it cannot call an asset fine when the CI gate fails it. Gate:
  `GENFORGE CONSOLE SELFTEST OK — 1 pack(s), fen_bells: 14 finding(s) rendered
  (2 failing), 1 art row(s), review page present`; the selftest asserts the live
  catalog STILL fails on bellwether.

- **Teacher/student distillation — Ricardo, 2026-09-13 (latest+6):** *"Let's
  train bigger models and use them to distill smaller ones, as to use the smaller
  nets in the actual games and the big ones to act as their teachers once they
  surpass the default script/engine behaviour!"*
  Three parts, and the third is the condition he attached:
  1. **Bigger nets.** `HIDDEN = (64, 64)` is hard-coded in
     `ml/training/policy_net.py`. Teachers need width as a parameter, recorded in
     the exported `arena.policy.v1` so a net says how big it is.
  2. **Distillation.** A small student (the shipping 64x64) learns to reproduce a
     wide teacher's head on observations from real play, then gates in Godot the
     normal way. The student is what deploys — teachers never ship.
  3. **THE TEACHING GATE (his condition): a teacher may only teach once it
     SURPASSES the default script/engine behaviour.** That is executable with
     the pieces already here: `versus` against `native` and `scripted` in the
     real arena. A teacher that cannot beat the built-in AI has nothing to
     teach, and distilling from it would actively make the student worse.
  WHY IT IS WORTH IT (the numbers from the glitchiness answer): the runtime cost
  is ~105 us/tick in C++ at 7,744 MACs; a 256x256 teacher is 80,128 MACs,
  ~1.09 ms/tick, and fifteen of those eat a whole 60 FPS frame. So a wide net can
  never ship — but it can train, and it can teach.
  **DONE 2026-09-13, commit `f3c866f`.**
  1. **Width is a parameter.** `PolicyNet(hidden=)`, npz reads its depth from the
     FILE (older nets fall back to counting w-keys — the same shape), the export
     declares `hidden` + `macs`, and `league train --hidden` / `ppo --hidden`
     take it. A width change refuses to warm-start from a different shape rather
     than silently training the old one.
  2. **`ml/training/distill.py`** — qualify -> DAgger collect -> KD fit -> gate.
     Round 0 drives with the teacher, later rounds drive with the STUDENT and the
     teacher only labels. Loss matched to what the runtime reads: MSE on move,
     softened CE on the action logits (argmaxed at runtime, so ranking is what
     matters), BCE on dodge. numpy + Adam, no venv needed. libdh-env rollouts at
     150-270k samples/s. **Measured 94.6% action agreement**, and the DAgger
     round is what took it from 92.7 to 94.6.
  3. **The teaching gate is enforced**: `versus` vs BOTH baselines in the real
     arena, `--qualify-margin` 0.55, fail -> nothing distilled, exit 1.
  Also `distill` is a tournament method (`--methods es,ppo,distill --teacher`).
  **A C++ BUG FOUND ON THE WAY:** dh-sim's frozen-opponent MLP forwarded through
  `float buf[96]` with no width check — PPO self-play with a 256-wide teacher
  would have smashed the stack. `Arena::set_opp_mlp` now refuses layers wider
  than `kMlpMaxUnits` (512) and the buffers are sized by that constant. ctest 4/4.
  **STILL OPEN:** PPO's GRU stack keeps the fixed shape (`--hidden` is mlp only);
  no wide teacher has actually been TRAINED yet — that is a GPU run for Ricardo
  to launch, and it is the real test of whether a big teacher outclasses ES.

- **A content approval/creation interface + a usable pipeline doc — Ricardo,
  2026-09-13 (latest+5):** *"create an interface to approve/check/create new
  content! Also further document the pipeline so it's usable by me!"* (said while
  confirming the asset-pipeline findings: *"I'll send your critiques directly to
  the other agent, you got some REAL mistakes, well done!"*).
  The genforge pipeline now has provenance and a cleanup/rejection stage, but no
  human-facing surface: approving a candidate, checking one against its
  provenance, and kicking off a new one are all ad-hoc python. Wanted:
  1. **An interface — DONE 2026-09-13, commit `f2e34de`.** `tools/genforge.py`:
     `list | check | create | build | show | approve | reject`. `check` is
     written backwards from the bellwether failure — a missing
     `provenance-v1.json`, a recorded `sha256` that does not match the file, a
     `prompt_sha256` that does not match the prompt, and a bake short of its
     `required_clips` are all FAILURES, not warnings. Run live it reproduces
     exactly the two bellwether gaps. Approval is pinned to the bundle's
     `content_hash` AND its manifest digest, stored in
     `genforge/approvals/<hash>.json` (never inside the immutable bundle), with
     every still-open blocker copied into the record. READY needs both halves
     clean. Nothing writes to `content/drops/` — promotion stays deliberate.
     14 tests.
  2. **Documentation — DONE, same commit.** `docs/USAGE.md` §7 is now the
     pipeline in order: release -> art source (and exactly what a source folder
     must contain) -> bake -> browser review page -> approve/reject.

- **Land the JOBS cap, a default-AI control in the console, and "can a PPO net
  make the game glitchy?" — Ricardo, 2026-09-13 (latest+4):** *"let's fix that,
  please!"* / *"make sure to add an option to the arena console/training
  interface to set new game default ais!"* / *"how can the PPO net get too heavy
  as to get the game to be glitchy?"*
  1. **JOBS cap — DONE 2026-09-13, `aa35f2b`.** Ricardo overrode the collision
     flag. `min(nproc -
     4, 16)` replaces `min(nproc/2, 4)` in `tools/train_run.sh` and the console's
     jobs spinbox. Both files are dirty with the other session's work, so the
     edit lands in the working tree and only MY hunks are staged (the
     split-the-diff-and-`git apply --cached` method already used for
     `docs/USAGE.md`). STATUS: doing.
  2. **Console: set the game's default AI — DONE 2026-09-13, `aa35f2b`.** The
     NETS tab already moved the deployed pin; what was missing was anything that
     read that pin as "the default" — every match had to be told `--policy-a`
     explicitly. Now `--policy-a default` resolves through
     `game/arena/data/ai_defaults.json` (`mode` + `per_build` overrides +
     `fallback`), `game/arena/ai_defaults.gd` resolves it, `fighter.gd` honours
     it, and the console writes it from NETS -> DEFAULT AI (SET FOR ALL / SET
     FOR BUILD / CLEAR BUILD). Nets come from `res://arena/data/nets/<key>.json`
     in an exported game, or the registry pin in a dev tree.
  3. **"How can the PPO net get too heavy as to get the game to be glitchy?" —
     ANSWERED 2026-09-13.** Not by training. The runtime contract
     (`arena.policy.v1`) fixes the shape at 47 -> 64 -> 64 -> 10 = **7,744 MACs**,
     so 2M steps and 200M steps export the identical net. Measured cost of one
     forward pass, run once per agent per physics tick: **566 us GDScript, 105 us
     C++** (`DhPolicyNet`). The 60 FPS frame is 16,670 us. Four real risks:
     (a) **agent count** — 29 neural agents saturate a frame in GDScript, 158 in
     C++, and that is before rendering and physics, so realistically ~8-14 vs
     ~40-60; at the canon 30 Hz sim rate both double;
     (b) **a widened net** — `HIDDEN = (64, 64)` in `ml/training/policy_net.py`;
     (256,256) is 80,128 MACs, 10.3x, ~1.09 ms per agent per tick in C++, and
     fifteen agents eat the whole frame;
     (c) **`--arch gru` / squad nets** export no `game_json` at all — the Godot
     runtime is a stateless 31-obs MLP — so they cannot be pinned (the tournament
     reports them as "no-candidate"); and
     (d) **a net that fails to load** (obs_dim mismatch after an OBS_DIM change)
     leaves `_layers` empty, `_act` returns immediately, and the creature stands
     still — a behaviour glitch, not a frame glitch, and the one to watch for.
     Also per agent per tick: `_obs_log` appends a 31-float observation into a
     24-entry ring, so allocation churn scales with agent count too.

  CURRENT STRATEGY AT THIS INTERRUPTION: the method tournament is designed and
  half-read (see the entry above); it lands as a NEW module
  `ml/training/tournament.py` plus a thin `tournament` subcommand in
  `league.py`, because `tools/train_run.sh` belongs to the other session. Order
  of work now: (1) JOBS cap, (2) console default-AI control, (3) the PPO answer,
  (4) finish the tournament, (5) the codex/launcher icon parity audit.

- **Build the method tournament + a desktop launcher parity audit — Ricardo,
  2026-09-13 (latest+3):** *"methods competing head-to-head per key during TRAIN
  ALL ... work on that!"* and *"create an execution icon binary as the rest. What
  is the difference in codex build code and yours? Don't alter, but investigate
  as to get yours up-to-date (we even have custom icons)"*.
  1. **Method tournament — DONE 2026-09-13, commit `aa35f2b`.**
     `ml/training/tournament.py` (+ a `tournament` subcommand on league, + the
     console's TOURNAMENT button). Every method trains the key, every candidate
     is gated against the SAME pre-tournament pin (the pin is snapshotted and
     restored around each gate call — otherwise gating ES first makes ES the
     yardstick for PPO), the candidates fight best-of-N in the real arena, and
     the winner takes the pin. CHAMPION (won the bracket) and WINNER (won it AND
     passed the gate) are reported separately; only a winner moves the pin.
     Verdicts are `arena.tournament.v1` in `ml/data/benchmarks/`. `evolve` is
     not an entrant — it registers under derived keys, so its champion goes in
     through `--extra`, which also takes `scripted`/paths/registry refs as
     reference points that can win the bracket but never the pin. 16 tests.
  2. **Launcher/icon parity — DONE 2026-09-13, `aa35f2b`.** Neither file was
     altered; both were read. THE DIFFERENCE: `tools/package_codex.py` is a full
     distribution pipeline — it renders the icon (`build_app_icon.py`),
     validates content, builds and ctests `sim/`, cross-compiles the Windows
     helper, imports, exports BOTH platforms, verifies the export against
     `game/branding/dragon-heroes.ico` (`verify_package.py`), smoke-runs the
     Linux build, stages the offline content review, writes a `BUILD-INFO.json`
     manifest with a sha256 per file, zips it and CRC-checks the zip, and ships
     `install-launcher.py` so the first launch registers a `.desktop` entry.
     `tools/build_arena.sh` did one thing: export the trainer and probe it.
     Linux exports carry no embedded icon (only preset.0/Windows sets
     `application/icon`) — on Linux the icon IS the `.desktop` entry, which the
     codex build had and the cockpit did not. NOW IT DOES: preset.3 "Arena
     Console (Linux)" + `run/main_scene.console` export the cockpit as its own
     binary, `tools/build_console.sh` verifies it reaches CONSOLE SELFTEST OK
     without opening a window, and `tools/install_console_launcher.py` registers
     "Dragon Heroes — Arena Console" with the Dragon Heroes icon. VERIFIED: 92M
     binary built, selftest OK from the binary, entry + icon installed under
     ~/.local/share. STILL MISSING vs codex (deliberate, it is a dev tool): no
     zip, no BUILD-INFO manifest, no Windows export, no content staging.
  - **EXTENDED 2026-09-13 (Ricardo ran `game/genforge/console.tscn` from bash:
    "Permissão negada / yooo wtf").** A `.tscn` is data, not a program — so the
    GenForge console got the same treatment: preset.4 "Genforge Console (Linux)"
    + `custom_features="genforge"` + `run/main_scene.genforge`, and the launcher
    became `tools/install_console_launcher.py arena|genforge|all` over a TARGETS
    table. `tools/build_console.sh [arena|genforge|all]` loops both with their
    own selftest sentinels.
  - **BUG THE APP BUILD EXPOSED — repo discovery.** Both cockpits shell out to
    the repo's python, and both resolved the repo as
    `globalize_path("res://..")`. In the editor `res://` IS `game/`, so that is
    right; in an exported binary `res://` is the PCK next to the executable, so
    `res://..` is `builds/` — the first GenForge app booted the right scene and
    reported "genforge.py list returned no packs". Fixed with
    `game/tools/repo_root.gd` (`DhRepoRoot`): `$DH_REPO`, else `res://..`, else
    climb from the executable, each candidate checked against sentinels
    (`docs/00-canon.md` + `tools/genforge.py`) rather than a guessed path shape.
    The arena console had the SAME latent bug — its selftest runs on `user://`
    fixtures, so it passed while a real TRAIN from the installed app would have
    written into `builds/`. Both now guard on `_repo == ""` and say what to do.
    VERIFIED: both 92M binaries reach their sentinels, and the GenForge app
    audits the real pack when launched from `/tmp`.

- **Asset pipeline: did it get stepped up, and was the dungeon boss made with
  it? — Ricardo, 2026-09-13 (latest+2):** *"did our asset generation pipeline
  got stepped up in the other sessions? We have an asset who's our new-role
  model as the dungeon boss, but perhaps it wasn't made using our asset
  generator pipeline."*
  **ANSWERED. Yes, it was stepped up — and no, the boss is not fully covered.**
  - **Stepped up:** `hunter-renewal` (other session, 2026-09-13) introduced
    versioned **`provenance-v1.json`** plus a **cleanup/rejection stage**
    (`cleanup-prompt.txt`, `cleanup-rejection.json`) — a generated image can now
    be rejected and re-cleaned with the rejection reason recorded.
  - **Covered:** `app_icon` and `haven-renewal` both carry `provenance.json`
    with `sha256` + `prompt_sha256`.
  - **NOT covered — the dungeon boss.** `bellwether` (the Gloamfen Bellwether /
    "Orun", `fen_bells.art.bellwether`) has **NO provenance file and no sha256
    anywhere**. It DID go through the generator — there is a `prompt.txt`, a
    `source.png`, and a release record in `genforge/releases/bell_beneath_fen.json`
    naming both, with `provider: "built-in image_gen; model identity not
    exposed"` — but the image cannot be verified against its prompt, so it is
    unreproducible and unauditable by the current rules.
  - **Second gap:** bellwether has only **`idle` of 6 `required_clips`**
    (`idle, move, anticipation, attack, hit, death`). As the role model for
    dungeon bosses it is 1/6 animated.
  - **RESOLVED both ways by the other session, 2026-09-13 — and the second half
    is MID-FLIGHT.** It backfilled AND regenerated:
    - `provenance-v1.json` hashes the legacy `source.png` as a
      `retrospective-integrity-record`, `generation_verified: false`, status
      "legacy idle-only reference; missing action clips; not production-approved".
      Verified independently: sha256 matches, and `check_art` now passes.
    - `source-v2.png` + `prompt-v2.txt` + `provenance-v2.json` are a NEW
      generation: 1024×1536, **4 columns × 6 rows = 24 frames**, one row per
      required clip, `generation_verified: true`, with a `references` entry
      pointing back at v1 for identity. Verified: both sha256s match, and the
      sheet visibly carries idle / move / rear / attack / hit / death.
    - **BUT v2 IS REJECTED** (`cleanup-rejection-v2.json`): the model painted a
      grey-and-white checkerboard INTO the RGB pixels instead of writing alpha.
      Confirmed independently — `source-v2.png` is mode RGB, no alpha channel at
      all (v1 is RGBA). `cleanup-prompt-v2.txt` is written and was never run.
  - **WHAT IS LEFT (in order):** re-clean v2 to a real transparent RGBA cutout →
    point `genforge/releases/bell_beneath_fen.json` at `source-v2.png`, change
    `grid` from `[4, 2]` to `[4, 6]` and define the six clips (frames 0-3, 4-7,
    8-11, 12-15, 16-19, 20-23) → `tools/genforge.py build fen_bells` → review →
    approve. The live gate still reads **1/6 clips**, because the release still
    names v1; nothing downstream knows v2 exists.
  - **A GATE FIRED ON THIS, correctly:**
    `test_the_live_audit_still_catches_the_dungeon_boss` went red the moment the
    provenance backfill landed — it was asserting the PROVENANCE gap, which is
    now genuinely closed. Retargeted at the remaining animation gap (and now
    audits against the built bundle, the way the CLI does) rather than deleted.

- **GPU physics, the persistent worker, and 60 Hz — Ricardo, 2026-09-13
  (latest): "but can't we use the gpu to calculate the physics math in the
  engine? some cuda stuff or smth" / "[persistent worker] ---> do it!" / "keep
  at 60hz as to be fully capable".**
  **60 Hz: DECIDED, keep it.** Ricardo: "as to be fully capable". The arena
  stays at 60 Hz even though canon's sim target is 30 — the extra resolution is
  deliberate, and no trained net or gate band needs revisiting. Closed; do not
  reopen this as an optimisation.
  **GPU physics: no, and the premise is worth correcting.** Godot's 2D physics
  is CPU-only; there is no CUDA backend to switch on, and writing one is an
  engine project, not a setting. More to the point, physics is not the cost:
  the profile puts the GDScript forward pass at ~93% of the tick and EVERYTHING
  else — physics, projectiles, fields, node processing — at ~7%. Taking physics
  to zero buys 7%. And the shape is wrong for a GPU regardless: a GPU wins on
  throughput (thousands of independent items in one launch), not latency. One
  match has two fighters and a handful of projectiles; a kernel launch costs
  ~5-10 us against a ~250-380 us step of branchy, data-dependent scalar logic,
  so the transfers would cost more than the math. The GPU-shaped version of
  this problem is "simulate ten thousand fights at once", which is exactly
  `libdh-env` + PPO — already built, already on the GPU at 56k steps/s. The
  right next step for the GODOT arena is C++ (`dh-godot`), not CUDA.
  **LANDED — the persistent arena worker.** `--serve` keeps one engine alive
  and takes matchups as JSON on stdin, answering `ARENA SERVE DONE <path>`;
  `league.py` holds a pool of them, one per job, booted once per RUN instead of
  once per match. Measured steady state (idle box, pop 10, 13 episodes, 2
  opponents, jobs 10, all including the flat-MLP fix):

  | configuration | s/generation | speedup |
  |---|---|---|
  | editor binary, one engine per match (the old way) | 13.0 | 1.00x |
  | editor binary + resident workers | 9.3 | 1.39x |
  | release export, one engine per match | 9.5 | 1.36x |
  | release export + resident workers | 7.1 | **1.83x** |

  All four produce identical scores. For a 1000-generation key that is 3.6 h ->
  2.0 h. Correctness gates: a served match must equal a fresh process, checked
  with the same matchup sent FIRST and LAST in a batch so state leaking across
  matches would show as order dependence. `DH_ARENA_POOL=0` disables it.
  **Two bugs worth remembering**, both found by running the thing rather than
  reasoning about it: (a) `OS.read_string_from_stdin()` is line-oriented and
  strips the newline, so waiting for a `"\n"` hangs on the first request;
  (b) Godot flushes stdout per print in DEBUG builds but NOT in release, so a
  release trainer's `ARENA SERVE READY` sat in the C buffer and every worker
  timed out — fixed with `run/flush_stdout_on_print=true`. The build script's
  first serve check missed (b) because it read stdout from a FILE after exit;
  it now probes through the real pool class over a live pipe.

- **Arena throughput — Ricardo, 2026-09-13 (later): "1) can't we load the
  engine just once and run all episodes? 2) can't we accelerate the 60 physics
  tick/s to just process all the ticks capped by our processing power? 3) how
  can we optimize the godot arena? i noticed my gpu is VERY subutilised, so we
  could run stuff much faster, even running all keys in parallel if needed".**
  Answered with measurements rather than guesses; two fixes landed, the rest is
  a ranked backlog below.
  **(1) Already true per match** — `run_match` passes `--episodes N` to ONE
  Godot process, so the engine loads once per match, not once per episode.
  Measured fixed startup: 4.01 s (editor binary) / 2.53 s (release export).
  What is NOT amortised is startup ACROSS matches: 20 matches per generation
  means ~80 s of pure engine boot per generation. A persistent arena worker
  (Godot boots once, reads matchups on stdin) would reclaim it — see backlog.
  **(2) Already CPU-bound** — `--speed max` sets `--fixed-fps 60`,
  `Engine.max_fps = 0` and `low_processor_usage_mode_sleep_usec = 0`, so the
  engine advances one 1/60 s tick per frame as fast as one core allows and
  never sleeps. 60 Hz is the sim RESOLUTION, not a wall-clock rate. The lever
  that remains is making each tick cheaper, and lowering the resolution —
  canon §: "Simulation: fixed-tick 30 Hz", but the ARENA runs at 60. Matching
  canon would halve the work. NOT done unilaterally: it changes dodge windows
  and projectile stepping, so every trained net and gate band would need
  revisiting. **Ricardo's call.**
  **(3) The GPU cannot help and the box is already saturated.** A `--headless`
  Godot draws nothing, so the arena never touches the GPU — the 4050 is idle in
  training because there is no rendering to do, not because we are leaving
  throughput on the table. The GPU tier is PPO over `libdh-env` (56k steps/s),
  which is a different path entirely. On "run all keys in parallel": the answer
  is still no, but the FIRST reasoning was wrong and is corrected here. I read
  load average 23-24 on 10 physical cores as oversubscription; measured on an
  idle box afterwards, `--jobs` does not plateau until 16 and `jobs=20` is
  exactly as fast as `jobs=16` (6.4 s/gen, vs 7.1 at jobs=10 and 9.6 at
  jobs=4). Hyperthreading earns its keep here. The real reason parallel keys buy
  nothing is throughput, not contention: a generation IS 20 matches, and one key
  at `jobs=20` already saturates the box at ~3.1 matches/s. Two keys at
  `jobs=10` each run the same 40 matches through the same pipe in the same
  total time. Parallel keys redistribute throughput; they do not add any.
  **LANDED — the arena was not reproducible at all.** Godot randomises the
  GLOBAL random stream at startup (proved: three runs, three different first
  `randf()` draws). `arena.gd` seeded its own `_rng` but never that one, and
  gameplay draws from it — `creature.gd` wander, `hag.gd` retreat,
  `projectile.gd` volley desync. So the same `--seed` produced different fights
  every run: dusk_revenant vs gloam_wisp on seed 77 gave dmg_b [0,0,0],
  [0,88.6,0] and [0,112,0] across three identical runs. Winners were stable, so
  it hid from every win-rate check, but fitness is `win_rate + 0.1*(own_hp -
  foe_hp)` — the hp term was partly luck. Measured fitness sd over 4 identical
  runs: **0.0037 before, 0.0000 after**, against a within-generation candidate
  sd of 0.0350 — so ~11% of what ES was ranking on was noise. Fixed by seeding
  the global stream per EPISODE in `_start_episode`.
  **LANDED — the GDScript MLP was 93% of the arena tick.** Measured by
  two-point slope (startup cancels): native vs native ~250-380 us/tick, neural
  vs neural ~4,740-4,950 us/tick; one neural side costs ~2,200 us/tick for a
  47-64-64-10 forward pass (7,744 MACs). `_forward` held weights as an Array of
  Arrays and did `float(row[j]) * float(out[j])` — every element through a
  Variant. Flattened to `PackedFloat64Array` indexed `o * n_in + j`: **1.74x
  faster, fights bit-identical** (the exported weights are float32-exact and
  the accumulator was always a GDScript float, so the numbers do not move).
  **BACKLOG, ranked by measured payoff:**
  1. **Move the forward pass to C++.** Even flattened it is ~3,100 us/tick —
     about 400 ns per multiply-add, ~1000x off what C does. This is the single
     biggest remaining win (~10x on the whole tick). Blocked on `dh-godot`,
     which is currently only a README: the GDExtension is not built or wired
     into `game/`. That is the real project behind this number.
  2. **Persistent arena worker** — boot Godot once per job, feed matchups over
     stdin. Reclaims ~80 s per generation of engine boot (~5-20% depending on
     episode length).
  3. **Release trainer export** — `game/export_presets.cfg` "Arena Trainer
     (Linux)" plus a feature-tagged `run/main_scene.trainer`, because a RELEASE
     template refuses a scene path on the command line. Verified bit-identical
     to the editor binary. Honest payoff: startup 4.01 s -> 2.53 s, and near
     nothing per tick while the GDScript MLP dominates — but 1.5 s x 20 matches
     x 1000 generations is ~8 h per key, so it pays for itself. Becomes a much
     bigger win once (1) lands.
  4. ~~Tune `JOBS` to physical cores~~ — **MEASURED and rejected.** On an idle
     box: jobs 4 -> 9.6 s/gen, 8 -> 7.4, 10 -> 7.1, 12 -> 7.0, 16 -> 6.4,
     20 -> 6.4. `JOBS=$(nproc)` was right all along. Note the other session is
     adding `TRAIN_PROFILE=desktop` to cap jobs at half the CPUs — that is a
     deliberate trade of ~11-16% training throughput for desktop
     responsiveness, not a fix for oversubscription.

- **Why a Godot episode is slow — measured, 2026-09-13 (Ricardo: "what is it
  about episodes that take them so long? won't they be only calculated
  computationally? we don't need to render images").** It is not rendering:
  `--headless` draws nothing. An episode simulates ~28.5 in-game seconds at 60
  physics ticks/s, so ~1,700 frames of GDScript `_physics_process` across every
  arena node, in a freshly booted engine process. Measured one-at-a-time on a
  loaded box: 1 episode 4.07 s, 4 episodes 7.74 s, 13 episodes 16.58 s — a
  straight line of ~3.0 s fixed engine startup per match plus ~1.04 s per
  episode. The live sweep sees ~86 s per 13-episode match because `--jobs 20`
  runs 20 engines on 20 cores. Same box, same moment: the Godot arena runs
  27.5x real time, `libdh-env` runs 6,076x — **~220x apart**. Written up in
  tech/37 §5. The standing consequence: the GATE must stay in Godot (it is the
  deployment environment), but the SEARCH does not have to — that is the case
  for moving ES onto dh-env the way PPO already is.

## PICK — the order-of-magnitude levers (design/24 §2; Ricardo's call)

L1 data-driven AI profiles for the 1000-species bestiary (arena `bot_drive`
seam is the executor socket) · L2 run structure (in-run boon picks, night-fall
escalation) · L3 bosses as system-play (generalize field combos) · L4 pets as
a second build axis (rolled skills never cast today) · L5 the dh-sim C++ port
(server authority + 100× RL throughput — the strategic one) · L6 Radiance
Cascades (below) · L7 reactive audio layer.

## SCHEDULED — visual program (design/19 catalog, canon §12.30)

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

## SCHEDULED — multiplayer arc (design/21)

M-A co-op on the infinite world, server-authoritative (Nakama + dh-net; the
streaming window IS the AOI) — P2P v1 is the friends/LAN stopgap → M-B PVP
(duels → arenas → tournaments; formats in design/16) → M-C the combat/skill
overhaul PVP requires (deterministic sim-side hitboxes, skill archetypes as
data, build identity, rollback-vs-delay open question). L5 is the
prerequisite for M-A proper.

## SCHEDULED — platforms

Android: export walkthrough exists (tech/30); needs touch controls (virtual
stick) + an on-device 60 FPS profiling pass before it is "playable on a
phone". Desktop packaging exists (`tools/package_game.sh`); Windows needs a
mingw `dh-server.exe`.

## BUDGET — re-enable when money allows (canon §12.38, "use full quality
## when budget is sufficient")

- **Cloud Run GPU mesh tier** (tech/31 §7): the PREFERRED full-quality
  image-to-3D path (TRELLIS / Hunyuan3D full on nvidia-l4). Parked code is
  intact and guarded; re-enable checklist in
  `genforge/service/mesh_cloudrun/PARKED.md`.
- Any cloud training for the arena league (tech/32 scales locally today).

## Polish backlog (design/24 §3 — do anytime, small)

- **DONE — Hunt exit-time RID leak (found 2026-09-13 while verifying the command
  ledger).** `godot --headless --path game res://prototype/main.tscn
  --quit-after 150` ends with 5 `RID allocations … were leaked at exit` lines
  (MultiMesh + Mesh + Material + Shader + `1 resources still in use`) on
  roughly one run in four; the other three are clean and no other scene does
  it. Fixed by freeing unfinished off-tree water MMIs in world_gen._exit_tree.
  Ground-state gate forces that exact lifetime; 12/12 verbose real Hunt exits pass
  tools/check_hunt_exit.py. Historical symptom retained here; R32 is complete.

Pet rolled skills executing (L4), pre-death meteors vs telegraph beams, bolts
through walls, Spirit Essence stack pickup, hitstop scene-time, HUD buff
icons, pet HP chips, DoT number aggregation, sell confirmation, panel pause,
boss bar persistence, telegraph shapes, respawn-near-fight, first-time toasts,
mount dismount lockout, HUD stats → icon chips, skill-bar label clipping.

## Demand ledger (2026-09-12 — the roadmap rule, AGENTS.md/CLAUDE.md)

Every new ask lands here the moment it arrives; work oldest NOW first.

### NOW (in flight)
1. ~~Ember Flask heal~~ DONE 2026-09-12 (gate FLASK OK): R drinks (40% HoT
   /2s, 0.8s commitment slow), 2 charges, 6 kills rekindle (fed from
   on_creature_died, covers bosses), haven refills, ember HUD pips with
   kill-counter fill, EN/PT hints. Probe: prototype/tests/flask_probe.tscn.
2. ~~Hordes don't keep spawning + always the same mobs~~ DONE 2026-09-12
   (gate REPOP OK): continuous spawn pressure every 18 s (floor 10 living
   within 45 tiles -> 1-2 packs prowl in from 30-45 tiles off-screen, cap
   120), pack mixing 0.25->0.45, half the free packs prowl with 1-2 wisps.
   Probe: prototype/tests/repop_probe.tscn.
2b. ~~Strategic horde presets~~ DONE 2026-09-12: game/prototype/data/
   hordes.json — 5 curated synergies (Conductors = mire+storm DETONATE,
   Pincer, Burning Ground, Grave Procession, Alpha Hunt elite-led); repop
   picks 60% preset / 40% free-mixed; species resolve against the hunt
   roster with graceful substitution. RULE: new creature = synergy review +
   preset entry (or a retirement) at content time.
2c. **Synergy review IN the asset pipeline** (Ricardo: new creature ->
   synergy review + horde preset) — standalone reviewer tool + checklist doc;
   DO NOT touch genforge/pipeline/* (other agent redesigning it).
2d. **Biome variation + biome-bound creatures** (Ricardo question) —
   investigate whether streamed chunks vary biomes and whether spawn rosters
   are biome-filtered; implement if absent (design/12: 5 biomes).
4b. **HUD order-of-magnitude** (Ricardo: "plain colored squares, no
   personality; skills have no icons, no cooldown countdown") — framed HP orb/
   bar w/ ghost damage, styled charge pips, REAL skill icons + radial cooldown
   sweep + numeric countdown. Pixel doctrine, bounded draw calls.
3. **Skills-screen text clutter/capping** (design/polish; Ricardo) — the
   character panel pins a FIXED 92px detail card; text clipped/capped.
   Investigate autowrap/min-size; declutter panels (OPTIONS screen was step 1).
2b. ~~Strategic horde presets~~ DONE 2026-09-12: game/prototype/data/
   hordes.json — 5 curated synergies (Conductors = mire+storm DETONATE,
   Pincer, Burning Ground, Grave Procession, Alpha Hunt elite-led); repop
   picks 60% preset / 40% free-mixed; species resolve against the hunt
   roster with graceful substitution. RULE: new creature = synergy review +
   preset entry (or a retirement) at content time.
2c. **Synergy review IN the asset pipeline** (Ricardo: new creature ->
   synergy review + horde preset) — standalone reviewer tool + checklist doc;
   DO NOT touch genforge/pipeline/* (other agent redesigning it).
2d. **Biome variation + biome-bound creatures** (Ricardo question) —
   investigate whether streamed chunks vary biomes and whether spawn rosters
   are biome-filtered; implement if absent (design/12: 5 biomes).
4b. **HUD order-of-magnitude** (Ricardo: "plain colored squares, no
   personality; skills have no icons, no cooldown countdown") — framed HP orb/
   bar w/ ghost damage, styled charge pips, REAL skill icons + radial cooldown
   sweep + numeric countdown. Pixel doctrine, bounded draw calls.
3. **Skills-screen text clutter/capping** (design/polish; Ricardo) — the
   character panel pins a FIXED 92px detail card; text clipped/capped.
   Investigate autowrap/min-size; declutter panels (OPTIONS screen was step 1).
3b. **ESC→YES return-to-hub broken** — PROBE GREEN IN SOURCE 2026-09-12
   (ESC OK: esc_probe.tscn returns to haven.tscn). Likely the stale Sept-4
   package and/or memory-pressure stall. VERIFY on the fresh zip.
3c. **Infinite-map memory growth** — RAM PROVEN BOUNDED 2026-09-12
   (mem_soak.tscn: 2 min forced streaming peaks 125 MB then settles ~107-119;
   nodes recycle). VRAM unmeasurable headless -> F3 in-game readout (fps /
   RAM / VRAM / nodes) shipped so Ricardo can watch it live windowed.
3d. **Arena console discoverability + launcher** (Ricardo: "where are the
   commands... perhaps a launcher") — command is `godot --path game
   res://arena/console.tscn`; add a launcher (tools/ + maybe menu entry).
4. **Slow opening minutes** (game feel; Ricardo) — first fight/first level
   pacing; make the first minutes rewarding (links to #1 heal + #2 density).
5. **Performance regression check** (Ricardo: "game seems a bit more laggy") —
   profile frame time vs the 60 FPS budget (canon directive 2); suspects:
   recent FX/HUD additions, audio warm, display fit.

### NEXT (queued, decided)
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

### NEW BATCH — Ricardo, 2026-09-21 (verbatim demands, unstarted)

Logged the moment they arrived, per the roadmap rule. Nothing here has been
touched yet; R56–R60 are bugs and go first.

**Bugs / correctness (do first)**

- **R56 — GPU processes are not ended properly after training in the console.**
  Training launched from the arena console leaves GPU work alive. Find the
  owner (`game/arena/console.gd` → `tools/train_*.sh` → the python trainer),
  make the console's stop path reap the whole process group and free VRAM, and
  prove it with `nvidia-smi` before/after. Ricardo runs arenas on LOCAL GPUs —
  a leaked trainer costs him the next run.
- **R57 — every captured mob turns into a gloamfen stalker.** Capture/bond
  collapses the captured species to one body. WANTED: maximum variety — every
  species keeps its own chassis, AND **bosses are capturable as mini-pet
  versions** with their signature skills ("sick string skills") that help you
  in a fight, **levelling alongside the player**. Related: NEXT #6 (bond works
  with ALL creatures) and R64 (pet levels/skills) — R57 is the bug at the root
  of all three.
- **R58 — the HP potion does not heal over 2 s.** It is supposed to be a
  heal-over-time, not an instant top-up. Fix the potion path and cover it with
  a probe (there is already `game/prototype/tests/flask_probe.gd`).
- **R59 — creatures do not collide with the player.** They stand *on top of*
  the player, where he cannot hit them. Ricardo: "bizarre stuff and a bit
  annoying." Give creature-vs-player the separation creature-vs-creature
  already has (`creature.gd::_separate`). **Note (2026-09-21):** this is the
  SAME missing separation the sim is short of — see R55's residual, where
  `_separate` is the next thing to port into `sim/`. One fix, two payoffs.
- **R60 — the arena console lost its value labels** (generation etc. — the
  boxes render without their captions), **and the interface must be legible at
  20 M-step values.** Training numbers are in the tens of millions now; the
  console's fields were sized for smoke runs. Format with thousands separators
  / SI suffixes and widen the boxes.
- **R61 — bosses are not spawning randomly among new hordes while exploring.**
  World generation places boss lairs but the roaming-horde path never rolls a
  boss. Ricardo expects to meet them out in the map, not only at lairs.

**Content volume (the standing "more of everything")**

- **R62 — more of every content axis:** creatures, bosses, loot, skills, pets,
  mechanics, **and potion enchanting with special effects**. Data-only work by
  canon §10 — new `pack.type.name` ids validated against `content/schemas/`,
  no engine change. Potion enchanting is the one new SYSTEM in this line.
- **R63 — better skill design and playability; probably MORE skills, to make
  combat more dynamic.** Ricardo's read is that the current kit is too static.
- **R64 — visual cues for skill cooldowns.** HUD work; pairs with R63.
- **R65 — pet levels and pet skills**, so a pet scales with the player instead
  of falling off. Depends on R57 (variety) landing first.
- **R66 — item scaling** pass. Previously audited (2026-09-12 section above);
  this is Ricardo asking for it again against the current numbers.
- **R67 — mob kill counter → streak rewards.** A running kill counter grants
  bonus gold and XP, and when a streak ENDS on the timer after a LOT of kills,
  **a chest drops from the sky with legendary loot.** Streak length decides the
  tier.

**Events, bosses and questlines (the big one)**

- **R68 — multi-boss events (2, 3, 4, 5+).** Named examples from Ricardo:
  *Giant Graveyard* (seven giants), *Dragon Nest* (baby dragons + adult
  dragons).
- **R69 — the DRAGON COUNCIL.** The headline event, and explicitly bigger than
  the rest: **12 legendary interdimensional dragons join forces to kill you**.
  Structured as a dungeon/questline, not an arena fight — you face 12 councils,
  some in COUPLES with combo mechanics, some alone with special skill
  mechanics. These are the **10+-skill mythical / celestial / demonic** bosses.
  Defeating all 12 unlocks special loot + a mechanic + a skill. Near-RAID
  difficulty, gated behind prior ARTIFACTS that open the council dimension, and
  meant to take real time to unlock.
- **R70 — bot "player" events.** Bot players act as **mercenaries hired under
  your bounty**, and bot players go **bounty hunting YOU** — raising and
  spending your own bounty. This is the leaderboard system already queued at
  NEXT #6g; R70 is the PvE-facing half of it.
- **R71 — questline themes** beyond the council: mercenary hunt contracts,
  political sabotage, underground-city business, political power disputes,
  wars, conflicting interests, powerful-people scandals. Feeds
  `docs/design/28-living-world-and-weekly-lore.md` and the weekly-lore
  generator.

### ON RICARDO
- **UE 5.4 install** (~45 GB + Epic account) → `rebirth/unreal/INSTALL.md`.
- **`sudo apt install python3.10-venv`** (workaround active).
- **Play the slices for feel** — gates prove loops, not fun.

R34/R35 execution checkpoint (2026-09-13): reserving CPUs 0–3 did not cure the
streaming wall-time spike (14.03 ms, now prop construction); trainer affinity was
restored on all 520 surviving threads. This is NOT a passing performance receipt.
Next measure an actual GL Hunt and bound expensive dressing work; preserve the
running pre-checkpoint sweep. Flask gate currently bypasses input and only checks
some delayed healing. Replace it with real R/mouse events, exact total healing,
full/empty/dead/recharge cases. Playtest tuning: preserve 40% total, deliver 20%
immediately and 20% over two seconds; clamp the final tick and show healing progress.
Co-op inspection also found no remote Flask command; track its host-owned input/
replication alongside the local repair, without claiming official-server authority.

R34 measurement/implementation checkpoint: real assisted-combat GL profile under
the existing sweep returned ~30.3 FPS on Intel; 25.5 FPS with two reserved CPU
cores; 28.9 FPS on NVIDIA RTX 4050. These short source runs are not the user's
RTX 4080 and are not a passing 60 FPS claim. Affinity restored after each probe.
Profiler now saves actual wall-frame intervals and screenshots; exported pass next.
Inspection found all distant initial packs still inside the old 1152px active
radius, full-health bars redrawn every tick and every environment light scanned
every frame. Reduce residency to a viewport-aware 512px wake/640px sleep minimum,
keep flight/loot/co-op preservation, redraw health only on change, spatially cull
static lights, and avoid square roots for non-overlapping separation candidates.
Run state/culling gates and before/after captures before judging this optimization.
R35 local and real two-process co-op healing pass. R38 real Back/Train All dispatch
probe passes with process creation substituted (no accidental training sweep).

Resume checkpoint: new requests R41–R43 and both exact prompts saved before work.
HEAD has advanced to a2a14c4 through the other session's native inference, resident
workers, provenance gate and cockpit changes. Re-read those seams; preserve them.
The prior sweep was lost in a machine reboot according to the newer HANDOFF, so
NEVER reuse PID 2499910 or the old affinity script against this new machine state.
Prior performance figures were under the old sweep and are historical, not a
current diagnosis. Last culling/redraw changes were NOT measured: automatic
approval review again rejected the GL profiling launch as workspace credits
exhausted. Retry a harmless read/check first, then resume fresh validation.
Next: audit build receipts/provenance enforcement, fix Orun's coverage honestly,
add skill-ready cues, validate integrated recovery code, commit/push and rebuild.
All R01–R40 remain tracked; written plans/candidates are not marked shipped.

### R73 — the Dead Cells / Phantom Tower brief, re-sent 2026-09-22 (comparison)

Ricardo re-sent the whole asset-generation brief with *"perhaps you already
improved, than let's compare stuff"*. It is the same brief, not a new one:

    MASTER identical  : True   sha256 731f520061aa054e…  (sent == genforge.hifi.spec.MASTER_STYLE)
    NEGATIVE identical: True
    spec.verify_against_source() -> verified: True   (sprites prompt.md still pins it)

So the comparison is pipeline-vs-brief, pillar by pillar. What `genforge/hifi/`
(ab2cd93, R52) already enforces — the model is never trusted with any of it,
`pipeline.process` re-imposes it on whatever comes back:

| Brief demands | Where it is enforced | How it is proven |
| --- | --- | --- |
| Ink-Hold perimeter, zero sel-out, zero lineless | `outline.measure` → `repair` (step 5), width knob, emissive protected from the ring | hard check `ink_hold_perimeter` (coverage + ≥1 closed ink loop) |
| Volumetric cluster shading, 8-shade ramps, directional hue-shift | `palette.build/quantize` in OKLab (step 3), per-material ramps + shared ink | hard `deep_ramps` + `indexed_palette`; advisory `rich_ramps`, `hue_shift`, `directional_shading`, `no_pillow_shading` |
| Emissive channel mask for HDR bloom | `emissive.extract` by declared hue (step 4), re-read from the SHIPPED pixels after outline repair | hard `emissive_core`; engine side `sprite_lit.gdshader` reads B<0.5 and pushes above 1.0 |
| Normal-map-ready planar depth | `hifi_normal` (step 6) — ramp relief, emissive packed into B<128 | every legacy `sheet_n.png` still decodes as no emission |
| Crisp native 1:1 grid, zero mixels | `grid.estimate/snap/fit_canvas` (step 2), integer-only fit | hard `native_grid` |
| No noisy dithering | `palette.dedither` (step 4b), emissive protected | hard `no_dithering` (before/after dither score) |
| Isolated asset, clean transparent background | `alpha.enforce` (step 1) — flood + matte-fringe eat + binary alpha | hard `transparent_bg`, `binary_alpha`, `isolated_fill` |
| 12–16 discrete key poses per cycle (pillar 4's sprite half) | `spec.KEY_POSES` fills the stance slot, one generation per pose | clip names match design/26 rule 4 |

Nine hard checks decide the verdict, four advisory ones score it; `scorecard`
grades ANY RGBA the same way, so a hand-drawn or externally-bought sprite is
judged on the identical bar. Bundles carry palette + scorecard + provenance
(`dragon-heroes.art-source.v1`) and a `review.html`.

**The three gaps — all engine-side, none in the generator.** The brief's pillars
1, 3 and 4 describe *runtime* behaviour, and only their asset halves are built:

1. **Pillar 1, real-time 2D normal-mapped lighting.** The normal maps exist and
   `sprite_lit.gdshader` consumes the emissive channel, but the only Light2D in
   the game is in `game/prototype/main.gd` — creatures are not yet lit by torches
   and spell lights through their normal maps. That is the visual program's job
   (see SCHEDULED — visual program), not the pipeline's.
2. **Pillar 3, the 3D→2D render path.** Dead Cells' animation fluidity comes from
   rigging in 3D and rendering down to an indexed palette. We generate stills.
   This is exactly R72(b): Meshy → Blender → render → `hifi.process` as the
   palette-indexing back half, tested on a boss fight. `blender_clean` in
   `rebirth/assets/tools/gen_assets.py` is the first step and Blender is not
   installed yet.
3. **Pillar 4, GPU particles at 60 FPS over discrete sprite poses.** The particle
   half exists (`fx.gd`, `motes.gd`, `ribbons.gd`, MultiMesh paths); the pairing
   rule — sprites step at 12–16 poses/cycle while VFX run at 60 — is not written
   down as a budget anywhere. Belongs with the visual program.

No code changed for R73. The brief was already law.


## R60 — the console's captions, and the three bugs behind one complaint (2026-09-22)

> "the arena console lost its value labels (generation etc. render without
> captions), and the interface must be legible at 20 M-step values"

One sentence, three unrelated defects. None was guessable; each was measured.

**1. Captions 1 px tall.** `_label()` set `clip_text = true` on labels that also
autowrap. In Godot 4.6 that combination makes `get_combined_minimum_size()`
return `(1, 1)` — the *height* collapses too, not just the width — and a
`VBoxContainer` hands a non-expanding child exactly its minimum. So every
wrapping caption drew as a 1 px line: present in the tree, invisible on screen,
which is precisely "renders without captions". `clip_text` is commented out
(never deleted) with the measured before/after table beside it.

**2. Captions one letter wide.** The same wrapping Label inside an
`HBoxContainer` / `GridContainer` / `HFlowContainer` is handed minimum width 1
and renders as a vertical column of single letters. Fixed with `wrap = false`
opt-outs where the caption sits in a horizontal row: `key`, `speed`, `net`,
`_spin()`, `_vs_count`.

**3. Legibility at 20 M.** `_grouped()` and `_si()` static formatters; `20M` in
the TOURNAMENT tooltip instead of `20000000`; grouped digits in the progress
header and in `_architectures()`; the magic numbers named as `GPU_PPO_STEPS` /
`GPU_PPO_ENVS`; strip and chart legends laid out on a *measured* stride with a
`+N` overflow marker instead of a guessed one.

**Then the capture disagreed with me.** Fixing the captions made the HISTORY
list readable for the first time — and it read as garbage:

    arity fe:n_   ? vs ?  0-0  ?

Three more causes, all separate. `_verdict_kind()` knew `versus`, `tournament`
and `ladder`, returned `"other"` for everything else, and `"other"` falls
through to the head-to-head renderer: every `arena.distill` and
`arena.env_parity` record on disk — **9 of 31** — claimed to be a match between
two nets that did not exist. `_verdict_when()` sliced a timestamp out of
character positions 5..15 of the filename, so a name that is not `DATE_TIME__*`
produced `arity fe:n_` (from `env_parity_fen_boar_scripted.json`) or an empty
stamp. And `_verdict_keys()` only harvested a top-level `key`, while distill and
parity records name their creature in `build` — so those rows vanished the
moment any creature filter was applied.

Fixed: two new kinds with their own row renderers and detail panels (a distill
is a teacher against the student it trained; a parity run is one policy measured
in two runtimes, where only the gaps matter), a shared `_arch_label()` so the
row and the detail cannot drift, a three-tier `_verdict_when()` (filename stamp
→ the record's own `started`/`finished` → the file's mtime → `?`, never an
invented one), `build` harvested as a filter key, and the two kinds added to the
kind dropdown.

**And the header was lying.** `_scan_bench` sorted on the *filename*, which is
chronological only while every writer stamps a date first. The two undated files
sorted above every `2026-*` name, so "every verdict, newest first" put 09-14
rows above 09-19 rows. Now that every record resolves a real time, `_verdict_at`
gives the same three-tier answer as an epoch and the list sorts on that.

**Both gates had holes, and both were proven shut.** The layout probe checked
overflow but not collapse, so a 1 px caption passed it — it now fails on either
axis (`MIN_LABEL_W`, plus a `_line_height` floor). The console selftest already
had a `? vs ?` check, but no fixture that could trigger it — it now ships a
distill, a parity run, and an undated record whose name sorts first while its
time is oldest. Every new assertion was verified by reverting the fix and
watching the gate fail: reverting `_verdict_kind` reproduced
`'09-11 09:30  ? vs ?  0-0  ?'` — the exact string from Ricardo's screen — and
reverting the sort put `09-10 08:00` at the top of a newest-first list. The
first version of the sort assertion passed *vacuously* (every fixture sorted the
same way under both keys); that is why the undated fixture exists.

`ui_capture.gd` gained `UI_TAB=<title>`, which walks to the first `TabContainer`
holding a tab with that title and selects it before the shot. The console keeps
five tabs and only the front one had ever been captured, so a caption that
collapsed on RUNS or VERSUS could not have shown up in a screenshot at all. Any
tabbed screen gets this for free.

Final state: `CONSOLE LAYOUT OK — 7 canvases x 2996 controls, nothing leaves the
canvas on EITHER axis and no caption collapsed` (640x360 → 1440x810, all five
tabs); `CONSOLE SELFTEST OK` over 8 fixtures covering all four verdict kinds;
`ui_console_versus.png` at 1600x900, 56 FPS, 122 draw calls.

---

## 2026-09-22 — R44/R61/R74: bosses roam, and they arrive together

Ricardo, twice, months apart: bosses should be met **out in the map**, not only
at the four authored lairs of the origin 5×5. The cause was never subtle —
`main.gd::_spawn_packs` is the only place a boss chassis is ever constructed,
and both restocking paths (`_repopulate`'s pressure roll and the frontier repop
field) only ever field `_ground_species`/`_caster_species`. Walk past the
authored window and the world has no bosses in it at all, forever.

The fix is a rare WARLORD slot in the pressure roll: `_roll_roaming_boss` reads
as a stack of refusals (hunt live, `danger >= 1` so the authored window keeps
its own bosses, under `ROAM_BOSS_MAX_ALIVE`, cooldown elapsed, `REPOP_CAP - 8`
headroom for the boss *and* its horde), and `_spawn_roaming_boss` rides a real
`bestiary_legendary` entry onto the matching chassis so the warlord inherits the
entry's hp/dmg multipliers, tint and bundle exactly like the authored pack-12
legendary. Odds `0.05 + 0.02·danger`, ceiling `0.22`. It is rolled *before* the
pack is built, so the warlord leads the horde that is arriving instead of
standing alone in a field.

**Mid-implementation, Ricardo reversed the design:** *"Bosses spawning together
and fighting multiple at once is actually a pretty fun mechanic, with unexpected
crossovers."* So the one-live-boss cap became `ROAM_BOSS_MAX_ALIVE = 3` and the
odds are *multiplied* by `ROAM_BOSS_CROSSOVER = 1.35` while one already prowls —
the crossover is encouraged, not tolerated. The cap that remains is the frame
budget, not the design, and the second arrival gets its own louder banner
(`msg_warlord_crossover`) because the player has to know the field changed.

**Two latent bugs surfaced on the way, both older than this work.**

1. `on_legendary_died` cleared `legendary_boss`/`_legendary_name`
   unconditionally. A warlord also rides a legendary entry, so killing one out
   in the field erased the *hunt's* legendary from the minimap while the real
   pack-12 boss was still standing. Now identity-guarded (`if b ==
   legendary_boss`).
2. `terravore_colossus.gd` and `pyre_sovereign.gd` stamp `display_name` and
   `bar_color` in `_ready()` — which Godot runs at `add_child`, i.e. *after* the
   caller named the node. `setup_legendary`'s contract says main owns the name,
   so the chassis was silently overwriting it: a colossus-chassis legendary went
   on the boss bar as "TERRAVORE COLOSSUS" instead of `Syvzarr, Star-Eaten
   Pillar` (its own boot log said so). Both chassis now treat their identity as
   a default, applied only when `legendary_entry` is empty. The authored pack-12
   legendary had this bug too.

Death routing is the sharp edge here: `on_boss_died` is hunt-defining (Emberfang
Blade + mount + the Matriarch banner) and must NEVER be reached by a roaming
kill, so a no-catalog warlord uses the Hag chassis, whose `on_hag_died` is pure
flourish.

Gate: `game/prototype/tests/roam_boss_probe.tscn`, eight assertions with teeth —
(a) no warlord in 200 waves at danger 0, (b) warlords arrive with hordes out in
the band, (c) several alive at once, (d) never above the cap, (e) the cooldown
blocks the roll, (f) on the boss-bar list but not the hunt legendary, (g) a
roaming kill leaves hunt legendary state untouched, (h) it wears its catalog
name. Verdict:

```
[hunt] roaming boss: GRUMANG, HALF-WOVEN COLOSSUS — Warlord (danger 2, 1 alive)
[hunt] roaming boss: THAXVEIG, CRONE OF THE DEEP WEAVE — Warlord (danger 2, 2 alive)
[hunt] roaming boss: BRYNROTH, PILLAR OF THE LAST KINDLING — Warlord (danger 2, 3 alive)
ROAM BOSS OK — 3 warlords over 9 waves, 3 alive at the peak (cap 3); none in
200 waves at danger 0; GRUMANG, HALF-WOVEN COLOSSUS — Warlord kept its catalog name
```

Three different chassis crossing over in one field: exactly what R74 asked for.
`repop_probe`, `spawn_test` and `ground_state_probe` stayed green throughout.

**A note on how this landed.** `main.gd` and `ui/lang.gd` held this work
entangled with eight days of the parallel session's uncommitted residency/flask
work in the same files. `git add -p` is unavailable in this harness, so the
split was mechanical: save the final file, strip the known R61 blocks with a
boundary-asserting helper, verify the intermediate still parses *and* passes
`repop_probe`, commit the cold tree, restore the final file, commit this. Each
side is reviewable on its own.

---

## 2026-09-22 — R76: the banner loses its hallucinated dragon

Ricardo, verbatim: *"hey, can we improve our banner? In github repo's readme. I
liked the vibe, but the giant dragon head in the horizon is bizarre and
hallucinated lol / Perhaps use our new quests themes to represent stuff! The
heroes party and spirit dog vibe was neat, tho, keep that. Reminds me of lord of
the rings journeys - companionship and adventure"*

### The constraint that shaped the deliverable

This session has no `image_gen` tool and `OPENAI_API_KEY` is unset, so re-rolling
the plate was not available. Re-rolling would have been the wrong answer anyway:
a banner only one session can reproduce is not an asset, it is a lucky file. The
deliverable is therefore a **deterministic in-repo compositor** —
`genforge/pipeline/readme_banner.py`, PIL + numpy, fixed seeds, no network —
that repaints the right third of the v1 plate, plus a corrected v2 prompt carried
for the day the paid path runs.

- v1 plate preserved: `docs/art/readme-banner/plate-v1-genai.png` (git mv, not delete).
- Gate: `python3 -m genforge.pipeline.readme_banner --check` re-renders and
  compares sha256 against the committed PNG →
  `BANNER OK — committed PNG matches the compositor`, exit 0.
- Shipped PNG 2172x724, sha256 `2cc63ad91eab968055e048cf923c36166543882fa00c95d5c9d8d4f8d53a4270`.
- The prompt was not innocent: v1's own text asked for *"an elegant monumental
  ivory-and-antique-gold dragon"* at the far right. The model did not hallucinate
  it unprompted. `prompt.txt` keeps v1 verbatim with that line marked `>>>`.

### What changed in the picture

Kept untouched: the party of three + spectral wolf, the causeway and its lanterns,
the pillar and banner, the moon and mountains, the citadel, the genuine waterfall,
the gothic arch ruins, and the whole gold title block.

Killed: the monumental dragon (wing x 0.685-0.86, head x 0.775-0.95, neck to the
right edge, the fake jaw-waterfalls at x 0.79-0.83).

Added, all sourced from `genforge/releases/bell_beneath_fen.json` so the banner
advertises the actual weekly-content promise: a ruined keepers' bell tower with a
lit belfry arch and a bronze bell, a lantern-lit ferry on the open water, Lumen
motes, and **two small distant wyrms on the high mist** — a rumour of dragons
rather than a portrait of one.

### Measurement trail (the part worth keeping)

**Stop eyeballing a downscaled crop.** I was convinced there was a hard rectangle
edge at x 0.774 and y 0.633 — a "pasted box". Blurred-luma gradient profiling
(`np.abs(np.diff(...)).mean(axis)`) disproved it: the strongest vertical edge in
the frame is at x 0.706-0.740 (the plate's own fog lip) and the strongest
horizontal at y 0.934-0.959 (the water line). There was no edge at 0.774 at all.

**The defect was a value hole, not a seam.** x 0.80-0.99 measured 32-40 luma
against the plate's 56-83. Repainting terrain alone ran 10-20 grey levels under
the painting *and the deficit grew with depth into the frame* — the signature of
missing atmosphere. Fixed with an aerial-perspective pass (`_haze`) plus lifted
layer colours; post-fix bands land within ~6 levels on every honest row.

**Reference bands can be contaminated.** My first comparator crop (x 0.555-0.680)
runs straight through the gold title at y 0.40-0.55, where R 91-102 > B 60-70.
It produced false "too dark" flags until I restricted comparisons to
blue-dominant rows.

### Four lessons, now also in `docs/art/readme-banner/README.md`

1. **A flat fill is the tell, not the seam.** Plate sky sigma 19.1 / mist 29.5 /
   bank 16.1; a clean repaint came back at 0.91-2.63. The eye reads the texture
   gap long before it finds an edge.
2. **Sigma is a diagnostic, not a target.** Grain amp 0.150 hit the number and
   looked like burlap. The usable band is ~10-12.
3. **Distance washes toward the sky, it does not darken.** Stacking ever-darker
   silhouettes digs a hole exactly where the composition wants light.
4. **Silhouettes composite; fills do not.** A three-tone bronze bell read as
   vector clipart. A dark shape with light coming *through* it has no fills to
   compare against.

Corollary learned the hard way: **a distant object must be hazed to ITS depth.**
The tower drawn at the foreground ruins' near-black (12,22,33) read as a floating
phone booth. Lifting it to (20,35,52) and seating it on a drawn bank with a teal
reflection made it read as a tower in the mid-distance.

And: **lay fog across a boundary, not up to it.** Feathering only converts a hard
seam into a soft one.

### Iteration sequence

- **try11** — `_haze` aerial perspective + lifted terrain colours. Closed the value hole.
- **try12** — `WING_X 0.685 -> 0.632`. The mask's feather ramp runs *from* x0
  *to* x0+fx, so at 0.685 the plate's lit dragon-wing edge survived at partial
  alpha across x 0.679-0.721 and read as a diagonal contrail. Also L1 fade
  0.30 -> 0.13 (a 217px fade made the ridge a wall) and the tower rewritten.
- **try13** — tower hazed to its depth, seated on a promontory, reflected on the fen.
- **try14** — `_clouds`: the repaint measured within six levels of the plate's sky
  and still read as a different picture, because the mismatch was never value or
  hue (R-B came back -60 against the plate's -66). An empty sky beside a worked
  one is a hole with correct colour. Noise on a wide, short grid stretched to the
  frame (which is what wind does to cloud), thresholded into masses, lit from the
  moon's side at x~0.21. Sky darkening eased 0.14 -> 0.09 and 0.12 -> 0.08.

Each iteration was judged against a rendered full-size read and an x>=0.60 crop,
never assumed.

### Also fixed in passing

Root `README.md` carried an orphaned half-sentence — *"as well as item markets,
with real-money. / player-to-player item marketplace settled via Pix."* — evidently
a bad edit. Rewritten into one sentence, and the image alt text now describes the
picture that actually exists.

---

## 2026-09-22 — R75: the repo cleanup, with the evidence

Ricardo: *"Hey clean up the repo when done - i noticed there are some unused
whole folders"*

The contract in the ledger was explicit: prove each candidate dead (no code
import, no path string, no CI/tooling reference, no doc link) before removing it,
and never silently delete something merely **paused**. Here is the whole
inventory and the verdict on each.

### DELETE — empty, unreferenced, nothing lost

| Path | Evidence |
|---|---|
| `sim/bin/` | Empty since 2026-09-14. 0 tracked files. `grep -rn "sim/bin"` across md/sh/py/cmake: no hits. |
| `rebirth/native/shaders/` | Empty since 2026-09-11. 0 tracked files. `grep -rn "native/shaders"`: no hits. |
| `.pytest_cache/`, `genforge/.pytest_cache/` | Tool caches. 0 tracked files. `.pytest_cache/` was not in `.gitignore` — added. |
| 14 × `__pycache__/` | Already gitignored, 0 tracked files, regenerated on demand. |

### UNTRACK — gitignored yet still in the index

`git` keeps tracking a file that entered the index before its ignore rule
existed, so both of these were being committed *despite* `.gitignore` naming
them. `git rm -r --cached` only; every file stays on disk.

| Path | Tracked | Note |
|---|---|---|
| `sim/build-windows/` | 137 files, 1.9 MB | A full CMake build tree: `CMakeCache.txt`, `CMakeFiles/`, generated Makefiles, compiler logs, object files. Entered in `674d57b`; `.gitignore` has said `sim/build-windows/` ever since. |
| `ml/data/logs/` | 7 files | Training logs. `.gitignore` has said `ml/data/logs/`; 19 files on disk, 7 of them tracked — an arbitrary subset, which is worse than either extreme. |

**The one thing in that tree that was load-bearing.** `dh-server.exe` (97 KB,
PE32+ x86-64) is what `tools/package_game.sh windows` ships next to the game
binary; without it the packaged Windows build has no infinite world and no co-op
world parity. Untracking the build tree wholesale would have silently downgraded
every clean clone's Windows zip to client-only.

So it moved to `builds/prebuilt/windows/dh-server.exe` with a README recording
its sha256 (`246445fa…`), size, target, toolchain and the commit it came from,
and `package_game.sh` now resolves the server binary in order:

```
sim/build-windows/dh-server.exe                  # a fresh local cross-build wins
sim/build-windows/libs/dh-server/dh-server.exe   # …even un-copied
builds/prebuilt/windows/dh-server.exe            # the committed cache
```

Both branches exercised: with the local build present it picks the local one;
with it hidden it falls back to the prebuilt. A rebuild always beats the cache,
so the cache can never go stale behind someone's back — it only answers when
nothing else can. `docs/tech/34` §256, which described the tracked cache, updated
in the same change.

### KEEP — and the reason each one looked empty

Nothing here was removed. Three of them gained a README, because the actual
defect was never that the folders were unused — it was that an unfamiliar or
empty folder had no way to say what it was for.

| Path | Verdict |
|---|---|
| `art/` (`palettes/ rigs/ tiles/`, all `.gitkeep`) | Canon §10 scaffold. Empty because art production runs through GenForge today; it is where hand-authored sources land. **README added.** |
| `reference_repos/` | Empty, awaiting the local image-gen repo (13b) — *paused, not dead*. **README + `.gitignore` added**: third-party checkouts are read, never imported, never committed; only the README is tracked. |
| `builds/` | Ships the two zips. **README added** mapping every subfolder to tracked/untracked. |
| `rebirth/`, `rebirth/godot3d/`, `game/prototype3d/` | Documented engine experiments (canon §12.27) with their own README and status log. Paused ≠ dead. |
| `genforge/candidates/*` | Quarantined generator output by contract (docs/tech/28 §6); the directory is kept, contents ignored. |
| `ml/runs/`, `ml/data/*` | Live training artifacts. `benchmarks/` and `ppo_snapshots/` were untracked-but-unignored, so they nagged in every `git status` — now ignored. |

**Canon §10 was the root cause for three of these.** `builds/`, `rebirth/` and
`reference_repos/` exist on disk but were missing from the tree that calls itself
the canonical layout, so they read as cruft to anyone checking. Added, with a
dated note. No structural change.

### Gate

- `python3 -m pytest genforge/tests -q` → **146 passed**.
- `ml/.venv/bin/python -m pytest ml/tests -q` → **147 passed, 1 skipped**.
  (Under system `python3` two mask tests fail on `ModuleNotFoundError: torch` —
  pre-existing and environmental; torch lives in `ml/.venv`.)
- `bash -n tools/package_game.sh`, plus both resolver branches run by hand.

## 2026-09-22 — R77: the build merge, and the client that had been stale for ten days

Ricardo, verbatim:

> hey, we are building on top of the code build, right? It really levelled up
> graphics and solved a lot of roadmap items. I think it's time we fully merge
> the build and keep our final one! Add that when finishing the roadmap (and
> consider that for continuing and perhaps fixing the roadmap!)

and, a moment later:

> yeah, i just noticed that as well, you were looking exactly at that lol. Keep
> in mind codex advanced some stuff we can reuse and perhaps extend

### The answer to the question, and the bug hiding behind it

**Yes — and the source had been merged for ten days already.** `246a6a5` landed
the parallel session's living-world/residency tree, and `game/export_presets.cfg`
has pointed at `builds/codex/` ever since. Every *export* since then was the
codex build.

What was never merged was the **packaging**, and that was a live shipping bug:

```
game/export_presets.cfg  →  export_path = ../builds/codex/<plat>/dragon-heroes-codex.<ext>
tools/package_game.sh    →  pack() zips  builds/<plat>/
```

The export landed in one directory and the zip was built from another. So
`builds/dragon-heroes-linux.zip` and `…-windows.zip` — the two artifacts that
are the game, as far as anyone downloading is concerned — carried a
**2026-09-12 client for ten days**. The levelled-up graphics Ricardo was
describing had never once been inside them.

### The decision: one packager, and which one

Two rival packagers existed. The legacy `tools/package_game.sh` copied three
files and verified nothing. `tools/package_codex.py` built the icon, validated
content, staged the living preview, built the sim and ran ctest, cross-built
mingw, ran Godot `--import`, exported, hashed a `BUILD-INFO.json`, then gated on
`verify_package.py`, a package smoke run, `check_living_preview`,
`check_lair_journey` and a zip CRC test — and refused to ship if any of them
failed.

The codex one wins, and the deciding reason is not the gate list. It is this
line:

```
godot --headless --path game --export-release "<preset>" <explicit path>
```

The explicit path argument **overrides** the preset's `export_path`. A packager
that passes it cannot be betrayed by preset drift — which is exactly the class
of bug that caused the ten-day staleness. The legacy script trusted the preset
and lost.

- `tools/package_codex.py` → **`tools/package_build.py`** (git mv + rewrite).
- `tools/smoke_codex.py` → `tools/smoke_package.py`; `tools/profile_codex.py` →
  `tools/profile_client.py`. Flags followed: `--codex-smoke` → `--package-smoke`,
  `--codex-profile` → `--client-profile`.
- `tools/package_game.sh` survives as a **142-line wrapper**: the whole old body
  is commented out, not deleted (standing rule), and the only live code is
  `fetch_templates()` — the one capability the Python packager never had — plus
  `exec python3 tools/package_build.py "${1:-all}"`. `DH_FETCH_TEMPLATES=1
  tools/package_game.sh all` still works on a fresh machine.

**What was reused from the legacy side**, per *"codex advanced some stuff we can
reuse and perhaps extend"* read in both directions: the prebuilt Windows-helper
cache, carried across as `helper_candidates()`. Fresh local cross-build first,
`builds/prebuilt/windows/dh-server.exe` second. That order is load-bearing and
is commented as such: **a cached helper must never outrank a rebuilt one**, or
the cache silently ships stale code — the same failure mode in a different
costume.

### Product identity, and the save directory that would have orphaned every hunter

Renaming `config/custom_user_dir_name` from `Dragon Heroes Codex` to
`Dragon Heroes` moves the save directory out from under every existing save.
Godot does not migrate; it just starts fresh, and the hunters appear to be gone.

So `game/tools/user_dir_migration.gd` runs as the **first** autoload, before
LairJourney, Session or anything else that reads `user://`. It works in
`_init()`, copies additively, **never clobbers an existing file and never
deletes the old directory**, and drops `user://.user-dir-migrated` so it runs
once.

Verified against Ricardo's real data, not a fixture:

```
USER DIR MIGRATION: copied 88 file(s) from …/.local/share/Dragon Heroes Codex
MENU OK — 13 buttons + OPTIONS screen … settings survive a language save
          (…/.local/share/Dragon Heroes), script compiled
```

Old directory afterwards: 89 files, 4 saves — untouched.

### The proof the bug is dead

`python3 tools/package_build.py all`, EXIT=0, every gate printing OK
(`CONTENT OK`, contents 18/16 files, `PACKAGE SMOKE OK … creatures=60`,
`LIVING PLAYTEST OK`, `LAIR JOURNEY OK: … fps=60.0 frame_cpu_ms=0.325`, both
six-size `EMBEDDED ICON OK` checks, both `PACKAGE OK`). Log:
`genforge/candidates/packaging/r77-merge-build.log`.

| | before | after |
|---|---|---|
| `dragon-heroes.x86_64` in the linux zip | 2026-09-12 | **2026-09-22 05:00**, 96,236,632 B |
| `dragon-heroes.exe` in the windows zip | 2026-09-12 | **2026-09-22 05:01**, 129,746,984 B |
| `dragon-heroes-linux.zip` | 37,542,323 B | 50,797,130 B |
| `dragon-heroes-windows.zip` | 46,463,352 B | 59,579,269 B |

The mingw cross-build ran for real this time (no fallback WARNING in the log,
`sim/build-windows/` rebuilt at 05:00), so the prebuilt cache was not exercised
by this run — it stays as the fallback for machines without mingw.

### Deleted, after the safety check

`builds/codex/` (331 MB) and `sim/build-codex-windows/` (34 MB), ~365 MB total —
and only **after** the new package run succeeded, so the only existing export
was never the thing being destroyed. Concurrent-session rule applied first:
nothing under either path was newer than 04:50, and `git status --porcelain` on
both was empty.

**Untouched, and deliberately so: the in-game CODEX** — the effects/affix
registry of canon §12.12. Same word, unrelated thing; it is game fiction, not a
build flavor.

### Fixed on the way

1. **The mingw cross-build was broken at HEAD.** `arena.cpp:24:17: error: unused
   variable 'kWindup' [-Werror,-Wunused-const-variable]` — R55 orphaned it, and
   gcc does not diagnose an unused namespace-scope `constexpr` while clang does,
   so the Linux build stayed green and nobody noticed. Commented out with a
   provenance note rather than deleted. Linux ctest stayed 4/4.
2. **The committed `builds/prebuilt/windows/dh-server.exe` was 97 KB of
   2026-09-12 code**, because the path canon §12(e) called "the output" is a
   hand-copy that nothing rebuilds. The real CMake output is
   `sim/build-windows/libs/dh-server/dh-server.exe` (287,232 B, sha256
   `bd9ece1f…88392`). Canon corrected, the cache replaced, and the trap written
   into `builds/prebuilt/windows/README.md`.
3. **`zip -qr` was appending to the previous archive** instead of replacing it.
   Moot under the new packager, which always zips from a fresh stage.

### Two findings logged, neither a regression — both closed the same day by R79

- **The Windows package ships no GDExtension.**
  `game/addons/dh_godot/dh_godot.gdextension` declares only
  `linux.debug.x86_64` and `linux.release.x86_64`, so Godot's exporter has
  nothing to put in the Windows zip. `game/arena/neural_policy.gd` already falls
  back to GDScript when the extension is absent, so Windows is playable — it is
  a pre-existing platform gap, older than R77.
- **The mingw tree emits a misnamed artifact**:
  `sim/build-windows/libs/dh-godot/libdhgodot.linux.template_debug.x86_64.dll`
  — says "linux", says "debug", is a `.dll`. Harmless today only because nothing
  consumes it.

Both are fixed in the R79 section at the end of this file, along with the third
finding they turned out to share a root with: the unexplained
`completed with warnings` on the Windows export was the missing-library warning
and nothing else.

### Docs updated in the same change

`docs/00-canon.md` §12.53 (the canonical record), `docs/USAGE.md` §8,
`docs/tech/34-living-content-pipeline.md`,
`docs/tech/35-playable-living-trial.md`,
`docs/harness/10-systems-map.md`. Historical narrative was deliberately left
alone — the recovery history in `10-systems-map.md`, the older entries in this
file and `genforge/candidates/packaging/recovery-*.log` still say `codex`,
because that is what happened.

### R17 addendum — the push that closed the 2026-09-12 backlog

`origin/master` had been frozen at `b622aa6` since 2026-09-12: **55 commits**
behind, everything from the living-world/residency merge through R77. Pushed
2026-09-22 05:15, `b622aa6..2ac37cf`, fast-forward, no conflicts. R17 stays
recurring, but the backlog is gone.

GitHub's one complaint is worth scheduling: `builds/dragon-heroes-windows.zip` is
**56.82 MB** — past the 50 MB recommendation, and it gained 13 MB in this single
merge. The 100 MB per-file hard limit is now the real deadline. Committing the
shipped zips is deliberate (canon §10, `builds/README.md`: they *are* the game to
anyone downloading), so the choice when it arrives is Git LFS or GitHub release
assets, decided before the limit forces it rather than after.

---

## 2026-09-22 — R57: the bond carries the body

**The complaint (verbatim):** *"Every captured mob turns into a gloamfen
stalker. Wanted: maximum variety — every species keeps its own chassis, AND
bosses are capturable as mini-pets with their signature skills, levelling
alongside the player."*

### Two hardcodes, not one

The complaint reads like one bug and is three:

1. `main.gd::_roll_pet()` stamped `"species": "core.creature.gloamfen_stalker"`
   into every record it wrote, no matter what body the snare took.
2. `pet.gd` then dressed whatever it was handed with
   `ProtoSprites.stalker_frames()` and gave it the founding `120` hp / `14`
   damage block — so even a correct record would have rendered as a stalker.
3. The design doc agreed with the bug: design/13 §7.1 said the **Legendary tier
   is never capturable**, and `duo_boss.gd` carried a comment promising that
   line would be rewritten "in the same change" if the rule ever moved.

### The seam: `capture_profile()`

`creature.gd::capture_profile()` is now the single export point. The subtlety is
levels: `_apply_entry()` runs unconditionally in `_ready` and bakes
`1 + rate*(level-1)` into `max_hp`/`damage`, recording `_level_hp_mult` /
`_level_dmg_mult`. A profile must export the **level-free** base, so
`capture_profile()` divides those multipliers back out — otherwise a pet
captured at level 30 would be re-levelled a second time on every tick and grow
without bound. Normals use `_power_rates() = (0.02, 0.01)`; boss/hag/duo
override to `(0.06, 0.03)`.

The profile carries species id, archetype, element, tint, scale, the level-free
hp/damage, the per-chassis capture terms, and — for a legendary — the authored
`kit`.

### Skills: a three-tier pool, not a constant

`main.gd::_signature_pool(fam, prof)` resolves in order:

1. the legendary's authored **`kit`** — if present it suppresses everything
   else, because that kit *is* the creature's identity;
2. a hand-written **species row** in `abyssal.json`;
3. `element_signatures[element]` + `archetype_signatures[archetype]`.

Deduped, then `out.shuffle()`, so `skills[0]` — the one the record leads with —
is a random member of the pool rather than always the same head. Final fallback
`["core.skill.shadow_rend"]`. `_roll_pet` takes `slots = randi_range(min(2,
max_slots), max_slots)`, **+1 if the profile carries a kit**, seeds with
`sig_pool.pop_front()` and fills the rest from the shared pool at
`family_skill_chance = 0.25`.

**Coverage gap worth recording:** `blood` and `frost` have **no dedicated skill**
in `content/core/skills/`. They degrade to their neighbours —
blood → `abyssal_maw` / `cleave`, frost → `void_step` / `hex_bolt`. The pool is
legal and the probe passes; it is authored content that is missing, not code.
Two skill definitions would close it.

### Every tier is capturable

The tier gate moved from "Normal only" to "all three, on their own terms":

| Chassis | Snare only below | Roll × | Pet keeps HP | Pet keeps dmg | Drawn at |
| --- | --- | --- | --- | --- | --- |
| Normal (stalker/lunger/brute/wisp) | 35% HP | ×1.0 | 100% | 100% | 100% |
| Elite (Matriarch, Bog Hag) | 15% HP | ×0.35 | 25% | 50% | 55% / 60% |
| Legendary duo (Pyre, Terravore) | 10% HP | ×0.15 | 20% | 45% | 50% |

A capture pays **no loot, no rune, no kill credit** — the bond *is* the spoil.
`_release_captured` nulls `legendary_boss` / `_legendary_name`, and if the taken
body is half of a duo whose mate still lives, the mate `avenge()`s. Every
elite/legendary chassis keeps its old `# capturable = false # pre-R57: …` line
commented rather than deleted, per the standing rule.

Records saved before R57 carry no chassis at all and stay **exactly** the
founding 120/14 stalker — the probe asserts that explicitly with a synthetic
old record, so the change is not retroactive on anyone's save.

### The gate, and proof it has teeth

`game/prototype/tests/capture_probe.tscn` →
`CAPTURE OK — 40 rolls legal; species/kit/rig/level/essence/F-path all held`,
zero ERROR lines. It boots the real `main.tscn`, takes the clock
(`set_physics_process(false)` on the hunt, `_streaming = false`, world and
residency processing off), clears the spawned creatures and then asserts:

- **species** — over 40 rolls of one body, every record's `species` is the
  probe drake, never `gloamfen_stalker` (`"R57 REGRESSION: every bond is a
  gloamfen stalker again"`), every skill id resolves in the family, and
  `kits.size() >= 3` so the shuffle actually varies;
- **rig** — a wisp pet carries `ProtoSprites.wisp_frames()`; a drake-chassis pet
  carries its species hue (`self_modulate.r > self_modulate.b * 2.0`);
- **kit** — the legendary's pet gets `prof["kit"]` verbatim and `>= 3` skills;
- **level** — at `Session.level = 11` the boss chassis reads `max_hp == 1440`,
  `base_hp == 225`, `base_damage == 11`, `hp_rate == 0.06`; moving the hunter
  11 → 21 re-derives the pet to `225 * 2.2 * roll` with `hp == max_hp * 0.5`
  preserved (the wound fraction, not the absolute HP);
- **essence** — the faucet is unchanged: stalker/lunger/brute drop, wisp/boss/
  hag/pyre/colossus do not;
- **the real F path** — the HP gate refuses *for free* (no snare spent), a bond
  spends one, `kills` does not move, `legendary_boss == null`,
  `_legendary_name == ""`, the hint reads `msg_bonded_leg`, and the duo survivor
  comes back `_enraged` with `msg_duo_taken`.

**Mutation test.** Reverting `capture_profile()`'s species lookup to the
pre-R57 hardcode (`var species_id := ""` / `if true:`) and re-running produced
**34 `CAPTURE FAIL` lines**; restoring `creature.gd` from the scratchpad backup
returned exit 0. The gate fails when the bug returns.

Capture is probabilistic, so the probe does not seed the RNG — `_bond()` makes
up to 200 fresh attempts at 1% HP (p ≈ 0.844 normal, 0.295 boss, 0.127 duo
half), which puts the residual flake below any threshold worth engineering for,
and it is handed `4 * TRIES` snares so the supply never runs dry.

### Two things the probe found on its way

- **Pre-existing error spam, not R57's.** Every pet spawn logged
  `There is no animation with name 'idle'` from `pet.gd:122`. `git diff` proved
  the line was a context line, older than this change: `_ready` called
  `sprite.play("idle")` before `_dress()` had installed any frames. Deleted —
  `_dress()` already plays idle when the current animation is missing.
- **Two probe bugs caught before the first run**, both worth naming because they
  are traps for the next test: parking the Terravore half at the player's
  position would have made *it* the nearest snare target (the reach is only
  `3 * TILE = 48 px`), so duo halves are parked at `FAR = (0, 320)`; and
  `partner` is declared on `ProtoDuoBoss`, not `ProtoCreature`, so any probe var
  holding a duo half must be untyped or GDScript's static analysis rejects
  `.partner`.

### The gate flaked, and the fix is worth remembering

Re-running the suite before the commit, `capture_probe` failed once in four with
`CAPTURE FAIL: the bond did not level with the hunter` — the one assertion that
waits for something to happen rather than reading it straight back. The cause is
a clock mismatch, not the code under test: the bond re-levels inside
`pet.gd::_physics_process`, the probe waited `await get_tree().process_frame`
three times, and **headless Godot runs process frames far faster than the fixed
60 Hz physics clock**, so three process frames can contain zero physics ticks.
Fixed with a `physics_frames()` helper that awaits `get_tree().physics_frame`;
16 consecutive runs green afterwards. Any probe that waits on a
`_physics_process` effect must wait on `physics_frame` — `process_frame` is a
coin flip in headless.

### Docs updated in the same change

`docs/design/13-creatures-and-bestiary.md` §7.1 (the tier gate rewritten to the
mini-pet rule, the terms table, the chassis-travels paragraph — this is the
rewrite `duo_boss.gd`'s comment promised), `docs/USAGE.md` §10 (the
`Capture / pets` gate row), `docs/harness/README.md` (the probe in the gate
breath), `docs/harness/10-systems-map.md` (a new **Capture & pets** section),
`docs/harness/20-roadmap.md` (R57 DONE; R65 marked unblocked, with the note that
its levelling half landed here and only the skills half remains).

## 2026-09-22 — R80: the gate that was red for two reasons, neither of them a bug

Found while running the full gate suite before committing R57. `residency_probe`
— a USAGE §10 gate — was red, and red **at HEAD too**, so it was not R57's doing.
Measured both trees before touching anything:

| tree | result |
| --- | --- |
| HEAD (`eed38cc`'s parent, probe in place) | `pass=0 fail=5` |
| the R57 tree | `pass=1 fail=4` |

Two independent causes, found one after the other. Neither is a game bug; both
are the probe lying about its own fixture.

### (a) The probe pinned no seed

The gate needs a water tile near the spawn point so it can park a flying record
over drawn water and watch residency wake it. It never asked for one. `main.gd`
calls `randomize()` and `world_gen.gd::_ready` rolls
`_hunt_seed = forced_seed if forced_seed != 0 else randi()`, so the fixture
existed only on lucky seeds.

Quantified it with a throwaway scanner (`ProtoWorld.new()` per seed with
`forced_seed`, reporting `origin_walkable`, `spawn_point()`, and the Chebyshev
ring of the nearest `T_WATER` tile within ±35 tiles). Over 28 seeds:

- seeds **41, 10, 24** — no water at all in range (ring 999)
- seeds **7, 16, 18** — ring 28–35, i.e. water exists but far outside the wake radius
- seed **42** (the lair-tour seat) — ring 19
- seed **41487** — `origin_walkable=true`, `spawn=(0,0)`, water at **ring 2**

So roughly one run in nine had no fixture at all, and several more had one too
far away to matter. Pinned to **41487** — the seat `stream_recovery.gd:48` and
`residency_capture.gd:28` already use — via `MpNet.pending_seed` before
`add_child(hunt)`, released to `0` immediately after so nothing else in the run
inherits a forced world.

### (b) The fixture search took the wrong tile

The seed pin alone did not turn it green: `flying creature over drawn water did
not return` survived. A temporary debug print located it in one run:

```
water=(-256.0, -560.0) here=(0.0, 0.0) dist=615.740234375 wake_d=512.0 ready=true
```

The old search was a row-major scan (`for y in -35..35: for x in -35..35:` then
break on the first hit), which returns the **most-northern** water tile, not the
nearest. 615.7 px is past residency's 512 px `wake_distance()`, so the system
did exactly the right thing and refused to wake the record — and the probe
called that a failure. Replaced with a ring-outward search bounded by the wake
radius itself:

```gdscript
var max_ring := int(residence.wake_distance() / ProtoWorld.TILE) - 4
```

The bound is the point: the probe can no longer place a fixture the system is
contractually allowed to ignore. If no water exists inside the wake radius the
gate now fails loudly with `water fixture missing` instead of blaming residency.

### After

`RESIDENCY OK`, then five consecutive runs: `R80 residency: pass=5 fail=0`,
`worst_step_ms` 0.50–0.87 across them. Nothing in `encounter_residency.gd`
changed — the whole fix is in `game/prototype/tests/residency_probe.gd`.

The lesson for the next probe: **a gate that builds its own fixture must pin the
world it builds it in, and must respect the radius of the system it is testing.**
Both halves of this failure looked like product bugs from the outside.

## 2026-09-22 — R58: the flask healed correctly for two seconds and never said so

Ricardo's complaint was "the HP potion does not heal over 2 s — it is meant to be
a heal-over-time, not an instant top-up." The ledger row had been re-scoped on
2026-09-21 with an explicit instruction: `flask_probe` is green, so **reproduce
the complaint in a real hunt before touching code**. That instruction is what
found the bug, and it was not in the flask.

### The reproduction

A throwaway scene (`_flask_repro`, deleted after use like `_seed_scan` before it)
pinned seed 41487, booted `main.tscn` with physics running, freed the creatures so
nothing could interfere, set `hp = max_hp * 0.3`, called `_use_flask()`, and then
printed the model and the HUD side by side every five physics ticks:

```
t=0.08 hp=50.8 (50.8%) bar=90.00 text=50 / 100 HP burn=1.92
t=0.42 hp=54.2 (54.2%) bar=90.00 text=50 / 100 HP burn=1.58
t=1.00 hp=60.0 (60.0%) bar=90.00 text=50 / 100 HP burn=1.00
t=2.00 hp=70.0 (70.0%) bar=90.00 text=50 / 100 HP burn=0.00
--- drip over: hp=70.0 bar_should_be=126.00 bar_is=90.00
```

The heal-over-time is **exactly right**: 20% immediately, then 20% more spread
linearly across 2.00 s on the real 60 Hz clock, landing on 70.0. The bar never
moved off the instant tick, and the text never moved at all — not during the burn,
not after it. From the player's chair that is indistinguishable from "the potion
gave me 20% and stopped". Ricardo was reporting the HUD.

Two candidate causes from the re-scope are now **disproved**: the HoT is not
cancelled by damage or dodge (nothing damaged the player here and the drip still
looked dead), and it is not a different potion.

### The cause

`main.gd::refresh_hud()` is the sole writer of `_hud.hp_bar.size.x`,
`_hud.hp_ghost.size.x` and `_hud.hp_text.text`, and it is **event-driven only** —
it runs on a hit, a kill, a level-up, an equip. `_update_gauges(delta)` runs every
frame from `_physics_process`, and it owned the damage-ghost *computation*
(`_hp_ghost` at main.gd:788) while the *drawing* of that ghost lived in
`refresh_hud()`. So any HP source that moves per frame rather than per event —
the flask being the only one today — was invisible until the next unrelated event
redrew the bar. A regeneration item, a bleed, or a pet's heal would all have hit
exactly the same wall.

### The fix

Split the readout out of `refresh_hud()` into `_refresh_hp_readout()` (bar, ghost,
text, low-HP pulse), and drive it from `_update_gauges()` behind a staleness check
against what is currently drawn (`_hp_shown` / `_max_hp_shown` / `_hp_ghost_shown`):
nothing moving means nothing redrawn, so the per-frame cost is a float compare.
The text write is additionally gated on `ceili()` changing, so there is no
per-frame string churn at 60 FPS. `refresh_hud()` now calls the same function, so
every existing caller keeps working unchanged. The burn also ends with a second
floating number — `+N HP` in the heal colour — so the drip is legible even at a
glance.

### The gate's blind spot

`flask_probe` was green *through* this bug, and it is worth recording why: it
drives `_process_flask()` by hand with `hunt.set_physics_process(false)` and
`p.set_physics_process(false)`, and it only sampled `hp_text` immediately after a
click — the one moment `refresh_hud()` had just run. A hand-driven model check
cannot see a rendering-cadence bug by construction. The probe now has a live-drip
section that re-enables physics, drinks, and asserts on the real clock that HP
climbs, the bar widens, the text changes, and that both settle exactly on the
healed total.

One detail in that section is itself a lesson: mid-burn the text is asserted to
have **moved**, not to be exact. The player node burns the flask in its own
`_physics_process` and main draws the gauge in its, so the readout trails the model
by at most one 16 ms tick — real, invisible, and not worth serialising nodes over.
Exactness is asserted after the burn ends, when HP has stopped moving.

Gate string (USAGE §10 updated): `FLASK OK — real R/click, 20% now + 20% over 2s
on the real clock, the bar and text follow the drip, exact budget, recharge never
heals, full/empty/dead feedback`. Re-ran green three times, plus the three gates
that share `refresh_hud()` — `level_up_probe`, `click_test`, `renewal_probe` — all
green.

---

## 2026-09-22 — R65: the pets had a kit on paper and a bite in practice

R57 gave the bond the *body* it was captured from. R65 is the other half of the
same promise: the skills that body fought with, and a reason to keep taking the
same pet out instead of the next one.

### What was actually broken

Nothing threw. `_roll_pet` rolled 2–4 `core.skill.*` ids, `Session.pets` stored
them, the companion card printed them — and `pet.gd` never read them. The pet
walked up and bit. That was the L4 known-issue in `10-systems-map.md`, and it had
two distinct causes stacked on top of each other:

1. **The content was not reachable at runtime.** `Session.load_content()` reads
   `res://prototype/data/<name>.json`, and the authored skills live in
   `content/core/skills/`. Nineteen snapshots now mirror into the prototype's flat
   data directory — the same mirroring every other content type already used.
2. **There was no executor.** `boss.gd` hand-writes each of its skills in
   `_cast`/`_strike`. Copying that shape would have made every new pet skill an
   engine change, which canon §10 forbids: content is data. So the pet dispatches
   on the snapshot's `behavior` field instead — seven of them (`melee_arc`,
   `projectile`, `aoe_field`, `channel`, `dash`, `buff`, `summon`) covering all 19
   authored skills — and reads the numbers in the units they were authored in:
   `windup_ticks / SIM_HZ` for seconds, `*_m * TILE` for pixels. Adding
   `core.skill.frost_nova` tomorrow is a JSON file, not a patch.

### The flat directory has teeth

`load_content("abyssal")` is the pet *family* definition. A naive
`pet_skill_def("core.skill.abyssal")` would have loaded it and handed back a
dictionary with no `behavior` and no `numbers`. The resolver therefore only
accepts a file whose own `id` equals the id that was asked for, and that exact
collision is now an assertion in the gate.

### The default that would have invented damage

`damage_coeff` defaults to **0.0**, not 1.0. Two authored skills (`void_step`,
`shrieking_curse`) carry no coefficient at all because they are pure mobility and
pure buff. A 1.0 default reads as "sensible" and silently gives both of them a
full-weapon hit. The gate asserts `void_step` moves the pet and takes the dummy's
HP down by exactly zero.

### A track of the pet's own

design/13 §7.1 specified the roll and said nothing about pet progression, so this
is a **design call made in implementation and flagged for Ricardo** (written into
§7.1, marked as awaiting confirmation). The shape:

- `bond_xp` +1 per kill the bond was **present** for — alive, not resting, inside
  the 11-tile leash of the corpse. A stabled pet banks nothing (the stables are a
  rest, not a career); a called wispling banks nothing.
- `6 + 2*level` kills for the next level → 8 to bond 2, **144 to the cap of 10**.
- One more rolled skill castable every 3 levels: **1 slot at capture, 4 at bond
  10**. The whole roll stays visible on the card from day one, locked slots
  printing the bond level that opens them — the prize you rolled is the reason to
  keep hunting with *that* pet.
- +3% hp/damage per bond level **on top of** the R57 chassis curve, never instead
  of it. A capped bond is ×1.27, not a second hunter.

The unlock had to land mid-hunt, not on reload: `main.gd::_credit_bonds` calls
`pet.refresh_bond()` on the live node after crediting, and because
`sync_pet_nodes` hands `pet.setup()` the **live** `Session.pets` dictionary
(`_record`, not a copy), the record, the node and the card all move together.

### Three hazards the executor had to respect

- A pet-laid field is `friendly: true` — otherwise the bond's Magma Breath burns
  the hunter who called for it.
- A pet bolt carries a real `shooter` (the friendly sweep dereferences it) and an
  **empty** `skill_def` — a populated one would run the *hunter's* synergy
  pipeline off a pet's cast.
- Summons take `uid = -1`. Real uids start at 1, and the HUD chips, rename and
  character panel all match on uid; a wispling with uid 0 would have shown up as a
  roster pet with a rename button.

### The gate

`tests/bond_probe.tscn` → `BOND OK — 19 skills resolve; curve/credit/unlock/
potency and all 7 behaviors held`. It drives the pet on the **physics** clock
(`physics_frames`, never process frames — the same headless flake that bit
`capture_probe`) and waits on `_skill_cd[0] > 0.0`, the one signal that means
"the cast branch ran", whatever the behavior was. Nine sections: id resolution
(including the family-collision and unknown-id guards), the curve and its inverse
`bond_slot_level`, a fresh capture (1 of N live, a pre-R65 record readable, an
unresolvable id not eating the slot it was paid for), credit (near banks, far
does not, resting does not, stabled does not, summon does not — then the same
thing again through a real `take_damage` → `_die` → `on_creature_died`), the live
unlock at 30 kills, potency layered on the chassis curve, one check per behavior,
the zero-coefficient rule, and a summon expiring on its own clock.

Mutation-verified twice: defaulting `damage_coeff` back to 1.0 produces exactly
one FAIL line (`void_step dealt 23.8 damage`), and deleting the leash check in
`_credit_bonds` produces exactly one (`a bond across the map banked a kill it
never saw`). Green ×3, with `capture_probe` and `level_up_probe` green beside it.

### One unrelated bug the probe surfaced

`creature.gd::_apply_presence_glow` is `call_deferred`-ed from `_ready`, and it
called `get_tree()` unconditionally. Any creature freed in the same frame it
spawned — the probe's teardown, or a stream cull in the real game — reached it
with a null tree and printed two errors per run. Guarded with `is_inside_tree()`.

## 2026-09-22 — R81: current assets and order-of-magnitude opportunities

Ricardo's request, verbatim:

> sup man, weekly session limit restarted so we can resume. Claude probably went through what you were previously on, so your new task will be to check up assets and see what might be up for improvement for order of magnitude gains. We got some new guidelines, as well, distilling what was previously done, so make sure to aalyze those, and perhaps propose improvements for order of magnitude gains:

The complete supplied Portuguese brief is preserved byte-for-byte in
`requests/2026-09-22-asset-pillars.md`. This is a fresh audit/proposal, not
authorization to replace the established art direction or restart completed
packaging work. Inspection starts at `3c006ac`; concurrent dirty R49 arena
files, the roadmap's prior edits, captures and Ricardo's root notes are retained.

Strategy: trace source art → hifi cleanup/scorecard → bundle → actual runtime
consumer; inspect images, quantify animation/catalog coverage, run relevant
offline gates, and compare the brief's rendering claims to primary sources.
Separate measured faults, unverified hypotheses and proposed investments.

**Completed audit:** `docs/research/asset-audit-2026-09-22.md`. The archived
brief passes `spec.verify_against_source` against the implemented prompt
constants; this is the existing R52 direction, not a different new style.
23 hifi tests and the offline synthetic selftest pass. Real Orun v2 samples
0/4/8/12/16/23 all reject: zero detected emission; five also fail silhouette
fill. The inspected output retains pale matte patches. Upright samples shrink
2×, death does not; a controlled 240→241px silhouette reproduces the abrupt
2× reduction. The six frames get six independent palettes; a duplicated
synthetic frame bundle still passes. Hunt has 10 bundles, zero hifi; Orun's
renderer still selects clip zero. The report separates format checks from
visual/animation approval and proposes a unified sequence compiler followed
by a hero/Orun/ordinary-creature scene, biome kit, local rig/bake pilot and
semantic VFX recipes. No production art or runtime was changed.

Fresh 5s GL assisted-Hunt profile: 60.002 average FPS, interval p95 17.424ms,
p99 17.786ms, max 18.307ms on Intel RPL-S, 57 peak creatures. Not a sustained
or mobile guarantee. Evidence and reproduction driver are preserved in
`docs/art/asset-audit-2026-09-22/`; no provider calls. The first sandboxed
capture lacked display access; the approved desktop retry succeeded. Current
Godot 4.6 documentation also supports a simpler Compatibility glow path, so
the old universal Vulkan-only glow claim needs qualification; no renderer
or glow settings were changed. R81 closes the requested audit, not the art
implementation rows. Concurrent Arena edits remain untouched. During the
audit the other session committed R49 as `f75f21d`, also carrying our initial
R81 ledger/journal checkpoint; the completed report/evidence remain local.

## 2026-09-22 — R49: the arena cockpit fits, and the gate can finally see it

Ricardo's demand, verbatim from the ledger: *"Arena interface needs polishing to
fit everything in."* The row had sat at NOW since 2026-09-14 behind a collision
warning; the warning is stale (the file's last writer is this session's R60
commit `1bb4e4d`, and Ricardo lifted the block: *"no other agent is currently
changing code. You have total autonomy!"*).

### Why a green gate and a broken screen disagreed

`game/arena/tests/console_layout_probe.gd::_walk` ends with

```gdscript
if not (c is ScrollContainer):
    out += _walk(c, canvas, label)
```

and that is *correct* in the general case — growing past the viewport is the
entire purpose of a ScrollContainer, so measuring its contents against the canvas
would fire on every healthy scroll in the project. But the arena's **whole left
column** was inside one. Every control Ricardo complained about was structurally
invisible to the gate: the probe walked ~800 controls per canvas, none of them
the run knobs.

So the gate came first. `_check_roster` measures the one thing `_walk` cannot:
the scroll's **content height against its own viewport height**, plus a per-child
height dump when it is over. Run red on purpose, it printed the bug as a number:

```
roster column: content 401 px in a 256 px viewport (OVER by 145)   # 640x360
roster column: content 401 px in a 346 px viewport (OVER by 55)    # 800x450
    Label        y=0    h=12  trainee — the build the net plays as
    ItemList     y=15   h=88
    HBoxContainer y=106 h=20  key
    Label        y=129  h=27  opponents — multi-select · none = native + scr
    ItemList     y=159  h=72
    GridContainer y=234 h=42  gens
    HBoxContainer y=279 h=20  speed
    HBoxContainer y=302 h=20  net
    Label        y=325  h=34  12 matches/gen (pop 6 × 2 opp) · jobs 16 · 20
    HBoxContainer y=362 h=24  isolated run
```

800x450 is not a corner case: it is what `DhConsoleFit._fit_window` picks on a
1080p desktop. 55 px over means the mode toggles (`isolated run` / `GPU (PPO)` /
`bracket`) are off-screen and the parallelism hint is sliced in half by the
viewport edge — which is exactly what the before capture shows.

### The fix is structural, not smaller numbers

Three alternatives were measured and rejected: rosters side by side (creature
names clip below ~114 px of width), an 8-column knob grid (each cell too narrow
for its SpinBox), and merging speed+net onto one row (the net caption
`default  [64, 64] tanh` overflows its own Button and trips the probe's `c`-axis
check). What landed instead:

- **The roster is the only thing that scrolls.** `key_row`, `grid`, `speed_row`,
  `net_row`, `_hint`, `mode_row` and `_cmd_label` moved out of the scrolled VBox
  and are pinned in `left_frame`. A knob you have to find an inner scrollbar to
  reach is a knob that is not there.
- **The lists got a floor, not a height.** `ROSTER_MIN_H := 28.0` (about two
  rows) + `SIZE_EXPAND_FILL` on both, and `SIZE_EXPAND_FILL` on the VBox inside
  the scroll — a ScrollContainer hands its child the child's minimum unless the
  child asks to expand, so without that last flag the lists sat at 28 px with
  blank space under them. The roster is now what grows when the canvas grows.
  The old fixed `88` / `72` are kept as `# PREVIOUS:` comments.
- **The title moved into a band already paid for.** `hb.offset_top = 28.0` has
  always reserved 28 px at the top for BACK alone. `TRAINING CONSOLE` is a
  heading, not a control, so it sits next to BACK in an HBox and the column gets
  a row back. BACK is built unconditionally now — R48's lesson: a button skipped
  under `_selftest` is a button the probe cannot measure.
- **The command echo is capped at two lines** with the whole invocation in its
  tooltip (`_set_cmd`, three call sites). A `train_run.sh` line with a full
  opponent list is longer than a 236 px column can ever show.
- **`opponents — multi-select · none = native + scripted`** wrapped to two lines
  and orphaned the last word; the rule stays on screen, the how-to-work-the-widget
  half went to the tooltip.

### Two probe bugs found on the way

`_text_width` measured every string with `ThemeDB.fallback_font` regardless of
the control's own font override. With the title moved into an HBox that override
started mattering: the probe called it `210 > 105 (over by 105)` at all seven
canvases — a false alarm, and in the other direction a blind spot for anything
drawn with a *wider* font than the fallback. `_font_of()` now honours the
override.

And `_check_roster` exempts `DhConsoleFit.MIN_CANVAS` (640x360) from the
no-scroll rule, because the arithmetic says it cannot hold the console: ~250 px
of pinned controls in a 326 px frame. `console_fit.gd` calls that canvas "the
fallback nobody chooses"; on every canvas `_fit_window` can actually pick, a
scrollbar is a failure. What is asserted there instead is `ROSTER_MIN_VIEW := 72`
— the lists may never be squeezed to slivers by what is pinned around them.

### Verification

```
CONSOLE LAYOUT OK — 7 canvases x 5656 controls, nothing leaves the canvas
on EITHER axis and no caption collapsed
```

with the roster line at each canvas: `74 px viewport (scrolls by 15)` at 640x360
(exempt, above the floor), then **fits** at 800x450 (164 px), 960x540 (254),
1024x576 (290), 1152x648 (362), 1280x720 (434), 1440x810 (524). Note 5656
controls measured against ~800 before — the pinned knobs left the ScrollContainer
and `_walk` now checks them directly, on both axes and for collapse, for free.

Capture: `game/prototype/tests/captures/ui_r49_fixed.png` (1600x900, 97 draw
calls, 4.1 ms) beside the before shot `ui_r49_progress.png`. Before: a scrollbar
down the whole column, the hint sliced, the mode row absent. After: both rosters
full-height, every knob and toggle on screen, no scrollbar.

---

## R51 — watching a match that has no window (2026-09-22)

The demand, verbatim from the ledger: *"Watch a match from the console — current
or last-best, for dh-env AND the arena, as a debugging tool."* Half of it was
already true: `godot --path game res://arena/arena.tscn` has always been
watchable. The other half is not a UI problem. **dh-env has no renderer and
should never have one** — it is the headless C++ environment the trainer steps
millions of times, and a window in it would be a window in the hot loop.

So the answer is a recording, not a viewer.

### What is recorded

`arena.trace.v1` — 23 floats per tick (`DH_ENV_TRACE_STRIDE = 1 + 2*11`): the
tick, then eleven per side — position x/y, aim x/y, hp fraction, windup timer,
dodge timer, the last committed action (`-1` = refused), and the **move x/y +
act the side's mind actually issued that tick**. The commands are the point. A
trace of positions is a movie; a trace of commands is an experiment you can
re-run.

Both sides carry theirs, including side B, whose slots hold what dh-sim's own
internal mind chose. A replay therefore drives BOTH fighters from the recording
and leaves the arena nothing to decide.

Four C symbols (`dh_env_trace_enable/frames/stride/side_fields`), a recorder
(`ml/eval/trace_match.py`), a replay mind (`game/arena/trace_policy.gd`, a real
`ArenaPolicy` that returns the recorded command for the current tick instead of
thinking), a ghost overlay (`game/arena/trace_ghosts.gd`), and `--replay` in
`game/arena/arena.gd`, which seats the bodies at the recorded frame-0 positions
because dh-env spawns on a random angle 200 px out and the arena spawns at ±150
on x.

Two gotchas cost time and are worth writing down. `DH_ENV_ACT_DODGE = 8` is a
**flag bit**, not an action id — decode `pick = act & 0x7`, `dodge = act & 8`.
And `fighter.gd` rewrites `"native"` to `"scripted"` for a `ProtoPlayer` and
sets `bot_drive` for everything that is not `"native"`; a replay handed
`"native"` would quietly be driven by the arena's own AI, which is exactly the
thing being measured. Hence a distinct `"trace"` spec through the same match.

### Why this is the parity instrument, not just a viewer

Every earlier instrument reports a **total** — win rate, health fraction,
damage per second, damage by source. Totals prove a divergence exists. They
cannot say when it began or which body began it, and two bugs that cancel read
as parity.

With identical commands into two runtimes, the distance between a body and its
ghost **is** the environment error. The verdict line says so directly:

```
ARENA REPLAY drift_mean_a=0.46 drift_peak_a=5.63 drift_mean_b=0.87 drift_peak_b=5.56
  break_tick_a=-1 break_tick_b=-1 gap_rec=28.8 gap_now=28.7
  recorded_winner=a recorded_hp=0.170/0.000 replayed_winner=a replayed_hp=0.178/0.000
  recorded_s=9.35 replayed_s=9.37
```

`break_tick_*` — the first tick that body crossed 20 px from its ghost (further
than a body is wide; `-1` = never) — is a divergence expressed as an index back
into the trace's own frames. `gap_rec`/`gap_now` — the mean distance *between*
the two bodies, recorded versus replayed — was added after the first run, and it
is the one that found the bug: drift says the pair moved differently, the gap
says whether they were fighting the same fight at all.

### The finding

| trace | gap recorded → replayed | first break | outcome |
|---|---|---|---|
| cinder_drake vs `scripted`, seed 3 | 28.8 → 28.7 px | never | kill → kill (0.170 → 0.178) |
| cinder_drake vs `native`, seed 3 | 16.8 → 62.2 px | tick 205 | kill → both alive |
| fen_boar_alpha vs `native`, seed 7 | 21.6 → 90.4 px | tick 372 | kill → **0.934/0.868** |

Read the first column, not the creature names. **Command-level replay is
faithful while the bodies are apart and breaks as soon as the recorded fight is
at contact range.** The ranged drake against a scripted opponent is a standoff
and reproduces to within half a pixel; the same drake against the native mind
closes to 17 px and diverges exactly like the boar does. The instrument is fine —
if the frame layout, the side stride, the dodge flag, the tick clock or the ghost
cursor were wrong, the ranged case could not land at 0.46 px.

What the arena cannot reproduce is a **contact equilibrium**. Trace forensics on
the boar: the recorded pair sits at 15.6 px apart, issuing **unit-length move
vectors** (median 1.00 across 1803 frames), and travels 1.9 px/s net. They are
both pushing at full throttle and going nowhere, because dh-sim's own
windup/recover/separation state is eating the motion. At tick 377 side B starts a
windup, its move command drops to 0.00 — and it moves at 49 px/s, which is pure
separation push with no locomotion behind it. Feed those same commands to the
arena and the pair simply drifts to 90 px and swings at air.

The separation constants match on paper (`Arena::separate_bodies()` was ported
from `creature.gd::_separate` verbatim in rule and in constants, `SEPARATE_RATE`
4.0 / `SEPARATE_RATE_PLAYER` 12.0), so the suspect is close-quarters locomotion
state — which bodies count as `is_player`, and whether a `bot_drive` creature
applies locomotion the same way in each runtime. That is R55's next lead, and it
is the first time the parity work has had a tick number to start from.

### The gate

`bash tools/trace_replay_test.sh` → `TRACE REPLAY OK`. It asserts the **ranged**
reference only: drift mean ≤ 3.0 px, peak ≤ 15.0, no break tick, the same winner,
and the pair gap within ±15%. The contact case is recorded and replayed too, but
printed as INFO — gating on a known-bad number only cements it, and the day it
converges someone will notice the line.

The pairing is deliberate: the reference is cinder_drake versus the **scripted**
mind, because the same creature versus **native** closes to 17 px and exhibits
the open bug. The gate's first run failed for exactly that reason — it recorded
with the recorder's default `--opp native` while the reference measurement had
used `--opp scripted`, two different matches (14.50 s vs 9.35 s), and it
faithfully reported the melee divergence as a gate failure.

### The console

**REPLAY ENV**, beside WATCH: one press records a dh-env episode for the selected
build with the selected key's latest net (falling back to `heuristic`, because an
env with no trained policy is still an env worth watching) and opens the arena on
the result. One `bash -lc` chained with `&&`, never `;` — a recorder that could
not build or load dh-env must not open a window on a stale trace from the
previous press. The seed advances on every press and is printed into the note, so
every press is a different match and every one of them is reproducible.

The seventh button cost 22 px. The action grid was three columns, and six
buttons over three columns is two rows; the seventh opens a third, and that row
comes out of the roster viewport — at 640x360 the lists went from the 74 px R49
measured to 52, under the layout probe's `ROSTER_MIN_VIEW` floor of 72. The fix
is the grid, not the button: four columns is two rows with one empty cell, and
`TOURNAMENT` (the widest label) still fits a 236 px column. The probe is back to
74 px and clean on both axes at all seven canvases — the floor caught a real
regression the moment it happened, which is what it is for.

### Verification

```
TRACE REPLAY OK
ARENA REPLAY drift_mean_a=0.46 drift_peak_a=5.63 drift_mean_b=0.87 drift_peak_b=5.56 break_tick_a=-1 break_tick_b=-1 gap_rec=28.8 gap_now=28.7 recorded_winner=a recorded_hp=0.170/0.000 replayed_winner=a replayed_hp=0.178/0.000 recorded_s=9.35 replayed_s=9.37
INFO (not gated — the known contact-range divergence): ARENA REPLAY drift_mean_a=53.21 ... gap_rec=21.6 gap_now=90.4 ...
CONSOLE SELFTEST OK — 2 generations, 8/12 matches, ETA 1:20, chart draws 1
CONSOLE LAYOUT OK — 7 canvases x 5796 controls (roster 74 px at 640x360, the R49 value)
```

## R79 — the Windows package shipped no GDExtension (2026-09-22)

Three findings from R77's packaging proof, logged so they would not be lost:
(a) the extension declared no Windows libraries, (b) the mingw tree emitted a
misnamed artifact, (c) the Windows export printed an unexplained
`completed with warnings`. They turned out to be two defects and one symptom.

### (c) was (a) — proven from the pre-fix log, not guessed

`genforge/candidates/packaging/export-windows.log` (2026-09-22 05:01), line 13:

```
WARNING: GDExtension: Biblioteca "x86_64" não encontrada para GDExtension: "res://addons/dh_godot/dh_godot.gdextension"
```

and line 663:

```
Project export for preset "Windows Desktop" completed with warnings.
```

The Linux log of the same run has neither line. So the "unexplained warning"
was the missing-library warning and nothing else — one fix closes both. The
export **finished anyway**, which is the whole shape of the bug: a Windows ZIP
that looks complete, passes every gate, and quietly runs the GDScript fallback
in `game/arena/neural_policy.gd` because `ClassDB.class_exists("DhPolicyNet")`
is false. Older than R77; as old as the Windows preset.

### (b) — the platform tag was following the host

`sim/libs/dh-godot/CMakeLists.txt` hard-coded `linux` into `OUTPUT_NAME`, so
the cross-build produced `libdhgodot.linux.template_debug.x86_64.dll`: says
linux, says debug, is a DLL. The tag is part of the FILENAME the `.gdextension`
names, so it has to follow `CMAKE_SYSTEM_NAME` — `Windows`→`windows`,
`Darwin`→`macos`, else `linux`. Two lines of `if`, and the packager's own
`sim/build-windows` tree now links a correctly named DLL.

### (a) — the two rows, and the build that fills them

`game/addons/dh_godot/dh_godot.gdextension` gained
`windows.debug.x86_64` / `windows.release.x86_64`, and
`tools/build_dh_godot.sh` gained the llvm-mingw loop that produces them. It now
builds **four** libraries, not two. The Windows step is guarded on
`$DH_MINGW_ROOT/bin/x86_64-w64-mingw32-clang++` and is a SKIP with a note when
the toolchain is missing — a clone without llvm-mingw must still end up with a
working Linux extension, so that case is not a failure. The DLLs are gitignored
alongside the `.so`s (`.gitignore:8`): binaries are built, not committed.

### Gate — three clauses proven, the fourth stated as unobserved

Roadmap gate, verbatim: *"`windows.release.x86_64` declared, built by the
cross-build, present in the zip, and the arena reporting the native policy path
on Windows."*

```
declared        dh_godot.gdextension, [libraries] windows.release.x86_64
cross-built     tools/build_dh_godot.sh → ✓ built: 4 libraries in game/addons/dh_godot/   (44 s)
in the zip      libdhgodot.windows.template_release.x86_64.dll   742,400 B
                sha256 f38f4a6a0e86fa2c95b1bfec8134b8564e967affa4b20906826e1650a782c8c2
                identical to the addon copy (same digest, byte for byte)
loadable        Export { Ordinal: 1  Name: dh_godot_library_init }   — matches entry_symbol
self-contained  imports: KERNEL32.dll + api-ms-win-crt-{convert,environment,filesystem,heap,
                locale,math,private,runtime,stdio,string}-l1-1-0.dll — UCRT stubs only,
                no libc++ / libunwind / libwinpthread to ship alongside
post-fix log    grep -c "completed with warnings" export-windows.log → 0
linux regress   POLICY PARITY OK — 256 forward passes matched bit-for-bit across
                linear, tanh, relu, leaky_relu
packager        PLAYABLE CONTENT OK · EMBEDDED ICON OK (both binaries) ·
                PACKAGE CONTENTS OK: windows / 17 files · PACKAGE OK
```

**The fourth clause was not observed and is not claimed.** `uses_native()`
(`game/arena/neural_policy.gd:104`) is read by exactly one caller,
`game/arena/tests/policy_parity_test.gd:78`, and `arena/tests/` sits in every
export preset's `exclude_filter` — so a shipped build has no code path that can
report which policy it is running. Confirming it needs a Windows machine or a
preset that carries the test. What is above is the honest substitute: the right
filename, the right export symbol, an import table a stock Windows box already
satisfies, and the same bytes inside the ZIP as on disk.

### R78 datum

The Windows ZIP went 59,579,269 → 59,938,069 B (+358,800 B, the release DLL):
56.82 → **57.16 MiB**. Still under GitHub's 100 MB hard limit, and R78's row
carries the new number.

### Files

`sim/libs/dh-godot/CMakeLists.txt` · `game/addons/dh_godot/dh_godot.gdextension`
· `tools/build_dh_godot.sh` · `.gitignore` · `docs/USAGE.md` ·
`docs/00-canon.md` §12.55 · regenerated `builds/dragon-heroes-windows.zip`.

---

## 2026-09-22 — R78: the distributable leaves the repository

### What the warning was actually about

GitHub warned on push that `builds/dragon-heroes-windows.zip` was 57.16 MB.
That framing is misleading, and following it would have produced the wrong fix.
The current pair of zips is 105.7 MiB and would have stayed under the 100 MB
per-file block for a while yet. The cost is that **git cannot compress a ZIP and
never forgets one**: every packaging run adds a whole new pair of ~110 MB blobs
that no future commit can remove.

Measured, rather than assumed (`git rev-list --objects --all` joined against
`git cat-file --batch-check`):

| what | size | objects |
| --- | --- | --- |
| `builds/dragon-heroes-*.zip` | **357.9 MB** | 8 distinct blobs (4 per path) |
| all of `builds/` | **440.7 MB** | 18 blobs |
| `.git` | **698 MB** | — |
| largest single object | **82.4 MB** | `builds/linux/dragon-heroes.x86_64` |

So roughly 63% of the repository is build output, and the biggest object is not
a zip at all but a loose executable from the pre-R77 era, when the export
directory itself was tracked. A correction to an earlier figure that reached
commit `3f7b8af`'s message: it says "Twenty-five versions". The real count is
**eight**. The commit was deliberately **not** amended — its hash is baked into
both published packages as `base_commit` and into the release tag, and amending
it to fix a sentence would invalidate the provenance the whole change exists to
provide. The correction lives here and in canon §12.56.

### The decision

Release assets, not Git LFS. LFS is a recurring bill for exactly the same bytes;
release assets are free, are not cloned, and report download counts. R78's row
had already recommended this, so no new decision was taken — only executed.

What stays in-tree is `builds/BUILD-INFO.json`, the index: release tag, URL,
`release_commit`, and per platform `file`, `bytes`, `sha256`, `built`,
`base_commit`, `working_tree_dirty`, `executable`, `download_url`. The name
collides with the `BUILD-INFO.json` **inside** each zip, deliberately: the inner
one hashes that package's contents (§12.53), the in-tree one hashes the
packages themselves.

### Two defects found by doing it

**1. `working_tree_dirty` was pinned true on every working checkout.**
`source_info()` in `tools/package_build.py` used `git status --porcelain`, which
lists untracked files. Ricardo permanently keeps untracked notes in the repo
root (`prompts queue.txt`, `sprites prompt.md`), so the flag read `true` on any
real checkout — and the first `publish_release.py --dry-run` duly refused:

    dragon-heroes-linux.zip was built from a dirty tree (3fd8ed3).

A provenance flag that is always true is worse than no flag, because a gate
reads it. Fixed to count tracked modifications only
(`git status --porcelain --untracked-files=no`), with the untracked count
reported separately as a number. Verified: repackaged with 22 and 21 untracked
files present, both packages report `working_tree_dirty: false`.

**2. `gh release create` tagged the wrong commit.** With no `--target`, it tags
the **server's** default-branch HEAD, not local HEAD. Observed directly:

    === tag points at (server):
    3c006ac7ca0e9072f0ec3ea334bb7a9e663b99f2
    === local 3f7b8af full:
    3f7b8af1269ece847d145759e7cea4c460752ccb

`3c006ac` was the pre-push server tip. The tag on a build release is the one
thing that has to be right — it is what "rebuild these exact bytes" means. The
publisher now passes `--target <base_commit>`, refuses to publish when the
packages disagree about their `base_commit`, and refuses when that commit is not
yet on the remote (an unreachable target is silently ignored, which is how this
failed quietly the first time). It then reads the tag ref back and compares.

Repairing it turned up GitHub behaviour worth recording: **deleting a tag reverts
its release to a draft**, and the release's URL becomes
`…/releases/tag/untagged-<hash>`. `gh release edit --draft=false` did not take;
the fix was `PATCH /repos/{o}/{r}/releases/{id}` with `draft=false` and
`tag_name` restated, after recreating the ref at the right sha.

### Published

    https://github.com/G-4-R-Y/DragonHeroes/releases/tag/build-20260922-3f7b8af

| platform | bytes | sha256 |
| --- | --- | --- |
| linux | 50,885,663 | `252e52e696a3971431f2fd05d2ad650f1e4ee110fafb007edca9ca0c56bc6421` |
| windows | 59,938,072 | `073d6a1ab42c6e8a2e549ca7cd7e6c85d9aa9f8b7ca93d089994ea1da8047145` |

Both built from `3f7b8af` with a clean tracked tree, both verified against the
server's own byte counts (a truncated upload is exactly what an index full of
local hashes would hide), and both confirmed downloadable anonymously at those
sizes. The release is public; the same bytes were already public in-tree, and
R78's row had pre-decided release assets, so this was execution rather than a
new outward-facing choice — but it is stated plainly here because it is the
project's first published artifact.

### The gate

`tools/clean_clone_gate.sh`, promoted out of the scratchpad because canon names
it. It clones `file://` with `--no-hardlinks`, asserts no zip came along,
asserts the index is present, then builds `sim/` from source, runs `ctest`, runs
`dh-server --entities 2000 --ticks 3000`, validates the content pack, and sends
a HEAD request to each `download_url` asserting `Content-Length` equals the
indexed byte count. It runs against a real clone rather than the working tree,
so a file that only exists because it was never committed cannot fool it.

### Still open, and it is Ricardo's call

`git rm --cached` caps future growth. **It does not shrink history.** The
440.7 MB of `builds/` blobs are in every clone and only a history rewrite
removes them — which invalidates every existing clone, and he runs concurrent
sessions on this tree. Not something to do autonomously.

### Files

`tools/publish_release.py` (new) · `tools/clean_clone_gate.sh` (new) ·
`tools/package_build.py` (`source_info`) · `.gitignore` · `builds/README.md` ·
`README.md` ("Download and play") · `docs/USAGE.md` §8 ·
`docs/tech/34-living-content-pipeline.md` · `docs/00-canon.md` §10 and §12.56 ·
`builds/BUILD-INFO.json` (the index itself) ·
`game/prototype/tests/{bond,capture}_probe.gd.uid` (untracked siblings of 140
tracked `.uid` files; an untracked one regenerates with a different UID in a
fresh clone).

## 2026-09-22 — R55-c: the loser could not slide along the wall it was touching

R55's residual had been stated for a day: every damage channel agreed, and the
episodes still ran ~1.8× longer in dh-env than in the arena. Row 110 of the
experiment ledger named a cause — port `creature.gd::_separate(delta)` into the
sim — and R59 killed it: separation landed in all four runtimes, and the arena
never ran it either (arena bodies are `bot_drive`, so `_state` parks at `"idle"`
and `_chase`, where the old call lived, never executed). The residual was left
with no candidate cause at all.

### The instrument first, because the roadmap's wording was degenerate

The roadmap asked for *time-to-first-death vs time-from-first-death-to-episode-
end*. Arena matches are 1v1 mirrors: the first death **is** the episode end, so
that split measures the whole clock against nothing. The measurable split with
the same intent is the one the scripted opponent itself defines —
`scripted_policy.gd` re-arms `_retreat_t = 2.5` the moment its hp drops below
`0.25`. So:

- **EXCHANGE** — spawn → the first moment either side falls below 0.25 hp.
- **CHASE** — that moment → episode end.

Both runtimes book it the same way. `arena.gd` samples `LOW_HP` once per
physics tick *before* the outcome checks (a killing blow that crosses the
threshold therefore lands at `low_t == duration`, an empty chase, not at `-1`)
and publishes `low_t_s` in the result dict; `env_parity.py` accumulates
`exch_ticks`/`chase_ticks` in dh-env and derives the same pair from `low_t_s`
for the arena. `exchange_s`/`chase_s` are deliberately **not** in `RATIO_TERMS`:
they do not move `verdict["agree"]`. They attribute a divergence the gate has
already caught, and `attribute_phase()` prints which phase owns what share.

First reading, cinder_drake v6.0 vs scripted, 32 eps, seed 4242:

| phase | dh-env | arena | ratio |
|---|---|---|---|
| exchange | 11.79 s | 10.87 s | 1.08× |
| chase | 8.73 s | 3.58 s | **2.44×** |

**89% of the whole clock gap lives in the chase**, and the exchange agrees. The
question stopped being "what does the sim mis-model about combat" and became
"what happens to two bodies at the ring after one of them turns to run".

### The cause: a movement fence that refused the whole step

`creature.gd::_move` was three lines:

```gdscript
var target := global_position + step
if world and world.is_walkable(target):
    global_position = target
```

All-or-nothing. A body running into the arena ring froze flat against it — it
could not even slide *along* the wall it was touching. The sim does not do that:
`Arena::clamp_disc` projects the post-move position radially back onto the ring
and **keeps the tangential component**, so a retreating body there keeps moving
around the boundary. Same fight, same policy, same ring radius (`kArenaRadius =
26.0f * 16.0f` == `ArenaWorld.radius := 26.0 * TILE` == 416 px): the sim's loser
slid and lived, the arena's stood still and died.

It is not only a parity bug. It is a gameplay bug that has always been there: a
fleeing creature pins itself in a corner and dies to a wall rather than to you.
`player.gd::_move` has had the axis-separated fallback since forever, and
`hunt3d.gd:307` calls its copy "wall slide, 2D parity". Creatures never got one.

### The fix, in two stages, because stage one was not enough

**Stage 1** — the general axis-separated fallback, copied from `player.gd`: try
the full step, else x-only, else y-only. Honest, and it moved most of the gap:
seconds 1.51× → 1.22×, chase 2.44× → 1.35×, win-rate gap 0.2188 → 0.0938. But
`dps_taken` stayed at **1.27×** against a 1.25× tolerance — the axis fallback
slides along a *circle* in two discrete chunks and loses distance every tick a
true radial projection would keep.

**Stage 2** — ask the world. `ArenaWorld` already had an unused
`clamp_inside(pos, margin) -> pos.limit_length(radius - margin)`, which is
`clamp_disc` exactly. `_move` now routes through it when the world offers the
method, and falls back to the axis slide for the tile grid in `world_gen.gd`,
which has no closed form. One deliberate semantic change came along: a null
world now moves freely instead of freezing, matching `player.gd`.

### Result — PARITY OK

cinder_drake v6.0 vs scripted, 32 eps, seed 4242, `core.arena.cinder_drake`:

| term | before | stage 1 | stage 2 |
|---|---|---|---|
| win_rate gap | 0.2188 DIVERGES | 0.0938 ok | **0.0000 ok** |
| seconds | 1.51× DIVERGES | 1.22× ok | **1.00× ok** (17.169 / 17.192) |
| dps_dealt | 1.43× DIVERGES | 1.17× ok | **1.06× ok** |
| dps_taken | 1.60× DIVERGES | 1.27× DIVERGES | **1.01× ok** |
| exchange | 1.08× | 1.10× | 1.11× |
| chase | **2.44×** | 1.35× | **1.10×** |
| verdict | PARITY FAILED | PARITY FAILED | **PARITY OK** |

### The trap that cost an hour on the way

Godot resolves a bare relative path against `res://`. A relative `--policy`
loads fine in dh-env (cwd-relative, Python) and silently fails in the arena: the
fighter runs the whole match at zero output and writes a perfectly well-formed
result with 0.000 bars in every channel, which reads as a catastrophic
environment divergence and is a typo. Three guards now: `env_parity.run()`
resolves `--policy` to an absolute path and `SystemExit`s if the file is
missing; `ArenaNeuralPolicy.loaded()` reports whether any layer parsed; and
`arena.gd::_start_episode` refuses to start a match whose neural policy did not
load, with an error that says *use an ABSOLUTE path*.

### Files

`game/prototype/creature.gd` (`_move`) · `game/arena/arena.gd` (`LOW_HP`,
`_low_t`, `low_t_s`, the unloaded-net refusal) · `game/arena/neural_policy.gd`
(`loaded()`) · `ml/eval/env_parity.py` (phase split, `attribute_phase`,
absolute-path resolution).

### The 64-episode matrix, measured both ways

The roadmap asked for the matrix re-run at 64 episodes. Running it only *after*
the fix would have proved nothing, so it ran twice — same seed, same nets, same
opponent, the only variable being `creature.gd::_move` (HEAD vs fixed). dh-env
is untouched by a GDScript change, and the numbers confirm it: **every dh-env
column is bit-identical between the two runs.** Only the arena moved.

Chase seconds, dh-env / arena (all vs `scripted`, 64 eps, seed 4242):

| build | dh-env | arena HEAD | arena fixed |
|---|---|---|---|
| bog_golem | 4.29 | 6.39 | 5.90 |
| cinder_drake | 8.96 | 3.87 | **8.54** |
| fen_boar_alpha | 18.89 | 13.48 | **20.65** |
| gloam_wisp | 4.64 | 8.50 | 11.70 |
| gloamfen_stalker | 6.10 | 3.45 | 8.93 |
| grave_shade | 19.60 | 7.41 | **18.87** |
| mire_serpent | 8.58 | 2.65 | **6.29** |

Summary terms:

| | HEAD | fixed |
|---|---|---|
| `agree` (the gate) | **0 / 7** | **3 / 7** |
| worst ratio across the matrix | 2.08× | 1.81× |
| mean \|chase ratio − 1\| | 1.098 | **0.415** |
| mean \|seconds ratio − 1\| | 0.361 | **0.138** |

### What is honestly left, and it is a different shape

The fence was a **one-directional bias**: the arena's chase was uniformly
truncated because the loser died against the wall. Removing it leaves a
residual of **mixed sign**, which is the healthier failure — no longer one
systematic error, just per-body driver differences:

- **Four builds converged** (cinder_drake 2.31× → 1.05×, grave_shade 2.65× →
  1.04×, fen_boar_alpha 1.40× → 1.09×, mire_serpent 3.24× → 1.36×).
- **Two overshot past parity** — `gloam_wisp` (1.83× → 2.52×) and
  `gloamfen_stalker` (1.77× → 1.46×, still improved but now on the other side).
  Both are the **kiting/ranged** bodies, and for both the *arena* chase is now
  the longer one: the sim ends their endgame too early, the opposite sign from
  the fence bug. gloam_wisp's worst ratio got worse (1.54× → 1.81×) while its
  worst absolute gap improved (0.165 → 0.149). That is the new R55 residual, and
  it is far better posed than the old one: one phase, two named builds, known
  sign, and the instrument to measure it already exists.
- **bog_golem's `worst` gap reads 0.234 → 0.422** and should not be read as a
  regression: that term is `win_rate` in a **mirror matchup with a greedy
  decode**, which is near-deterministic — a hair of divergence flips every
  episode at once. Its rate ratios all improved (1.14× → 1.08×). The ledger
  already says to judge this probe on rate ratios, not win_rate.

### Gates

MENU · SPAWNTEST (creatures=58, nearest=176 px) · STREAMTEST (worst_apply
1.27 ms of a 2 ms budget) · GROUND STATE · RESIDENCY (worst_step 1.072 ms) ·
CAPTURE (40 rolls) · BOND (19 skills, all 7 behaviors) · LEVEL UP · CLICKTEST
(6/6) · FXSTRESS (frame 3.75 ms of 16.6, 0 nodes after warmup) · ROAM BOSS ·
ARENA SELFTEST (4 matchups, HUD 7072 frames) · CONSOLE SELFTEST · COSMETICS ·
TRAINER STOP · TRACE REPLAY · MP TEST — all OK. `validate_content.py`: 46
definitions, 11 types, 5 registries, 0 problems. `pytest ml/tests
genforge/tests`: 291 passed, 1 skipped; the 2 reported failures are
`ModuleNotFoundError: torch` under the *system* python — all 7 pass under
`ml/.venv/bin/python3`, which is where torch lives.

---

## R64 + R43 — the cooldown cue, and the two defects its captures found (2026-09-22)

R43 asked for two things and had only ever received one. The CENTRAL readout
landed earlier as `HudSkillChip` — a 26×26 tile with a procedural 1 px glyph per
`kind`, a top-down cooldown sweep and a numeric countdown under 10 s. The
sentence after the comma, *"peripheral visual cues so players need not
constantly watch timers"*, was still open, and R64 ("visual cues for skill
cooldowns") was the same demand arriving a second time. So R64 was built as
R43's missing half rather than as a second, competing readout, and both rows
close together.

### Where a peripheral cue can live

The constraint is that the eye is on the fight, not the corner. That rules out
anything at the edge of the screen — which is where the existing chips already
are — and it rules out anything that needs to be read, because reading is the
attention cost R43 is complaining about. What is left is the one place the eye
is already looking: **the ground under the hero**. The fan is four segments on a
13 px radius spanning `PI*0.18 → PI*0.82`, the lower arc, under the body and
away from the character art. Segments index *down* from `CUE_A1` so slot 0 sits
leftmost — the same left-to-right 1→4 order the hotbar uses, because a cue that
maps to the wrong key is worse than no cue.

Colour is not chosen locally. Each segment is tinted from
`HudSkillChip.KIND_TINT`, the dictionary the chips themselves read, so the fan
and the hotbar are two renderings of one table. Two surfaces that agree by
construction cannot drift.

### One edge detector, two surfaces

The interesting failure mode in cue work is the two displays disagreeing about
the same skill — chip flashes, fan does not, or worse, the fan flashes twice
because each surface found the transition on its own frame. `_update_cues` in
`player.gd` therefore finds the cooldown→ready edge exactly once per cycle,
guarded by `if ready and not _cue_ready[i] and was > 0.0:` — the `was > 0.0`
term is what stops a slot that was never on cooldown (a freshly assigned skill,
a respawn) from blooming at birth. The fan reads `_cue_bloom` directly;
`main.gd` reads the same array through `skill_ready_flash(i)` and uses it to
flash the chip frame and fire one soft blip. Four skills coming back on the same
frame produce one sound, not a chord, for the same reason.

### Motion is reserved for the transition

A ready slot draws a calm, motionless bright arc. The ONLY animation in the
whole system is the one-shot 0.35 s bloom on the edge. This is deliberate and it
is precisely R43's "no false-ready/cue spam" acceptance term: if ready-ness
pulsed, four ready skills would give a permanently churning fan at the hero's
feet and the peripheral channel would become noise — the exact thing the demand
asked to remove. Standing still is the feature.

The one addition beyond ready/not-ready is the **denied press**. Pressing a slot
whose cooldown is longer than the 0.15 s input buffer previously did nothing at
all — no sound, no mark, indistinguishable from a dropped input. It now draws a
short red tick just inside the arc for 0.25 s. `INPUT_BUFFER_S` itself is
untouched: this answers the *feedback* half of the open buffer question without
touching combat feel, so no design call is owed.

Bots return early in both `_update_cues` and `_draw_skill_cues` on `bot_drive`,
so arena and training frame cost is unchanged. The draw budget is asserted live
rather than assumed: `cue_arcs ≤ 12`, measured 8.

### The gate, and proving it has teeth

`game/prototype/tests/cue_probe.tscn` runs 8 lettered assertions over a quiet
start, a cast and return, an emptied slot, a denied press and a grave. A passing
probe proves nothing by itself, so both guards were mutated:

- dropping the `was > 0.0` edge guard → **4 failures**
- widening the deny window from `> INPUT_BUFFER_S` to `> 0.0` → **exactly 1**

Both restored after.

### The capture, and the coordinate bug in it

`UI_TAG=cue` in `tests/ui_capture.gd` seeds a throwaway `cue_capture` hunter —
never `"Hunter"`, because `learn_node`/`assign_skill` both call `request_save()`
and a capture must never edit a player's character — carrying four DIFFERENT
skill kinds (`rv_gash` melee_arc, `rv_hurled_cleaver` projectile,
`rv_artery_storm` nova, `rv_earthsplitter` field) so one frame shows four tints
at once. `_stage_cue` then drives all four states through the SHIPPING path:
real seconds written onto `skill_cds` (3.1 / 1.2 / 0.05 / 0.0) and a real
`slot2` press, so slot 1 is deep in cooldown, slot 2 is nearly back AND freshly
denied, slot 3 is caught inside its own genuine 0.35 s bloom and slot 4 is calm.
Nothing is posed. The run printed
`UI_CAPTURE CUE flash=0.857 deny=0.867 arcs=8`.

640×360 of canvas cannot show a 13 px fan, so the tag also writes two
nearest-neighbour insets at 4× the logical pixel: `_feet` and `_hotbar`. **The
first attempt cropped the wrong region.** `project.godot` runs a 640×360
viewport with `window_width_override=1280` and `stretch/scale_mode="integer"`,
so `get_global_transform_with_canvas().origin` is in CANVAS space (640×360)
while `get_viewport().get_texture().get_image()` returns the WINDOW (1280×720) —
every rect was off by half. Fixed by computing
`k := img.width / viewport.visible_rect.size.x` at the call site, scaling the
rect by `k` inside `_inset`, and replacing the hard `× 4` magnification with
`zoom := maxi(1, int(round(4.0 / k)))` so the inset stays 4× the *logical* pixel
whatever the window override is. Pixel art must be magnified by whole pixels or
the capture lies about what the renderer drew.

Both languages captured on `DISPLAY=:1` under `--rendering-method
gl_compatibility` at `--max-fps 60`, with `XDG_DATA_HOME`/`XDG_CONFIG_HOME`/
`XDG_CACHE_HOME` pointed at the scratchpad so the run cannot alter a player's
language, volume or saves:

| | EN | PT |
|---|---|---|
| fps | 60.0 | 60.0 |
| draw_calls | 97 | 102 |
| process_ms | 16.2 | 18.4 |
| cue_arcs | 8 | 8 |

The feet inset reads left→right exactly as designed: pale-steel sliver deep in
cooldown, cyan nearly full with the red deny tick *inside* toward the body, gold
mid-bloom with its halo *outside*, calm green. The hotbar inset shows the same
four kinds with matching glyphs and chip 3 carrying the ready flash.

### Two defects the captures found, which are NOT R64's

Logged as **R82** rather than fixed inline, because neither is the cue system
and both deserve their own measured fix:

1. **The hotbar names run together.** `main.gd:1734` gives each name Label a
   32 px box on a 34 px chip pitch while `main.gd:2035` fills it with
   `.left(8)` at font size 8 — 8 glyphs need ≈40 px. EN reads
   `Gash Hurled Artery Earths` as one smear; PT is worse. This is the same
   defect the systems map has carried as "skill-bar labels clip at fixed
   widths (Lumenpie)" — now with the measurement attached.
2. **`game/living/world_lairs.gd:68` is hardcoded English** and never passes
   through `ProtoLang`, so `"A distant bell calls %s · SHRINE %dm"` stays
   English in the PT frame — the one English sentence in an otherwise fully
   Portuguese HUD, visible in `ui_cue_pt.png`.

### Gates

CUE (8 assertions) · FLASK · MENU · LEVEL UP — all OK.
