# Roadmap — the one consolidated list (2026-09-10)

Ricardo decides DIRECTION (which lever, when); harnesses execute inside it.
Every item points at its law doc. Statuses: NOW (in flight) · PICK (awaiting
Ricardo's call) · SCHEDULED (decided, sequenced) · BUDGET (blocked on money).

## NOW — finish what is open

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
