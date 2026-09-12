"""Explicit provider step; never used by builds, tests or CI automatically.

Uses GenForge's existing ImageBackend protocol. Writes raw candidate provenance
only; point the draft's source/prompt fields at these files after inspection.
"""
import argparse
import hashlib
import json
import tempfile
from pathlib import Path

from genforge.pipeline.image_backend import get_image_backend
from .build import brief, canonical
from .validation import load_validated


def generate(data, art_id, backend, out):
    art=next((a for a in data["art"] if a["id"]==art_id),None)
    if art is None: raise ValueError(f"unknown art id: {art_id}")
    if out.exists(): raise ValueError("output exists; use a new candidate directory")
    prompt=brief(data,art)
    images=backend.generate(prompt,n=1)
    if len(images)!=1: raise ValueError("provider must return exactly one sheet candidate")
    out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".generate-",dir=out.parent) as temporary:
        stage=Path(temporary)
        images[0].convert("RGBA").save(stage/"source.png")
        (stage/"prompt.txt").write_text(prompt,encoding="utf-8")
        (stage/"provenance.json").write_bytes(canonical({
            "provider":backend.name,"model":backend.model,"status":"candidate",
            "art_id":art_id,"source_sha256":hashlib.sha256((stage/"source.png").read_bytes()).hexdigest(),
            "prompt_sha256":hashlib.sha256(prompt.encode()).hexdigest()}))
        stage.rename(out)
    return out


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("release",type=Path);p.add_argument("--art",required=True)
    p.add_argument("--backend",required=True,help="Explicit provider; may incur configured API costs")
    p.add_argument("--out",type=Path,required=True)
    args=p.parse_args(argv)
    try:
        print(generate(load_validated(args.release),args.art,get_image_backend(args.backend),args.out))
    except (ValueError,OSError,RuntimeError) as error:
        p.exit(1,str(error)+"\n")


if __name__=="__main__": main()
