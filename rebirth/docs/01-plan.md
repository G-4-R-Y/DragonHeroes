# Rebirth 01 — The Plan: SOTA engine, vertical slice, Gen-AI asset pipeline

> Status: planning baseline (2026-09-02). Experimental; the 2D game stays canon
> (parent repo, canon §1/§6). Author: this spike, for Ricardo.

## 1. What Rebirth is

A full-3D, third-person Dragon Heroes vertical slice: **one hunter, one
legendary dragon, one valley, one pet companion** — with the same combat
language (telegraphs, punish windows, dodges, fields, elemental damage types)
and the same canon bosses doctrine (≥5 signature skills composing a learnable
strategy, canon §4). "Sick graphics" target: a dark-fantasy night valley where
fire, lightning and umbral darkness are *media that light the world* — the 2D
game's own VFX doctrine (canon §12.27) translated into 3D.

## 2. Engine evaluation (SOTA graphics, 2026)

| Candidate | Verdict |
|---|---|
| **Unreal Engine 5.x (PICK)** | The SOTA bar: **Nanite** (virtualized micropoly — Pixal3D's dense PBR GLBs import without retopo pain), **Lumen** (dynamic GI — "effects light the world" is *native*), **Niagara** (GPU particles — our aura/fire/storm/umbra vocabulary), World Partition (streaming), MassEntity (crowds — matches our SoA doctrine), Chaos Flesh/destruction for colossi. C++ modules — `dh-sim` (engine-agnostic, canon §10) can compile in as combat authority later. Costs: Epic EULA, 5% royalty past $1M gross (how marketplace fees count = **counsel question, park it**), huge install, team skill ramp. |
| Unity HDRP | Weaker ceiling (no Nanite/Lumen parity), C# (against the one-systems-language directive even for experiments), licensing drama history. |
| Custom C++ (bgfx/wgpu + dh-sim) | Max control, zero royalty, our exact aesthetic — and 12+ months to a baseline UE gives on day one. Research-only. |
| Godot 4 3D | Already evaluated in-house (prototype3d, design/22): reuse is total, the ceiling is not SOTA 3D. |

**Pick: UE 5.x.** Not because it's fashionable — because Nanite+Lumen+Niagara
is the shortest path to "the most beautiful dark fantasy beast hunt," and
Pixal3D's output is exactly the asset shape Nanite eats.

## 3. The Gen-AI asset pipeline (the actual moat)

```
GenForge world bible + season theme
  → concept render (genforge image backend, gpt-image-1, transparent PNG)
  → Pixal3D (MIT, TRELLIS.2 backbone) single-image → GLB, PBR textures
      · draft: RTX 4050 low_vram @1024 · hero: rented 24 GB @1536
  → RIGGING (the pipeline's honest gap — see risks)
  → Unreal import (Nanite mesh + PBR material) → Niagara/Lumen dressing
  → content JSON (stats/skills/AI) — SAME pack.type.name data as the 2D game
```

`tools/gen_assets.py` orchestrates: concept → mesh → staged `Content/`
import + provenance sidecar (mirrors genforge mesh_gen's candidate contract).
Multi-view Pixal3D (`inference_mv.py`) once concept renders ship front/side/back.

## 4. Vertical slice scope (the only honest way to answer "is this fun?")

1. **The valley:** one hand-built night valley (World Partition off for v1),
   Lumen, volumetric fog, Niagara ground mist — the 2D game's darkness model
   reborn in 3D.
2. **The hunter:** third-person locomotion, lock-on, dodge (i-frames + input
   buffering — the 2D game's own feel rules), 3-hit melee combo + one skill.
3. **The dragon:** one Pixal3D-generated legendary; behavior tree with 5
   signature skills (breath cone, meteor volley, tail sweep, wing gust,
   enrage phase at 40%) — telegraphs via Niagara danger volumes; the canon
   fight structure, not a stat wall.
4. **The pet:** one companion beast (follow + one skill on cooldown) — the
   pet canon in miniature.
5. **The loop:** kill → legendary drop toast → rematch. No economy, no MP.

## 5. Milestones

| Gate | Exit |
|---|---|
| R0 scaffold | uproject compiles; hunter walks in the valley (this repo's Source/) |
| R1 asset proof | ONE Pixal3D beast in-scene, lit, at 60 FPS — judged vs the 2D game's bar |
| R2 combat feel | lock-on + dodge + combo reads like the 2D game (buffering included) |
| R3 the fight | dragon with 5-skill kit beatable; telegraph language verified on video |
| R4 verdict | Ricardo plays it; continue-or-kill decision recorded in parent canon |

## 6. Risks (honest)

- **Rigging/animation is THE gap.** Pixal3D emits static meshes; creatures
  need skeletons. Mitigations: auto-rig (Mixamo/UEFN retarget), Rigify pass,
  or quadruped template rigs in Blender with generated textures. Budget real
  time here before scaling assets. (Same gap the parent's tech/31 flags.)
- **Team skill:** Ricardo is C++ — UE C++ is reachable, but Niagara/animation
  authoring is a new craft; the slice is scoped to one of everything for this
  reason.
- **Scope bleed:** Rebirth must never pull engineering from the canon game
  (60 FPS 2D game, arena/RL, dh-env). It lives or dies at the R4 verdict.
- **Legal/payments:** if Rebirth ever ships with the marketplace attached, the
  UE royalty vs marketplace-fee accounting question goes to counsel *before*
  any store page.

## 7. What crosses back to the 2D game (even if Rebirth dies)

Pixal3D asset proofs → 3D-to-sprite hero renders (canon §12.34 payoff loop);
Niagara effect studies → new vfx_lab vocabulary; the boss-kit data format
validated twice; the answer to "what would 3D cost," measured instead of
argued (design/22 started that measurement).
