# 22 — The 3D Alternative View (experiment, 2026-07-18)

**Status:** working experiment, landed v0.2.1. **The 2D game remains canon** —
this scene exists to measure, with running code instead of opinions, how much
of Dragon Heroes is renderer-independent. Ricardo's question: "can we easily
do a 3D version from a renderer, reusing our 2D creations and mechanics?"

Run it: `godot --path game res://prototype3d/hunt3d.tscn`
(WASD walks, LMB swings — the same InputMap actions as the 2D hunt.
The 2D game is untouched; both views live in one Godot project.)

Reference frame: `game/prototype/tests/captures/ui_3d.png`.

## What it is

A perspective 3D night scene built from the exact assets and data of the 2D
hunt (`game/prototype3d/`, ~400 lines total):

- **World**: the same `dh-server --dump-window` chunk dump (live seed roll,
  same fallback ladder). `Proto3DWorldData` is the 2D loader minus every
  Node2D — tile semantics alias `ProtoWorld` constants so the views can't
  drift. The ground is one textured plane per chunk, composited from the SAME
  16px tile atlas (nearest-filtered — texels stay chunky); the anti-repetition
  variant recipe is the 2D one verbatim.
- **Height, for free**: T_ROCK tiles extrude into a per-chunk MultiMesh of
  boxes — real 3D occlusion where the 2D view bakes an SDF. Water tiles get a
  recessed translucent sheet, so shores read as banks.
- **Actors**: `ProtoBundleArt.frames_for()` feeds `AnimatedSprite3D` directly —
  the entire GenForge bestiary ports as Y-billboards in one call (idle/walk/
  attack animations included). One adapter exists (`_frames_3d`): the 2D
  frames are CanvasTextures (diffuse+normal for the sprite N·L stack), a
  2D-renderer type, so the 3D path unwraps to the diffuse texture per frame.
- **Light**: the ideas of the 2D lighting model, literal — moon
  DirectionalLight, warm lantern OmniLight on the hero, cyan OmniLights on
  the nearest glowshrooms, depth fog in the 2D night palette.
- **Mechanics parity gestures**: walkability/wall-slide reuse the same tile
  rules; input actions are shared; creatures wander with bundle animations.

## The reuse scorecard

| layer | reuse | note |
|---|---|---|
| worldgen (C++ dh-procgen/dh-server) | 100% | identical binary, identical dumps |
| sim core (C++, future) | 100% | never knew a renderer existed — by design |
| content packs / bestiary data | 100% | data is data |
| GenForge sprite bundles | ~95% | one CanvasTexture unwrap adapter |
| tile art / props | 100% | atlas composited onto planes, props billboard |
| walkability / input | 100% | same rules, same InputMap |
| 2D FX stack (fx/shader_fx/lights/darkness/fog/post) | 0% | canvas shaders + the multiplicative-quad model are 2D-specific |
| UI/HUD | 0% (unchanged) | UI is renderer-neutral anyway (CanvasLayer over either) |
| combat/skills GDScript | not ported | prototype logic is Node2D-coupled; the SHIPPING split (C++ sim + thin view) ports clean |

## Honest verdict

"Easily from a renderer" — the **world, art, data and rules: yes**, and this
scene proves it in an afternoon. The real cost of a 3D *product* is exactly
the layers we authored as 2D presentation: the spectacle-VFX stack, the
lighting/atmosphere model (§12.28-12.30), and combat feel — those would be
re-authored, not ported (weeks-to-months, not days). Architecture takeaway:
the server-authoritative C++ sim + data-driven content decisions mean the
renderer is a view-layer swap, which is why this experiment cost ~400 lines
and zero changes to the 2D game. HD-2D (3D world, billboard sprites — the
Octopath read) is therefore a *plausible future art direction*, parked unless
Ricardo calls it.

Not done (scoped out of the experiment): 3D streaming (the §29 window applies
1:1 when wanted), combat, VFX, UI mounting, mobile perf on the 3D path.
