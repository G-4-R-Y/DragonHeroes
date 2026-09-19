"""Pillar "crisp native 1:1 pixel grid, strictly zero mixels".

A model asked for a 256-grid sprite at 1024x1024 returns a picture OF pixel
art: a lattice of roughly 4x4 blocks with blurred seams, blocks that straddle
the lattice (mixels), and sometimes a different pitch altogether. This stage
measures the lattice the image actually follows (edge concentration on a
candidate pitch), resamples ONE logical pixel per cell (per-channel median,
robust to seam blur), and places the result on the target grid without any
non-integer scaling. Output pixels are native by construction; the input's
grid conformity is reported so a generator that draws real pixels scores
above one whose picture merely resembles them.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Tuple

import numpy as np

from .colour import rgb_to_oklab

MIN_CONFORMITY = 0.08   # lattice gain under which the input counts as painted


def _luma(rgba: np.ndarray) -> np.ndarray:
    """OKLab L with transparent pixels pulled to a distinct value, so alpha
    edges count as edges too (float64, H x W)."""
    L = rgb_to_oklab(rgba[..., :3])[..., 0]
    return np.where(rgba[..., 3] >= 128, L, -0.25)


def _homogeneity(L: np.ndarray, p: int, phx: int, phy: int) -> float:
    """1 - (mean within-cell variance / total variance) for the lattice (p, phase)."""
    h, w = L.shape
    ch, cw = (h - phy) // p, (w - phx) // p
    if ch < 2 or cw < 2:
        return 0.0
    crop = L[phy:phy + ch * p, phx:phx + cw * p]
    cells = crop.reshape(ch, p, cw, p).transpose(0, 2, 1, 3).reshape(ch, cw, p * p)
    within = cells.var(axis=2).mean()
    total = crop.var()
    if total <= 1e-9:
        return 0.0
    return float(1.0 - within / total)


def _knot_profiles(L: np.ndarray):
    """Per-column / per-row mass of first and second differences. Nearest
    upscales put all first-difference mass on cell boundaries; bilinear
    upscales put all curvature on the knots; a painting spreads both."""
    d1x = np.abs(L[:, 1:] - L[:, :-1]).sum(axis=0); d1x = np.concatenate([[0.0], d1x])
    d1y = np.abs(L[1:, :] - L[:-1, :]).sum(axis=1); d1y = np.concatenate([[0.0], d1y])
    d2x = np.abs(L[:, 2:] - 2 * L[:, 1:-1] + L[:, :-2]).sum(axis=0); d2x = np.concatenate([[0.0], d2x, [0.0]])
    d2y = np.abs(L[2:, :] - 2 * L[1:-1, :] + L[:-2, :]).sum(axis=1); d2y = np.concatenate([[0.0], d2y, [0.0]])
    return (d1x, d2x), (d1y, d2y)


def _gain(profile: np.ndarray, p: int) -> float:
    """Best-phase share of the profile's mass on a pitch-p lattice, rescaled
    so uniform (1/p) is 0 and a perfect lattice is 1."""
    # 8-bit rounding leaves a noise floor on every column; the median column
    # of a gridded image is off-lattice, so subtracting it isolates the knots
    profile = np.maximum(profile - np.median(profile), 0.0)
    total = profile.sum()
    if total <= 0:
        return 0.0
    conc = np.bincount(np.arange(len(profile)) % p, weights=profile, minlength=p) / total
    base = 1.0 / p
    return float(max(0.0, (conc.max() - base) / (1.0 - base)))


def _best_phase(L: np.ndarray, p: int) -> Tuple[int, int]:
    """Cell phase (x, y) with the most homogeneous cells for pitch p."""
    hx = [_homogeneity(L, p, phx, 0) for phx in range(p)]
    hy = [_homogeneity(L, p, 0, phy) for phy in range(p)]
    return int(np.argmax(hx)), int(np.argmax(hy))


@dataclass
class GridEstimate:
    pitch: int
    phase_x: int
    phase_y: int
    conformity: float          # 0 painted .. 1 perfectly gridded input
    requested_pitch: int
    cells: Tuple[int, int]

    def as_dict(self) -> Dict[str, object]:
        d = dict(self.__dict__)
        d["cells"] = list(self.cells)
        return d


def _estimate_once(rgba: np.ndarray, grid_px: int, max_pitch: int = 16) -> GridEstimate:
    """One level of lattice search (see estimate).

    Pitch: concentration of difference mass (first OR second difference, per
    axis) on a candidate lattice. Divisors of the true pitch concentrate just
    as well, multiples do not, so the LARGEST pitch within 80% of the best
    gain is the fundamental. Phase: the cell offset whose cells are most
    homogeneous (works for boundary knots and centre knots alike).
    Conformity is the winning gain: ~1 for real pixel art scaled up, ~0 for a
    painting that merely resembles it.
    """
    h, w = rgba.shape[:2]
    requested = max(1, int(round(max(w, h) / grid_px)))
    if requested == 1 and max(w, h) <= grid_px:
        return GridEstimate(1, 0, 0, 1.0, 1, (w, h))
    L = _luma(rgba)
    a = rgba[..., 3] >= 128
    y0 = x0 = 0
    if a.any() and not a.all():   # the content box: a background band adds nothing
        ys, xs = np.where(a)
        y0, x0 = max(0, ys.min() - max_pitch), max(0, xs.min() - max_pitch)
        L = L[y0:ys.max() + 1 + max_pitch, x0:xs.max() + 1 + max_pitch]
    (d1x, d2x), (d1y, d2y) = _knot_profiles(L)
    gains = {}
    for p in range(2, max_pitch + 1):
        gx = max(_gain(d1x, p), _gain(d2x, p))
        gy = max(_gain(d1y, p), _gain(d2y, p))
        gains[p] = min(gx, gy)
    best = max(gains.values())
    if best < MIN_CONFORMITY:
        pitch, conf = requested, round(best, 4)
    else:
        pitch = max(p for p, g in gains.items() if g >= 0.8 * best)
        # the requested grid is a strong prior: keep it when it explains the
        # lattice nearly as well as the winner
        if requested in gains and gains[requested] >= 0.6 * best:
            pitch = requested
        conf = round(gains[pitch], 4)
    phx, phy = _best_phase(L, pitch)
    phx = (phx + x0) % pitch
    phy = (phy + y0) % pitch
    cells = ((w - phx) // pitch, (h - phy) // pitch)
    return GridEstimate(pitch, phx, phy, conf, requested, cells)


def estimate(rgba: np.ndarray, grid_px: int, max_pitch: int = 16, max_levels: int = 4) -> GridEstimate:
    """Find the lattice the image follows, harmonics resolved by recursion.

    Interpolated upscales leave difference mass on sub-lattices (a bilinear
    x4 image is also, weakly, a x2 image), so one level can return a divisor
    of the true pitch. After snapping at the found pitch, the result is
    re-estimated: if it is still gridded, the pitches multiply and the phases
    compose, until the snapped image is lattice-free or already the target
    grid. Conformity is the first level's gain — how much the ORIGINAL image
    is real pixel art (1) rather than a painting of it (0)."""
    first = _estimate_once(rgba, grid_px, max_pitch)
    total_p, phx, phy = first.pitch, first.phase_x, first.phase_y
    cur = rgba
    est = first
    for _ in range(max_levels - 1):
        if est.pitch <= 1:
            break
        cur = snap(cur, est)
        if max(cur.shape[:2]) <= grid_px:
            break
        nxt = _estimate_once(cur, grid_px, max_pitch)
        # a deeper level must be STRONG and PLAUSIBLE: a small image of real
        # pixels has few difference peaks, which can line up by chance
        remaining = max(1, int(round(max(cur.shape[:2]) / grid_px)))
        if nxt.pitch <= 1 or nxt.conformity < 0.3 or nxt.pitch > remaining + 1:
            break
        phx = phx + total_p * nxt.phase_x
        phy = phy + total_p * nxt.phase_y
        total_p *= nxt.pitch
        est = nxt
    h, w = rgba.shape[:2]
    return GridEstimate(total_p, phx, phy, first.conformity, first.requested_pitch,
                        ((w - phx) // total_p, (h - phy) // total_p))


def snap(rgba: np.ndarray, est: GridEstimate) -> np.ndarray:
    """One logical pixel per lattice cell: per-channel median over the cell."""
    p, phx, phy = est.pitch, est.phase_x, est.phase_y
    if p == 1:
        return np.asarray(rgba, dtype=np.uint8).copy()
    cw, ch = est.cells
    crop = rgba[phy:phy + ch * p, phx:phx + cw * p].astype(np.float32)
    blocks = crop.reshape(ch, p, cw, p, 4).transpose(0, 2, 1, 3, 4).reshape(ch, cw, p * p, 4)
    med = np.median(blocks, axis=2)
    out = np.clip(np.round(med), 0, 255).astype(np.uint8)
    a = np.where(out[..., 3] >= 128, 255, 0).astype(np.uint8)
    out[..., 3] = a
    out[a == 0] = 0
    return out


def block_reduce(rgba: np.ndarray, factor: int) -> np.ndarray:
    """Integer down-scale by per-channel median (never a resample filter)."""
    if factor <= 1:
        return rgba
    h, w = rgba.shape[:2]
    ch, cw = h // factor, w // factor
    est = GridEstimate(factor, 0, 0, 1.0, factor, (cw, ch))
    return snap(rgba[:ch * factor, :cw * factor], est)


def fit_canvas(rgba: np.ndarray, grid_px: int, margin_frac: float = 0.03) -> Tuple[np.ndarray, Dict[str, object]]:
    """Place the snapped sprite on a grid_px square: centred horizontally,
    feet at the bottom margin, transparent margin all round. Integer block
    reduction only if the sprite is bigger than the canvas allows."""
    margin = max(2, int(round(grid_px * margin_frac)))
    inner = grid_px - 2 * margin
    a = rgba[..., 3] > 0
    if not a.any():
        raise ValueError("sprite is empty after alpha enforcement")
    ys, xs = np.where(a)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    crop = rgba[box[1]:box[3], box[0]:box[2]]
    factor = 1
    bh, bw = crop.shape[:2]
    if max(bh, bw) > inner:
        factor = int(np.ceil(max(bh, bw) / inner))
        crop = block_reduce(crop, factor)
        a2 = crop[..., 3] > 0
        ys, xs = np.where(a2)
        crop = crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        bh, bw = crop.shape[:2]
    canvas = np.zeros((grid_px, grid_px, 4), dtype=np.uint8)
    x0 = (grid_px - bw) // 2
    y0 = grid_px - margin - bh
    canvas[y0:y0 + bh, x0:x0 + bw] = crop
    return canvas, {"margin_px": margin, "reduced_by": factor,
                    "sprite_px": [int(bw), int(bh)], "anchor": [grid_px // 2, grid_px - margin]}
