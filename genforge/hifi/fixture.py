"""A synthetic 'what a model returns' candidate — for tests and the self-test.

Draws a small creature on the 256 grid the RIGHT way (ink perimeter, six
material ramps lit from the upper left, a cyan core), then breaks it the way
image models do: bilinear 4x upscale (mixels + seam blur), a painted
checkerboard "transparency", a soft bloom halo around the core, a gap in the
outline, a dithered patch. process() must undo every one of those and the
scorecard must say FAIL before and PASS after. No model is involved, so the
pipeline's own behaviour is pinned independently of any provider.
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw

from .colour import oklab_to_rgb

GRID = 256


def _ramp(hue_deg: float, chroma: float, n: int = 8, lo: float = 0.28, hi: float = 0.86):
    out = []
    for i in range(n):
        L = lo + (hi - lo) * i / (n - 1)
        h = np.radians(hue_deg)
        out.append(tuple(int(v) for v in oklab_to_rgb(np.array([[L, chroma * np.cos(h), chroma * np.sin(h)]]))[0]))
    return out


def clean_sprite(seed: int = 7) -> Image.Image:
    """256x256 RGBA: a quadruped-ish blob with ink outline, six ramps, cyan core."""
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ramps = {"moss": _ramp(140, 0.09), "bark": _ramp(60, 0.07), "bronze": _ramp(75, 0.12),
             "bone": _ramp(80, 0.015), "hide": _ramp(35, 0.06), "core": _ramp(195, 0.14, lo=0.6, hi=0.95)}
    ink = (14, 12, 22, 255)
    # body masses (ellipses) filled with a light-from-upper-left ramp gradient
    masses = [("hide", (70, 96, 200, 176)), ("moss", (60, 70, 150, 130)),
              ("bark", (150, 40, 205, 110)), ("bone", (186, 60, 230, 100))]
    legs = [("hide", (84, 160, 104, 232)), ("hide", (110, 164, 128, 236)),
            ("bark", (150, 160, 170, 234)), ("bark", (174, 164, 192, 232))]
    for name, box in legs + masses:
        d.ellipse(box, fill=ramps[name][3])
    a = np.asarray(img).copy()
    # directional shading: shade index from the upper-left key light
    yy, xx = np.mgrid[0:GRID, 0:GRID]
    key = ((xx - 40) * 0.6 + (yy - 40) * 0.8) / 260.0
    for name, box in legs + masses:
        m = np.zeros((GRID, GRID), dtype=bool)
        sub = Image.new("L", (GRID, GRID), 0); ImageDraw.Draw(sub).ellipse(box, fill=255)
        m = np.asarray(sub) > 0
        # distance to the mass' upper-left edge decides the shade
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        rel = ((xx - cx) * 0.6 + (yy - cy) * 0.8) / max(box[2] - box[0], box[3] - box[1])
        shade = np.clip(np.round(3.5 - rel * 9.0 - key * 1.5), 0, 7).astype(int)
        cols = np.array(ramps[name], dtype=np.uint8)
        a[m, :3] = cols[shade[m]]
        a[m, 3] = 255
    # cyan core (unshaded highlight + two rim shades)
    core = Image.new("L", (GRID, GRID), 0); ImageDraw.Draw(core).ellipse((100, 118, 128, 150), fill=255)
    cm = np.asarray(core) > 0
    a[cm, :3] = ramps["core"][6]; a[cm, 3] = 255
    inner = Image.new("L", (GRID, GRID), 0); ImageDraw.Draw(inner).ellipse((106, 124, 122, 144), fill=255)
    a[np.asarray(inner) > 0, :3] = ramps["core"][7]
    # ink perimeter (1 px) + bronze antler-ish bar with its own outline
    d2 = ImageDraw.Draw(Image.fromarray(a, "RGBA"))
    opaque = a[..., 3] > 0
    pad = np.pad(opaque, 1); outside = ~pad
    ring = opaque & (outside[:-2, 1:-1] | outside[2:, 1:-1] | outside[1:-1, :-2] | outside[1:-1, 2:])
    a[ring] = ink
    return Image.fromarray(a, "RGBA")


def model_like_candidate(seed: int = 7, pitch: int = 4, checkerboard: bool = True,
                         halo: bool = True, outline_gap: bool = True, dither: bool = True) -> Image.Image:
    """The clean sprite, damaged the way a diffusion model damages pixel art."""
    clean = np.asarray(clean_sprite(seed)).copy()
    rng = np.random.default_rng(seed)
    if outline_gap:   # lineless stretch: replace ink on a band of the perimeter with the body colour
        band = (slice(150, 200), slice(60, 110))
        sub = clean[band]
        opaque = sub[..., 3] > 0
        ink = (sub[..., :3].astype(int).sum(-1) < 80) & opaque
        sub[ink, :3] = (120, 96, 70)
    if dither:        # a checker-dithered patch inside the hide
        ys, xs = np.mgrid[150:170, 90:120]
        chk = ((ys + xs) % 2 == 0)
        clean[150:170, 90:120][chk & (clean[150:170, 90:120][..., 3] > 0), :3] = (60, 50, 40)
    big = Image.fromarray(clean, "RGBA").resize((GRID * pitch, GRID * pitch), Image.BILINEAR)
    b = np.asarray(big).copy().astype(np.float32)
    if halo:          # bloom baked into alpha around the core
        yy, xx = np.mgrid[0:GRID * pitch, 0:GRID * pitch]
        r = np.hypot(xx - 114 * pitch, yy - 134 * pitch) / (26.0 * pitch)
        glow = np.clip(1.0 - r, 0, 1) ** 2 * 0.6
        trans = b[..., 3] < 128
        b[trans, :3] = np.array([90, 220, 230]) * glow[trans, None] + b[trans, :3] * (1 - glow[trans, None])
        b[trans, 3] = np.maximum(b[trans, 3], glow[trans] * 255 * 0.45)
    out = b.astype(np.uint8)
    if checkerboard:  # painted transparency
        yy, xx = np.mgrid[0:GRID * pitch, 0:GRID * pitch]
        cells = ((yy // (8 * pitch)) + (xx // (8 * pitch))) % 2
        bg = np.where(cells[..., None] == 0, np.array([236, 236, 236]), np.array([204, 204, 204])).astype(np.float32)
        af = out[..., 3:4].astype(np.float32) / 255.0
        rgb = out[..., :3].astype(np.float32) * af + bg * (1 - af)
        out = np.concatenate([np.clip(rgb, 0, 255).astype(np.uint8),
                              np.full((GRID * pitch, GRID * pitch, 1), 255, np.uint8)], axis=-1)
    return Image.fromarray(out, "RGBA")
