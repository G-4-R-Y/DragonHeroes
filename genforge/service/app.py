"""GenForge v0 service — parts-sheet generation + baking behind a small API.

Internal-only (docs/tech/28 §5): no public ingress, no game-server route.
v0 wires the **stub provider** (procedural Pillow drawing) to the skeleton/
pose/baker pipeline; a real style-locked image model replaces the provider
behind the same interface (see pipeline/stub_provider.py) without touching
this service's contract.

THE CANDIDATE CONTRACT (docs/tech/28 §6): this service writes ONLY under
``genforge/candidates/`` — never to ``content/``, never to ``art/``, no live
path to game servers. Every bundle carries ``provenance.json``.

Run:
    uvicorn genforge.service.app:app --reload      # from the repo root

Endpoints:
    GET  /health
    POST /generate/creature
      {"archetype": "humanoid"|"dragon", "family": "...", "tier": "...",
       "palette_hints": [...], "theme_tags": [...]}
    -> candidate bundle paths + provenance

v0 is synchronous because the stub renders in milliseconds; real image jobs
are slow and will move to the async 202 + job-poll flow of docs/tech/28 §5.
"""
from __future__ import annotations

import json
import re
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Literal, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from genforge.pipeline import __version__ as PIPELINE_VERSION
from genforge.pipeline.assemble import Assembler
from genforge.pipeline.poses import PoseLibrary, available_pose_libraries
from genforge.pipeline.skeletons import Skeleton, available_skeletons
from genforge.pipeline.stub_provider import GenerationRequest, StubPartsProvider

GENFORGE_ROOT = Path(__file__).resolve().parents[1]
CANDIDATES_ROOT = GENFORGE_ROOT / "candidates"

app = FastAPI(
    title="GenForge v0",
    description="Parts-sheet generation + skeleton baking. Internal only. "
    "Writes exclusively under genforge/candidates/.",
    version=PIPELINE_VERSION,
)

_PROVIDER = StubPartsProvider()


class CreatureGenRequest(BaseModel):
    """POST /generate/creature body (subset of the docs/tech/28 §5 sketch)."""

    archetype: Literal["humanoid", "dragon"]
    family: str = "unnamed"
    tier: Literal["normal", "elite", "legendary"] = "normal"
    palette_hints: List[str] = Field(default_factory=list)
    theme_tags: List[str] = Field(default_factory=list)
    entity: Optional[str] = None          # explicit slug; derived when omitted
    animations: Optional[List[str]] = None  # default: all in the pose library
    supersample: bool = False


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _new_candidate_id() -> str:
    week = datetime.now(timezone.utc).strftime("%G-w%V")
    return f"cand.{week}.creature.{uuid.uuid4().hex[:8]}"


def _bundle_dir(candidate_id: str) -> Path:
    """Resolve the bundle dir and enforce the candidates-only write rule."""
    safe = re.sub(r"[^a-zA-Z0-9._-]", "_", candidate_id)
    path = (CANDIDATES_ROOT / safe).resolve()
    if CANDIDATES_ROOT.resolve() not in path.parents:
        raise HTTPException(500, "bundle path escaped genforge/candidates/")
    return path


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "pipeline_version": PIPELINE_VERSION,
        "provider": {"name": _PROVIDER.name, "version": _PROVIDER.version},
        "skeletons": available_skeletons(),
        "pose_libraries": available_pose_libraries(),
        "candidates_root": str(CANDIDATES_ROOT),
    }


@app.post("/generate/creature")
def generate_creature(req: CreatureGenRequest) -> dict:
    requested_at = _utc_now()
    candidate_id = _new_candidate_id()
    bundle = _bundle_dir(candidate_id)

    gen_req = GenerationRequest(
        archetype=req.archetype,
        family=req.family,
        tier=req.tier,
        palette_hints=req.palette_hints,
        theme_tags=req.theme_tags,
        entity=req.entity,
    )

    try:
        parts = _PROVIDER.generate_parts(gen_req, bundle / "parts")
        skeleton = Skeleton.load(req.archetype)
        poses = PoseLibrary.load(req.archetype)
        assembler = Assembler(
            parts.manifest, skeleton, poses, supersample=req.supersample
        )
        atlas = assembler.bake(bundle / "baked", req.animations)
    except ValueError as e:
        shutil.rmtree(bundle, ignore_errors=True)  # no partial bundles
        raise HTTPException(status_code=400, detail=str(e)) from e

    def rel(p: Path) -> str:
        return str(Path(p).resolve().relative_to(GENFORGE_ROOT))

    outputs: Dict[str, object] = {
        "parts_sheet": rel(parts.sheet_path),
        "parts_manifest": rel(parts.manifest_path),
        "atlas": rel(bundle / "baked" / "atlas.json"),
        "combined_sheet": rel(bundle / "baked" / "sheet.png"),
        "strips": {
            name: rel(bundle / "baked" / a["strip"])
            for name, a in atlas["animations"].items()
        },
    }

    provenance = {
        "candidate_id": candidate_id,
        "kind": "creature",
        "request": req.model_dump(),
        "provider": {
            "name": _PROVIDER.name,
            "version": _PROVIDER.version,
            "palette": getattr(_PROVIDER, "last_palette", None),
            "note": "procedural stub — no model call. A real provider records "
            "model + fine-tune checkpoint versions, sampling seeds/params, "
            "and grounding lore IDs here (docs/tech/28 §6).",
        },
        "pipeline_version": PIPELINE_VERSION,
        "skeleton": skeleton.name,
        "pose_library": poses.skeleton,
        "animations": atlas["animations"],
        "timestamps": {"requested": requested_at, "completed": _utc_now()},
        "outputs": outputs,
    }
    (bundle / "provenance.json").write_text(
        json.dumps(provenance, indent=2) + "\n"
    )

    return {
        "candidate_id": candidate_id,
        "entity": parts.manifest.entity,
        "bundle_dir": rel(bundle),
        "outputs": outputs,
        "provenance": rel(bundle / "provenance.json"),
        "animations": {
            name: {"frames": a["frames"], "fps": a["fps"], "loop": a["loop"]}
            for name, a in atlas["animations"].items()
        },
    }
