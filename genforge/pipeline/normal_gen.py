"""Tangent-space normal maps for pixel-art sprites — bevel + Sobel, no ML.

The Dead Cells trick: light 2D sprites as if they were 3D by shipping a
normal map next to each sheet. Learned generators exist for this exact
problem (cf. arXiv:2212.09692, which trains a network to infer pixel-art
normals); here we use the closed-form approximation those papers benchmark
against, because it is deterministic, dependency-free (numpy + PIL only)
and good enough for 640x360 sprites under dynamic lights:

1. **Height field.** The alpha silhouette is distance-transformed *inward*
   (chamfer metric, pure numpy): each opaque pixel's height is its distance
   to the nearest transparent pixel, clamped to a bevel width of ~3 px and
   smoothstepped — so every silhouette reads as a rounded bevel that catches
   rim light. The image border is treated as *not* an edge (replicate
   padding), so frames cropped to a sheet cell don't grow fake bevels.
   A small high-pass luminance term (hand-drawn shading minus its local
   mean, weight ~0.2) is added so interior pixel-art detail becomes relief.
2. **Normals.** Sobel gradients of the height field give the surface slope;
   the normal n = normalize(-dh/dx, +dh/dy_img, 1) is encoded (n+1)/2 into
   RGB with B as "up" (OpenGL / Godot green-up convention). Transparent
   pixels get the neutral normal (128, 128, 255); the output alpha channel
   copies the source alpha.

CLI (from the repo root):
    python3 -m genforge.pipeline.normal_gen <in.png> [out.png]
    python3 -m genforge.pipeline.normal_gen --batch [--art-dir DIR]

Batch mode walks every *.png under game/prototype/art/ (recursively), skips
files whose stem ends in ``_n`` and files that already have a ``<stem>_n.png``
sibling, and writes the missing normal maps next to their sources.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List, Optional, Tuple

import numpy as np
from PIL import Image

# defaults tuned for 640x360 pixel art under prototype/darkness.gd lights
BEVEL_WIDTH = 3.0          # px of silhouette rounded into the bevel
DETAIL_WEIGHT = 0.2        # luminance high-pass contribution (0.15-0.25)
DETAIL_BLUR_RADIUS = 2     # box radius of the local mean the high-pass removes
STRENGTH = 2.0             # gradient scale before normalization
ALPHA_SOLID = 128          # alpha >= this counts as inside the silhouette

_SQRT2 = float(np.sqrt(2.0))

GENFORGE_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ART_DIR = GENFORGE_ROOT.parent / "game" / "prototype" / "art"


# --------------------------------------------------------------------------
# height field
# --------------------------------------------------------------------------


def _interior_distance(mask: np.ndarray, max_dist: float) -> np.ndarray:
    """Chamfer distance from each True pixel to the nearest False pixel.

    Iterative min-propagation (1 / sqrt2 step costs), vectorized per pass;
    exact up to ``max_dist``, which is all the bevel needs. Out-of-image is
    replicate-padded so the border never acts as a silhouette edge.
    """
    far = max_dist + 2.0
    dist = np.where(mask, far, 0.0)
    for _ in range(int(np.ceil(max_dist)) + 1):
        p = np.pad(dist, 1, mode="edge")
        neigh = np.minimum.reduce([
            p[:-2, 1:-1] + 1.0, p[2:, 1:-1] + 1.0,
            p[1:-1, :-2] + 1.0, p[1:-1, 2:] + 1.0,
            p[:-2, :-2] + _SQRT2, p[:-2, 2:] + _SQRT2,
            p[2:, :-2] + _SQRT2, p[2:, 2:] + _SQRT2,
        ])
        dist = np.where(mask, np.minimum(dist, neigh), 0.0)
    return np.minimum(dist, far)


def _box_blur(field: np.ndarray, radius: int) -> np.ndarray:
    """Separable box blur with replicate edges (small radius, shift-and-sum)."""
    if radius <= 0:
        return field
    size = 2 * radius + 1
    p = np.pad(field, ((radius, radius), (0, 0)), mode="edge")
    out = np.zeros_like(field)
    for dy in range(size):
        out += p[dy:dy + field.shape[0], :]
    p = np.pad(out / size, ((0, 0), (radius, radius)), mode="edge")
    out = np.zeros_like(field)
    for dx in range(size):
        out += p[:, dx:dx + field.shape[1]]
    return out / size


def _height_field(rgba: np.ndarray, bevel_width: float, detail_weight: float) -> Tuple[np.ndarray, np.ndarray]:
    """RGBA uint8 array -> (height field float, opaque mask bool)."""
    alpha = rgba[..., 3]
    mask = alpha >= ALPHA_SOLID

    # bevel term: interior distance, clamped and smoothstepped to [0, 1]
    t = np.clip(_interior_distance(mask, bevel_width) / bevel_width, 0.0, 1.0)
    height = t * t * (3.0 - 2.0 * t)

    # detail term: high-pass of luminance, masked so the silhouette edge
    # (background zeros) never bleeds a halo into the blur
    lum = (rgba[..., :3].astype(np.float64) @ [0.299, 0.587, 0.114]) / 255.0
    m = mask.astype(np.float64)
    local_mean = _box_blur(lum * m, DETAIL_BLUR_RADIUS) / np.maximum(_box_blur(m, DETAIL_BLUR_RADIUS), 1e-6)
    height += np.where(mask, (lum - local_mean) * detail_weight, 0.0)
    return height, mask


# --------------------------------------------------------------------------
# normal encode
# --------------------------------------------------------------------------


def generate_normal_map(
    image: Image.Image,
    bevel_width: float = BEVEL_WIDTH,
    detail_weight: float = DETAIL_WEIGHT,
    strength: float = STRENGTH,
    height_bias: Optional[np.ndarray] = None,
) -> Image.Image:
    """RGBA sprite -> tangent-space normal map (RGBA, alpha follows source).

    height_bias: optional (H, W) float field added to the height inside the
    silhouette before the gradient — genforge.hifi feeds the sprite's own
    ramp shading in here so painted planes become real slopes.
    """
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    height, mask = _height_field(rgba, bevel_width, detail_weight)
    if height_bias is not None:
        height = height + np.where(mask, np.asarray(height_bias, dtype=np.float64), 0.0)

    # Sobel gradients (replicate edges); /8 normalizes to per-pixel slope
    p = np.pad(height, 1, mode="edge")
    gx = (
        (p[:-2, 2:] + 2.0 * p[1:-1, 2:] + p[2:, 2:])
        - (p[:-2, :-2] + 2.0 * p[1:-1, :-2] + p[2:, :-2])
    ) / 8.0
    gy = (
        (p[2:, :-2] + 2.0 * p[2:, 1:-1] + p[2:, 2:])
        - (p[:-2, :-2] + 2.0 * p[:-2, 1:-1] + p[:-2, 2:])
    ) / 8.0

    # image y grows downward; Godot normal maps are green-up (OpenGL), so
    # n = (-dh/dx, +dh/dy_img, 1) points outward at every silhouette edge
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(nx)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)

    out = np.empty_like(rgba)
    out[..., 0] = np.where(mask, np.clip(np.round((nx * inv_len * 0.5 + 0.5) * 255.0), 0, 255), 128)
    out[..., 1] = np.where(mask, np.clip(np.round((ny * inv_len * 0.5 + 0.5) * 255.0), 0, 255), 128)
    out[..., 2] = np.where(mask, np.clip(np.round((nz * inv_len * 0.5 + 0.5) * 255.0), 0, 255), 255)
    out[..., 3] = rgba[..., 3]
    return Image.fromarray(out, "RGBA")


# --------------------------------------------------------------------------
# file + batch plumbing
# --------------------------------------------------------------------------


def normal_path_for(src: Path) -> Path:
    """sheet.png -> sheet_n.png (same directory)."""
    return src.with_name(src.stem + "_n" + src.suffix)


def process_file(src: Path, dst: Optional[Path] = None) -> Path:
    """Generate and write the normal map for one sprite PNG."""
    dst = dst or normal_path_for(src)
    generate_normal_map(Image.open(src)).save(dst, "PNG")
    return dst


def run_batch(art_dir: Path = DEFAULT_ART_DIR) -> List[Path]:
    """Write a ``_n.png`` sibling for every *.png under ``art_dir`` missing one.

    Skips normal maps themselves (stem ends in ``_n``) and any source whose
    sibling already exists — existing maps are never overwritten. Returns the
    list of files written, sorted for determinism.
    """
    written: List[Path] = []
    for src in sorted(art_dir.rglob("*.png")):
        if src.stem.endswith("_n"):
            continue
        dst = normal_path_for(src)
        if dst.exists():
            continue
        written.append(process_file(src, dst))
    return written


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python3 -m genforge.pipeline.normal_gen",
        description="Bevel+Sobel normal maps for pixel-art sprites.",
    )
    parser.add_argument("input", nargs="?", type=Path, help="source sprite/sheet PNG")
    parser.add_argument("output", nargs="?", type=Path, help="output path (default: <input>_n.png)")
    parser.add_argument("--batch", action="store_true",
                        help="process every *.png under --art-dir lacking a _n.png sibling")
    parser.add_argument("--art-dir", type=Path, default=DEFAULT_ART_DIR,
                        help="batch root (default: game/prototype/art)")
    args = parser.parse_args(argv)

    if args.batch:
        if args.input is not None:
            parser.error("--batch takes no positional arguments (use --art-dir)")
        written = run_batch(args.art_dir)
        for path in written:
            print(f"wrote {path}")
        print(f"batch: {len(written)} normal map(s) written under {args.art_dir}")
        return 0

    if args.input is None:
        parser.error("an input PNG is required (or use --batch)")
    dst = process_file(args.input, args.output)
    print(f"wrote {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
