"""Deterministic compositor for the GitHub README banner (R76).

Ricardo, 2026-09-22: *"can we improve our banner? In github repo's readme. I
liked the vibe, but the giant dragon head in the horizon is bizarre and
hallucinated lol. Perhaps use our new quests themes to represent stuff! The
heroes party and spirit dog vibe was neat, tho, keep that. Reminds me of lord
of the rings journeys - companionship and adventure"*.

So this is a RE-ART, not a re-generation. The v1 plate (kept beside this script
as ``plate-v1-genai.png``) got the fellowship, the lantern causeway and the
blue-hour marsh kingdom right; it got exactly one thing badly wrong — a
monumental dragon head filling the right third at an impossible scale, drawn in
a different material language than everything around it, with a waterfall
pouring out of its jaw. Nothing else in the frame is wrong, so nothing else is
touched: the mask below repaints the head, its horns, its wing and the neck,
and stops at the ruin skyline.

What takes its place comes from our own fiction instead of a model's
imagination, so the banner advertises the thing we actually ship weekly:

* the **bell shrine** of `The Bell Beneath the Fen`
  (``genforge/releases/bell_beneath_fen.json``) — the drowned Haven tied a
  warning bell to Orun's antlers and it called the living home for seven
  nights; it is the released chapter's central artifact, and it becomes the
  right-hand anchor the dragon head used to be;
* a **ferry mooring** out on the open water — Keeper Ilyra's crossing, standing
  in for the travellers/rescues encounter class, and carrying the causeway's
  lantern trail on across the fen;
* a **dragon at the distance a dragon belongs at**, riding the high mist: the
  "telegraphed rare boss" of the encounter director (docs/design/28), seen long
  before it is ever fought. The subject was never the problem in v1. The scale
  was.

Read left to right the banner is now a journey — the party, the lanterns, the
crossing, the shrine, and something enormous circling far off. Companionship
and adventure, with the weekly quest themes as its landmarks.

Why a compositor rather than another text-to-image round: this harness has no
image-generation tool and ``OPENAI_API_KEY`` is unset, but the better reason is
that a banner only one session can reproduce is not an asset, it is a lucky
file. Every pixel here is a pure function of the committed plate plus fixed
seeds, so ``--check`` can prove the committed PNG is exactly what this code
makes. ``prompt.txt`` carries the corrected v2 prompt for the day the paid path
is run against the same brief.

Usage::

    python3 -m genforge.pipeline.readme_banner             # render + write
    python3 -m genforge.pipeline.readme_banner --check     # verify committed PNG
    python3 -m genforge.pipeline.readme_banner --debug     # overlay mask + boxes
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import List, Sequence, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ART = Path(__file__).resolve().parents[2] / "docs" / "art" / "readme-banner"
PLATE = ART / "plate-v1-genai.png"
OUT = ART / "dragon-heroes-banner.png"

Pt = Tuple[float, float]

# The released chapter's own palette (fen_bells.style.lumen_nocturne). The
# banner may not invent colours the game does not use.
NAVY = (14, 24, 34)
DEEP = (8, 14, 23)
TEAL = (23, 87, 87)
LUMEN = (126, 212, 186)
LUMEN_HI = (215, 255, 242)
BRONZE_DARK = (74, 55, 36)
BRONZE = (152, 113, 67)
BRONZE_HI = (216, 184, 117)
LANTERN = (243, 206, 140)
HORIZON = (46, 74, 96)      # blue-hour air the distance washes toward

# Measured off the plate with a 1% grid overlay (see the work journal):
#   the "S" of HEROES ends at x=0.775 (glow to 0.778), letters span y 0.385-0.575
#   the dragon's wing reaches back to x=0.685 above y=0.30
#   its snout tip is at (0.775, 0.33); the jaw waterfall runs down to y=0.63
#   the gothic ruins we keep start at y=0.50, the far bank at y~0.58
WING_X, WING_Y = 0.632, 0.352      # region 1: the wing, above the lettering
HEAD_X, HEAD_Y = 0.782, 0.575      # region 2: head, neck, jaw — down to the ruins
FALL_X0, FALL_X1, FALL_Y = 0.783, 0.852, 0.635   # region 3: the jaw's waterfall
TITLE_KEEP = (0.560, 0.360, 0.779, 0.600)        # hard veto around the last letters


# ---------------------------------------------------------------------------
# numeric helpers
# ---------------------------------------------------------------------------

def _smoothstep(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _fbm(h: int, w: int, seed: int, cells: int = 4, octaves: int = 5) -> np.ndarray:
    """Value-noise in [0,1]: bicubic-upscaled random grids, amplitude halving."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), dtype=np.float32)
    amp = total = 0.0
    amp = 1.0
    for o in range(octaves):
        c = cells * (2 ** o)
        grid = rng.random((max(2, c), max(2, int(c * w / h))))
        layer = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (w, h), Image.BICUBIC)
        acc += amp * (np.asarray(layer, dtype=np.float32) / 255.0)
        total += amp
        amp *= 0.5
    return acc / total


