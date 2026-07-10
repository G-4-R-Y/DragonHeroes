"""The baker: parts sheet + skeleton + poses -> baked frame strips + atlas.

For every animation frame, each skeleton bone's part is cut from the parts
sheet, rotated around its pivot (PIL rotate, NEAREST resampling — pixel-crisp,
no interpolation blur; an optional 2x supersample->downsample flag trades a
touch of edge softness for smoother rotations at high fidelity), placed at the
bone's forward-kinematics world transform, and composited in z-order onto a
fixed canvas.

Outputs, per entity:
  strips/<anim>.png   horizontal frame strip per animation
  sheet.png           combined sheet (one row per animation)
  atlas.json          Godot-friendly: frame size, per-animation frame counts,
                      fps, loop flags, strip paths + row index in sheet.png

Baked frames are the runtime contract: the client plays plain frame strips and
the server derives per-frame hitboxes from the same frame timeline
(docs/tech/23) — nothing here requires a rig, a video model, or any
generation call at animation time.

CLI:
  python -m genforge.pipeline.assemble \
      --manifest path/to/parts.json --skeleton humanoid \
      --out out_dir [--animations idle,walk] [--supersample]
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from PIL import Image

from .manifest import PartsManifest
from .poses import Animation, PoseLibrary
from .skeletons import Skeleton


def _rotate_around_pivot(
    img: Image.Image, pivot: Tuple[float, float], degrees_cw: float
) -> Tuple[Image.Image, Tuple[float, float]]:
    """Rotate ``img`` by ``degrees_cw`` (clockwise, y-down) and track the pivot.

    PIL's ``rotate(expand=True)`` always rotates around the image center, so we
    rotate around the center and compute where the pivot landed in the expanded
    output. Returns (rotated image, pivot position in the rotated image).
    """
    if degrees_cw % 360.0 == 0.0:
        return img, pivot
    rotated = img.rotate(-degrees_cw, resample=Image.NEAREST, expand=True)
    cx, cy = img.width / 2.0, img.height / 2.0
    vx, vy = pivot[0] - cx, pivot[1] - cy
    rad = math.radians(degrees_cw)
    c, s = math.cos(rad), math.sin(rad)
    # clockwise-positive rotation in y-down coordinates
    rvx = vx * c - vy * s
    rvy = vx * s + vy * c
    ncx, ncy = rotated.width / 2.0, rotated.height / 2.0
    return rotated, (ncx + rvx, ncy + rvy)


def _composite(canvas: Image.Image, img: Image.Image, x: int, y: int) -> None:
    """Alpha-composite ``img`` onto ``canvas`` at (x, y), clipping as needed."""
    sx, sy = max(0, -x), max(0, -y)
    dx, dy = max(0, x), max(0, y)
    w = min(img.width - sx, canvas.width - dx)
    h = min(img.height - sy, canvas.height - dy)
    if w <= 0 or h <= 0:
        return
    if (sx, sy, w, h) != (0, 0, img.width, img.height):
        img = img.crop((sx, sy, sx + w, sy + h))
    canvas.alpha_composite(img, dest=(dx, dy))


class Assembler:
    """Bakes one entity's animations from its parts sheet."""

    def __init__(
        self,
        manifest: PartsManifest,
        skeleton: Skeleton,
        poses: PoseLibrary,
        supersample: bool = False,
    ):
        poses.validate_against(skeleton)
        self.manifest = manifest
        self.skeleton = skeleton
        self.poses = poses
        self.scale = 2 if supersample else 1
        self.sheet = manifest.open_sheet()
        self._part_cache: Dict[str, Image.Image] = {}
        # every part a bone can draw by default must exist on the sheet
        for bone in skeleton.bones:
            if bone.part is not None and bone.part not in manifest.parts:
                raise ValueError(
                    f"skeleton '{skeleton.name}' bone '{bone.name}' wants part "
                    f"'{bone.part}' which is not in the manifest for "
                    f"'{manifest.entity}'"
                )

    def _part_image(self, name: str) -> Image.Image:
        img = self._part_cache.get(name)
        if img is None:
            img = self.manifest.crop(self.sheet, name)
            if self.scale != 1:
                img = img.resize(
                    (img.width * self.scale, img.height * self.scale),
                    Image.NEAREST,
                )
            self._part_cache[name] = img
        return img

    def bake_frame(self, pose_frame: dict) -> Image.Image:
        """Bake a single frame: FK-resolve bones, rotate parts, composite by z."""
        s = self.scale
        cw, ch = self.skeleton.canvas
        canvas = Image.new("RGBA", (cw * s, ch * s), (0, 0, 0, 0))
        world = self.skeleton.world_transforms(pose_frame)
        for bone in self.skeleton.draw_order():
            bw = world[bone.name]
            if bw.hidden or bw.part is None:
                continue
            if bw.part not in self.manifest.parts:
                raise ValueError(
                    f"frame keys bone '{bone.name}' to unknown part '{bw.part}'"
                )
            region = self.manifest.parts[bw.part]
            img = self._part_image(bw.part)
            pivot = (region.pivot[0] * s, region.pivot[1] * s)
            effective_deg = bw.rotation_deg - region.angle_hint
            img, pivot = _rotate_around_pivot(img, pivot, effective_deg)
            px = int(round(bw.pos[0] * s - pivot[0]))
            py = int(round(bw.pos[1] * s - pivot[1]))
            _composite(canvas, img, px, py)
        if s != 1:
            # BOX downsample: averages the supersampled grid -> smoother rotated
            # edges. The real pipeline re-quantizes palettes afterwards (17 §5).
            canvas = canvas.resize((cw, ch), Image.BOX)
        return canvas

    def bake_animation(self, anim: Animation) -> List[Image.Image]:
        return [self.bake_frame(frame) for frame in anim.frames]

    def bake(
        self, out_dir: Path, animations: Optional[List[str]] = None
    ) -> dict:
        """Bake strips + combined sheet + atlas.json into ``out_dir``.

        Returns the atlas dict (also written to ``out_dir/atlas.json``).
        """
        out_dir = Path(out_dir)
        strips_dir = out_dir / "strips"
        strips_dir.mkdir(parents=True, exist_ok=True)

        names = animations or list(self.poses.animations)
        for n in names:
            if n not in self.poses.animations:
                raise ValueError(
                    f"unknown animation '{n}' (have: {list(self.poses.animations)})"
                )

        cw, ch = self.skeleton.canvas
        atlas: dict = {
            "entity": self.manifest.entity,
            "archetype": self.manifest.archetype,
            "skeleton": self.skeleton.name,
            "frame_size": [cw, ch],
            "anchor": list(self.skeleton.anchor),
            "combined_sheet": "sheet.png",
            "animations": {},
        }

        baked: Dict[str, List[Image.Image]] = {}
        for row, name in enumerate(names):
            anim = self.poses.animations[name]
            frames = self.bake_animation(anim)
            baked[name] = frames
            strip = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
            for i, f in enumerate(frames):
                strip.alpha_composite(f, dest=(i * cw, 0))
            strip_rel = f"strips/{name}.png"
            strip.save(out_dir / strip_rel)
            atlas["animations"][name] = {
                "frames": len(frames),
                "fps": anim.fps,
                "loop": anim.loop,
                "strip": strip_rel,
                "row": row,
            }

        max_frames = max(len(f) for f in baked.values())
        combined = Image.new(
            "RGBA", (cw * max_frames, ch * len(names)), (0, 0, 0, 0)
        )
        for row, name in enumerate(names):
            for i, f in enumerate(baked[name]):
                combined.alpha_composite(f, dest=(i * cw, row * ch))
        combined.save(out_dir / "sheet.png")

        (out_dir / "atlas.json").write_text(json.dumps(atlas, indent=2) + "\n")
        return atlas


