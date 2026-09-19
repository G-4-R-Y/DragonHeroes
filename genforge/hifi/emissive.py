"""Pillar 2 — the Emissive Channel Mask.

The brief: the glowing core is an EMISSION channel the engine blooms, not a
light colour painted on. The model paints it as saturated bright pixels; this
stage separates them into their own channel (colour where emissive,
transparent elsewhere - the living/atlas.py emissive.png convention) using the
creature's declared glow hue, plus a per-pixel intensity from lightness for
the "sharp unshaded glow highlights" the brief asks for.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Optional, Tuple

import numpy as np

from .colour import chroma, hue_deg, hue_delta, rgb_to_oklab
from .labels import drop_small, label


@dataclass
class EmissiveReport:
    expected: bool
    hue_deg: Optional[float]
    pixels: int
    fraction: float              # of the silhouette
    components: int
    bbox: Optional[list]

    def as_dict(self) -> Dict[str, object]:
        return dict(self.__dict__)


def extract(rgba: np.ndarray, hue: Optional[float], hue_tol: float = 32.0,
            min_chroma: float = 0.09, min_l: float = 0.55, min_component_px: int = 6,
            min_component_share: float = 0.10
            ) -> Tuple[np.ndarray, np.ndarray, np.ndarray, EmissiveReport]:
    """-> (emissive_rgba, mask, intensity[0..1], report). hue None = no core expected
    (nothing is extracted; saturated highlights stay albedo). Components under
    min_component_px, or under min_component_share of the largest one, are
    strays (a highlight that happens to sit near the glow hue) and stay albedo:
    a two-pixel bloom on a moss highlight is noise, not a core."""
    h, w = rgba.shape[:2]
    opaque = rgba[..., 3] > 0
    mask = np.zeros((h, w), dtype=bool)
    intensity = np.zeros((h, w), dtype=np.float32)
    em = np.zeros_like(rgba)
    if hue is None or not opaque.any():
        return em, mask, intensity, EmissiveReport(hue is not None, hue, 0, 0.0, 0, None)
    lab = rgb_to_oklab(rgba[..., :3])
    L, C, H = lab[..., 0], chroma(lab), hue_deg(lab)
    cand = opaque & (C >= min_chroma) & (L >= min_l) & (hue_delta(H, hue) <= hue_tol)
    mask, _, _ = drop_small(cand, min_component_px)
    lab_c, comps = label(mask, 8)
    if comps > 1:
        sizes = np.bincount(lab_c.ravel(), minlength=comps + 1)[1:]
        keep = sizes >= max(min_component_px, min_component_share * sizes.max())
        mask &= keep[np.clip(lab_c - 1, 0, None)] & (lab_c > 0)
        comps = int(keep.sum())
    if mask.any():
        # intensity: brightest emissive pixels bloom hardest (0.5 .. 1.0)
        Lm = L[mask]
        lo, hi = float(Lm.min()), float(Lm.max())
        t = (L - lo) / max(1e-6, hi - lo)
        intensity = np.where(mask, 0.5 + 0.5 * np.clip(t, 0, 1), 0.0).astype(np.float32)
        em[mask, :3] = rgba[mask, :3]
        em[mask, 3] = 255
        ys, xs = np.where(mask)
        bbox = [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]
    else:
        bbox = None
    px = int(mask.sum())
    return em, mask, intensity, EmissiveReport(True, hue, px, round(px / max(1, int(opaque.sum())), 4),
                                               int(comps), bbox)
