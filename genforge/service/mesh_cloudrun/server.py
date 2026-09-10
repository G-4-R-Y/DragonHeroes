"""GenForge mesh service — image-to-3D on Cloud Run GPU. PARKED 2026-09-10
(canon §12.38: budget) — kept intact, see PARKED.md. Re-enable when budget
allows; full quality is the intended path.

One endpoint, one job: POST a concept image, get a GLB back. The model
pipeline loads ONCE per instance (cold start pays it, warm requests reuse it);
Cloud Run scales to zero between weekly batches, so idle cost is zero.

Deployed private (--no-allow-unauthenticated): callers hold roles/run.invoker
and send a Google identity token — see the parked CloudRunMeshProvider
(genforge/pipeline/mesh_gen.py).

MODEL env selects the backend at deploy time:
  hunyuan3d  (default) — tencent Hunyuan3D-2.x full shape+texture
  trellis              — microsoft TRELLIS image-large
The upstream repos are baked into the image by the Dockerfile; weights pull
from Hugging Face at build time (open weights, no token needed today — a
gated model would arrive via Secret Manager, see docs/tech/31 §7).
"""

from __future__ import annotations

import os
import tempfile
import threading
from pathlib import Path

from fastapi import FastAPI, Request, Response

MODEL = os.environ.get("MODEL", "hunyuan3d")
app = FastAPI()
_lock = threading.Lock()          # one L4 = one generation at a time
_pipeline = None


def _load_pipeline():
    global _pipeline
    if _pipeline is not None:
        return _pipeline
    if MODEL == "hunyuan3d":
        from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline
        from hy3dgen.texgen import Hunyuan3DPaintPipeline
        shape = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(
            "tencent/Hunyuan3D-2")
        paint = Hunyuan3DPaintPipeline.from_pretrained("tencent/Hunyuan3D-2")
        _pipeline = ("hunyuan3d-2", shape, paint)
    elif MODEL == "trellis":
        from trellis.pipelines import TrellisImageTo3DPipeline
        pipe = TrellisImageTo3DPipeline.from_pretrained(
            "microsoft/TRELLIS-image-large")
        pipe.cuda()
        _pipeline = ("trellis-image-large", pipe)
    else:
        raise RuntimeError(f"unknown MODEL '{MODEL}'")
    return _pipeline


@app.get("/health")
def health() -> dict:
    return {"ok": True, "model": MODEL, "loaded": _pipeline is not None}


@app.post("/generate")
async def generate(request: Request, seed: int = 0) -> Response:
    img_bytes = await request.body()
    with _lock:
        pipe = _load_pipeline()
        with tempfile.TemporaryDirectory() as td:
            src = Path(td) / "concept.png"
            src.write_bytes(img_bytes)
            out = Path(td) / "mesh.glb"
            from PIL import Image
            if pipe[0].startswith("hunyuan3d"):
                _, shape, paint = pipe
                image = Image.open(src).convert("RGBA")
                mesh = shape(image=image, seed=seed)[0]
                mesh = paint(mesh, image=image)
                mesh.export(str(out))
            else:
                _, tp = pipe
                res = tp.run(Image.open(src), seed=seed)
                res["mesh"][0].export(str(out))   # textured GLB extraction
            glb = out.read_bytes()
    return Response(content=glb, media_type="model/gltf-binary",
                    headers={"X-DH-Model": pipe[0]})
