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
| R08 | SCHEDULED | Unload distant hordes from active memory/cap, then restore them when revisited. | tech/29, C++ authority; identity/HP/death persistence and bounded active-memory outcomes |
| R09 | SCHEDULED | Fix distant map-generation stalls and missing biome variety; overhaul biome textures and atmosphere to match the shrine aesthetic. | tech/24/29, design/17/26; long-distance streaming/biome gates and captures |
| R10 | SCHEDULED | Redesign HP/dodge HUD and make the Ember Flask clearly visible. | design/11/17; cooldown/resource readability and gameplay captures |
| R11 | SCHEDULED | Turn Haven into a place with NPCs; enrich forge/enchanting and related facilities; salvage items into crafting materials; craft improved/unique/fixed-rarity randomized gear. | design/14/15, no paid randomness; inventory/material conservation, persistence and UI outcomes |
| R12 | SCHEDULED | Upgrade all particle families to the dark-VFX quality bar; add wings, auras and cosmetic items earned through boss drops, hunting, quests, crafting, forge and enchanting. | design/18, economy boundaries; bounded VFX, acquisition/equip/save outcomes |
| R13 | SCHEDULED | More classes, build choices, meaningful skill synergies, aesthetic customization and distinct equipment visuals; reflect them in the asset pipeline. | design/10/11/26, stable data IDs; real skill/build effects and visual coverage |
| R14 | SCHEDULED | Explain and provide a sustainable local asset pipeline; avoid permanent dependence on cloud credits. | tech/23/34, canon local-compute directive; offline generation and explicit optional-provider costs |
| R15 | SCHEDULED | Fix the PNG/application-icon attachment or packaging problem reported for the binary. | tech/34 packaging; inspect package files, icon association and executable resources; clarify symptom if needed |
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
  STATUS: logged 2026-09-14, working item 1 first.

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

### ON RICARDO
- **UE 5.4 install** (~45 GB + Epic account) → `rebirth/unreal/INSTALL.md`.
- **`sudo apt install python3.10-venv`** (workaround active).
- **Play the slices for feel** — gates prove loops, not fun.
