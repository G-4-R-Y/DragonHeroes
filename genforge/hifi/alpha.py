"""Pillar "isolated game asset on a clean transparent background".

Models paint what they were asked to imply: a checkerboard "transparency"
(the bellwether v2 rejection), a flat studio backdrop, a bloom halo baked into
soft alpha. This stage makes the background actually transparent, hardens the
alpha to binary (design/26 rule 3: never bake bloom into a silhouette) and
drops stray specks, and it REPORTS what it had to do so the scorecard can
tell a clean generation from a rescued one.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Tuple

import numpy as np

from .colour import chroma, rgb_to_oklab
from .labels import drop_small

ALPHA_SOLID = 128


def border_band(shape: Tuple[int, int], frac: float = 0.06) -> np.ndarray:
    h, w = shape
    t = max(2, int(round(min(h, w) * frac)))
    m = np.zeros((h, w), dtype=bool)
    m[:t, :] = m[-t:, :] = True
    m[:, :t] = m[:, -t:] = True
    return m


def dominant_colours(rgb: np.ndarray, k: int = 2, levels: int = 12) -> List[Tuple[np.ndarray, float]]:
    """Coarse-histogram peaks -> [(mean rgb, coverage fraction)] sorted by coverage."""
    if len(rgb) == 0:
        return []
    q = (rgb.astype(np.int64) * levels) // 256
    keys = q[:, 0] * levels * levels + q[:, 1] * levels + q[:, 2]
    uniq, inv, counts = np.unique(keys, return_inverse=True, return_counts=True)
    order = np.argsort(-counts)[:k]
    out = []
    for o in order:
        members = rgb[inv == o]
        out.append((members.mean(axis=0), counts[o] / len(rgb)))
    return out


def checkerboard_score(rgba: np.ndarray) -> Dict[str, float]:
    """How much the border band looks like a painted transparency checkerboard
    (two light, low-chroma tones sharing the band) or a solid opaque backdrop."""
    band = border_band(rgba.shape[:2])
    px = rgba[band]
    opaque = px[..., 3] >= ALPHA_SOLID
    opaque_frac = float(opaque.mean()) if len(px) else 0.0
    if opaque_frac < 0.5:
        return {"checkerboard": 0.0, "solid_backdrop": 0.0, "band_opaque": opaque_frac}
    rgb = px[opaque][:, :3]
    dom = dominant_colours(rgb, k=2)
    lab = rgb_to_oklab(np.array([d[0] for d in dom]))
    light_grey = (lab[:, 0] > 0.55) & (chroma(lab) < 0.05)
    checker = 0.0
    if len(dom) == 2 and light_grey.all():
        checker = float(min(dom[0][1], dom[1][1]) * 2.0)   # both tones share the band
    solid = float(dom[0][1]) if len(dom) else 0.0
    return {"checkerboard": round(min(1.0, checker), 4),
            "solid_backdrop": round(solid, 4), "band_opaque": round(opaque_frac, 4)}


def _flood_from_border(bg_like: np.ndarray) -> np.ndarray:
    """Pixels reachable from the image border through bg-like pixels (4-conn)."""
    h, w = bg_like.shape
    reach = np.zeros_like(bg_like)
    reach[0, :] = bg_like[0, :]; reach[-1, :] = bg_like[-1, :]
    reach[:, 0] = bg_like[:, 0]; reach[:, -1] = bg_like[:, -1]
    for _ in range(h + w):
        grown = reach.copy()
        grown[1:, :] |= reach[:-1, :]
        grown[:-1, :] |= reach[1:, :]
        grown[:, 1:] |= reach[:, :-1]
        grown[:, :-1] |= reach[:, 1:]
        grown &= bg_like
        if np.array_equal(grown, reach):
            break
        reach = grown
    return reach


@dataclass
class AlphaReport:
    background_mode: str          # "alpha" | "checkerboard" | "solid"
    checkerboard_score: float
    solid_backdrop: float
    cleared_px: int               # background pixels made transparent
    halo_px: int                  # semi-transparent pixels hardened away
    specks_removed: int
    speck_px: int
    fringe_px: int = 0            # matte fringe eaten on a painted backdrop

    def as_dict(self) -> Dict[str, object]:
        return dict(self.__dict__)


def enforce(rgba: np.ndarray, tol: float = 0.09, speck_px: int = 0, fringe_iters: int = 3,
            fringe_tol: float = 0.20) -> Tuple[np.ndarray, AlphaReport]:
    """Make the background transparent and the alpha binary.

    tol: OKLab distance under which a pixel counts as background-coloured
    (the flood only crosses such pixels, from the border inward, so a
    bg-coloured patch INSIDE the creature is kept).
    fringe_iters / fringe_tol: painted backdrops only — up to this many
    one-pixel passes eat the anti-aliased matte fringe (pixels adjacent to
    the cleared background, within fringe_tol of a backdrop colour, and not
    dark), so a light haze never becomes sprite. Bounded, sub-logical-pixel.
    speck_px: drop opaque components smaller than this (0 = keep all).
    """
    rgba = np.asarray(rgba, dtype=np.uint8).copy()
    a = rgba[..., 3]
    score = checkerboard_score(rgba)
    band = border_band(rgba.shape[:2])
    mode, cleared, fringe = "alpha", 0, 0
    if score["band_opaque"] >= 0.5:
        mode = "checkerboard" if score["checkerboard"] >= 0.3 else "solid"
        band_rgb = rgba[band & (a >= ALPHA_SOLID)][:, :3]
        k = 2 if mode == "checkerboard" else 1
        centres = np.array([d[0] for d in dominant_colours(band_rgb, k=k)])
        lab = rgb_to_oklab(rgba[..., :3])
        clab = rgb_to_oklab(centres)
        dist = np.min(np.linalg.norm(lab[..., None, :] - clab[None, None, :, :], axis=-1), axis=-1)
        bg_like = dist <= tol
        reach = _flood_from_border(bg_like)
        # matte fringe: the model anti-aliased the silhouette INTO the painted
        # backdrop, so a ring of half-blended pixels survives the strict flood.
        # Eat it from the background side, one pixel per pass, only where the
        # colour still leans toward the backdrop (dark ink stops it at once).
        fringe = 0
        for _ in range(fringe_iters):
            pad = np.pad(reach, 1, constant_values=True)
            adj = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
            eat = adj & ~reach & (dist <= fringe_tol) & (lab[..., 0] >= 0.45)
            if not eat.any():
                break
            reach |= eat
            fringe += int(eat.sum())
        cleared = int((reach & (a >= ALPHA_SOLID)).sum())
        a = np.where(reach, 0, a).astype(np.uint8)
    halo = int(((a > 0) & (a < ALPHA_SOLID)).sum())
    a = np.where(a >= ALPHA_SOLID, 255, 0).astype(np.uint8)
    removed_c, removed_px = 0, 0
    if speck_px > 0:
        kept, removed_c, removed_px = drop_small(a > 0, speck_px)
        a = np.where(kept, 255, 0).astype(np.uint8)
    rgba[..., 3] = a
    rgba[a == 0] = 0   # clean RGB under transparency (deterministic bytes)
    return rgba, AlphaReport(mode, score["checkerboard"], score["solid_backdrop"],
                             cleared, halo, removed_c, removed_px, fringe)