def _blend(base: np.ndarray, layer: np.ndarray, mask: np.ndarray) -> np.ndarray:
    return base * (1.0 - mask[..., None]) + layer * mask[..., None]


def _screen(dst: Image.Image, glow: Image.Image) -> Image.Image:
    """Screen-blend a blurred layer so light adds instead of covering."""
    a = np.asarray(dst.convert("RGB"), dtype=np.float32) / 255.0
    g = np.asarray(glow.convert("RGBA"), dtype=np.float32) / 255.0
    out = 1.0 - (1.0 - a) * (1.0 - g[..., :3] * g[..., 3:4])
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def _bezier(a: Pt, c: Pt, b: Pt, n: int = 12) -> List[Pt]:
    return [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t * t * b[0],
             (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t * t * b[1])
            for t in (i / n for i in range(n + 1))]


# ---------------------------------------------------------------------------
# step 1 — retire the dragon head
# ---------------------------------------------------------------------------

def _repaint_mask(w: int, h: int) -> np.ndarray:
    """Feathered alpha over exactly the hallucinated shapes.

    Three soft half-planes unioned, because the dragon is not a rectangle: it
    reaches furthest left up in the sky (the wing), sits behind the last
    letters at mid height, and drools a waterfall past the skyline. Hard edges
    read as seams on a painted plate, so every boundary is a smoothstep ramp,
    and the lettering gets a hard veto on top of all of it.
    """
    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :].repeat(h, 0)
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None].repeat(w, 1)

    def band(x0, y1, fx, fy, x1=None):
        m = _smoothstep((xs - x0) / fx) * (1.0 - _smoothstep((ys - y1) / fy))
        if x1 is not None:
            m = m * (1.0 - _smoothstep((xs - x1) / fx))
        return m

    mask = np.maximum(band(WING_X, WING_Y, 0.045, 0.090),
                      band(HEAD_X, HEAD_Y, 0.024, 0.072))
    mask = np.maximum(mask, band(FALL_X0, FALL_Y, 0.014, 0.045, x1=FALL_X1))

    kx0, ky0, kx1, ky1 = TITLE_KEEP
    keep = (_smoothstep((xs - kx0) / 0.02) * (1.0 - _smoothstep((xs - kx1) / 0.006))
            * _smoothstep((ys - ky0) / 0.012) * (1.0 - _smoothstep((ys - ky1) / 0.012)))
    return np.clip(mask * (1.0 - keep), 0.0, 1.0)


def _sky_fill(plate: Image.Image) -> np.ndarray:
    """Material for the patch, derived from the plate's own sky.

    Not a copy-paste: for every scanline we take a robust colour from the quiet
    strip left of the dragon (x 0.55-0.675) and stretch it across, which
    reproduces the plate's exact vertical gradient and colour temperature with
    none of its structure -- so the patch cannot be caught by matching a
    landmark to its twin.

    Two things have to be excluded or the sample lies. Gold: the title runs
    right through that strip, and a plain percentile came back tan, painting a
    desert into the sky. Sky, mist and water are all blue-dominant and the
    lettering is emphatically not, so only B > R pixels are sampled. And the
    plate darkens a ledger band behind the title for legibility, which no
    amount of smoothing removes -- so the whole title band is dropped and the
    gradient is interpolated straight through it. Clouds and drifting fog then
    come back as noise in the chapter's own palette.
    """
    w, h = plate.size
    arr = np.asarray(plate, dtype=np.float32) / 255.0
    strip = arr[:, int(0.55 * w):int(0.675 * w), :]
    blueish = strip[..., 2] > strip[..., 0] * 1.02

    col = np.zeros((h, 3), dtype=np.float32)
    good = np.zeros(h, dtype=bool)
    ys = np.arange(h) / float(h)
    for y in range(h):
        if 0.330 < ys[y] < 0.630:                 # the title's ledger band
            continue
        m = blueish[y]
        if int(m.sum()) >= 12:
            col[y] = np.percentile(strip[y][m], 62, axis=0)
            good[y] = True
    idx = np.arange(h)
    for c in range(3):
        col[:, c] = np.interp(idx, idx[good], col[good, c])
    for _ in range(2):                            # 41-row box smooth, twice
        pad = np.pad(col, ((20, 20), (0, 0)), mode="edge")
        col = np.stack([np.convolve(pad[:, c], np.ones(41) / 41, mode="valid")
                        for c in range(3)], axis=1)
    sky = np.repeat(col[:, None, :], w, axis=1)

    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :].repeat(h, 0)
    yy = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None].repeat(w, 1)

    # cloud bodies: low-frequency noise lifting toward the plate's cloud grey
    cloud = _fbm(h, w, seed=1904, cells=3, octaves=4)
    cloud = _smoothstep((cloud - 0.46) / 0.30)
    cloud *= (1.0 - _smoothstep((yy - 0.26) / 0.20))
    sky = _blend(sky, sky * 1.30 + 0.030, cloud * 0.50)

    # the ground fog the far bank stands in, thickest at the skyline
    fog = _fbm(h, w, seed=808, cells=5, octaves=4)
    band = np.exp(-((yy - 0.505) / 0.115) ** 2)
    sky = _blend(sky, np.array(NAVY, np.float32)[None, None, :] / 255.0 * 2.5,
                 np.clip(band * (0.28 + 0.55 * fog), 0, 1) * 0.60)

    # atmospheric perspective + the plate's own corner vignette
    sky *= (1.0 - 0.09 * _smoothstep((xs - 0.68) / 0.32))[..., None]
    sky *= (1.0 - 0.08 * _smoothstep((yy - 0.34) / 0.26))[..., None]
    sky *= (1.0 - 0.15 * _smoothstep((xs - 0.90) / 0.10)
            * (1.0 - _smoothstep((yy - 0.12) / 0.30)))[..., None]
    return np.clip(sky, 0.0, 1.0)


