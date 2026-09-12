# Rebirth · Unreal Engine 5.4 — the plan's PICK (scaffold, uncompiled)

The engine the plan chose (`../docs/01-plan.md` §2: Nanite + Lumen + Niagara =
"the shortest path to the most beautiful dark-fantasy beast hunt"). This folder
is the complete C++ project for the vertical slice (§4) — it has **not been
compiled**: no UE on the dev box, and the install needs Ricardo's Epic account
([INSTALL.md](INSTALL.md)).

## What is here

| Path | What |
|---|---|
| `Rebirth.uproject` · `Config/` | UE 5.4 project; Nanite, Lumen (software RT), VSM, volumetric fog, TSR; legacy input bindings identical to the other slices |
| `Source/Rebirth/Combat/RebirthCombat.h` | **the shared combat table** — same numbers as `../godot3d` and `../native` (skills, hunter feel constants, arc/cone math). Plain C++: the piece dh-sim replaces |
| `Source/Rebirth/Valley/` | `AValleyGenerator`: procedural heightfield bowl (ProceduralMeshComponent), instanced rocks, glowshroom + fire-pit point lights, exponential/volumetric fog |
| `Source/Rebirth/Hunter/` | `AHunterCharacter`: third-person camera, lock-on framing, dodge with i-frames + input buffer (3 charges), 3-hit combo, skill lunge, `TakeDamage` honours i-frames |
| `Source/Rebirth/Creatures/DragonBoss.*` | `ADragonBoss`: five signature skills + enrage + retreat leap, pooled telegraph meshes/fire fields/meteors (Niagara soft refs for later), `OnSlain/OnEnraged/OnSkillUsed` |
| `Source/Rebirth/Creatures/PetCompanion.*` | `APetCompanion`: heel, nip, HOWL (stagger + heal) |
| `Source/Rebirth/RebirthGameMode.*` · `RebirthHUD.*` | spawns everything at BeginPlay on an empty map; kill → legendary drop toast → R rematch; Canvas HUD with frame-time readout |
| `Source/Rebirth/Pipeline/AssetManifest.*` | reads `Content/Generated/manifest.json` (from `../assets/tools/gen_assets.py --stage unreal`) and swaps placeholders for imported GLBs, provenance included |
| `Content/Generated/manifest.json` | current staging: three pure-python placeholders (source `placeholder`) |

`Source/*.Target.cs` / `Rebirth.Build.cs` are UnrealBuildTool rules — C# is
UBT's language, not game code; the no-C# directive is about systems.

## Status vs the plan's milestones

| Gate | Status |
|---|---|
| R0 scaffold | code complete, **uncompiled** (no engine) — INSTALL.md §2 |
| R1 asset proof | pipeline ready (`gen_assets.py --stage unreal` + Interchange import), no Gen-AI mesh yet (needs a concept render: the local image repo Ricardo is adding) |
| R2 / R3 | designed and implemented from the same table the Godot/native slices PASS with; unverified in UE |
| R4 verdict | pending Ricardo playing all three |

## Layout note

The other Claude session started a UE scaffold at the **rebirth root**
(`../Rebirth.uproject`, `../Config/`, `../tools/gen_assets.py`, 2026-09-11 08:04)
in parallel. This folder follows Ricardo's per-engine-folder instruction and is
the complete one; reconcile by deleting the root-level trio or `git mv`-ing this
folder's contents up — see `../docs/02-status.md`.
