# PARKED — Cloud Run GPU mesh tier (kept, not deleted)

**Status:** parked 2026-09-10 for budget (canon §12.38). Designed 2026-09-02
as the PREFERRED max-quality image-to-3D tier (nvidia-l4 24 GB, scale-to-
zero, ~cents per asset). Never deployed. Re-enable the day budget allows —
full quality is the intended path; local offload (tech/31 §6) is the stopgap.

Everything here is intact and inert:
- `server.py` — FastAPI `/generate`: concept image in, GLB out.
- `Dockerfile` — bakes upstream repo + open weights (`--build-arg MODEL=hunyuan3d|trellis`).
- `deploy.sh` — the executable runbook. **Guarded**: exits immediately unless
  `DH_CLOUD_TIER_ENABLED=1` is set, so nothing can reach GCP by accident.

Re-enable checklist (docs/tech/31 §7 has the full credentials map):
1. `gcloud auth login` on a project with billing (a DEDICATED project).
2. Uncomment `CloudRunMeshProvider` + the registry lines in
   `genforge/pipeline/mesh_gen.py`, and the parked tests in
   `genforge/tests/test_mesh_gen.py`.
3. `DH_CLOUD_TIER_ENABLED=1 DH_GCP_PROJECT=<project> ./deploy.sh`
4. `export DH_MESH_CLOUDRUN_URL=<printed URL>` (repo-root `.env.local`, gitignored).
