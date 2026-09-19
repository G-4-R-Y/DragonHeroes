"""Pillar 5 — the Ink-Hold Perimeter.

"A continuous dark perimeter line, 1-2 px, unbreakable" is a GAMEPLAY
requirement in the brief (hitbox and posture read in a tenth of a second among
dozens of enemies and VFX). Measure it as the fraction of silhouette-boundary
pixels that are dark ink, and repair it by painting the ring in the palette's
ink colour. The repair never touches emissive pixels (the core glows through
to the edge only if the model drew it there; that is reported, not hidden).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Optional, Tuple

import numpy as np

from .colour import rgb_to_oklab
from .labels import label

INK_L_MAX = 0.36        # OKLab lightness at or under which a pixel reads as ink


def perimeter_ring(opaque: np.ndarray) -> np.ndarray:
    """Opaque pixels with a transparent 4-neighbour (image border counts as transparent)."""
    pad = np.pad(opaque, 1, constant_values=False)
    outside = ~pad
    touch = (outside[:-2, 1:-1] | outside[2:, 1:-1] | outside[1:-1, :-2] | outside[1:-1, 2:])
    return opaque & touch


def inner_ring(opaque: np.ndarray, ring: np.ndarray) -> np.ndarray:
    """The second pixel row inward: opaque, not ring, 4-adjacent to the ring."""
    pad = np.pad(ring, 1, constant_values=False)
    adj = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    return opaque & ~ring & adj


def ink_mask(rgba: np.ndarray, l_max: float = INK_L_MAX) -> np.ndarray:
    opaque = rgba[..., 3] > 0
    L = rgb_to_oklab(rgba[..., :3])[..., 0]
    return opaque & (L <= l_max)


@dataclass
class OutlineReport:
    ring_px: int
    ink_px: int
    coverage: float            # ink_px / ring_px
    gaps: int                  # ring pixels that are not ink
    silhouettes: int           # connected opaque components
    ink_loops: int             # connected components of the ink ring
    continuous: bool           # every silhouette has exactly one unbroken ink loop
    width2_coverage: float     # ink share of the second ring inward

    def as_dict(self) -> Dict[str, object]:
        return dict(self.__dict__)


def measure(rgba: np.ndarray, l_max: float = INK_L_MAX) -> OutlineReport:
    opaque = rgba[..., 3] > 0
    ring = perimeter_ring(opaque)
    ink = ink_mask(rgba, l_max)
    ring_ink = ring & ink
    ring_px, ink_px = int(ring.sum()), int(ring_ink.sum())
    _, sil = label(opaque, 8)
    _, loops = label(ring_ink, 8)
    ring2 = inner_ring(opaque, ring)
    w2 = float((ring2 & ink).sum() / max(1, ring2.sum()))
    cov = ink_px / max(1, ring_px)
    continuous = ring_px > 0 and ink_px == ring_px and loops == sil
    return OutlineReport(ring_px, ink_px, round(cov, 4), ring_px - ink_px,
                         sil, loops, bool(continuous), round(w2, 4))


def repair(rgba: np.ndarray, ink_rgb, width: int = 1, l_max: float = INK_L_MAX,
           protect: Optional[np.ndarray] = None) -> Tuple[np.ndarray, int]:
    """Paint the perimeter ring (and the inner ring for width 2) in ink where it
    is not ink already. protect: mask never repainted (emissive pixels)."""
    out = np.asarray(rgba, dtype=np.uint8).copy()
    opaque = out[..., 3] > 0
    ring = perimeter_ring(opaque)
    target = ring.copy()
    if width >= 2:
        target |= inner_ring(opaque, ring)
    ink = ink_mask(out, l_max)
    paint = target & ~ink
    if protect is not None:
        paint &= ~protect
    out[paint, :3] = np.asarray(ink_rgb, dtype=np.uint8)
    return out, int(paint.sum())
