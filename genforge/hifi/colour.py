"""Vectorised OKLab helpers (numpy) — batched twin of living/atlas.oklab."""
from __future__ import annotations

import numpy as np


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    c = np.asarray(c, dtype=np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(np.asarray(c, dtype=np.float64), 0.0, 1.0)
    s = np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)
    return np.clip(np.round(s * 255.0), 0, 255).astype(np.uint8)


def rgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    """(...,3) uint8 sRGB -> (...,3) float OKLab (L, a, b)."""
    lin = srgb_to_linear(rgb)
    r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.stack([
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ], axis=-1)


def oklab_to_rgb(lab: np.ndarray) -> np.ndarray:
    """(...,3) OKLab -> (...,3) uint8 sRGB (clipped)."""
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    lin = np.stack([
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ], axis=-1)
    return linear_to_srgb(lin)


def chroma(lab: np.ndarray) -> np.ndarray:
    return np.hypot(lab[..., 1], lab[..., 2])


def hue_deg(lab: np.ndarray) -> np.ndarray:
    """OKLab hue angle in [0, 360)."""
    return np.degrees(np.arctan2(lab[..., 2], lab[..., 1])) % 360.0


def hue_delta(a_deg, b_deg) -> np.ndarray:
    """Smallest angular distance between two hue angles (degrees)."""
    d = np.abs((np.asarray(a_deg) - np.asarray(b_deg) + 180.0) % 360.0 - 180.0)
    return d


def hex_of(rgb) -> str:
    r, g, b = (int(v) for v in rgb[:3])
    return f"#{r:02x}{g:02x}{b:02x}"


def rgb_of(hex_str: str):
    h = hex_str.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
