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
| draft | Ricardo's RTX 4050 Laptop (6 GB; driver 570/CUDA 12.8; toolkit 12.8 at /usr/local/cuda — 2026-09-02) | TripoSR (MIT), Hunyuan3D-2mini shape stage | 4-6 GB | iterate compositions, validate the pipeline, curate candidates |
| **max quality — LOCAL (Ricardo 2026-09-10: "don't run anything into cloud gpu on google... arenas will be run on local gpus")** | the 4050 with `DH_MESH_OFFLOAD=1` today; any bigger local card later through the SAME adapters | Hunyuan3D full via the "GPU-poor" offload forks (~5 GB floor, minutes/asset); TRELLIS bottoms out ~8 GB — **does not fit 6 GB even offloaded**, needs a ≥8 GB local card | 5-24 GB | weights stream from system RAM per layer (31 GB RAM is plenty); activations, not weights, set the floor |

Cloud GPU tiers are out of scope (a Cloud Run design existed for one week —
2026-09-02→09-10 — and was removed with the GCP account; canon §12.38). The
open-weights/our-pipeline/provenance properties are what mattered and they
hold entirely on local hardware. TRELLIS-class and full Hunyuan want 16-24 GB
resident; offloading moves *weights* out of VRAM but the attention/activation
working set must still fit — that is the 6 GB wall for TRELLIS and the
minutes-per-asset price for offloaded Hunyuan.

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

System prerequisite DONE (Ricardo, 2026-09-02): CUDA toolkit 12.8 installed at
/usr/local/cuda. The apt `nvcc` (11.5) still shadows it on PATH — venv
installs that compile extensions must export first:

    export PATH=/usr/local/cuda/bin:$PATH CUDA_HOME=/usr/local/cuda

TripoSR — DONE on this machine 2026-09-10 (venv at ~/tools/TripoSR). The
exact sequence that worked (no python3-venv apt → user-level virtualenv;
torchmcubes needs a CUDA 12.8 patch):

    pip3 install --user virtualenv
    git clone https://github.com/VAST-AI-Research/TripoSR ~/tools/TripoSR
    cd ~/tools/TripoSR && python3 -m virtualenv .venv
    .venv/bin/pip install torch --index-url https://download.pytorch.org/whl/cu124
    .venv/bin/pip install numpy pybind11 scikit-build-core cmake ninja
    # torchmcubes vs CUDA 12.8: helper_math.h:877 `float lerp` clashes with
    # the toolkit's own — guard it, then build WITHOUT isolation
    git clone https://github.com/tatsy/torchmcubes.git ~/tools/torchmcubes
    #   wrap the scalar lerp in: #if !defined(CUDART_VERSION) || CUDART_VERSION < 12080
    export PATH=/usr/local/cuda/bin:$PATH CUDA_HOME=/usr/local/cuda \
        CUDACXX=/usr/local/cuda/bin/nvcc TORCH_CUDA_ARCH_LIST=8.9 \
        CMAKE_ARGS="-DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCMAKE_PREFIX_PATH=$(.venv/bin/python -c 'import torch;print(torch.utils.cmake_prefix_path)');$(.venv/bin/python -m pybind11 --cmakedir)"
    .venv/bin/pip install --no-build-isolation ~/tools/torchmcubes
    grep -vi torchmcubes requirements.txt > /tmp/req.txt && .venv/bin/pip install -r /tmp/req.txt
    cp <repo>/genforge/pipeline/runners/dh_runner_triposr.py ~/tools/TripoSR/dh_runner.py
    export DH_TRIPOSR_DIR=~/tools/TripoSR       # persist in ~/.bashrc
    # weights (~1.5 GB, public HF) auto-pull on the first generation

Hunyuan3D-2mini: same shape (`~/tools/Hunyuan3D`, `DH_HUNYUAN3D_DIR`);
shape-only on 6 GB, add `--low-vram`/offload flags per upstream README.

A bigger local card later: same checkouts + runners, floors met without
offload; nothing else changes.

## 5. Spike plan (next session, the gate before scaling)

