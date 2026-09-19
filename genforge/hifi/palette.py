"""Pillar "deep 8-shade color ramps, pronounced directional hue-shifting".

The palette is BUILT from the sprite (its material families are the hue
clusters the model painted) and then DISCIPLINED: each family becomes one
ramp of exactly `shades` steps spanning its lightness range, with the hue
rotated cool in the shadows and warm in the highlights (the directional
hue-shift the brief names). A shared dark ink colour anchors every ramp and is
the Ink-Hold Perimeter colour. Quantisation is nearest-in-OKLab, exactly as
living/atlas.py does it, so the output is an indexed image ready for the
biome LUT shaders (design/17 §3.4).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

import numpy as np

from .colour import chroma, hex_of, hue_deg, hue_delta, oklab_to_rgb, rgb_to_oklab

WARM_DEG, COOL_DEG = 90.0, 270.0     # highlights lean yellow, shadows lean violet-blue
ACHROMATIC = 0.025                   # OKLab chroma under which a pixel is grey/bone


@dataclass
class PaletteConfig:
    ramps: int = 6
    shades: int = 8
    hue_shift_deg: float = 8.0       # per ramp end, from the ramp's mean hue
    ink_hex: Optional[str] = None    # None = derived (L .16, cool)
    emissive_hue_deg: Optional[float] = None


@dataclass
class Ramp:
    name: str
    hue_deg: float
    chroma: float
    shades: List[str]                # hex, dark -> light
    pixels: int

    def as_dict(self) -> Dict[str, object]:
        return {"name": self.name, "hue_deg": round(self.hue_deg, 1),
                "chroma": round(self.chroma, 4), "shades": self.shades, "pixels": self.pixels}


@dataclass
class Palette:
    ink: str
    ramps: List[Ramp]
    colors: List[str]                # ink first, then ramps in order (dark->light)
    ramp_of: List[int]               # per colour index: -1 ink, else ramp index
    shade_of: List[int]              # per colour index: -1 ink, else 0..shades-1

    def as_dict(self) -> Dict[str, object]:
        return {"schema": "dragon-heroes.hifi-palette.v1", "ink": self.ink,
                "ramps": [r.as_dict() for r in self.ramps], "colors": self.colors}

    @property
    def rgb(self) -> np.ndarray:
        return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in self.colors], dtype=np.uint8)


def _ink(cfg: PaletteConfig) -> Tuple[str, np.ndarray]:
    if cfg.ink_hex:
        rgb = np.array([int(cfg.ink_hex.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.uint8)
        return hex_of(rgb), rgb
    lab = np.array([0.16, 0.03 * np.cos(np.radians(COOL_DEG)), 0.03 * np.sin(np.radians(COOL_DEG))])
    rgb = oklab_to_rgb(lab[None, :])[0]
    return hex_of(rgb), rgb


def _seed_hues(h: np.ndarray, k: int, forced: Optional[float]) -> List[float]:
    """Histogram peaks at least 30 degrees apart (deterministic init)."""
    hist, edges = np.histogram(h, bins=36, range=(0.0, 360.0))
    centres = (edges[:-1] + edges[1:]) / 2
    seeds: List[float] = [] if forced is None else [forced % 360.0]
    for i in np.argsort(-hist):
        if len(seeds) >= k or hist[i] == 0:
            break
        c = float(centres[i])
        if all(hue_delta(c, s) >= 30.0 for s in seeds):
            seeds.append(c)
    while len(seeds) < k:               # degenerate images: spread the rest evenly
        seeds.append((seeds[-1] + 360.0 / k) % 360.0 if seeds else 0.0)
    return seeds


def _cluster_hues(h: np.ndarray, seeds: List[float], iters: int = 25) -> Tuple[np.ndarray, np.ndarray]:
    centres = np.array(seeds, dtype=np.float64)
    assign = np.zeros(len(h), dtype=np.int32)
    for _ in range(iters):
        d = hue_delta(h[:, None], centres[None, :])
        new = np.argmin(d, axis=1)
        if np.array_equal(new, assign) and _ > 0:
            break
        assign = new
        for k in range(len(centres)):
            m = assign == k
            if m.any():   # circular mean
                ang = np.radians(h[m])
                centres[k] = np.degrees(np.arctan2(np.sin(ang).mean(), np.cos(ang).mean())) % 360.0
    return assign, centres


def _shift_sign(hue: float) -> float:
    """+1 if increasing the hue angle moves it toward warm (90 deg) rather than cool."""
    to_warm = (WARM_DEG - hue + 180.0) % 360.0 - 180.0
    return 1.0 if to_warm >= 0 else -1.0


def _ramp(name: str, labs: np.ndarray, hue: float, cfg: PaletteConfig, achromatic: bool) -> Ramp:
    n = cfg.shades
    L = labs[:, 0]
    lo, hi = float(np.percentile(L, 2)), float(np.percentile(L, 98))
    lo, hi = max(0.22, lo), min(0.96, hi)
    if hi - lo < 0.35:                       # "deep" ramps: a real dark->light span
        mid = (lo + hi) / 2
        lo, hi = max(0.22, mid - 0.175), min(0.96, mid + 0.175)
    steps = lo + (hi - lo) * (np.arange(n) + 0.5) / n
    c = 0.0 if achromatic else float(np.clip(np.median(chroma(labs)), 0.04, 0.22))
    sign = _shift_sign(hue)
    shades = []
    for i, Li in enumerate(steps):
        t = (i - (n - 1) / 2) / ((n - 1) / 2)          # -1 dark .. +1 light
        hi_deg = hue + sign * cfg.hue_shift_deg * t if not achromatic else hue
        # chroma sags a little in the deepest shadow and the hottest highlight
        ci = c * (1.0 - 0.25 * t * t)
        lab = np.array([Li, ci * np.cos(np.radians(hi_deg)), ci * np.sin(np.radians(hi_deg))])
        shades.append(hex_of(oklab_to_rgb(lab[None, :])[0]))
    return Ramp(name, hue % 360.0, c, shades, int(len(labs)))


def build(rgba: np.ndarray, cfg: PaletteConfig) -> Palette:
    """Material ramps from the sprite's opaque pixels."""
    opaque = rgba[..., 3] > 0
    rgb = rgba[opaque][:, :3]
    if len(rgb) == 0:
        raise ValueError("no opaque pixels to build a palette from")
    lab = rgb_to_oklab(rgb)
    C = chroma(lab)
    grey = C < ACHROMATIC
    ramps: List[Ramp] = []
    k = cfg.ramps
    if grey.mean() >= 0.03 and k > 1:
        ramps.append(_ramp("grey", lab[grey], 0.0, cfg, achromatic=True))
        k -= 1
    chrom = lab[~grey]
    if len(chrom) >= 8:
        h = hue_deg(chrom)
        seeds = _seed_hues(h, k, cfg.emissive_hue_deg)
        assign, centres = _cluster_hues(h, seeds)
        for i in range(len(centres)):
            m = assign == i
            if m.sum() < 4:
                continue
            ramps.append(_ramp(f"ramp_{i}", chrom[m], float(centres[i]), cfg, achromatic=False))
    if not ramps:
        ramps.append(_ramp("grey", lab, 0.0, cfg, achromatic=True))
    ink_hex, _ = _ink(cfg)
    colors, ramp_of, shade_of = [ink_hex], [-1], [-1]
    for ri, r in enumerate(ramps):
        for si, s in enumerate(r.shades):
            colors.append(s); ramp_of.append(ri); shade_of.append(si)
    return Palette(ink_hex, ramps, colors, ramp_of, shade_of)