def bake_bundle(
    manifest_path: Path,
    skeleton_name: str,
    out_dir: Path,
    animations: Optional[List[str]] = None,
    poses_path: Optional[str] = None,
    supersample: bool = False,
) -> dict:
    """Convenience one-call bake used by the service and the CLI."""
    manifest = PartsManifest.load(Path(manifest_path))
    skeleton = Skeleton.load(skeleton_name)
    poses = PoseLibrary.load(poses_path or skeleton.name)
    assembler = Assembler(manifest, skeleton, poses, supersample=supersample)
    return assembler.bake(Path(out_dir), animations)


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python -m genforge.pipeline.assemble",
        description="Bake animation strips from a parts sheet + skeleton + poses.",
    )
    ap.add_argument("--manifest", required=True, help="path to parts.json")
    ap.add_argument(
        "--skeleton", required=True, help="skeleton name (humanoid|dragon) or path"
    )
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument(
        "--animations",
        default=None,
        help="comma-separated animation names (default: all in the pose library)",
    )
    ap.add_argument(
        "--poses", default=None, help="pose library name or path (default: skeleton's)"
    )
    ap.add_argument(
        "--supersample",
        action="store_true",
        help="2x supersample then downsample for smoother rotations",
    )
    args = ap.parse_args(argv)

    anims = args.animations.split(",") if args.animations else None
    atlas = bake_bundle(
        Path(args.manifest),
        args.skeleton,
        Path(args.out),
        animations=anims,
        poses_path=args.poses,
        supersample=args.supersample,
    )
    for name, a in atlas["animations"].items():
        print(f"  baked {name}: {a['frames']} frames @ {a['fps']} fps -> {a['strip']}")
    print(f"  atlas: {Path(args.out) / 'atlas.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
