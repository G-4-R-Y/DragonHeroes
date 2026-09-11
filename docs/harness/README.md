# Harness Memory — START HERE (any harness, any session)

Ricardo (2026-09-10): "create specs and roadmap docs so any harness can
continue your work. Centralize them." This directory is the DURABLE layer.
`HANDOFF.md` (repo root) is the VOLATILE delta (where the last session
stopped). `docs/00-canon.md` §12 is the append-only decision log (current
through item 38). Nothing here duplicates a law doc — it points at it.

## Read order (15 minutes to full context)

1. `CLAUDE.md` — standing directives + hard rules (legal/architectural).
2. This file — invariants, gates, doctrine, environment.
3. `docs/harness/10-systems-map.md` — every system: status, law doc, files, gate.
4. `docs/harness/20-roadmap.md` — the one consolidated roadmap.
5. `HANDOFF.md` — the last session's exact stopping point + watch items.
6. `docs/00-canon.md` §12 items 27→38 — why things are the way they are.
7. `docs/USAGE.md` — every runnable command (play/co-op/arena/train/gates).

## Invariants (violating these has bitten us — each is a canon lesson)

- **Renderer**: `gl_compatibility` default; GLES3/WebGL2-safe shaders only;
  640×360 canvas_items integer 2× stretch (fragments run at window res).
  **NEVER launch a Vulkan window** (crashed Ricardo's X once) — `tools/
  run_vulkan.sh` is Ricardo-only.
- **2D pixel art is canon** (§12.27, §12.33). The 3D view (`prototype3d/`) is
  an experiment; never let it pull work from the 2D game.
- **No worldgen logic engine-side** — the C++ generator emits chunks; Godot
  only renders windows (§12.32). `sim/` never imports Godot; `game/` has no
  gameplay rules (prototype GDScript is a PROTOTYPE HARNESS, marked so).
- **Gates assert OUTCOMES, not just "no errors"** (§ spawn_probe incident:
  dead code passed error-grep gates for a day). Add an outcome gate with
  every system.
- **The capture loop** (§12.28): visual work is verified on FRAMES —
  `tests/vfx_showcase.tscn` (hunt), `tests/ui_capture.tscn` (any scene:
  `UI_SCENE/UI_TAG/UI_WAIT`), PNGs land in `game/prototype/tests/captures/`.
  Windowed GL only (no xvfb here). Lab sheets validate effects, captures
  validate frames — review the composite after every visual change.
- **Light registry** (§12.30): one gather in darkness.gd → shader globals
  `dh_light_tex`/`dh_light_count`; N consumer shaders; never couple a
  consumer to the gatherer.
- **Pools** sized for HIGH at load; intensity gates USAGE, never allocation;
  `_pool_debug()` on every pool; `fx_stress` is the budget gate.
- **Typography**: Pixel Operator 8/16 px only, sizes via `ProtoTheme.SIZE_*`;
  bare labels need the DEFAULT THEME restamped (§12.31 trap).
- **Content is data**: `pack.type.name` IDs, `content/schemas/`,
  `tools/validate_content.py` in every gate run.
- **No cloud GPUs while budget is absent** (§12.38) — arenas/ML/mesh run on
  local GPUs; the Cloud Run tier is PARKED (commented out, not deleted) and
  is the intended full-quality path when budget returns.
- **Legal hard rules** (CLAUDE.md): no paid randomness; server-authoritative;
  economy core sole writer; marketplace web-only.

## The gate suite (run ALL before any commit — one line each, from `game/`)

`docs/USAGE.md` §Dev gates is authoritative. In one breath:
`--import` once after new class_name/.gdshader → `tests/menu_probe.tscn`
(MENU OK — the main scene BUILT; 2026-09-11: display.gd's parse error had
been aborting the menu's `_build` for 9 days behind "no errors" boot checks)
→ hunt boot ×2 (`main.tscn --quit-after 150`, no error lines) →
`tests/spawn_probe.tscn` (SPAWNTEST OK)
→ `tests/stream_test.tscn` (STREAMTEST OK, worst apply ≤2 ms) →
`tests/click_test.tscn` (CLICKTEST DONE — ALL PASS; guards PT-BR SAIR/Talho)
→ `tests/fx_stress.tscn --quit-after 260` (FXSTRESS OK) → `arena/arena.tscn
-- --selftest` (ARENA SELFTEST OK) → `arena/console.tscn -- --selftest`
(CONSOLE SELFTEST OK) → `arena/tests/cosmetics_test.tscn`
(COSMETICS OK) → `bash tools/mp_test.sh` (MP TEST OK) → `python3 -m pytest
ml/tests genforge/tests -q` → `python3 tools/validate_content.py` (0 problems).
Watch item: spawn_probe flaked ONCE right after `--import` (2026-09-10),
passed on rerun — rerun before declaring it broken.

## Operational gotchas (cost real time before)

- `pkill -x godot` (never `-f`). `grep -c` exits 1 on zero matches — chain
  with `;` not `&&`. Headless only for gates; windowed only for captures.
- Lab/agent outputs go IN-REPO (captures/, candidates/), never /tmp.
- Python 3.10, no `python3-venv` apt → `pip3 install --user virtualenv` then
  `python3 -m virtualenv .venv`. CUDA: driver 570 / runtime 12.8; toolkit
  12.8 at `/usr/local/cuda` but `/usr/bin/nvcc` is 11.5 and shadows PATH —
  `export PATH=/usr/local/cuda/bin:$PATH CUDA_HOME=/usr/local/cuda
  CUDACXX=/usr/local/cuda/bin/nvcc` before any extension build.
- GPU: RTX 4050 Laptop 6 GB. 31 GB RAM. Display runs on the Intel iGPU (the
  `nouveau` libGL lines in Godot logs are noise).
- Sim binary: `sim/build/libs/dh-server/dh-server` (`cmake --build sim/build
  --target dh-server`); world_gen also finds it next to exported executables.
- Commit trailer: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
  Version bumps live in commit titles (v0.3.0 is HEAD's era).

## Working doctrine (Ricardo's, distilled — also in the harness memory files)

- Consult Ricardo on DIRECTIONAL decisions; execute freely inside them.
- Reusable, decoupled, extensible code; registries/seams over coupling.
- Token economy: work INLINE. Background agents/workflows are OFF by default —
  two workflows exhausted the session quota on 2026-09-11 and their work was
  lost mid-flight (canon §12.39). Spawn them only when Ricardo asks in the
  moment; keep the main context lean with /compact instead.
- Orders of magnitude over increments; capture-verified; docs updated IN THE
  SAME CHANGE (canon note when deviating).
- Never delete a decided-then-paused design — comment it out and log the
  history (Cloud Run tier precedent).