def quantize(rgba: np.ndarray, palette: Palette) -> Tuple[np.ndarray, np.ndarray, Dict[str, float]]:
    """Nearest palette colour in OKLab. -> (rgba_q, index_map [-1 transparent], metrics)."""
    rgba = np.asarray(rgba, dtype=np.uint8)
    opaque = rgba[..., 3] > 0
    idx = np.full(rgba.shape[:2], -1, dtype=np.int16)
    out = np.zeros_like(rgba)
    if not opaque.any():
        return out, idx, {"mean_oklab_error": 0.0, "max_oklab_error": 0.0, "colors_used": 0}
    lab = rgb_to_oklab(rgba[opaque][:, :3])
    plab = rgb_to_oklab(palette.rgb)
    # chunked to keep memory flat on 1024^2 inputs
    best = np.empty(len(lab), dtype=np.int64); err = np.empty(len(lab))
    for s in range(0, len(lab), 65536):
        d = np.linalg.norm(lab[s:s + 65536, None, :] - plab[None, :, :], axis=-1)
        best[s:s + 65536] = np.argmin(d, axis=1)
        err[s:s + 65536] = d[np.arange(len(d)), best[s:s + 65536]]
    idx[opaque] = best.astype(np.int16)
    out[opaque, :3] = palette.rgb[best]
    out[opaque, 3] = 255
    return out, idx, {"mean_oklab_error": round(float(err.mean()), 4),
                      "max_oklab_error": round(float(err.max()), 4),
                      "colors_used": int(len(np.unique(best)))}


