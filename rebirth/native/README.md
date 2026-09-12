# Rebirth · native C++20 + OpenGL slice — BUILDS, GATED, CAPTURED

The plan's "custom C++" row, made concrete: the same vertical slice with no
engine — a 30 Hz fixed-step deterministic simulation (`src/sim.*`) and a thin
OpenGL 3.3 core renderer over X11/GLX (`src/render_gl.*`). It answers the
plan's question "what does zero-engine cost?" with numbers, and it is the
closest sibling to the parent's `sim/` doctrine (fixed tick, interpolation,
no allocation in the loop, pooled everything).

## Build · gate · capture

```bash
cd rebirth/native
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j
./build/rebirth-native --sim-only --verify        # gate → REBIRTH-NATIVE OK (exit 0) / FAIL (1)
ctest --test-dir build                            # the same gate + determinism (2 tests)
DISPLAY=:1 ./build/rebirth-native --autopilot --capture captures/native_fight.ppm --frames 400 --force-skill breath
python3 -c "from PIL import Image; Image.open('captures/native_fight.ppm').save('captures/native_fight.png')"
```

Deps: cmake ≥ 3.22, g++ ≥ 11 (C++20), libGL + libX11 dev headers (`pkg-config gl x11`).
No GLFW/SDL — the window is raw Xlib + GLX; functions load through
`glXGetProcAddressARB` (`RB_GL_FUNCS` macro table in `render_gl.cpp`).
Windowed runs from an agent shell land on Intel Mesa GL (NVIDIA GLX is not
reachable from that shell); Ricardo's own X gets the RTX.

## Architecture

- `sim.hpp/.cpp` — `State` (hunter, dragon, pet, fields, meteors, telegraphs,
  stats, rng), `Intent`, `step(State&, Intent, dt)`, `reset_fight` (keeps
  stats across rematches), `autopilot(State) -> Intent` (the gate's player),
  `state_hash` (FNV-1a over the whole state — the determinism test), the
  five-skill FSM identical to `godot3d/scripts/dragon.gd`.
- `geometry.hpp/.cpp` — valley heightfield (same formula as the Godot slice),
  procedural meshes (capsule hunter, wyrm body, rocks), `.dhm` ingest.
- `render_gl.hpp/.cpp` — lit shader (vertex colour, moon directional light,
  ≤ 16 nearest point lights, exp fog, soft tonemap), unlit additive
  telegraphs, UI rect shader (bars; no text), interpolation alpha between the
  last two sim states, PPM capture.
- `main.cpp` — CLI (`--sim-only --verify`, `--autopilot`, `--capture`,
  `--frames`, `--force-skill`, `--glb-dir`), fixed-step accumulator, X11 input.

`.dhm` (Dragon Heroes mesh): magic `DHM1`, u32 vertex count, u32 index count,
per-vertex 9 × f32 (pos, normal, rgb), u32 indices — written by
`../assets/tools/glb_to_dhm.py` from any GLB (node TRS baked).

## Last gate + numbers (2026-09-12, this box)

```
REBIRTH-NATIVE OK — skills breath:1 meteors:1 tail:2 gust:5 pounce:1 · enrage · iframe avoids 5
· max combo 9 · hits 35 · dmg taken 16 · kills 1 · toast · rematch
determinism OK — hash 3ee260753c412fd1 over 1225 ticks (two runs identical) · 1.6–2.6 M ticks/s
ctest: 2/2 passed
```

Windowed (1280×720, Mesa Intel RPL-S GL 4.6 core): render avg 9.5–10.3 ms,
p99 12.6–15.2 ms → the 60 FPS directive holds on the iGPU fallback with
headroom. Captures: `captures/native_breath.png`, `captures/native_fight.png`.
