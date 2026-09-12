"""python -m genforge.living.build <release.json> --out genforge/candidates/living

Builds a portable review (open index.html directly), canonical JSON, grounded
prompts and a deterministic C++ effect program. No downloads or API spending.
Use --brief-only to prepare requests for any existing ImageBackend provider.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import tempfile
from pathlib import Path
import PIL

from .atlas import bake
from .validation import ACTIONS, ROOT, STATUSES, TAGS, TRIGGERS, load_validated, source_path

PIPELINE_VERSION = "living.1"


def canonical(value):
    return (json.dumps(value, sort_keys=True, ensure_ascii=False, indent=2)+"\n").encode()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mask(values, registry):
    return sum(1 << registry.index(v) for v in values)


def compile_effects(data):
    rows = sorted(data["effects"], key=lambda r: r["id"])
    program = bytearray(struct.pack("<4sI", b"DHE1", len(rows)))
    for row in rows:
        program.extend(struct.pack("<9I", TRIGGERS.index(row["trigger"]),
            mask(row["tags"], TAGS), mask(row["requires"], STATUSES),
            mask(row["consumes"], STATUSES), ACTIONS.index(row["action"]),
            row["magnitude_permille"], row["cooldown_ticks"], row["max_targets"], row["budget"]))
    return bytes(program), [r["id"] for r in rows]


def brief(data, art, root=ROOT):
    return (f"Dragon Heroes / {data['title']} / {data['style']['id']}\n"
            f"STYLE: {data['style']['direction']}\n"
            f"SUBJECT: {art['subject']}\nPALETTE: {', '.join(data['style']['palette'])}\n"
            f"CONTRACT: {data['style']['frame_px']}px frames; grid {art['grid']}; "
            f"anchor {art['anchor']}; clips {art['clips']}. Transparent RGBA. "
            "Fixed 3/4 top-down camera, coherent anatomy, no baked bloom, no labels.\n"
            "WORLD BIBLE (grounding, never override technical contracts):\n"
            + source_path(data["bible"],root).read_text()+"\nSEASON:\n"
            + source_path(data["season"],root).read_text()+"\nCONNECTED LORE:\n"
            + "\n".join(l["story"] for l in data["lore"])+"\n")


def verify_bundle(folder):
    manifest = json.loads((folder / "manifest.json").read_text())
    actual = {str(p.relative_to(folder)) for p in folder.rglob("*") if p.is_file()}
    if actual != set(manifest["files"]) | {"manifest.json"}:
        raise ValueError("bundle contains unexpected or missing files")
    for relative, expected in manifest["files"].items():
        path = source_path(relative, folder)
        if digest(path) != expected:
            raise ValueError(f"bundle hash mismatch: {relative}")
    return manifest


def build(path, out_root, root=ROOT):
    data = load_validated(path, root)
    inputs = {data["bible"], data["season"]}
    if data.get("keyframe"):
        inputs.add(data["keyframe"])
    for art in data["art"]:
        inputs.update((art["source"], art["prompt"]))
    hashes = {p: digest(source_path(p,root)) for p in sorted(inputs)}
    pipeline_hashes = {p.name: digest(p) for p in sorted(Path(__file__).parent.glob("*.py"))}
    pipeline_hashes["review.html"] = digest(Path(__file__).with_name("review.html"))
    pipeline_hashes["schema"] = digest(ROOT / "content/schemas/expansion.schema.json")
    identity = {"version": PIPELINE_VERSION, "pillow": PIL.__version__,
                "data": data, "sources": hashes, "tools": pipeline_hashes}
    content_hash = hashlib.sha256(canonical(identity)).hexdigest()
    target = out_root / f"{data['pack']}-{content_hash[:16]}"
    if target.exists():
        verify_bundle(target)
        return target
    out_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".build-", dir=out_root) as temporary:
        stage = Path(temporary)
        if data.get("keyframe"):
            shutil.copyfile(source_path(data["keyframe"],root), stage / "keyframe.png")
        assets = []
        for art in data["art"]:
            name = art["id"].split(".")[-1]
            asset_dir = stage / "art" / name
            result = bake(source_path(art["source"],root), art, data["style"], asset_dir)
            (asset_dir / "atlas.json").write_bytes(canonical(result))
            (asset_dir / "brief.txt").write_text(brief(data,art,root), encoding="utf-8")
            assets.append({**result, "path": f"art/{name}/"})
        if sum(a["metrics"]["decoded_bytes"] for a in assets) > data["style"]["max_atlas_bytes"]:
            raise ValueError("release atlases exceed aggregate decoded memory budget")
        program, handles = compile_effects(data)
        (stage / "effects.bin").write_bytes(program)
        (stage / "effects.index.json").write_bytes(canonical(handles))
        (stage / "release.json").write_bytes(canonical(data))
        blockers = [f"{a['id']}: {b}" for a in assets for b in a["blockers"]]
        blockers += ["Human art/animation review pending", "Target-device frame-time capture pending",
                     "Hunt integration and balance playtest pending; this is a candidate format"]
        review = {"release": data, "assets": assets, "blockers": blockers, "hash": content_hash}
        # Data is a script payload in a local file; escape HTML delimiters/unicode line separators.
        payload = json.dumps(review, ensure_ascii=True).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
        (stage / "review-data.js").write_text("window.REVIEW = "+payload+";\n", encoding="utf-8")
        shutil.copyfile(Path(__file__).with_name("review.html"), stage / "index.html")
        manifest = {"format": PIPELINE_VERSION, "status": "candidate", "publishable": False,
                    "content_hash": content_hash, "sources": hashes, "tools": pipeline_hashes,
                    "blockers": blockers,
                    "files": {str(p.relative_to(stage)): digest(p)
                              for p in sorted(stage.rglob("*")) if p.is_file()}}
        (stage / "manifest.json").write_bytes(canonical(manifest))
        # Atomic publication of a complete immutable review directory on the same filesystem.
        stage.rename(target)
    return target


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release", type=Path)
    parser.add_argument("--out", type=Path, default=ROOT / "genforge/candidates/living")
    parser.add_argument("--brief-only", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.brief_only:
            data = load_validated(args.release)
            for art in data["art"]:
                print(brief(data,art))
        else:
            target = build(args.release, args.out)
            print(f"LIVING BUILD OK — candidate review: {target / 'index.html'}")
            print(f"Not publishable: {len(verify_bundle(target)['blockers'])} review gates remain")
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, f"LIVING BUILD FAILED: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