fen_boar + gloamfen_stalker: concept render → draft-tier mesh → judge twice —
(a) GLB dropped into `prototype3d/hunt3d.tscn` replacing the billboard,
(b) re-rendered to a sprite sheet + baked normals vs today's frames under
sprite N·L. Acceptance: style match under curation, silhouette read at game
zoom, normal-map quality ≥ bevel+Sobel. Then run the same two actors
through offloaded Hunyuan-full (DH_MESH_OFFLOAD=1) for the quality delta.

2026 reality check (sources in session log): image-to-3D is production-ready
for creatures/props — the 80% multiplier — not for hero assets (Matriarch,
legendary chassis) which keep hand-tuned topology. Auto-rig is humanoid-strong,
quadruped-weak: expect curation loss on boars/serpents.

## 6. Max quality on local GPUs (`DH_MESH_OFFLOAD=1`)

Per Ricardo's question (2026-09-02): yes — the big models can run locally by
streaming weights from system RAM per layer (accelerate-style CPU offload;
the Hunyuan3D "GPU-poor" forks package this). mesh_gen wires it as an opt-in
env flag: `DH_MESH_OFFLOAD=1` lowers each adapter's preflight floor
(hunyuan3d 16000→5000 MB, trellis 16000→7500 MB — TRELLIS still refuses on
this 6 GB card, honestly) and passes `--offload` to the runner. Expect
minutes per asset and occasional OOM on texture-stage attention peaks; this IS the
max-quality path until a bigger local card lands (same adapters, same runbook). 31 GB system
RAM is enough to stage either model without touching disk per layer.

## 7. PARKED — the Cloud Run GPU tier (kept for the day budget returns)

History (canon §12.38): designed 2026-09-02 as the PREFERRED max-quality tier —
Google Cloud Run GPU, nvidia-l4 24 GB, scale-to-zero, per-second billing,
~cents per asset, zero idle cost — never deployed; PARKED 2026-09-10 when the
GCP account/budget went away. Ricardo: "comment out... don't delete" and
"remember to use full quality when budget is sufficient". Everything is intact
and inert: `genforge/service/mesh_cloudrun/` (server.py, Dockerfile, deploy.sh
guarded behind `DH_CLOUD_TIER_ENABLED=1`, PARKED.md checklist) and the
commented-out `CloudRunMeshProvider` + tests in mesh_gen.py / test_mesh_gen.py.

Re-enable: uncomment the provider + registry lines + tests; then

    export DH_GCP_PROJECT=dragon-heroes-dev     # a DEDICATED project
    DH_CLOUD_TIER_ENABLED=1 genforge/service/mesh_cloudrun/deploy.sh
    export DH_MESH_CLOUDRUN_URL=...             # printed by deploy.sh
    python -m genforge.pipeline.mesh_gen --actor fen_boar --image ... --provider cloudrun

### Credentials map (when re-enabled — nothing else, nowhere else)

| credential | where it lives | how it gets there | used for |
|---|---|---|---|
| your Google identity | `~/.config/gcloud/` | `gcloud auth login` (browser, once) | deploy.sh AND invoking — mesh_gen runs `gcloud auth print-identity-token` per call |
| service URL | repo-root `.env.local` (gitignored) or `~/.bashrc` | copy the deploy.sh output line | `DH_MESH_CLOUDRUN_URL` — not secret, machine-specific |
| HF token (ONLY if a gated model is ever adopted) | GCP Secret Manager | `gcloud secrets create hf-token --data-file=-` + `--set-secrets HF_TOKEN=hf-token:latest` in deploy.sh | weight download at image build/boot |
| CI / render-box invoker (optional) | key JSON OUTSIDE the repo, e.g. `~/.config/dh/sa.json` | create SA, grant `roles/run.invoker`, `GOOGLE_APPLICATION_CREDENTIALS=...` | headless batch invocation |

Never in the repo: keys, tokens, URLs with embedded auth. Behavior notes:
scale-to-zero pays a cold start on the first request of a batch (weights are
baked into the image); `--concurrency 1 --max-instances 1` serializes the L4;
request timeout 900 s covers the slowest full-texture generations.
