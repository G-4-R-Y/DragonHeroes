"""mesh_gen — GenForge stage: concept image -> 3D mesh (docs/tech/31).

Ricardo's directive (2026-09-02): max-quality image-to-3D, OPEN WEIGHTS, run
under our control — never a per-asset SaaS. Two execution tiers share this one
stage (the adapter decides where the compute lives):

  draft  — fits the local RTX 4050 (6 GB): TripoSR, Hunyuan3D-2mini (shape).
  batch  — max quality (TRELLIS / Hunyuan3D full, 16-24 GB VRAM): the SAME
           adapters on a rented GPU box; weights stay open, pipeline stays ours.

Design mirrors the parts pipeline (stub_provider.PartsProvider): a MeshProvider
protocol, get_mesh_provider() registry, deterministic stub for CI, and
provenance.json in a candidates/ folder — human curation stays the gate
(canon: gen-AI behind a curated pipeline, style-locked, human-directed).

Real adapters shell out to their upstream repos in dedicated venvs (the heavy
deps — torch-cu12x, custom CUDA extensions — must never leak into genforge's
env). Each declares a VRAM floor and is preflighted against nvidia-smi.

Usage:
  python -m genforge.pipeline.mesh_gen --actor fen_boar \
      --image genforge/candidates/<id>/concept.png [--provider auto] [--seed 7]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Protocol

STAGE_VERSION = "0.1.0"


@dataclass
class MeshRequest:
    actor: str                     # bestiary/actor slug ("fen_boar")
    image_path: Path               # high-res concept render (NOT a 52px sprite)
    seed: int = 0

    def digest(self) -> str:
        h = hashlib.sha256()
        h.update(self.actor.encode())
        h.update(str(self.seed).encode())
        if self.image_path.exists():
            h.update(self.image_path.read_bytes())
        return h.hexdigest()[:8]


@dataclass
class MeshResult:
    mesh_path: Path                # .obj or .glb inside the candidate dir
    provider: str
    meta: Dict = field(default_factory=dict)


class MeshProvider(Protocol):
    name: str
    min_free_vram_mb: int

    def generate_mesh(self, request: MeshRequest, out_dir: Path) -> MeshResult: ...


def free_vram_mb() -> Optional[int]:
    """Free VRAM via nvidia-smi; None when no NVIDIA stack is available."""
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.free", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10, check=True).stdout
        return int(out.strip().splitlines()[0])
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


# --------------------------------------------------------------------------
# stub: deterministic procedural mesh so CI exercises the stage contract
# (folder layout, provenance, digests) with zero model weights.
# --------------------------------------------------------------------------

class StubMeshProvider:
    name = "stub_procedural"
    min_free_vram_mb = 0

    def generate_mesh(self, request: MeshRequest, out_dir: Path) -> MeshResult:
        rows, cols, radius = 8, 12, 1.0
        jitter = int(hashlib.sha256(
            (request.actor + str(request.seed)).encode()).hexdigest()[:8], 16)
        verts: List[tuple] = [(0.0, radius, 0.0)]
        for r in range(1, rows):
            phi = math.pi * r / rows
            for c in range(cols):
                th = 2.0 * math.pi * c / cols
                amp = 1.0 + 0.08 * math.sin(jitter % 977 + r * 3.1 + c * 1.7)
                verts.append((radius * amp * math.sin(phi) * math.cos(th),
                              radius * amp * math.cos(phi),
                              radius * amp * math.sin(phi) * math.sin(th)))
        verts.append((0.0, -radius, 0.0))
        faces: List[tuple] = []
        for c in range(cols):                       # caps
            faces.append((1, 2 + c, 2 + (c + 1) % cols))
            base = 2 + (rows - 2) * cols
            faces.append((len(verts), base + (c + 1) % cols, base + c))
        for r in range(rows - 2):                   # bands
            a = 2 + r * cols
            b = a + cols
            for c in range(cols):
                c2 = (c + 1) % cols
                faces.append((a + c, b + c, b + c2))
                faces.append((a + c, b + c2, a + c2))
        mesh = out_dir / "mesh.obj"
        with mesh.open("w") as f:
            f.write(f"# genforge mesh_gen stub — {request.actor}\n")
            for v in verts:
                f.write("v %.5f %.5f %.5f\n" % v)
            for face in faces:
                f.write("f %d %d %d\n" % face)
        return MeshResult(mesh, self.name,
                          {"verts": len(verts), "faces": len(faces)})


# --------------------------------------------------------------------------
# external adapters: upstream repo + its own venv, located via env vars.
# script contract: <venv python> <runner> --image X --out mesh.glb --seed N
# Runners live in the upstream checkouts (see docs/tech/31 install runbook);
# this stage only orchestrates and records provenance.
# --------------------------------------------------------------------------

def offload_enabled() -> bool:
    """DH_MESH_OFFLOAD=1: weights staged in system RAM and streamed through
    the GPU per layer (accelerate-style CPU offload / the upstream low-VRAM
    forks). Lowers each adapter's VRAM floor at the cost of minutes-per-asset
    inference — the patient fallback when the Cloud Run tier is not wanted."""
    return os.environ.get("DH_MESH_OFFLOAD", "") == "1"


class ExternalMeshProvider:
    name = "external"
    min_free_vram_mb = 0
    offload_free_vram_mb: Optional[int] = None   # None = offload can't save it
    env_dir = ""                   # env var naming the upstream checkout
    runner = "dh_runner.py"        # adapter script inside that checkout

    def _root(self) -> Path:
        root = os.environ.get(self.env_dir, "")
        if not root or not Path(root).is_dir():
            raise RuntimeError(
                f"{self.name}: set {self.env_dir} to the upstream checkout "
                f"(install runbook: docs/tech/31-image-to-3d-local.md)")
        return Path(root)

    def _vram_floor(self) -> int:
        if offload_enabled() and self.offload_free_vram_mb is not None:
            return self.offload_free_vram_mb
        return self.min_free_vram_mb

    def _preflight(self) -> None:
        free = free_vram_mb()
        floor = self._vram_floor()
        if free is not None and free < floor:
            hint = ("even offloaded (activations set this floor, not weights)"
                    if offload_enabled() else
                    "try DH_MESH_OFFLOAD=1 (slow) or the Cloud Run tier")
            raise RuntimeError(
                f"{self.name}: needs ~{floor} MB free VRAM, found {free} MB — "
                f"{hint}; rented-GPU/Cloud Run runbook: docs/tech/31 §6")

    def generate_mesh(self, request: MeshRequest, out_dir: Path) -> MeshResult:
        root = self._root()
        self._preflight()
        py = root / ".venv" / "bin" / "python"
        if not py.exists():
            raise RuntimeError(f"{self.name}: no venv at {py} — see docs/tech/31")
        mesh = out_dir / "mesh.glb"
        cmd = [str(py), str(root / self.runner), "--image",
               str(request.image_path), "--out", str(mesh),
               "--seed", str(request.seed)]
        if offload_enabled():
            cmd.append("--offload")
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0 or not mesh.exists():
            raise RuntimeError(
                f"{self.name} failed ({proc.returncode}):\n{proc.stderr[-2000:]}")
        return MeshResult(mesh, self.name,
                          {"cmd": " ".join(cmd), "offload": offload_enabled()})


class TripoSRProvider(ExternalMeshProvider):
    """Draft tier — MIT weights, comfortably inside 6 GB."""
    name = "triposr"
    min_free_vram_mb = 4000
    env_dir = "DH_TRIPOSR_DIR"


class Hunyuan3DMiniProvider(ExternalMeshProvider):
    """Draft tier — Hunyuan3D-2mini shape stage (0.6B); texture stage off."""
    name = "hunyuan3d-mini"
    min_free_vram_mb = 5000
    env_dir = "DH_HUNYUAN3D_DIR"


class TrellisProvider(ExternalMeshProvider):
    """Max-quality — 16 GB class; low-VRAM forks bottom out ~8 GB
    (sparse-voxel attention activations), so offload can NOT reach 6 GB."""
    name = "trellis"
    min_free_vram_mb = 16000
    offload_free_vram_mb = 7500
    env_dir = "DH_TRELLIS_DIR"


class Hunyuan3DFullProvider(ExternalMeshProvider):
    """Max-quality — full shape+texture. The 'GPU-poor' offload forks run the
    whole pipeline on ~5-6 GB at minutes-per-asset speeds."""
    name = "hunyuan3d"
    min_free_vram_mb = 16000
    offload_free_vram_mb = 5000
    env_dir = "DH_HUNYUAN3D_DIR"
    runner = "dh_runner_full.py"


# --- PARKED 2026-09-10 — Cloud Run GPU tier (Ricardo: "don't run anything
# into cloud gpu on google... arenas will be run on local gpus" + "comment out
# previous max quality settings, don't simply delete code"). Kept verbatim,
# disabled: not registered, never imported. Service container + deploy script
# live in genforge/service/mesh_cloudrun/ (deploy.sh exits early). Re-enable
# by uncommenting this block + the registry lines below. docs/tech/31 §7.
#
# class CloudRunMeshProvider:
#     """Max-quality tier on Google Cloud Run GPU: POSTs the concept image to
#     our private mesh service (nvidia-l4, 24 GB, scale-to-zero) and writes
#     the returned GLB. Auth = the caller's gcloud identity token
#     (roles/run.invoker on the service); nothing secret in the repo."""
#     name = "cloudrun"
#     min_free_vram_mb = 0           # remote GPU — local VRAM is irrelevant
#     env_url = "DH_MESH_CLOUDRUN_URL"
#
#     def _url(self) -> str:
#         url = os.environ.get(self.env_url, "")
#         if not url:
#             raise RuntimeError(
#                 f"{self.name}: set {self.env_url} to the deployed service URL "
#                 f"(deploy + credentials runbook: docs/tech/31 §7)")
#         return url.rstrip("/")
#
#     def _id_token(self) -> str:
#         try:
#             out = subprocess.run(["gcloud", "auth", "print-identity-token"],
#                                  capture_output=True, text=True, timeout=30,
#                                  check=True).stdout.strip()
#             if out:
#                 return out
#         except (OSError, subprocess.SubprocessError) as exc:
#             raise RuntimeError(
#                 f"{self.name}: could not mint an identity token — run "
#                 f"`gcloud auth login` first (docs/tech/31 §7)") from exc
#         raise RuntimeError(f"{self.name}: empty identity token from gcloud")
#
#     def generate_mesh(self, request: MeshRequest, out_dir: Path) -> MeshResult:
#         import urllib.request
#         url = f"{self._url()}/generate?seed={request.seed}"
#         req = urllib.request.Request(
#             url, data=request.image_path.read_bytes(), method="POST",
#             headers={"Authorization": f"Bearer {self._id_token()}",
#                      "Content-Type": "application/octet-stream"})
#         with urllib.request.urlopen(req, timeout=900) as resp:
#             glb = resp.read()
#             model = resp.headers.get("X-DH-Model", "unknown")
#         if len(glb) < 1000:
#             raise RuntimeError(f"{self.name}: suspiciously small mesh "
#                                f"({len(glb)} bytes) — check service logs")
#         mesh = out_dir / "mesh.glb"
#         mesh.write_bytes(glb)
#         return MeshResult(mesh, self.name, {"service_model": model, "url": url})
# --- end PARKED block -------------------------------------------------------

