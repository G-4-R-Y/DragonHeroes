# Dragon Heroes: Rebirth — engine experiments (index)

A **separate, experimental** full-3D exploration of the Dragon Heroes fantasy:
one hunter, one legendary dragon, one night valley, one pet, kill → legendary
drop → rematch. **NOT a direction change** — the canon game is the 2D
pixel-art ARPG in the parent repo (canon §1/§6/§12.27). Rebirth exists to
learn what a 3D Dragon Heroes costs and feels like per engine, and to
pressure-test the Gen-AI → 3D asset pipeline.

The plan is [docs/01-plan.md](docs/01-plan.md); the execution log, gate
outputs and open decisions are [docs/02-status.md](docs/02-status.md).
Ricardo's instruction (2026-09-11): *"For each engine experiment, create a new
folder inside rebirth, containing the whole thing (3d assets and pipelines may
be outside, as to be reusable)."*

## One slice, several engines — same combat table

| Folder | Engine | Status (2026-09-12) | Gate |
|---|---|---|---|
| [`godot3d/`](godot3d/) | Godot 4.6, GDScript, gl_compatibility (Forward+ flip is Ricardo's) | **RUNS + GATED + CAPTURED.** Valley, hunter (dodge i-frames/buffer/combo/skill/lock-on), five-skill dragon with enrage + retreat leap, pet howl, HUD, drop → rematch, autopilot selftest | `REBIRTH_SELFTEST=1 godot --headless --fixed-fps 60 --path godot3d` → `REBIRTH3D OK` |
| [`native/`](native/) | Custom C++20 + OpenGL 3.3 (X11/GLX), own 30 Hz deterministic sim | **BUILDS (-Werror) + GATED + CAPTURED.** Same slice; render interpolation; pooled telegraphs; PNG captures | `cmake -S native -B native/build -DCMAKE_BUILD_TYPE=Release && cmake --build native/build -j && native/build/rebirth-native --sim-only --verify` → `REBIRTH-NATIVE OK` |
| [`unreal/`](unreal/) | Unreal Engine 5.4, C++ (the plan's PICK: Nanite/Lumen/Niagara) | **CODE COMPLETE, UNCOMPILED** — no UE on the dev box; install needs Ricardo's Epic account ([unreal/INSTALL.md](unreal/INSTALL.md)) | `Build.sh RebirthEditor` + Play (unverified) |
| [`unity-hdrp/`](unity-hdrp/) | Unity 6 HDRP | **NOT BUILT, by decision** — no Unity, C# systems directive, weaker ceiling; cost table in its README | — |
| [`assets/`](assets/) | engine-neutral | Placeholder GLBs + `.dhm` + provenance staged for all engines; GenForge hook in place | `python3 assets/tools/gen_assets.py --all-placeholders --stage godot3d native unreal` |

The five skills, hunter feel constants, dragon decision order, pet numbers and
the enrage → retreat → meteors → pounce pattern are ONE table implemented
three times (`godot3d/scripts/{dragon,hunter,pet}.gd`, `native/src/sim.cpp`,
`unreal/Source/Rebirth/Combat/RebirthCombat.h`) — see docs/02-status.md
§"shared combat table". In the long game the parent's `sim/` (dh-sim,
engine-agnostic by canon §10) is the piece that replaces all three.

## Shared asset pipeline (outside the engines)

`assets/tools/gen_assets.py` — concept render → parent GenForge
`mesh_gen.py` (TripoSR draft tier on the RTX 4050, `DH_MESH_OFFLOAD=1`;
cloud tier parked) → GLB + provenance sidecar → staged per engine:
`godot3d` loads GLBs at runtime (`REBIRTH_GLB_DIR`), `native` ingests a baked
`.dhm`, `unreal` gets `Content/Generated/<name>.glb` + `manifest.json`.
`--all-placeholders` writes pure-python stand-ins so every engine renders
without a Gen-AI mesh; a real mesh is blocked on valid concept renders
(Ricardo's local image repo — parent roadmap).

## Layout note (needs Ricardo's pick)

The other Claude session scaffolded a UE project at this folder's **root**
(`Rebirth.uproject`, `Config/`, `Source/Rebirth/` stub, `tools/gen_assets.py`,
commit 69a5cd3) and two sibling repos next to `rebirth/` (`../rebirth-native/`
— links the parent's dh-sim and runs an arena episode headless; `../rebirth-
unity/` — README + one C# stub). This index follows the per-engine-folder
instruction; nothing of theirs was removed. Reconcile per docs/02-status.md §5.

- **License:** same split as the parent repo (code MIT / art proprietary).
- **This repo is git-ignored by the parent** and has its own history.