def _ridge_y(w: int, h: int, prof: Sequence[Tuple[float, float]], seed: int,
             rough: float, x0: float, x1: float) -> np.ndarray:
    """Per-column skyline height: a smooth control profile plus seeded jaggedness."""
    rng = np.random.default_rng(seed)
    ctrl = rng.random(22)
    t = np.clip((np.arange(w, dtype=np.float32) / w - x0) / (x1 - x0), 0.0, 1.0)
    u = t * (len(ctrl) - 1)
    j = np.clip(u.astype(int), 0, len(ctrl) - 2)
    f = u - j
    f = f * f * (3 - 2 * f)
    jag = ctrl[j] * (1 - f) + ctrl[j + 1] * f - 0.5
    ys = np.interp(t, [p[0] for p in prof], [p[1] for p in prof]).astype(np.float32)
    return (ys + rough * jag) * h


def _clouds(w: int, h: int, mask: np.ndarray, base: np.ndarray,
            seed: int = 4242) -> np.ndarray:
    """Wind-driven cloud over the repainted sky.

    The repaint measured within six grey levels of the plate's sky and still
    read as a different picture, because the mismatch was never value or hue
    (R-B came back -60 against the plate's -66) -- it was that the painted sky
    has weather in it and the fill had none. An empty sky beside a worked one
    is a hole with correct colour.

    So: noise on a wide, short grid, stretched to the frame, which is what wind
    does to cloud; thresholded so it forms masses with gaps instead of an even
    haze; and a lighter flank wherever density rises left-to-right, because the
    plate's moon is out at x~0.21 and every cloud on it is lit from that side.
    """
    ys = (np.arange(h, dtype=np.float32) / h)[:, None]
    xs = (np.arange(w, dtype=np.float32) / w)[None, :]
    rng = np.random.default_rng(seed)
    small = (rng.random((7, 26)) * 255).astype(np.uint8)          # wind-stretched cells
    c = np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC), np.float32) / 255.0
    c = 0.62 * c + 0.38 * _fbm(h, w, seed + 1, cells=9, octaves=3)
    c = (c - c.min()) / (c.ptp() or 1.0)

    band = (1.0 - _smoothstep((ys - 0.30) / 0.17)) * mask
    body = np.clip((c - 0.46) / 0.34, 0.0, 1.0) ** 1.4
    base = _blend(base, np.array((58, 86, 116), np.float32)[None, None, :] / 255.0,
                  body * band * 0.44)
    lit = np.clip(np.roll(c, -int(0.012 * w), axis=1) - c, 0.0, None)   # flank facing the moon
    lit = (lit / (lit.max() or 1.0)) ** 0.8
    return _blend(base, np.array((96, 126, 152), np.float32)[None, None, :] / 255.0,
                  lit * body * band * 0.50)