# Registry is LOCAL-ONLY (canon §12.38). Max quality = the offload path
# (DH_MESH_OFFLOAD=1) or a bigger local card through the same adapters.
_PROVIDERS = {p.name: p for p in
              (StubMeshProvider, TripoSRProvider, Hunyuan3DMiniProvider,
               TrellisProvider, Hunyuan3DFullProvider)}
#              ^ PARKED: add CloudRunMeshProvider here to re-enable the tier
# auto = best installed local checkout. The stub is only ever explicit (CI).
_AUTO_ORDER = ["hunyuan3d", "trellis", "hunyuan3d-mini", "triposr"]
#             ^ PARKED: prepend "cloudrun" to prefer the remote tier when set


def _configured(prov) -> bool:
    # PARKED: `if isinstance(prov, CloudRunMeshProvider): return bool(
    #             os.environ.get(prov.env_url, ""))`
    return bool(os.environ.get(prov.env_dir, "")) and Path(
            os.environ[prov.env_dir]).is_dir()


def get_mesh_provider(name: str = "auto") -> MeshProvider:
    if name != "auto":
        if name not in _PROVIDERS:
            raise KeyError(f"unknown mesh provider '{name}' "
                           f"(have: {', '.join(sorted(_PROVIDERS))})")
        return _PROVIDERS[name]()
    for cand in _AUTO_ORDER:
        prov = _PROVIDERS[cand]()
        if _configured(prov):
            return prov
    raise RuntimeError("no mesh provider installed — install runbook: "
                       "docs/tech/31-image-to-3d-local.md")


