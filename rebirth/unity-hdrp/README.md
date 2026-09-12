# Rebirth · Unity HDRP branch — BLOCKED (documented, not built)

Sibling of [`../unreal/`](../unreal/), [`../godot3d/`](../godot3d/) and
[`../native/`](../native/): same vertical slice (one hunter, one legendary
dragon, one valley, one pet — [`../docs/01-plan.md`](../docs/01-plan.md) §4),
different engine.

## Why this folder is a document and not a project

1. **Not installed.** No Unity Hub / Editor on the dev box (checked 2026-09-11:
   no `unityhub`, no `~/Unity`, no `Unity` binary). Installing needs a Unity
   account + Hub + a 6000.x LTS editor (~10 GB) — Ricardo's call and login.
2. **C# is the game language.** The parent's standing directive #1 rules out C#
   for systems; the plan's own engine table (§2) marks HDRP "against the
   one-systems-language directive even for experiments". A slice written in C#
   would measure a language we would never ship.
3. **The ceiling answer is already known.** HDRP has no Nanite/Lumen parity,
   so it cannot beat the UE5 row on the plan's one question ("the most
   beautiful dark-fantasy beast hunt"). What it *could* answer — iteration
   speed for a small team — the Godot 3D slice answers cheaper (it exists,
   it runs, it has a gate).

## What it would take (if Ricardo overrides)

| Step | Cost |
|---|---|
| Unity Hub + Unity 6000.x LTS (Linux), HDRP template | account + ~10 GB, ~1 h |
| Port the slice: `Hunter.cs`, `Dragon.cs` (5-skill FSM), `Pet.cs`, `Valley.cs` (procedural mesh), `Telegraphs.cs` (pooled), `SliceLoop.cs` | ~1 500 lines C#, 1–2 days |
| GLB feed: UnityGLTF or glTFast package, `Assets/Generated/` staging (`../assets/tools/gen_assets.py --stage unity`) | 1 h |
| Gate: PlayMode test mirroring `REBIRTH3D OK` (5 skills, enrage, i-frame avoid, combo3, kill, toast, rematch) | 2 h |

The shared combat table (numbers) is in [`../unreal/Source/Rebirth/Combat/RebirthCombat.h`](../unreal/Source/Rebirth/Combat/RebirthCombat.h)
and [`../native/src/sim.hpp`](../native/src/sim.hpp); a C# port would copy
those constants verbatim so all four slices stay comparable.

## Decision recorded

Stays a document until the R4 verdict on the UE5/Godot/native slices says a
fourth data point is worth the install. Note: the other Claude session created
a sibling repo `../../rebirth-unity/` (scaffold + `BoarCharge.cs`) on
2026-09-11 with the opposite layout (folders NEXT TO `rebirth/`); Ricardo picks
one layout — see `../docs/02-status.md`.
