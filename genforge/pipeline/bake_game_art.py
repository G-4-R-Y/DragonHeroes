"""Bake the prototype's five actor bundles into game/prototype/art/.

This is a human-invoked dev bake for the M1 prototype CLIENT art (presentation
only — no gameplay data, so the GenForge candidate contract for content/ is
untouched). For each hand-authored actor (pipeline/actor_art.py):

  parts sheet   -> genforge/candidates/game_art/<actor>/parts/   (gitignored)
  baked bundle  -> game/prototype/art/<actor>/{strips/*.png, atlas.json, sheet.png}

Bundles are baked with --supersample (2x internal supersample -> BOX
downsample) at 2x the logical on-screen size; the atlas gains a
"logical_size" key = frame_size / 2 that the Godot loader
(game/prototype/bundle_art.gd) feeds to ImageTexture.set_size_override so the
hi-res frames display at the procedural sprites' world sizes.

Run from the repo root:
    python3 -m genforge.pipeline.bake_game_art [--previews DIR] [--actors a,b]
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Dict, List, Optional

from PIL import Image

try:
    from .actor_art import ACTOR_BUILDERS
    from .assemble import Assembler
    from .manifest import PartsManifest
    from .poses import PoseLibrary
    from .skeletons import Skeleton
    from .stub_provider import GenerationRequest, StubPartsProvider
except ImportError:  # invoked as a plain script path, not as a module
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from genforge.pipeline.actor_art import ACTOR_BUILDERS
    from genforge.pipeline.assemble import Assembler
    from genforge.pipeline.manifest import PartsManifest
    from genforge.pipeline.poses import PoseLibrary
    from genforge.pipeline.skeletons import Skeleton
    from genforge.pipeline.stub_provider import GenerationRequest, StubPartsProvider

GENFORGE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = GENFORGE_ROOT.parent
PARTS_ROOT = GENFORGE_ROOT / "candidates" / "game_art"
GAME_ART_ROOT = REPO_ROOT / "game" / "prototype" / "art"

# actor -> animations to bake (names are the game's animation contract)
ACTOR_ANIMS: Dict[str, List[str]] = {
    "hero": ["idle", "walk", "attack", "cast", "heavy", "spin", "dodge"],
    "gloamfen_stalker": ["idle", "walk", "lunge"],
    "gloamfen_wisp": ["idle", "walk", "lunge"],
    "emberwing_matriarch": ["idle", "fly", "walk", "attack", "lunge"],
    "ember_drake": ["fly", "idle", "walk"],
}


def bake_actor(actor: str, out_root: Path = GAME_ART_ROOT) -> dict:
    """Parts sheet -> baked bundle for one actor. Returns the atlas dict."""
    provider = StubPartsProvider()
    bundle = provider.generate_parts(
        GenerationRequest(archetype=actor, family=actor, entity=actor),
        PARTS_ROOT / actor / "parts",
    )
    skeleton = Skeleton.load(actor)
    poses = PoseLibrary.load(actor)
    manifest = PartsManifest.load(bundle.manifest_path)

    out_dir = out_root / actor
    if out_dir.exists():
        shutil.rmtree(out_dir)
    assembler = Assembler(manifest, skeleton, poses, supersample=True)
    atlas = assembler.bake(out_dir, ACTOR_ANIMS[actor])

    # the loader contract: logical on-screen size = baked / 2
    fw, fh = atlas["frame_size"]
    atlas["logical_size"] = [fw // 2, fh // 2]
    (out_dir / "atlas.json").write_text(json.dumps(atlas, indent=2) + "\n")
    # Atlas layout changes invalidate every matching normal strip. Rebuild
    # them in this transaction instead of leaving lighting on stale frames.
    from genforge.pipeline.normal_gen import run_batch
    run_batch(out_dir)
    return atlas


def write_preview(actor: str, atlas: dict, preview_dir: Path,
                  bundle_dir: Optional[Path] = None, zoom: int = 4) -> Path:
    """4x-nearest contact sheet (one row per animation) on a dark backdrop."""
    bundle_dir = bundle_dir or (GAME_ART_ROOT / actor)
    fw, fh = atlas["frame_size"]
    anims = atlas["animations"]
    max_frames = max(a["frames"] for a in anims.values())
    pad = 2
    sheet = Image.new(
        "RGBA",
        ((fw * max_frames + pad * (max_frames + 1)) * 1,
         (fh + pad) * len(anims) + pad),
        (16, 22, 27, 255),
    )
    for row, (name, entry) in enumerate(anims.items()):
        strip = Image.open(bundle_dir / entry["strip"]).convert("RGBA")
        for i in range(entry["frames"]):
            frame = strip.crop((i * fw, 0, (i + 1) * fw, fh))
            sheet.alpha_composite(
                frame, dest=(pad + i * (fw + pad), pad + row * (fh + pad)))
    big = sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST)
    preview_dir.mkdir(parents=True, exist_ok=True)
    out = preview_dir / f"{actor}_{zoom}x.png"
    big.save(out)
    return out


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python -m genforge.pipeline.bake_game_art",
        description="Bake the five prototype actor bundles into game/prototype/art/.",
    )
    ap.add_argument("--actors", default=None,
                    help="comma-separated subset (default: all five)")
    ap.add_argument("--previews", default=None,
                    help="also write 4x-nearest preview PNGs into this directory")
    args = ap.parse_args(argv)

    actors = args.actors.split(",") if args.actors else list(ACTOR_ANIMS)
    for actor in actors:
        if actor not in ACTOR_BUILDERS:
            raise SystemExit(f"unknown actor '{actor}' (have: {list(ACTOR_BUILDERS)})")

    for actor in actors:
        atlas = bake_actor(actor)
        fw, fh = atlas["frame_size"]
        lw, lh = atlas["logical_size"]
        anims = ", ".join(
            f"{n}:{a['frames']}f@{a['fps']:g}" for n, a in atlas["animations"].items())
        print(f"  {actor}: {fw}x{fh} baked -> {lw}x{lh} logical | {anims}")
        if args.previews:
            p = write_preview(actor, atlas, Path(args.previews))
            print(f"    preview: {p}")
    print(f"  bundles: {GAME_ART_ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