def generate(request: MeshRequest, provider_name: str = "auto",
             candidates_root: Optional[Path] = None) -> Path:
    """Runs one mesh generation into a fresh candidates/ folder; returns it."""
    provider = get_mesh_provider(provider_name)
    root = candidates_root or Path(__file__).resolve().parents[1] / "candidates"
    week = datetime.now(timezone.utc).strftime("%Y-w%W")
    cand_id = f"mesh.{week}.{request.actor}.{request.digest()}"
    out_dir = root / cand_id
    out_dir.mkdir(parents=True, exist_ok=True)
    result = provider.generate_mesh(request, out_dir)
    provenance = {
        "candidate_id": cand_id,
        "kind": "mesh",
        "stage_version": STAGE_VERSION,
        "request": {
            "actor": request.actor,
            "image": str(request.image_path),
            "image_sha256": hashlib.sha256(
                request.image_path.read_bytes()).hexdigest()
                if request.image_path.exists() else None,
            "seed": request.seed,
        },
        "provider": {"name": result.provider, "meta": result.meta},
        "gpu": {"free_vram_mb_at_start": free_vram_mb()},
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "mesh": result.mesh_path.name,
    }
    (out_dir / "provenance.json").write_text(json.dumps(provenance, indent=2))
    return out_dir


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--actor", required=True)
    ap.add_argument("--image", required=True, type=Path)
    ap.add_argument("--provider", default="auto")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--candidates-root", type=Path, default=None)
    args = ap.parse_args(argv)
    out = generate(MeshRequest(args.actor, args.image, args.seed),
                   args.provider, args.candidates_root)
    print(f"mesh candidate: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