def shade_usage(idx: np.ndarray, palette: Palette) -> List[int]:
    """Distinct shades used per ramp (the 'deep ramp' evidence)."""
    used = np.unique(idx[idx >= 0])
    per = [set() for _ in palette.ramps]
    for u in used:
        r = palette.ramp_of[int(u)]
        if r >= 0:
            per[r].add(palette.shade_of[int(u)])
    return [len(s) for s in per]


def dither_score(idx: np.ndarray) -> float:
    """Fraction of fully-opaque 2x2 windows forming a checker (a==d, b==c, a!=b)."""
    a, b, c, d = idx[:-1, :-1], idx[:-1, 1:], idx[1:, :-1], idx[1:, 1:]
    win = (a >= 0) & (b >= 0) & (c >= 0) & (d >= 0)
    if not win.any():
        return 0.0
    checker = win & (a == d) & (b == c) & (a != b)
    return round(float(checker.sum() / win.sum()), 4)


def lightness_of(idx: np.ndarray, palette: Palette) -> np.ndarray:
    """Per-pixel OKLab L of the quantised image (0 where transparent)."""
    L = rgb_to_oklab(palette.rgb)[:, 0]
    return np.where(idx >= 0, L[np.clip(idx, 0, None)], 0.0)


def dedither(idx: np.ndarray, protect: Optional[np.ndarray] = None, passes: int = 3) -> Tuple[np.ndarray, int]:
    """Kill checker dithering and point noise: an opaque pixel none of whose
    4-neighbours share its index (with >= 3 opaque neighbours) takes the
    majority neighbour index (ties -> the lower index, i.e. the darker
    shade). protect: pixels never changed (the emissive core)."""
    idx = idx.copy()
    changed = 0
    h, w = idx.shape
    parity = (np.add.outer(np.arange(h), np.arange(w)) % 2) == 0
    for k in range(passes * 2):
        pad = np.pad(idx, 1, constant_values=-1)
        nb = np.stack([pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]])  # 4 x H x W
        opaque = idx >= 0
        nb_opaque = (nb >= 0).sum(axis=0)
        same = (nb == idx[None]).any(axis=0)
        cand = opaque & ~same & (nb_opaque >= 3)
        # one parity per pass: a checker updated all at once merely swaps its
        # two colours forever; alternating parities collapses it in two passes
        cand &= parity if k % 2 == 0 else ~parity
        if protect is not None:
            cand &= ~protect
        if not cand.any():
            if k % 2 == 1:
                break
            continue
        # majority of the opaque neighbours (lower index wins ties)
        ys, xs = np.where(cand)
        vals = nb[:, ys, xs]                     # 4 x N
        new = np.empty(len(ys), dtype=idx.dtype)
        for k in range(len(ys)):
            v = vals[:, k]; v = v[v >= 0]
            u, c = np.unique(v, return_counts=True)
            new[k] = u[np.argmax(c)]             # np.unique is sorted: ties -> lowest
        idx[ys, xs] = new
        changed += int(len(ys))
    return idx, changed


def render(idx: np.ndarray, palette: Palette) -> np.ndarray:
    """Index map -> RGBA (transparent where idx < 0)."""
    out = np.zeros(idx.shape + (4,), dtype=np.uint8)
    m = idx >= 0
    out[m, :3] = palette.rgb[idx[m]]
    out[m, 3] = 255
    return out
