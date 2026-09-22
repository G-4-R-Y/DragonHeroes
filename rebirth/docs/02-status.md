# Rebirth 02 — Execution status (2026-09-12)

> Companion to [01-plan.md](01-plan.md). Ricardo (2026-09-11): *"Unreal engine,
> godot 3d and the rest of suggested themes. Execute what is documented in the
> rebirth folder! For each engine experiment, create a new folder inside
> rebirth, containing the whole thing (3d assets and pipelines may be outside,
> as to be reusable)."* Everything below ran INLINE in one session (no
> background agents), gl_compatibility / Intel Mesa from the agent shell, no
> Vulkan window opened (parent harness rule).

## 1. What ran, per engine

| Engine | Folder | Built | Gate | Captures | Verdict so far |
|---|---|---|---|---|---|
| Godot 4.6 (3D, GDScript) | `godot3d/` | yes | **`REBIRTH3D OK`** (headless autopilot, `--fixed-fps 60`) | 3 × 1280×720 | Whole slice in a day; reads like the 2D game's combat; ceiling limited by gl_compatibility here (Forward+ untested) |
| Custom C++20 + GL 3.3 | `native/` | yes, `-Werror` clean | **`REBIRTH-NATIVE OK`** + determinism + ctest 2/2 | 2 × 1280×720 | Same slice, ~2 000 lines; deterministic and fast (1.6–2.6 M ticks/s); render 9.5–10 ms avg on the iGPU; no text/UI/anim/asset toolchain — that is the 12+ months the plan warned about |
| Unreal 5.4 (C++) | `unreal/` | **no — no UE installed** | none | none | 20 source files, compile-by-eye against 5.4 API; needs Ricardo's Epic account + ~45 GB (`unreal/INSTALL.md`) |
| Unity 6 HDRP | `unity-hdrp/` | not started, by decision | — | — | README documents why (no Unity, C# systems directive, weaker ceiling) and the cost if reversed |
| Shared assets | `assets/` | yes | placeholders staged to all engines | — | GenForge hook wired; blocked on a valid concept render for a real mesh |

### Gate outputs (verbatim)

```
REBIRTH3D OK — sim 41s in 0.2s wall · skills {breath:1, gust:5, meteors:1, pounce:1, tail:2} · enrage
· iframe avoids 2 · max combo 9 · hits 34 · dmg taken 40 · kills 1 · toast 'LEGENDARY DROP — Cinderscale Fang'
· rematch · fx overflow 0 · nodes 210

REBIRTH-NATIVE OK — skills breath:1 meteors:1 tail:2 gust:5 pounce:1 · enrage · iframe avoids 5
· max combo 9 · hits 35 · dmg taken 16 · kills 1 · toast · rematch
determinism OK — hash 3ee260753c412fd1, 1225 ticks
ctest --test-dir native/build: 100% tests passed, 0 tests failed out of 2
```

Both gates assert OUTCOMES (parent harness doctrine): five distinct skills
seen, enrage happened, at least one i-frame avoid, a 3+ combo, a kill, the
drop toast, a rematch, zero pool overflow, no node/allocation growth after
warm-up. They were watched FAIL first (skills 3/5 → retreat leap + ranged-first
decision order; 4/5 → pounce min range; native stats reset on rematch →
stats preserved).

### Measured

| Number | Godot 3D (Intel Mesa, gl_compatibility) | Native (Intel Mesa GL 4.6) |
|---|---|---|
| windowed fps / frame | 66–145 fps | avg 9.5–10.3 ms, p99 12.6–15.2 ms |
| physics / sim tick | ≈ 0.14 ms per 60 Hz tick | 0.4–0.6 µs per 30 Hz tick (sim-only) |
| headless gate wall | 0.2 s for 41 s of sim (`--fixed-fps 60`) | < 0.1 s |
| scene | 210 nodes after warm-up, fx pools 16/4/6/8/10/3 | ≤ 16 point lights per draw, pools identical |

## 2. The shared combat table (implemented three times, one set of numbers)

Hunter: HP 100 · speed 6.2 m/s · dodge 0.42 s / 6 m / i-frames 0.28 s / 3
charges / recharge 1.8 s · input buffer 0.15 s · combo link 0.45 s · hitstun
0.30 s · skill cd 6 s. Combo steps (startup/active/recover, dmg, reach, arc):
{0.12/0.10/0.22, 10, 2.6 m, 70°}, {0.10/0.10/0.22, 10, 2.6, 70°},
{0.16/0.12/0.34, 18, 2.9, 90°}; skill {0.18/0.16/0.36, 45, 3.4, 100°, lunge 4 m}.

Dragon: HP 600 · hit radius 2.4 m · speed 4.2 · turn 2.0 rad/s (1.2 while
telegraphing) · enrage at 40 % (telegraphs ×0.8, speed ×1.3, 5 meteors) ·
commit 0.35 s before the strike (aim locks — the dodge window).

| Skill | tele / act / recover (s) | range (m) | dmg | cd | shape |
|---|---|---|---|---|---|
| breath | 1.10 / 1.20 / 1.60 | 3–15 | 30 | 5 | cone 14 m, half-angle 35°, leaves a fire field (4 dmg / 0.5 s) |
| meteors | 1.40 / 0.50 / 1.00 | 9–60 | 24 | 9 | 3 (5 enraged) rings r 3.2, fields on impact |
| tail | 0.80 / 0.30 / 1.20 | 0–7 | 22 | 4 | rear sweep, reach 7 (punishes standing behind) |
| gust | 0.90 / 0.30 / 1.90 | 0–7.5 | 12 | 6 | ring r 7.5, long recovery = the punish window |
| pounce | 1.00 / 0.55 / 1.30 | 3–30 | 34 | 8 | leap onto the hunter, ring r 3.6 |

Decision order: forced → tail (behind, or enraged & close) → meteors if d > 9
→ pounce if d > 3 → gust if d < 4 and (enraged or 35 %) → breath if d ≥ 3 →
gust. Enrage schedules a RETREAT LEAP (0.6 s, 14 m, every 18 s while in
melee) that zeroes the meteor cd and caps pounce cd at 2.5 s — the
learnable pattern: retreat → meteors → pounce.

Pet: speed 8 · nip 6 dmg / 4 s / 4.5 m · HOWL 12 s / 14 m: heal 10 + stagger 1.1 s.

Files: `godot3d/scripts/{hunter,dragon,pet}.gd` · `native/src/sim.cpp` ·
`unreal/Source/Rebirth/Combat/RebirthCombat.h` (+ `Creatures/DragonBoss.cpp`).
Long game: parent `sim/` dh-sim replaces all three (canon §10).

## 3. Asset pipeline (outside the engines, reusable)

`assets/tools/make_placeholder_glb.py` (pure-python glTF 2.0 binary writer:
POSITION / NORMAL / COLOR_0, u32 indices) · `glb_to_dhm.py` (GLB → `.dhm`,
node TRS baked) · `gen_assets.py` (concept → parent GenForge `mesh_gen.py`
with `DH_MESH_OFFLOAD=1` → GLB + `<name>.provenance.json` → `--stage
godot3d|native|unreal|unity`). Proven end-to-end with placeholders: Godot
loads them at runtime (`RbGlb`), native ingests `.dhm`, UE gets
`Content/Generated/*.glb` + `manifest.json` (`URebirthAssetManifest`).
Blocked for a REAL mesh on the same thing as the parent: a valid concept
render (Ricardo's local image repo → `GENFORGE_IMAGE_BACKEND=local`).

### 3.1 R72 — "meshy + blender + unreal: is it a natural stepup?" (answered 2026-09-21)

Ricardo, 2026-09-21: *"people are using a pipeline with meshy + blender +
unreal for game dev, is it a natural stepup? perhaps that's what we were
looking for when testing out the experiments with 3d stuff. Later we will make
a boss fight to test out the concept."*

**Judgement: two of those three stations already exist here; the one we are
actually missing is Blender. And the version of the pipeline worth building
points back at the 2D game, not away from it.**

- **Meshy is not a step up — it is a provider swap behind a seam we already
  built.** `genforge/pipeline/mesh_gen.py` defines a `MeshProvider` protocol, a
  `get_mesh_provider()` registry with five implementations and an `_AUTO_ORDER`
  of `hunyuan3d → trellis → hunyuan3d-mini → triposr`. Only TripoSR is actually
  installed (`~/tools/TripoSR`). A `MeshyProvider` is a ~100-line adapter plus a
  credit card, available any day. So the decision is never "adopt Meshy" as a
  pipeline; it is "is draft-tier local good enough for THIS asset" — answered
  per asset. Note the cost asymmetry: TripoSR on the RTX 4050 is free, Meshy
  bills per generation, and we already parked one hosted GPU tier for exactly
  that reason (`genforge/service/mesh_cloudrun/PARKED.md`, 2026-09-10).
- **Unreal is not blocked on tooling.** `rebirth/unreal/` is CODE COMPLETE and
  UNCOMPILED — no UE on the box, install needs Ricardo's Epic account
  (`unreal/INSTALL.md`, and §4.2 below). Putting Meshy upstream moves that zero.
- **Blender is the genuine gap, and it is the free one.** `gen_assets.py` goes
  concept → `mesh_gen` → GLB → stage-per-engine with NO cleanup station: no
  retopo, no UV, no rig, no LOD, no bake. Every image-to-3D model on the market,
  Meshy included, emits dense, badly-topologised, unrigged meshes. Headless
  Blender (`blender --background --python`) is the scriptable, free, local fix,
  and it is the piece with no substitute. **Not installed here yet.**

**The pushback.** Meshy → Blender → *Unreal* is a 3D-game pipeline, and Dragon
Heroes ships 2D pixel art (canon §1/§6/§12.27 — `rebirth/` is explicitly not a
direction change). The pipeline that feeds the SHIPPING game is `genforge.hifi`,
the Dead Cells / Phantom Tower sprite generator. So the step up actually worth
taking is **mesh (Meshy or TripoSR) → Blender → render to sprite sheets → the 2D
game** — which is how Dead Cells itself was made: 3D models, animated, rendered
down to pixels. That path buys the one thing a pure-2D image generator cannot
give: rotational and animation consistency, exactly what breaks when you ask an
image model for the same creature at eight angles across twelve frames. And a
64–128 px sprite hides most of what is wrong with a draft-tier mesh — which is
why TripoSR may well be sufficient there while being nowhere near sufficient for
Nanite/Lumen.

**The boss fight (the concept test Ricardo asked for).** Build it in
`godot3d/` — the only slice that RUNS + GATED + CAPTURED today — unless UE gets
installed, in which case Unreal, since it is already the plan's PICK. The thing
under test is the ASSET PIPELINE, not the renderer, so the engine is the cheap
variable. Order of work: install Blender → add a `blender_clean` stage to
`gen_assets.py` (decimate, UV, origin, scale, LOD) → a turntable/sprite-sheet
renderer behind the same stage → one boss through it end to end → the fight.

## 4. Open decisions for Ricardo

1. **Godot renderer.** The slice runs gl_compatibility (agent shell). The
   Forward+ flip (`godot3d/project.godot`) is yours: it turns on volumetric
   fog, SDFGI and SSAO automatically. Until then the Godot-vs-UE "SOTA
   graphics" comparison is not honest.
2. **Unreal install.** ~45 GB prebuilt Linux 5.4 + Epic account; then the
   compile-fix pass on `unreal/` and the R0–R3 gates (`unreal/INSTALL.md`).
3. **Layout** — see §5.
4. **Is the fight fun?** R4 in the plan: play `godot3d` first (it is the one
   that runs); the autopilot's numbers say the loop closes, not that it feels
   good.

## 5. Layout collision with the parallel session (needs a pick)

While this work ran, the other Claude session (arena/training tree) created
a UE scaffold at the **rebirth root** and two sibling repos, and committed
the root one (69a5cd3, 2026-09-11 08:05, canon §12.42(e) second entry):

| Theirs | Mine | Overlap |
|---|---|---|
| `rebirth/Rebirth.uproject`, `Config/`, `Source/Rebirth/` (module + GameMode stub), `tools/gen_assets.py` (→ `Content/Creatures`) | `rebirth/unreal/` (complete slice, 20 files) + `assets/tools/gen_assets.py` (multi-engine staging) | same engine, two project roots; their root `Config/DefaultEngine.ini` sets `GameEngine=` to the GameMode class (would not boot as-is) |
| `../rebirth-native/` (CMake, links parent dh-sim, runs an arena episode headless — the §10 bet) | `rebirth/native/` (full slice with its own sim + GL renderer) | different questions: theirs = "does dh-sim link outside Godot", mine = "what does zero-engine cost" — both worth keeping |
| `../rebirth-unity/` (README + `BoarCharge.cs`) | `rebirth/unity-hdrp/README.md` (decision doc) | both say "not now" |

Nothing of theirs was deleted (their `Source/` had been removed by mistake
while it was still an empty stub and was restored from their commit).
Recommendation, per the instruction "each engine in its own folder inside
rebirth": delete the root-level UE trio (`Rebirth.uproject`, `Config/`,
`Source/`, `tools/`) in favour of `unreal/`, and move the siblings in as
`rebirth/native-dhsim/` and `rebirth/unity/` (or fold their READMEs into
`native/` and `unity-hdrp/`). Your call; either is one `git mv`.

## 6. Notes worth keeping (pitfalls met)

- GDScript 4.6: `var x := dict[...]` is a FATAL inference error; a member
  named `_init` shadows the constructor; assigning `Array.filter()` to an
  `Array[Dictionary]` var fails at runtime; `var name :=` shadows Node.name.
- Godot `TorusMesh`: `rings` is the segment count around the MAJOR circle,
  `ring_segments` the tube cross-section. The telegraph ring shipped as 6/48 —
  a hexagon with a round tube — and read as straight orange bars from inside;
  now 48/6. Found by capture, not by the gate (gates cannot see shape).
- Godot compatibility particles: size the QuadMesh in world units and keep
  `scale_min/max` near 1 — per-particle scale 0.06 rendered as metre-wide squares.
- Capture composition is EVENT-driven, not frame-driven (`REBIRTH_CAPTURE_EVENT`
  + `REBIRTH_CAPTURE_DELAY`): frame counts drift with fps, and 0.5 s after
  enrage the camera sits inside the 8.4 m enrage burst ring while the dragon is
  mid-leap — the frame read as a broken cone until traced. 1.7 s shows the
  pattern (leap done, meteors telegraphing).
- Windowed Godot from an agent shell: `DISPLAY=:1 godot --rendering-driver
  opengl3 --resolution 1280x720 --position 100,100` (libGL nouveau errors are
  harmless); `--fixed-fps 60` headless runs ~100× realtime.
- X11 headers define `None`/`Always`/`Success` — hence `Skill::Nil` and the
  `#undef`s in `render_gl.cpp`.
- Native gate FAILED once with 7 kills and "skills 2/5": `reset_fight` was
  wiping the stats each rematch; stats now survive rematches.
- UE (by eye): a member named `Dragon`/`Hunter`/`Pet` hides the
  `RebirthCombat::Dragon` namespace inside that class — qualify fully; hunter
  binding must work from BeginPlay (PIE) *and* PostLogin (standalone).
