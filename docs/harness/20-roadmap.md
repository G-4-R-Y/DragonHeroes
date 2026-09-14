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

  | R44 | NOW | Bosses still do not spawn like hordes do. | with R36/R29; encounter spawn parity between boss and horde paths, actual in-world spawn evidence |
  | R45 | NOW | Still a single biome in play. | with R09/R29; distinct biome generation reaching the played world, not only the generator |
  | R46 | ANSWER | "How are assets gen going?" — a question, owed a status answer, not a task. | 13b/13c; local image-gen repo still not delivered to reference_repos |
  | R47 | NOW | Document the reward function fully, INCLUDING every version with its rationale — trace the whole story up to the current one. | tech/25 §5.2, tech/37; a versioned changelog, not a snapshot of the current weights |
  | R48 | NOW | GenForge console cannot return to the main menu. | genforge console scene; real Back navigation evidence (same class as R38's arena Back) |
  | R49 | NOW | Arena interface needs polishing to fit everything in. | design/23/17; COLLISION RISK — the other session owns game/arena/console.gd, check before editing |
  | R50 | NOW / the big one | Tune arena training to learn from SCRIPTS first, then self-play once reliably winning; then run a train_all experiment (PPO is fine alone) with enough steps that the model actually converges. | tech/25 §4.2, tools/train_all.sh; a real curriculum + a converged run, not a smoke run |

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
