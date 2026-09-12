# Roadmap — the one consolidated list (2026-09-10)

Ricardo decides DIRECTION (which lever, when); harnesses execute inside it.
Every item points at its law doc. Statuses: NOW (in flight) · PICK (awaiting
Ricardo's call) · SCHEDULED (decided, sequenced) · BUDGET (blocked on money).

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
`/tmp/dragon-heroes-codex-content-engine`, originally based on `b3d41e9`, now rebased onto committed `8568d26`.
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
