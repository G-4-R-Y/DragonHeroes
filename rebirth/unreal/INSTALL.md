# Rebirth · Unreal — install + first run (Linux dev box, RTX 4050)

Nothing in this folder has been compiled: **no Unreal Engine is installed on
the dev box** (checked 2026-09-11/12: no `UnrealEditor`, no `~/UnrealEngine`,
no Epic launcher — and installing needs Ricardo's Epic account). The code is
written against the UE 5.4 API and reviewed by eye; expect a short compile-fix
pass on first build (INSTALL step 3 tells you where errors would surface).

## 1. Get UE 5.4 on Linux (Ricardo, once)

Two routes — both need an Epic Games account linked to GitHub:

| Route | Size / time | Notes |
|---|---|---|
| **Prebuilt binaries** (recommended): <https://www.unrealengine.com/en-US/linux> → "Download Linux build" (5.4.x `.zip`) | ~25 GB zip → ~45 GB unpacked, minutes | Ships `Engine/Binaries/Linux/UnrealEditor`; no compile of the engine |
| **Source**: `git clone -b 5.4 git@github.com:EpicGames/UnrealEngine.git && cd UnrealEngine && ./Setup.sh && ./GenerateProjectFiles.sh && make` | ~100 GB + 1–3 h on 20 cores | Only if we need engine patches (we don't for the slice) |

Prerequisites (Ubuntu 22.04): `sudo apt install build-essential clang lld cmake mono-complete dotnet-sdk-8.0` is NOT
required for prebuilt binaries — UE bundles its own toolchain (`Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v22_clang-16.0.6-centos7`)
and .NET runtime for UnrealBuildTool. Vulkan-capable driver required (the box
has NVIDIA 570.x — fine; **the editor is a Vulkan window: Ricardo launches it,
never an agent shell** — parent `docs/harness/README.md`).

Set `UE_ROOT=/path/to/UE_5.4` for the commands below.

## 2. Generate + build the project

```bash
cd rebirth/unreal
$UE_ROOT/Engine/Build/BatchFiles/Linux/Build.sh RebirthEditor Linux Development \
    -Project="$PWD/Rebirth.uproject" -WaitMutex
```

First build compiles the `Rebirth` module (10 source files) against the
engine's precompiled headers — a few minutes. UnrealHeaderTool runs first;
generated headers land in `Intermediate/` (gitignored).

**Where compile errors would surface** (compile-by-eye caveats):
- `Valley/ValleyGenerator.cpp` — `FMath::SmoothStep(a, b, x)` argument order and
  `FLinearColor::LerpUsingHSV` are 5.x APIs; if renamed, replace with `FMath::Lerp`.
- `Creatures/DragonBoss.cpp` — `UNiagaraFunctionLibrary::SpawnSystemAttached`
  overload (the 9-arg form is in 5.4; drop the trailing `bAutoActivate`/`bAutoDestroy`
  pair if the signature differs). `USceneComponent::SetAbsolute` exists on 5.x.
- `RebirthGameMode.cpp` — `SpawnActorDeferred<T>(Class, Transform)` then
  `FinishSpawning(Transform)`; `ASkyLight::GetLightComponent()` returns
  `USkyLightComponent*` in 5.4.
- `Hunter/HunterCharacter.cpp` — legacy `BindAxis/BindAction` names must match
  `Config/DefaultInput.ini` exactly (they do: MoveForward, MoveRight, Turn, LookUp,
  Dodge, Attack, Skill, PetSkill, LockOn, Rematch).

## 3. One editor step: the empty map

The slice builds everything at runtime (procedural valley, spawned lights,
dragon, pet), so the only asset the project needs is an **empty level** saved
at `Content/Maps/Valley.umap` (DefaultEngine.ini already points GameDefaultMap
and EditorStartupMap at `/Game/Maps/Valley`):

```bash
$UE_ROOT/Engine/Binaries/Linux/UnrealEditor "$PWD/Rebirth.uproject"   # Ricardo's Vulkan window
```

File → New Level → **Empty Level** → Save As `Maps/Valley`. World Settings
→ GameMode Override is already the project default (`RebirthGameMode`).
Press Play: hunter (placeholder capsule, lantern) in the valley, dragon 24 m
ahead, pet at heel; `LogRebirth` prints "Rebirth slice ready".

## 4. Bring the Gen-AI meshes in (R1 asset proof)

```bash
python3 ../assets/tools/gen_assets.py --all-placeholders --stage unreal   # or --name dragon --concept ../assets/concepts/dragon.png
```

writes `Content/Generated/{dragon,hunter,pet}.glb` + `manifest.json`. In the
editor, drag the GLBs from `Content/Generated/` into the Content Browser
folder `Generated` (Interchange glTF import; static mesh, **enable Nanite**
in the import dialog — the plan's whole point). Asset names must be
`/Game/Generated/<name>.<name>` (the manifest's `asset` field);
`URebirthAssetManifest` picks them up at BeginPlay and swaps the placeholders.
Provenance (source, sha256, tier) travels in the manifest.

## 5. Gates (mirror of the Godot/native slices)

| Gate | How | Exit |
|---|---|---|
| R0 scaffold | Build.sh above, Play in editor | hunter walks the valley at 60 FPS (HUD frame-time readout green) |
| R1 asset proof | §4 with a real TripoSR/Pixal3D GLB | one generated beast in-scene, Nanite, Lumen-lit by the fire pits |
| R2 combat feel | play: dodge on the commit window, 3-hit combo, lock-on camera | reads like the 2D game (i-frames + buffering) |
| R3 the fight | `stat unit` + `LogRebirth` skill lines | all 5 skills seen, enrage retreat pattern, kill → toast → R rematch |
| Automation | `Build.sh` + `UnrealEditor-Cmd Rebirth.uproject -ExecCmds="Automation RunTests Rebirth" -unattended -nullrhi` once a functional test actor is added (TODO) | REBIRTH-UE OK |

Headless verification on the dev box is not possible without the engine
install; until then the executable truth for this design lives in
[`../godot3d/`](../godot3d/) (`REBIRTH3D OK`) and [`../native/`](../native/)
(`REBIRTH-NATIVE OK`), which share the same combat table
(`Source/Rebirth/Combat/RebirthCombat.h`).
