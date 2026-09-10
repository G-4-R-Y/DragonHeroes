"""TripoSR runner — the adapter script mesh_gen.TripoSRProvider invokes.

Lives in the repo (versioned) and is COPIED into the upstream checkout as
`dh_runner.py` (docs/tech/31 §4), because it must run under that checkout's
venv with `tsr` importable:

    cp genforge/pipeline/runners/dh_runner_triposr.py ~/tools/TripoSR/dh_runner.py

Contract (mesh_gen.ExternalMeshProvider): --image PNG --out mesh.glb --seed N
[--offload]. TripoSR is a deterministic feed-forward model (no seed; ignored)
and fits the 6 GB draft tier without offload (flag accepted, ignored). Input
images with an alpha channel are used as-is (sprite/concept renders carry
their own mask); opaque images go through rembg.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--seed", type=int, default=0)          # unused: deterministic
    ap.add_argument("--offload", action="store_true")       # unused: fits 6 GB
    ap.add_argument("--mc-resolution", type=int, default=256)
    args = ap.parse_args()

    root = Path(__file__).resolve().parent                  # the TripoSR checkout
    has_alpha = Image.open(args.image).mode in ("RGBA", "LA")
    with tempfile.TemporaryDirectory() as td:
        cmd = [sys.executable, str(root / "run.py"), str(args.image),
               "--output-dir", td, "--model-save-format", "glb",
               "--mc-resolution", str(args.mc_resolution)]
        # NOT --bake-texture: TripoSR's bake path builds its sampling grid on
        # CPU and trips grid_sample's same-device check on torch>=2.6; the
        # default vertex-colored GLB is what the spike judges anyway
        if has_alpha:
            cmd.append("--no-remove-bg")
        proc = subprocess.run(cmd, cwd=root)
        if proc.returncode != 0:
            return proc.returncode
        produced = sorted(Path(td).rglob("mesh.glb"))
        if not produced:
            print("dh_runner: TripoSR produced no mesh.glb", file=sys.stderr)
            return 2
        args.out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(produced[0], args.out)
        tex = produced[0].with_name("texture.png")
        if tex.exists():
            shutil.copy2(tex, args.out.with_name("texture.png"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
