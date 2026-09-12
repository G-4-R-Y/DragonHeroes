# Rebirth · Godot 4 3D slice — RUNS, GATED, CAPTURED

The plan's §4 vertical slice in Godot 4.6 (GDScript, everything built in code,
no scenes beyond the root). It is the executable truth for the shared combat
table today: the same fight the UE scaffold implements, playable and gated.

## Run

```bash
cd rebirth/godot3d
godot --path .                                   # play (Ricardo; any renderer)
REBIRTH_SELFTEST=1 godot --headless --fixed-fps 60 --path .          # gate → REBIRTH3D OK / FAIL, exit 0/1
REBIRTH_CAPTURE=fight REBIRTH_CAPTURE_FRAMES=400 REBIRTH_FORCE_SKILL=breath \
  godot --rendering-driver opengl3 --path . --resolution 1280x720      # windowed capture → captures/rebirth_fight.png
```

Controls: WASD move (camera-relative) · mouse orbit · **Space/Shift dodge**
(3 charges, i-frames, input buffer) · **J / LMB attack** (3-hit combo, buffered
links) · **K / RMB skill** (lunge, 45 dmg, 6 s) · **E pet HOWL** (stagger +
heal 10) · **Tab/Q/MMB lock-on** · **R rematch**.

Env: `REBIRTH_SELFTEST=1` (headless autopilot gate, 300 s sim limit),
`REBIRTH_CAPTURE=<tag>` + `REBIRTH_CAPTURE_FRAMES=N` + `REBIRTH_FORCE_SKILL=id`
(windowed capture at frame N, then quit), or `REBIRTH_CAPTURE_EVENT=
enrage|slain|tele:<skill>` + `REBIRTH_CAPTURE_DELAY=s` (shoot s seconds after
the event — deterministic composition; capture mode forces a 1280×720 window),
`REBIRTH_GLB_DIR` (override the generated-mesh folder; default `../assets/glb`).

The three reference frames were shot with:

```bash
REBIRTH_CAPTURE=breath REBIRTH_CAPTURE_EVENT=tele:breath REBIRTH_FORCE_SKILL=breath ...   # the cone as the aim locks
REBIRTH_CAPTURE=fight  REBIRTH_CAPTURE_FRAMES=400 ...                                       # mid-fight, embers + sparks
REBIRTH_CAPTURE=enrage REBIRTH_CAPTURE_EVENT=enrage REBIRTH_CAPTURE_DELAY=1.7 ...          # after the retreat leap
```

## Renderer

`project.godot` pins **gl_compatibility** because the agent shell cannot open a
Vulkan window (parent harness rule) and Intel Mesa GL is what runs here. The
slice detects the method at boot: on Forward+ it additionally enables
volumetric fog, SDFGI and SSAO (`slice.gd::_build_environment`). Flipping
`renderer/rendering_method` to `forward_plus` is Ricardo's call (his RTX 4050,
his window) — the SOTA-graphics comparison against UE is not honest until then.

## What is in the scene

| Script | Class | Role |
|---|---|---|
| `slice.gd` | root | mode detection, environment (night sky, moon, fog, glow, ACES), builds everything, loop (fight → drop toast → rematch), capture |
| `valley.gd` | `RbValley` | 180 m bowl: chunked SurfaceTool heightfield with vertex colours, MultiMesh rocks (160), glowshroom clusters (teal lights), fire pits (warm lights + embers), ground mist |
| `hunter.gd` | `RbHunter` | states idle/dodge/attack/skill/hitstun/dead; buffers, dodge-cancel, combo links, arc hit tests vs the dragon's hit radius, i-frame stats |
| `dragon.gd` | `RbDragon` | five skills (breath cone + fire field, meteor volley, tail sweep, wing gust, pounce), telegraph → commit → act → recover, enrage at 40 % (faster, 5 meteors, RETREAT LEAP every 18 s → meteors → pounce), stagger, death squash |
| `pet.gd` | `RbPet` | heel, nip (6 dmg / 4 s), HOWL (12 s: heal 10 + stagger ≤ 14 m) |
| `fx.gd` | `RbFx` | POOLED telegraphs: 16 rings, 4 cones, 6 fire fields, 8 meteors, 10 sparks, 3 slashes; `overflow` counter is a gate assertion |
| `camera_rig.gd` | `RbCameraRig` | orbit + lock-on framing, ground clamp, smoothing |
| `hud.gd` | `RbHud` | single `_draw` Control: bars, charges, cooldowns, combo, telegraph/punish cue, toast, frame/phys ms |
| `autopilot.gd` | `RbAutopilot` | the gate's player: dodge at ≤ 0.22 s telegraph left, punish recover/stagger, howl, rematch |
| `selftest.gd` | `RbSelftest` | asserts OUTCOMES (5 distinct skills, enrage, ≥ 1 i-frame avoid, combo ≥ 3, a kill, the toast, a rematch, fx overflow 0, no node growth) |
| `glb_hook.gd` | `RbGlb` | runtime GLTF load of `assets/glb/<name>.glb` (falls back to code-built placeholders) |
| `rb_input.gd` | `RbInput` | InputMap setup + one `Intent` struct per tick (the seam an RL policy or dh-sim would drive) |

## Last gate + captures (2026-09-12, Intel Mesa GL, this box)

```
REBIRTH3D OK — sim 41s in 0.2s wall · skills {breath:1, gust:5, meteors:1, pounce:1, tail:2} · enrage
· iframe avoids 2 · max combo 9 · hits 34 · dmg taken 40 · kills 1 · toast 'LEGENDARY DROP — Cinderscale Fang'
· rematch · fx overflow 0 · nodes 210
```

`captures/rebirth_breath.png`, `rebirth_fight.png`, `rebirth_enrage.png`
(1280×720; 66–145 fps windowed on the Intel iGPU fallback, physics ≈ 0.14 ms
per tick). GDScript pitfalls met on the way are logged in
`../docs/02-status.md` §6.
