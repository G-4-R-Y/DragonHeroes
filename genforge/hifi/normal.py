"""Pillar 1 — normal-map-ready planar depth, made into an actual normal map.

Builds on genforge.pipeline.normal_gen (bevel + Sobel, the closed-form
approximation the Dead Cells stack is usually benchmarked against) with one
hifi addition: the quantised sprite's own shading becomes relief. In a
"volumetric cluster shaded" sprite the light shades ARE the planes facing the
key light, so ramp lightness (blurred to plane scale, mean-removed inside the
silhouette) is added to the bevel height before the gradient - the
"normal-map-ready planar depth" of the brief becomes a real slope field.

The emissive mask is PACKED into the normal map's blue channel low range
(B < 128 never occurs in a valid tangent normal: nz > 0 -> B >= 128; the
default flat normal is B = 255). sprite_lit.gdshader reads B < 0.5 as "this
pixel is emissive, intensity 1 - 2B", lights it flat (the core is 'unshaded
glow' by spec) and pushes it above 1.0 for the HDR bloom pass - so pillar 2
reaches the engine with zero extra textures, materials or nodes (canon 60 FPS
budget), and every existing sheet_n.png stays valid.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

from genforge.pipeline.normal_gen import generate_normal_map

from .palette import Palette, lightness_of

BEVEL_256 = 4.0          # px of silhouette rounded into the bevel at 256 grid
DETAIL_WEIGHT = 0.12     # luminance high-pass, lower than normal_gen's default:
                         # the relief term below carries the interior form instead
RELIEF_PX = 2.5          # height (px) between the darkest and lightest shade


def _box3(field: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """3x3 mean of field over mask pixels only (transparent never leaks in)."""
    f = np.where(mask, field, 0.0)
    m = mask.astype(np.float64)
    pf = np.pad(f, 1, mode="edge"); pm = np.pad(m, 1, mode="edge")
    acc = np.zeros_like(f); cnt = np.zeros_like(f)
    for dy in range(3):
        for dx in range(3):
            acc += pf[dy:dy + f.shape[0], dx:dx + f.shape[1]]
            cnt += pm[dy:dy + f.shape[0], dx:dx + f.shape[1]]
    return np.where(cnt > 0, acc / np.maximum(cnt, 1), 0.0)


def relief_field(idx: np.ndarray, palette: Palette, relief_px: float = RELIEF_PX) -> np.ndarray:
    """Plane-scale lightness relief, zero-mean inside the silhouette."""
    mask = idx >= 0
    L = lightness_of(idx, palette)
    smooth = _box3(L, mask)
    if mask.any():
        smooth = np.where(mask, smooth - smooth[mask].mean(), 0.0)
    return smooth * relief_px


def hifi_normal(albedo: np.ndarray, idx: np.ndarray, palette: Palette,
                emissive_mask: np.ndarray, emissive_intensity: np.ndarray,
                grid_px: int = 256) -> np.ndarray:
    scale = grid_px / 256.0
    bias = relief_field(idx, palette, RELIEF_PX * scale)
    n = np.asarray(generate_normal_map(Image.fromarray(albedo, "RGBA"),
                                       bevel_width=BEVEL_256 * scale,
                                       detail_weight=DETAIL_WEIGHT,
                                       height_bias=bias)).copy()
    if emissive_mask.any():
        # floor, so unpack() never reads an intensity below the one packed
        b = np.clip(np.floor(127.0 * (1.0 - emissive_intensity)), 0, 127).astype(np.uint8)
        n[emissive_mask, 0] = 128
        n[emissive_mask, 1] = 128
        n[emissive_mask, 2] = b[emissive_mask]
    return n


def unpack_emissive(normal: np.ndarray) -> np.ndarray:
    """Inverse of the blue-channel packing: intensity 0..1 (0 where not emissive)."""
    b = normal[..., 2].astype(np.float64)
    return np.where(b < 128, 1.0 - b / 127.0, 0.0)