def _far_terrain(w: int, h: int, mask: np.ndarray, base: np.ndarray) -> np.ndarray:
    """Give the right third its mass back.

    Deleting the dragon deleted the only large shape in that third, and flat sky
    where the composition expects weight reads as a pasted-on rectangle -- which
    is exactly what the first pass looked like. So the space gets filled the way
    the rest of the plate fills it: a hazed mountain wall, a ruin-studded middle
    ridge, and the near bank, each darker and crisper than the one behind, so
    the new third recedes at the same rate as the painted two.

    Each layer is a skyline whose body FADES OUT below its own ridge rather than
    a silhouette flooded to the frame bottom. Flooding is what a vector tool
    does; a painter loses the near ground of a distant range in haze, and a flat
    slab of fill is the one thing no amount of grain can rescue afterwards.
    """
    layers = (
        # profile                                                   seed  rough  colour        a   fade  towers
        ([(0.0, 0.300), (0.30, 0.180), (0.52, 0.240), (0.74, 0.152), (1.0, 0.225)],
         7311, 0.030, (42, 62, 84), 0.62, 0.13, ()),
        ([(0.0, 0.452), (0.34, 0.415), (0.66, 0.462), (1.0, 0.430)],
         5150, 0.016, (28, 46, 66), 0.80, 0.075,
         ((0.760, 0.055), (0.793, 0.037), (0.906, 0.068), (0.967, 0.044))),
        ([(0.0, 0.548), (0.40, 0.566), (1.0, 0.552)],
         2027, 0.008, (17, 31, 47), 0.88, 0.070, ()),
    )
    x0, x1 = 0.655, 1.005
    rows = np.arange(h, dtype=np.float32)[:, None]
    for prof, seed, rough, col, alpha, fade, towers in layers:
        ry = _ridge_y(w, h, prof, seed, rough, x0, x1)
        for tx, th in towers:                           # broken ruin towers
            lo, hi = int((tx - 0.0055) * w), int((tx + 0.0055) * w)
            top = ry[(lo + hi) // 2] - th * h
            ry[lo:hi] = np.minimum(ry[lo:hi], top)
            ry[(lo + hi) // 2:hi] += th * h * 0.14      # ... with a broken crown
        d = rows - ry[None, :]
        a = (alpha * np.clip(d / 2.0, 0.0, 1.0)
             * np.exp(-np.clip(d, 0.0, None) / (fade * h))).astype(np.float32)
        base = _blend(base, np.array(col, np.float32)[None, None, :] / 255.0, a * mask)
    return base


def _haze(w: int, h: int, mask: np.ndarray, base: np.ndarray) -> np.ndarray:
    """Aerial perspective: distance washes toward the sky, it does not darken.

    Measured against the plate at the same rows, the terrain pass alone ran
    10-20 grey levels under the painting, and the deficit GREW with depth into
    the frame -- the signature of missing atmosphere, not of wrong colour. A
    painter loses a distant range into the air between; stacking ever-darker
    silhouettes instead digs a hole exactly where the composition wants light,
    and a hole reads as a pasted rectangle no matter how clean its edges are.

    So every layer is lifted back toward a horizon mist whose strength rises
    with depth and peaks in the band where the marsh meets the sky. This buys
    the value back AND softens the ridgelines, which is the same thing the
    plate's own far mountains do.
    """
    ys = (np.arange(h, dtype=np.float32) / h)[:, None]
    xs = (np.arange(w, dtype=np.float32) / w)[None, :]
    mist = np.array(HORIZON, np.float32)[None, None, :] / 255.0
    band = np.exp(-((ys - 0.545) / 0.150) ** 2)          # the horizon air itself
    deep = _smoothstep((xs - 0.66) / 0.30)               # thickens with distance
    return _blend(base, mist, (0.10 + 0.34 * band) * (0.45 + 0.55 * deep) * mask)


def _grain(w: int, h: int, mask: np.ndarray, base: np.ndarray,
           seed: int = 1717) -> np.ndarray:
    """Give the repaint the plate's own grain.

    Measured on the plate, a 15x15 sky patch carries a high-frequency sigma of
    ~20-30 grey levels; the first clean repaint came back at 0.9-2.6. That gap
    is the entire "pasted-on rectangle" effect -- not the seam, which feathering
    had already handled, but the flatness inside it. Smooth fill next to painted
    texture reads as a hole however well its edges are blended, so the fill gets
    matched noise: fine grain at the plate's brush scale, two octaves of
    mottling, and a faint streak component for the rain and mist the painter put
    everywhere else. Amplitude rides the local luminance, because paint has more
    variance in the lights than in the shadows.

    Deliberately UNDER the measured target: a pass tuned until the numbers
    matched (sigma 22) came back looking like burlap, because the plate earns
    its sigma from painted structure -- rain, foliage, masonry -- and noise
    buys the same number with none of the meaning. ~10-12 is where the fill
    stops reading as a hole without starting to read as a texture.
    """
    rng = np.random.default_rng(seed)

    def unit(a: np.ndarray) -> np.ndarray:
        a = a - a.mean()
        return a / (a.std() or 1.0)

    fine = np.asarray(Image.fromarray(
        ((rng.standard_normal((h, w)) * 0.22 + 0.5).clip(0, 1) * 255).astype(np.uint8)
    ).filter(ImageFilter.GaussianBlur(1.0)), np.float32)
    streak = np.asarray(Image.fromarray(
        ((rng.standard_normal((h // 9, w)) * 0.22 + 0.5).clip(0, 1) * 255).astype(np.uint8)
    ).resize((w, h), Image.BICUBIC), np.float32)

    tex = unit(0.62 * unit(fine)
               + 0.13 * unit(streak)
               + 0.46 * unit(_fbm(h, w, seed + 1, cells=16, octaves=4))
               + 0.11 * unit(_fbm(h, w, seed + 2, cells=44, octaves=3)))

    luma = base @ np.array([0.30, 0.59, 0.11], np.float32)
    amp = 0.052 * (0.40 + 0.60 * np.clip(luma / 0.45, 0.0, 1.0)) * mask
    tint = np.array([0.94, 1.00, 1.08], np.float32)[None, None, :]
    return np.clip(base + tex[..., None] * amp[..., None] * tint, 0.0, 1.0)


# ---------------------------------------------------------------------------
# step 2 — the quest-theme landmarks
# ---------------------------------------------------------------------------

def _gothic(cx: float, spring: float, span: float, rise: float,
            n: int = 96) -> List[Pt]:
    """A two-centre pointed arch — the apex is a corner, not a dome."""
    d = (rise * rise - span * span) / (2.0 * span)
    r = span + d
    out: List[Pt] = []
    for i in range(n + 1):
        t = i / n
        x = cx - span + 2 * span * t
        dx = x - (cx + d) if x <= cx else x - (cx - d)
        out.append((x, spring - math.sqrt(max(0.0, r * r - dx * dx))))
    return out


def _bell_tower(art: ImageDraw.ImageDraw, glow: ImageDraw.ImageDraw,
                w: int, h: int, s: float) -> None:
    """Orun's bell, in the keepers' ruined tower on the far bank.

    `The Bell That Refused the Gloom`: the Haven's keepers tied a warning bell
    to the stag's antlers, and when the water took the town the bell kept
    ringing for seven nights. It is the chapter's icon, so it -- not a floating
    dragon head -- is what holds the right third now.

    Drawn as a SILHOUETTE with lit openings, which is the whole trick. An
    earlier pass modelled the same shrine in three tones of bronze and it read
    as vector clipart pasted on an oil painting: a painted plate has texture
    everywhere and flat fills have none, so any drawn object big enough to show
    its fills gives itself away. A dark shape with light coming through it has
    no fills to compare, so it composites at any size -- which is also how the
    plate's own ruins are lit.
    """
    cx = 0.8385 * w * s                     # clear of the title's final S
    base = 0.6120 * h * s                   # seated into the near bank
    top = 0.3920 * h * s
    H = base - top
    hw = 0.0082 * w * s                     # half width at the base
    tw = hw * 0.80                          # ... and at the belfry
    corn = top + H * 0.34                   # cornice: shaft below, belfry above
    dark = (20, 35, 52, 242)                # hazed to ITS depth, not the foreground's
    rim = (48, 74, 88, 255)
    lit = (74, 104, 112, 255)               # sky seen through the openings
    lw = max(1, int(0.0008 * w * s))

    art.polygon([(cx - hw, base), (cx - tw * 1.02, corn),
                 (cx + tw * 1.02, corn), (cx + hw, base)], fill=dark)
    art.rectangle([cx - tw * 1.34, corn - H * 0.035,
                   cx + tw * 1.34, corn + H * 0.022], fill=dark)
    art.polygon([(cx - tw * 1.06, corn),                     # belfry, broken crown
                 (cx - tw * 1.06, top + H * 0.10), (cx - tw * 0.72, top + H * 0.10),
                 (cx - tw * 0.72, top), (cx - tw * 0.16, top),
                 (cx - tw * 0.16, top + H * 0.13), (cx + tw * 0.40, top + H * 0.16),
                 (cx + tw * 0.40, top + H * 0.05), (cx + tw * 1.06, top + H * 0.07),
                 (cx + tw * 1.06, corn)], fill=dark)
    art.polygon([(cx - hw * 1.9, base), (cx - hw * 1.05, base - hw * 1.5),
                 (cx - hw * 0.9, base)], fill=dark)           # fallen buttress
    art.polygon([(cx + hw, base), (cx + hw * 1.7, base - hw * 0.9),
                 (cx + hw * 1.8, base)], fill=dark)           # rubble
    art.polygon([(cx - hw * 3.4, base + hw * 0.55), (cx - hw * 1.5, base - hw * 0.30),
                 (cx + hw * 2.2, base - hw * 0.22),
                 (cx + hw * 4.1, base + hw * 0.60)], fill=(15, 27, 40, 224))

    span = tw * 0.66                                          # the belfry opening
    rise = span * 1.50
    spring = corn - H * 0.075
    arch = _gothic(cx, spring, span, rise)
    art.polygon(arch, fill=lit)
    glow.polygon(arch, fill=LUMEN + (120,))                   # backlit, so the bell reads
    art.line(arch[len(arch) // 2:], fill=rim, width=lw)

    bw = span * 0.54                                          # the bell itself
    bt = spring - rise * 0.74
    bh = rise * 0.70
    prof = [(bw * (0.36 + 0.64 * t ** 1.7), bt + bh * t)
            for t in (i / 24 for i in range(25))]
    art.polygon([(cx + rx, y) for rx, y in prof]
                + [(cx + bw * 1.10, bt + bh), (cx - bw * 1.10, bt + bh)]
                + [(cx - rx, y) for rx, y in reversed(prof)],
                fill=(9, 16, 24, 255))
    art.line([(cx - bw * 1.08, bt + bh), (cx + bw * 1.08, bt + bh)],
             fill=BRONZE + (210,), width=lw)                  # the lip catches the glow
    art.ellipse([cx - bw * 0.20, bt + bh * 0.96, cx + bw * 0.20, bt + bh * 1.20],
                fill=LUMEN_HI + (255,))                       # the clapper, still lit
    for dy, rw in ((0.58, 0.30), (0.80, 0.24)):               # keepers' lit windows
        y = corn + (base - corn) * dy
        art.rectangle([cx - tw * rw, y, cx + tw * rw, y + hw * 0.40],
                      fill=LANTERN + (190,))

    glow.ellipse([cx - span * 2.6, bt - bh * 1.5, cx + span * 2.6, bt + bh * 2.6],
                 fill=LUMEN + (86,))
    glow.ellipse([cx - hw * 1.1, base - hw * 3.0, cx + hw * 1.1, base + hw * 0.6],
                 fill=LANTERN + (44,))
    glow.ellipse([cx - hw * 3.2, base + hw * 0.2, cx + hw * 3.2, base + hw * 3.4],
                 fill=TEAL + (52,))                            # reflected on the fen


def _cat(pts: Sequence[Pt], n: int = 8) -> List[Pt]:
    """Smooth a control polyline into a curve via midpoint quadratics."""
    out: List[Pt] = [pts[0]]
    for i in range(1, len(pts) - 1):
        a = ((pts[i - 1][0] + pts[i][0]) / 2, (pts[i - 1][1] + pts[i][1]) / 2)
        b = ((pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2)
        out += _bezier(a, pts[i], b, n)
    out.append(pts[-1])
    return out


# Side-on soar facing -x, in units of "one dragon" (~2.6 long, ~1.5 tall).
_NECK = [(-1.18, -0.42), (-1.06, -0.50), (-0.95, -0.47), (-0.90, -0.38),
         (-0.80, -0.33), (-0.66, -0.24), (-0.50, -0.12), (-0.34, -0.02),
         (-0.20, 0.02)]
_BELLY = [(-1.16, -0.34), (-1.04, -0.29), (-0.92, -0.25), (-0.76, -0.12),
          (-0.58, 0.02), (-0.40, 0.13), (-0.26, 0.20)]
_TORSO_T = [(-0.20, 0.02), (0.04, 0.01), (0.26, 0.04), (0.46, 0.05)]
_TORSO_B = [(-0.26, 0.20), (0.02, 0.25), (0.26, 0.25), (0.46, 0.20)]
_TAIL_T = [(0.46, 0.05), (0.70, 0.00), (0.96, -0.08), (1.18, -0.19),
           (1.34, -0.30), (1.46, -0.40)]
_TAIL_B = [(0.46, 0.20), (0.72, 0.14), (0.98, 0.05), (1.20, -0.07),
           (1.32, -0.19), (1.42, -0.33)]
_WING_NEAR = ((-0.18, 0.02), (0.30, -0.96), (-0.06, -0.50),
              [(0.60, -1.14), (0.74, -0.80), (0.76, -0.44), (0.62, -0.12),
               (0.10, 0.08)])
_WING_FAR = ((-0.10, 0.01), (0.10, -0.70), (-0.08, -0.36),
             [(0.30, -0.84), (0.40, -0.58), (0.42, -0.32), (0.33, -0.08),
              (0.02, 0.06)])


def _wing(spec) -> Tuple[List[Pt], List[Tuple[Pt, Pt]]]:
    root, wrist, ctl, tips = spec
    lead = _bezier(root, ctl, wrist, 10) + _bezier(
        wrist, ((wrist[0] + tips[0][0]) / 2 - 0.05,
                (wrist[1] + tips[0][1]) / 2 - 0.05), tips[0], 6)
    edge: List[Pt] = []
    for i in range(len(tips) - 1):
        a, b = tips[i], tips[i + 1]
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        vx, vy = m[0] - wrist[0], m[1] - wrist[1]
        n = math.hypot(vx, vy) or 1.0
        k = 0.17 if i < len(tips) - 2 else 0.09
        edge += _bezier(a, (m[0] - vx / n * k, m[1] - vy / n * k), b, 10)
    return lead + edge, [(wrist, t) for t in tips[:-1]]


def _far_dragon(art: ImageDraw.ImageDraw, glow: ImageDraw.ImageDraw,
                w: int, h: int, s: float) -> None:
    """The telegraphed rare boss, at the distance a dragon belongs at.

    v1's failure was scale, not subject: a wyrm the size of the sky standing in
    front of the ruins it is meant to haunt. Here it is a silhouette on the high
    mist with a thread of Lumen down its spine, sized so the party could
    plausibly be afraid of it rather than standing inside it.

    At the size a README banner is actually viewed -- call it sixty pixels --
    nothing survives but the outline, and the outline has exactly three jobs:
    long neck, long tail, fingered wing. Those are the whole difference between
    a dragon and a bird. Which is why the trailing edge scallops CONCAVE toward
    the wrist, leaving the finger tips as points; bulge them outward and the
    wing becomes a moth's. A second wyrm, smaller and further off and turning
    the other way, because two say "this world has them" where one says "this
    is the one".
    """
    body = _cat(_NECK + _TORSO_T[1:] + _TAIL_T[1:], 8)
    body = body + list(reversed(_cat(_BELLY + _TORSO_B + _TAIL_B[1:], 8)))

    def wyrm(cx: float, cy: float, k: float, tilt: float, alpha: int,
             flip: bool = False) -> None:
        ct, st = math.cos(tilt), math.sin(tilt)
        sx = -1.0 if flip else 1.0

        def P(p: Pt) -> Pt:
            return (cx + (p[0] * sx * ct - p[1] * st) * k,
                    cy + (p[0] * sx * st + p[1] * ct) * k)

        dark = (11, 19, 29, alpha)
        lw = max(1, int(k * 0.020))
        poly, _ = _wing(_WING_FAR)
        art.polygon([P(p) for p in poly], fill=(14, 24, 35, int(alpha * 0.70)))
        art.polygon([P(p) for p in body], fill=dark)
        art.polygon([P((0.10, 0.23)), P((0.26, 0.22)), P((0.31, 0.40)),
                     P((0.21, 0.42)), P((0.14, 0.32))], fill=dark)
        for a, b in (((-1.04, -0.50), (-0.90, -0.62)),
                     ((-0.97, -0.48), (-0.86, -0.61))):
            art.line([P(a), P(b)], fill=dark, width=lw)          # horns
        poly, struts = _wing(_WING_NEAR)
        art.polygon([P(p) for p in poly], fill=dark)
        for a, b in struts:
            art.line([P(a), P(b)], fill=(6, 12, 20, alpha), width=lw)
        rim = LUMEN + (int(alpha * 0.30),)
        art.line([P(p) for p in _bezier((-0.18, 0.02), (-0.06, -0.50),
                                        (0.30, -0.96), 10)], fill=rim, width=lw)
        art.line([P(p) for p in _cat(_NECK, 6)], fill=rim,
                 width=max(1, int(k * 0.014)))

    wyrm(0.737 * w * s, 0.140 * h * s, 0.0255 * w * s, -0.12, 235)
    wyrm(0.947 * w * s, 0.072 * h * s, 0.0105 * w * s, 0.16, 140, flip=True)


def _mooring(art: ImageDraw.ImageDraw, glow: ImageDraw.ImageDraw,
             w: int, h: int, s: float) -> None:
    """Ilyra's ferry, out on the open water: travellers and rescues.

    `The Second Stroke`: she cut the ferry ropes during the flood and struck
    the bronze rail twice at every crossing — once for the living, once for
    those already beneath it. Two lanterns keep that beat, and they carry the
    causeway's lantern trail on across the fen so the eye keeps travelling
    right, toward the bell.
    """
    cx, wy = 0.655 * w * s, 0.858 * h * s
    ln = 0.021 * w * s
    hull = (10, 17, 26, 255)
    art.polygon([(cx - ln, wy - 0.004 * h * s), (cx + ln * 1.15, wy - 0.010 * h * s),
                 (cx + ln * 1.02, wy + 0.011 * h * s),
                 (cx - ln * 0.92, wy + 0.013 * h * s)], fill=hull)
    art.line([(cx - ln * 0.9, wy - 0.001 * h * s), (cx + ln * 1.05, wy - 0.007 * h * s)],
             fill=(31, 44, 52, 235), width=max(1, int(0.0011 * w * s)))
    # the ferryman, leaning on the pole
    fx = cx - ln * 0.45
    art.line([(fx, wy - 0.004 * h * s), (fx - 0.001 * w * s, wy - 0.040 * h * s)],
             fill=hull, width=max(1, int(0.0026 * w * s)))
    art.ellipse([fx - 0.0026 * w * s, wy - 0.050 * h * s,
                 fx + 0.0018 * w * s, wy - 0.038 * h * s], fill=hull)
    art.line([(fx + 0.004 * w * s, wy + 0.012 * h * s),
              (fx - 0.004 * w * s, wy - 0.068 * h * s)],
             fill=(26, 38, 46, 245), width=max(1, int(0.0012 * w * s)))
    # bow lantern on its hook, stern lantern on the rail
    for lx, ly, r, a in ((cx + ln * 0.95, wy - 0.036 * h * s, 0.0031 * w * s, 105),
                         (cx - ln * 0.80, wy - 0.022 * h * s, 0.0022 * w * s, 78)):
        art.line([(lx, ly), (lx, wy - 0.006 * h * s)], fill=(30, 40, 48, 220),
                 width=max(1, int(0.0008 * w * s)))
        art.ellipse([lx - r, ly - r, lx + r, ly + r], fill=LANTERN + (255,))
        glow.ellipse([lx - r * 8, ly - r * 8, lx + r * 8, ly + r * 8],
                     fill=(255, 182, 92, a))
        glow.ellipse([lx - r * 1.7, ly + 0.012 * h * s,       # on the water
                      lx + r * 1.7, ly + 0.075 * h * s], fill=(255, 182, 92, a - 22))
    glow.ellipse([cx - ln * 1.6, wy + 0.010 * h * s, cx + ln * 1.6, wy + 0.040 * h * s],
                 fill=TEAL + (40,))


def _lumen(art: ImageDraw.ImageDraw, w: int, h: int, s: float, seed: int) -> None:
    """Fireflies over the new ground, so the patch shares the plate's life."""
    rng = np.random.default_rng(seed)
    for _ in range(46):
        x = (0.690 + 0.305 * rng.random()) * w * s
        y = (0.478 + 0.148 * rng.random() ** 0.7) * h * s
        r = (0.0005 + 0.0010 * rng.random()) * w * s
        a = int(70 + 120 * rng.random())
        art.ellipse([x - r, y - r, x + r, y + r], fill=LUMEN_HI + (a,))
        art.ellipse([x - r * 2.1, y - r * 2.1, x + r * 2.1, y + r * 2.1],
                    fill=LUMEN + (a // 11,))


# ---------------------------------------------------------------------------
# the render
# ---------------------------------------------------------------------------

def render(debug: bool = False) -> Image.Image:
    plate = Image.open(PLATE).convert("RGB")
    w, h = plate.size
    base = np.asarray(plate, dtype=np.float32) / 255.0

    mask = _repaint_mask(w, h)
    base = _blend(base, _sky_fill(plate), mask)
    base = _clouds(w, h, mask, base)
    base = _far_terrain(w, h, mask, base)
    base = _haze(w, h, mask, base)
    base = _grain(w, h, mask, base)

    s = 3                                   # supersample: curves on a painted plate
    art_l = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    glow_l = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    art, glow = ImageDraw.Draw(art_l), ImageDraw.Draw(glow_l)
    _bell_tower(art, glow, w, h, s)
    _far_dragon(art, glow, w, h, s)
    _mooring(art, glow, w, h, s)
    _lumen(art, w, h, s, seed=4242)
    art_l = art_l.resize((w, h), Image.LANCZOS)
    glow_l = glow_l.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(10))

    frame = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    frame.paste(art_l, (0, 0), art_l)
    frame = _screen(frame, glow_l)

    # Fog, laid ACROSS the boundaries rather than up to them.
    #
    # Feathering a repaint only turns a hard seam into a soft one: the eye still
    # finds the straight line where the new fill stops matching. What actually
    # hides it is atmosphere that ignores the boundary -- a bank of mist drawn
    # over old plate and new fill alike has no seam to betray, because both
    # sides are equally veiled. So: a high veil over the repainted sky, a marsh
    # bank across the bottom edge, and a column across the left one.
    arr = np.asarray(frame, dtype=np.float32) / 255.0
    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :].repeat(h, 0)
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None].repeat(w, 1)
    fog = np.array(NAVY, np.float32)[None, None, :] / 255.0 * 1.9
    mist = np.array(NAVY, np.float32)[None, None, :] / 255.0 * 2.6

    veil = (_smoothstep((xs - 0.66) / 0.12) * (1.0 - _smoothstep((ys - 0.46) / 0.24))
            * (0.30 + 0.70 * _fbm(h, w, seed=2211, cells=3, octaves=3)) * 0.20)
    arr = _blend(arr, fog, veil)

    bank = (_smoothstep((xs - 0.600) / 0.10) * np.exp(-((ys - 0.618) / 0.052) ** 2)
            * (0.35 + 0.65 * _fbm(h, w, seed=3307, cells=5, octaves=4)) * 0.40)
    arr = _blend(arr, mist, bank)

    col = (np.exp(-((xs - 0.764) / 0.034) ** 2)
           * _smoothstep((ys - 0.120) / 0.10) * (1.0 - _smoothstep((ys - 0.560) / 0.14))
           * (0.30 + 0.70 * _fbm(h, w, seed=9091, cells=4, octaves=4)) * 0.15)
    arr = _blend(arr, mist, col)
    out = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))

    if debug:
        d = ImageDraw.Draw(out)
        red = Image.fromarray(np.dstack([
            (mask * 255).astype(np.uint8), np.zeros((h, w), np.uint8),
            np.zeros((h, w), np.uint8), (mask * 90).astype(np.uint8)]))
        out.paste(red, (0, 0), red)
        d.rectangle([TITLE_KEEP[0] * w, TITLE_KEEP[1] * h,
                     TITLE_KEEP[2] * w, TITLE_KEEP[3] * h], outline=(0, 255, 0))
    return out


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    ap.add_argument("--check", action="store_true",
                    help="render and compare against the committed PNG")
    ap.add_argument("--debug", action="store_true", help="overlay the repaint mask")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args(argv)

    img = render(debug=args.debug)
    dest = args.out or OUT
    if args.check:
        tmp = dest.with_suffix(".check.png")
        img.save(tmp)
        same = dest.exists() and _sha256(tmp) == _sha256(dest)
        tmp.unlink()
        print("BANNER OK — committed PNG matches the compositor" if same
              else "BANNER MISMATCH — committed PNG is not this render")
        return 0 if same else 1
    img.save(dest)
    print(json.dumps({"out": str(dest), "size": list(img.size),
                      "sha256": _sha256(dest)}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
