# Roadmap — the one consolidated list (2026-09-10)

Ricardo decides DIRECTION (which lever, when); harnesses execute inside it.
Every item points at its law doc. Statuses: NOW (in flight) · PICK (awaiting
Ricardo's call) · SCHEDULED (decided, sequenced) · BUDGET (blocked on money).

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
