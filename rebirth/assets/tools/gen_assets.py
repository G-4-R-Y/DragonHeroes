#!/usr/bin/env python3
"""Rebirth asset feed — concept render -> 3D mesh -> every engine folder.

    GenForge world bible + season theme
      -> concept render (genforge image backend; transparent PNG)     [assets/concepts/<name>.png]
      -> mesh (genforge/pipeline/mesh_gen.py: TripoSR draft tier on the RTX 4050,
         hunyuan3d/trellis when installed; Cloud Run tier PARKED canon §12.38)  [assets/glb/<name>.glb]
      -> provenance sidecar                                            [assets/glb/<name>.provenance.json]
      -> per-engine staging (--stage):
           godot3d : nothing to copy (runtime GLB hook reads assets/glb/ directly)
           native  : assets/glb/<name>.dhm via glb_to_dhm.py (renderer ingest format)
           unreal  : unreal/Content/Generated/<name>.glb + manifest.json (editor import: Interchange)
           unity   : unity-hdrp/Assets/Generated/<name>.glb (if that project ever exists)

Lives OUTSIDE the engine folders on purpose: the pipeline is the reusable part
(plan §3 "the actual moat"). Zero third-party deps on the bare system python;
the heavy lifting happens inside genforge's own runners/venvs.

Usage:
  gen_assets.py --name dragon --concept assets/concepts/dragon.png          # real pipeline
  gen_assets.py --name dragon --placeholder                                 # no GPU/weights: stylized stand-in
  gen_assets.py --name dragon --stage native unreal                          # stage an existing GLB
  gen_assets.py --all-placeholders --stage native                           # what the gates run on today
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REBIRTH = HERE.parents[1]
PARENT = REBIRTH.parent
GLB_DIR = REBIRTH / "assets" / "glb"
CONCEPTS = REBIRTH / "assets" / "concepts"
MESH_GEN = PARENT / "genforge" / "pipeline" / "mesh_gen.py"
PLACEHOLDERS = ("dragon", "hunter", "pet")


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_provenance(name: str, glb: Path, source: str, extra: dict) -> Path:
    side = GLB_DIR / f"{name}.provenance.json"
    doc = {
        "name": name,
        "glb": glb.name,
        "sha256": sha256(glb),
        "bytes": glb.stat().st_size,
        "source": source,               # "placeholder" | "genforge-mesh_gen"
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "pipeline": "rebirth/assets/tools/gen_assets.py",
        **extra,
    }
    side.write_text(json.dumps(doc, indent=2) + "\n")
    return side


def make_placeholder(name: str) -> Path:
    out = GLB_DIR / f"{name}.glb"
    subprocess.run([sys.executable, str(HERE / "make_placeholder_glb.py"), name, str(out)], check=True)
    write_provenance(name, out, "placeholder", {"note": "pure-python stand-in until a concept render exists"})
    return out


def run_mesh_gen(name: str, concept: Path, tier: str) -> Path:
    if not MESH_GEN.exists():
        sys.exit(f"[gen_assets] {MESH_GEN} missing — parent repo checkout required")
    if not concept.exists():
        sys.exit(f"[gen_assets] concept render not found: {concept}")
    out = GLB_DIR / f"{name}.glb"
    env = dict(os.environ)
    env.setdefault("DH_MESH_OFFLOAD", "1")   # local GPU tier (parent docs/tech/31); never Cloud Run by default
    cmd = [sys.executable, str(MESH_GEN), "--input", str(concept), "--output", str(out), "--tier", tier]
    print("[gen_assets]", " ".join(cmd))
    subprocess.run(cmd, cwd=PARENT, check=True, env=env)
    write_provenance(name, out, "genforge-mesh_gen", {"concept": str(concept.relative_to(REBIRTH)), "concept_sha256": sha256(concept), "tier": tier})
    return out


def stage(name: str, glb: Path, targets: list[str]) -> None:
    for t in targets:
        if t == "godot3d":
            print(f"[stage] godot3d reads {glb.relative_to(REBIRTH)} at runtime (RbGlb) — nothing to copy")
        elif t == "native":
            dhm = glb.with_suffix(".dhm")
            subprocess.run([sys.executable, str(HERE / "glb_to_dhm.py"), str(glb), str(dhm)], check=True)
        elif t == "unreal":
            dst_dir = REBIRTH / "unreal" / "Content" / "Generated"
            dst_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(glb, dst_dir / glb.name)
            manifest = dst_dir / "manifest.json"
            doc = json.loads(manifest.read_text()) if manifest.exists() else {"creatures": {}}
            side = GLB_DIR / f"{name}.provenance.json"
            doc["creatures"][name] = {
                "file": glb.name,
                "asset": f"/Game/Generated/{name}.{name}",     # after Interchange import (INSTALL.md §4)
                "provenance": json.loads(side.read_text()) if side.exists() else {},
            }
            manifest.write_text(json.dumps(doc, indent=2) + "\n")
            print(f"[stage] unreal: {dst_dir / glb.name} + manifest.json")
        elif t == "unity":
            dst_dir = REBIRTH / "unity-hdrp" / "Assets" / "Generated"
            dst_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(glb, dst_dir / glb.name)
            print(f"[stage] unity: {dst_dir / glb.name} (project not created — see unity-hdrp/README.md)")
        else:
            sys.exit(f"[gen_assets] unknown stage target {t}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--name", help="creature id (dragon, hunter, pet, or any pack.type.name slug)")
    ap.add_argument("--concept", type=Path, help="concept render PNG (transparent background)")
    ap.add_argument("--tier", default="draft", help="mesh_gen tier (draft = local TripoSR)")
    ap.add_argument("--placeholder", action="store_true", help="write the pure-python stand-in instead of running mesh_gen")
    ap.add_argument("--all-placeholders", action="store_true", help="dragon + hunter + pet placeholders")
    ap.add_argument("--stage", nargs="*", default=[], choices=["godot3d", "native", "unreal", "unity"], help="engine folders to stage into")
    args = ap.parse_args()
    GLB_DIR.mkdir(parents=True, exist_ok=True)
    names: list[str] = []
    if args.all_placeholders:
        for n in PLACEHOLDERS:
            make_placeholder(n)
            names.append(n)
    elif args.name:
        if args.placeholder:
            make_placeholder(args.name)
        elif args.concept:
            run_mesh_gen(args.name, args.concept, args.tier)
        elif not (GLB_DIR / f"{args.name}.glb").exists():
            sys.exit("[gen_assets] give --concept (pipeline) or --placeholder, or have an existing GLB to --stage")
        names.append(args.name)
    else:
        ap.error("--name or --all-placeholders required")
    for n in names:
        glb = GLB_DIR / f"{n}.glb"
        stage(n, glb, args.stage)
        print(f"[gen_assets] {n}: {glb.relative_to(REBIRTH)} ({glb.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
