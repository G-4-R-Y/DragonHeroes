# 31 — Image-to-3D, Local Open Weights (decision + runbook)

**Status:** decided 2026-09-02 (Ricardo: "go with the max quality ones which
can be run locally"). Stage scaffold landed: `genforge/pipeline/mesh_gen.py`
(+ tests). First real spike blocked only on the install runbook below.
**Related:** docs/design/22 (the 3D view these meshes feed), the 3D-to-sprite
backlog item (canon catalog), canon §12.34.

## 1. The decision

Open-weight image-to-3D models, run under our control — never per-asset SaaS.
"Locally" splits into two tiers after the hardware audit, and both tiers run
the SAME GenForge stage and adapters — only the box changes:

| tier | where | models | VRAM | role |
|---|---|---|---|---|
| draft | Ricardo's RTX 4050 Laptop (6 GB, driver 570/CUDA 12.8 ✓) | TripoSR (MIT), Hunyuan3D-2mini shape stage | 4-6 GB | iterate compositions, validate the pipeline, curate candidates |
| batch / max quality | rented GPU (24 GB class: 4090/A5000, ~$0.3-0.8/h) | TRELLIS(.2), Hunyuan3D full shape+texture | 16-24 GB | the actual quality bar; a weekly batch of accepted concepts costs single-digit dollars |

Why not "max quality on the 4050": TRELLIS-class and full Hunyuan want
16-24 GB; 6 GB runs only distilled/shape-only variants. Renting keeps the
open-weights/license-clean/our-pipeline properties — it is "local" in every
sense that matters (weights, control, provenance), just not this laptop.

## 2. The pipeline (per canon: curated, style-locked, human-directed)

bestiary spec → high-res CONCEPT RENDER (existing GenForge image stage — the
52×52 sprites are never the conditioning input) → `mesh_gen` (this stage) →
human curation gate on the candidates/ folder → consumers:
- **3D view**: GLB replaces the actor billboard (design/22).
- **canon 2D game**: 3D-to-sprite re-render — consistent animation frames at
  scale + TRUE baked normal maps replacing the bevel+Sobel approximations
  behind sprite N·L. This is the payoff that feeds BOTH views from one asset.
- rigging/animation pass (UniRig / Blender auto-rig; quadrupeds need curation)
  sits between curation and consumers — spike scope, not yet built.

## 3. Stage contract (mesh_gen.py)

- Mirrors the parts pipeline: `MeshProvider` protocol, `get_mesh_provider()`,
  deterministic `stub_procedural` for CI, provenance.json per candidate
  (`candidates/mesh.<week>.<actor>.<digest>/`).
- Real adapters shell out to upstream checkouts in THEIR OWN venvs (torch-cu12x
  and custom CUDA extensions never enter genforge's env), located via
  `DH_TRIPOSR_DIR` / `DH_HUNYUAN3D_DIR` / `DH_TRELLIS_DIR`; each declares a
  VRAM floor preflighted against nvidia-smi (TRELLIS on the 4050 fails fast
  with a pointer here instead of OOMing after 10 minutes).
- `--provider auto` picks the best installed real adapter (never the stub).

## 4. Install runbook (draft tier, this machine)

One system prerequisite (needs sudo — the system nvcc is CUDA 11.5 while the
driver speaks 12.8; upstream CUDA extensions must compile against 12.x):

    sudo apt install cuda-toolkit-12-4      # or the NVIDIA .run installer

TripoSR (~15 min, ~4 GB downloads):

    git clone https://github.com/VAST-AI-Research/TripoSR ~/tools/TripoSR
    cd ~/tools/TripoSR && python3 -m venv .venv && .venv/bin/pip install \
        torch --index-url https://download.pytorch.org/whl/cu124
    .venv/bin/pip install -r requirements.txt   # weights auto-pull on first run
    # then write the thin dh_runner.py wrapper (contract in mesh_gen.py):
    # --image/--out/--seed -> run_model -> export GLB
    export DH_TRIPOSR_DIR=~/tools/TripoSR       # persist in ~/.bashrc

Hunyuan3D-2mini: same shape (`~/tools/Hunyuan3D`, `DH_HUNYUAN3D_DIR`);
shape-only on 6 GB, add `--low-vram`/offload flags per upstream README.

Batch tier: same checkouts + runners on the rented box; sync accepted
candidates back into genforge/candidates/ (provenance travels with them).

## 5. Spike plan (next session, the gate before scaling)

fen_boar + gloamfen_stalker: concept render → draft-tier mesh → judge twice —
(a) GLB dropped into `prototype3d/hunt3d.tscn` replacing the billboard,
(b) re-rendered to a sprite sheet + baked normals vs today's frames under
sprite N·L. Acceptance: style match under curation, silhouette read at game
zoom, normal-map quality ≥ bevel+Sobel. Only then rent the 24 GB tier and run
the same two actors through TRELLIS/Hunyuan-full for the quality delta.

2026 reality check (sources in session log): image-to-3D is production-ready
for creatures/props — the 80% multiplier — not for hero assets (Matriarch,
legendary chassis) which keep hand-tuned topology. Auto-rig is humanoid-strong,
quadruped-weak: expect curation loss on boars/serpents.
