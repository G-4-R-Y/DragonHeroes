"""The gate — every pillar measured, PASS/FAIL with reasons.

A scorecard is computed for ANY RGBA image against a creature spec, so it
grades our own output, a raw model image, or a competitor's sprite the same
way. Hard checks decide the verdict; advisory checks are reported and scored
but cannot fail an asset (they are heuristics for taste-adjacent properties:
pillow shading, light direction). ``score`` is a 0-100 weighted number for
ranking candidates and generators; the verdict is what ships.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional

import numpy as np

from . import alpha as alpha_mod
from . import emissive as emissive_mod
from . import grid as grid_mod
from . import outline as outline_mod
from . import palette as palette_mod
from .colour import hue_deg, hue_delta, rgb_of, rgb_to_oklab
from .creatures import CreatureSpec


@dataclass
class GateConfig:
    grid_px: int = 256
    ink_l_max: float = outline_mod.INK_L_MAX
    min_outline_coverage: float = 0.98
    max_dither: float = 0.02
    max_colors_over_palette: int = 0        # colours beyond ramps*shades+ink
    min_deep_ramps: int = 2                 # ramps using >= min_deep_shades shades (hard)
    rich_ramps: int = 3                     # advisory: ramps using >= min_deep_shades shades
    min_deep_shades: int = 6
    min_fill: float = 0.12                  # silhouette / canvas
    max_fill: float = 0.90
    min_emissive_px: int = 12
    max_emissive_fraction: float = 0.20
    min_grid_conformity: float = 0.35       # raw inputs only
    max_pillow: float = 0.55                # advisory
    min_directional: float = 0.25           # advisory
    hue_shift_min_deg: float = 4.0          # advisory: shadows vs highlights hue delta


@dataclass
class Check:
    name: str
    passed: bool
    hard: bool
    detail: str
    value: Optional[float] = None

    def as_dict(self) -> Dict[str, object]:
        return dict(self.__dict__)


@dataclass
class Scorecard:
    checks: List[Check] = field(default_factory=list)
    metrics: Dict[str, object] = field(default_factory=dict)

    @property
    def verdict(self) -> str:
        return "PASS" if all(c.passed for c in self.checks if c.hard) else "FAIL"

    @property
    def failures(self) -> List[str]:
        return [f"{c.name}: {c.detail}" for c in self.checks if c.hard and not c.passed]

    @property
    def score(self) -> float:
        """0-100: hard checks 70 points (equal weight), advisory 30."""
        hard = [c for c in self.checks if c.hard]
        soft = [c for c in self.checks if not c.hard]
        h = 70.0 * (sum(c.passed for c in hard) / len(hard)) if hard else 70.0
        s = 30.0 * (sum(c.passed for c in soft) / len(soft)) if soft else 30.0
        return round(h + s, 1)

    def as_dict(self) -> Dict[str, object]:
        return {"schema": "dragon-heroes.hifi-scorecard.v1", "verdict": self.verdict,
                "score": self.score, "failures": self.failures,
                "checks": [c.as_dict() for c in self.checks], "metrics": self.metrics}

    def table(self) -> str:
        rows = [f"{'check':<22} {'hard':<5} {'ok':<4} detail", "-" * 72]
        for c in self.checks:
            rows.append(f"{c.name:<22} {'hard' if c.hard else 'adv.':<5} "
                        f"{'yes' if c.passed else 'NO':<4} {c.detail}")
        rows.append("-" * 72)
        rows.append(f"verdict {self.verdict}   score {self.score}")
        return "\n".join(rows)


# --------------------------------------------------------------------------
# shading heuristics (advisory)
# --------------------------------------------------------------------------

def _interior_distance(opaque: np.ndarray, cap: int = 24) -> np.ndarray:
    """Chamfer-ish distance to the nearest transparent pixel (4-conn steps)."""
    d = np.where(opaque, np.inf, 0.0)
    ring = outline_mod.perimeter_ring(opaque)
    d[ring] = 1.0
    cur = ring
    for k in range(2, cap + 1):
        pad = np.pad(cur, 1, constant_values=False)
        grow = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & opaque & np.isinf(d)
        if not grow.any():
            break
        d[grow] = float(k)
        cur = grow
    d[np.isinf(d)] = float(cap)
    return d


def pillow_score(rgba: np.ndarray) -> float:
    """Correlation between lightness and distance-from-edge over the interior
    (1 = perfectly concentric 'pillow', ~0 = form shaded by a direction)."""
    opaque = rgba[..., 3] > 0
    if opaque.sum() < 64:
        return 0.0
    L = rgb_to_oklab(rgba[..., :3])[..., 0]
    d = _interior_distance(opaque)
    inner = opaque & (d > 1)             # the ink ring would bias this
    if inner.sum() < 32:
        return 0.0
    x, y = d[inner], L[inner]
    if x.std() < 1e-6 or y.std() < 1e-6:
        return 0.0
    return round(float(max(0.0, np.corrcoef(x, y)[0, 1])), 4)


def directional_score(rgba: np.ndarray) -> Dict[str, float]:
    """Agreement of the lightness gradient direction across the interior:
    one key light gives one dominant direction (|mean unit gradient| -> 1)."""
    opaque = rgba[..., 3] > 0
    L = rgb_to_oklab(rgba[..., :3])[..., 0]
    d = _interior_distance(opaque)
    inner = opaque & (d > 2)
    if inner.sum() < 32:
        return {"directional": 0.0, "light_deg": 0.0}
    gy, gx = np.gradient(np.where(opaque, L, np.nan))
    gx = np.where(inner, gx, 0.0); gy = np.where(inner, gy, 0.0)
    gx = np.nan_to_num(gx); gy = np.nan_to_num(gy)
    mag = np.hypot(gx, gy)
    sel = inner & (mag > 0.01)
    if sel.sum() < 16:
        return {"directional": 0.0, "light_deg": 0.0}
    ux, uy = gx[sel] / mag[sel], gy[sel] / mag[sel]
    mx, my = ux.mean(), uy.mean()
    return {"directional": round(float(np.hypot(mx, my)), 4),
            "light_deg": round(float(np.degrees(np.arctan2(-my, mx)) % 360.0), 1)}


def ramp_hue_shift(palette: palette_mod.Palette) -> float:
    """Mean |hue(highlight) - hue(shadow)| across chromatic ramps (degrees)."""
    deltas = []
    for r in palette.ramps:
        if r.chroma <= 0.0 or len(r.shades) < 2:
            continue
        lab = rgb_to_oklab(np.array([rgb_of(r.shades[0]), rgb_of(r.shades[-1])], dtype=np.uint8))
        deltas.append(float(hue_delta(hue_deg(lab[0:1])[0], hue_deg(lab[1:2])[0])))
    return round(float(np.mean(deltas)), 2) if deltas else 0.0


# --------------------------------------------------------------------------
# the gate
# --------------------------------------------------------------------------

def evaluate(rgba: np.ndarray, spec: CreatureSpec, cfg: GateConfig,
             palette: Optional[palette_mod.Palette] = None,
             idx: Optional[np.ndarray] = None,
             extra_metrics: Optional[Dict[str, object]] = None) -> Scorecard:
    """Grade an RGBA image. Pass palette+idx for a processed sprite; a raw
    image gets a palette built from its own colours (so colour-count checks
    measure what the model drew)."""
    rgba = np.asarray(rgba, dtype=np.uint8)
    sc = Scorecard()
    h, w = rgba.shape[:2]
    opaque = rgba[..., 3] > 0
    m: Dict[str, object] = {"size": [int(w), int(h)]}

    # -- background / alpha --------------------------------------------------
    bg = alpha_mod.checkerboard_score(rgba)
    semi = int(((rgba[..., 3] > 0) & (rgba[..., 3] < 255)).sum())
    m.update({"background": bg, "semi_alpha_px": semi})
    sc.checks.append(Check("transparent_bg", bg["band_opaque"] < 0.5, True,
                           f"border band opaque {bg['band_opaque']:.2f}; checkerboard {bg['checkerboard']:.2f}",
                           bg["band_opaque"]))
    sc.checks.append(Check("binary_alpha", semi == 0, True, f"{semi} semi-transparent px", semi))

    # -- grid -------------------------------------------------------------------
    native = (w == cfg.grid_px and h == cfg.grid_px)
    if native:
        m["grid"] = {"pitch": 1, "conformity": 1.0, "native": True}
        sc.checks.append(Check("native_grid", True, True, f"{w}x{h} native grid", 1.0))
    else:
        # estimate the lattice on the isolated sprite: a painted backdrop or
        # checkerboard has its own (irrelevant) lattice
        cleaned = alpha_mod.enforce(rgba)[0] if bg["band_opaque"] >= 0.5 else rgba
        est = grid_mod.estimate(cleaned, cfg.grid_px)
        m["grid"] = {**est.as_dict(), "native": False}
        ok = est.conformity >= cfg.min_grid_conformity
        sc.checks.append(Check("native_grid", False, True,
                               f"{w}x{h} is not the {cfg.grid_px} grid (pitch {est.pitch}, "
                               f"conformity {est.conformity:.2f}, {'gridded' if ok else 'painted'})",
                               est.conformity))

    fill = float(opaque.mean())
    ys, xs = np.where(opaque) if opaque.any() else (np.array([0]), np.array([0]))
    touches = bool(opaque.any() and (ys.min() == 0 or xs.min() == 0 or ys.max() == h - 1 or xs.max() == w - 1))
    m.update({"fill": round(fill, 4), "touches_border": touches})
    sc.checks.append(Check("isolated_fill", (cfg.min_fill <= fill <= cfg.max_fill) and not touches, True,
                           f"fill {fill:.2f} (want {cfg.min_fill}-{cfg.max_fill}); "
                           f"{'touches border' if touches else 'clear margin'}", fill))

    # -- palette / ramps --------------------------------------------------------
    if palette is None or idx is None:
        if opaque.any():
            pcfg = palette_mod.PaletteConfig(ramps=spec.ramps, emissive_hue_deg=spec.emissive_hue_deg)
            palette = palette_mod.build(rgba, pcfg)
            _, idx, _ = palette_mod.quantize(rgba, palette)
    colors = int(len(np.unique(rgba[opaque][:, :3].astype(np.uint32)
                                @ np.array([65536, 256, 1], dtype=np.uint32)))) if opaque.any() else 0
    budget = 1 + spec.ramps * 8
    usage = palette_mod.shade_usage(idx, palette) if palette is not None and idx is not None else []
    deep = sum(1 for u in usage if u >= cfg.min_deep_shades)
    m.update({"colors": colors, "palette_budget": budget, "shades_per_ramp": usage,
              "hue_shift_deg": ramp_hue_shift(palette) if palette else 0.0})
    sc.checks.append(Check("indexed_palette", colors <= budget + cfg.max_colors_over_palette, True,
                           f"{colors} colours vs budget {budget} (ink + {spec.ramps}x8)", colors))
    sc.checks.append(Check("deep_ramps", deep >= cfg.min_deep_ramps, True,
                           f"{deep} ramps use >= {cfg.min_deep_shades} shades {usage}", deep))
    sc.checks.append(Check("rich_ramps", deep >= cfg.rich_ramps, False,
                           f"{deep} deep ramps (want >= {cfg.rich_ramps})", deep))
    sc.checks.append(Check("hue_shift", m["hue_shift_deg"] >= cfg.hue_shift_min_deg, False,
                           f"shadow->highlight hue delta {m['hue_shift_deg']} deg", m["hue_shift_deg"]))

    dither = palette_mod.dither_score(idx) if idx is not None else 0.0
    m["dither"] = dither
    sc.checks.append(Check("no_dithering", dither <= cfg.max_dither, True,
                           f"checker 2x2 share {dither:.3f}", dither))

    # -- outline ------------------------------------------------------------------
    ol = outline_mod.measure(rgba, cfg.ink_l_max)
    m["outline"] = ol.as_dict()
    sc.checks.append(Check("ink_hold_perimeter", ol.coverage >= cfg.min_outline_coverage and ol.ink_loops >= 1
                           and ol.ink_loops <= max(1, ol.silhouettes), True,
                           f"ink on {ol.coverage:.3f} of the perimeter, {ol.gaps} gaps, "
                           f"{ol.ink_loops} loop(s) for {ol.silhouettes} silhouette(s)", ol.coverage))

    # -- emissive ------------------------------------------------------------------
    _, emask, _, er = emissive_mod.extract(rgba, spec.emissive_hue_deg)
    m["emissive"] = er.as_dict()
    if spec.has_emissive:
        ok = cfg.min_emissive_px <= er.pixels and er.fraction <= cfg.max_emissive_fraction
        sc.checks.append(Check("emissive_core", ok, True,
                               f"{er.pixels} px ({er.fraction:.3f} of silhouette) at hue {spec.emissive_hue_deg}",
                               er.pixels))
    else:
        sc.checks.append(Check("emissive_core", True, True, "no core expected", 0))

    # -- shading heuristics (advisory) -----------------------------------------------
    pil = pillow_score(rgba)
    dr = directional_score(rgba)
    m.update({"pillow": pil, **dr})
    sc.checks.append(Check("no_pillow_shading", pil <= cfg.max_pillow, False,
                           f"lightness~depth correlation {pil:.2f}", pil))
    sc.checks.append(Check("directional_shading", dr["directional"] >= cfg.min_directional, False,
                           f"gradient agreement {dr['directional']:.2f}, key light {dr['light_deg']} deg",
                           dr["directional"]))
    if extra_metrics:
        m.update(extra_metrics)
    sc.metrics = m
    return sc
