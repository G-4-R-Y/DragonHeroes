#!/usr/bin/env python3
"""
ENERGY VORTEX / ORBITAL  --  numpy preview of a procedural Godot canvas_item shader.

Curl/flow-noise driven streaks orbiting a hollow center. Logarithmic-spiral
arms + fBm turbulence, differential rotation (tighter spin near the eye),
tapered wispy filaments, additive/translucent, chromatic dispersion on the
bright leading edge. `p` (progress 0..1) drives spin-up -> peak spin ->
spin-down + expansion + front-loaded fade.

Renders a horizontal contact sheet over a dark dungeon backdrop with a bright
hero marker at the eye of the vortex, so we can judge that the hero stays
visible through the effect.
"""

import numpy as np
from PIL import Image

# ----------------------------------------------------------------------------
# tunables
FRAME       = 240          # px per frame
PROGS       = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
ARMS        = 5            # spiral arm count (INT -> sin() arms wrap seamlessly)
XPERIOD     = 12           # angular noise period (cells around circle)
SWIRL       = 0.55         # differential rotation strength (1/r term)
LOG_SPIRAL  = 2.2          # log-spiral tightness (theta - k*ln r)
TOTAL_TURNS = 2.4          # how much the whole thing rotates across life
INNER_R     = 0.10         # hollow eye radius
OUTER_R0    = 0.30         # outer radius at spin-up
OUTER_R1    = 0.46         # outer radius at peak
EDGE_SOFT   = 0.10
SEED        = 7.0
OCTAVES     = 3            # fBm octaves (match shader -> mobile-cheap)
SMEAR_TAPS  = 1            # tangential motion-blur taps (1 = cheapest, matches shader)

# ----------------------------------------------------------------------------
# vectorized value noise + fBm (same construction we inline in GLSL)

def _hash2(ix, iy, seed):
    # deterministic pseudo-random in [0,1) from integer lattice coords
    n = np.sin((ix * 127.1 + iy * 311.7) + seed * 13.13) * 43758.5453
    return n - np.floor(n)

def value_noise(x, y, seed, xperiod=0.0):
    """Value noise. If xperiod>0 the X lattice wraps modulo xperiod, giving
    a seamless tile around the circle (kills the atan2 branch-cut seam)."""
    x0 = np.floor(x); y0 = np.floor(y)
    fx = x - x0;      fy = y - y0
    ux = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    uy = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
    xa = x0; xb = x0 + 1
    if xperiod > 0:
        xa = np.mod(xa, xperiod); xb = np.mod(xb, xperiod)
    a = _hash2(xa, y0,     seed)
    b = _hash2(xb, y0,     seed)
    c = _hash2(xa, y0 + 1, seed)
    d = _hash2(xb, y0 + 1, seed)
    return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy

def fbm(x, y, seed, octaves=4, xperiod=0.0):
    total = np.zeros_like(x)
    amp = 0.5; freq = 1.0; norm = 0.0
    for _ in range(octaves):
        xp = xperiod * freq if xperiod > 0 else 0.0
        total += amp * value_noise(x * freq, y * freq, seed, xp)
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm

# ----------------------------------------------------------------------------
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0.0, 1.0)
    return t * t * (3 - 2 * t)

def ease_out(t):   # fast start
    return 1 - (1 - t) ** 2

def ease_in_out(t):
    return t * t * (3 - 2 * t)

# ----------------------------------------------------------------------------
def _streak_noise(phase, reff, seed, flow, rfreq=20.0, smear=0.12):
    """Seamless tangentially-smeared filaments. `phase` is periodic (units of
    XPERIOD cells around the circle). Smear taps ALONG the arm -> motion blur."""
    taps = ((0.0, 1.0),) if SMEAR_TAPS == 1 else ((-1.0, 0.5), (0.0, 1.0), (1.0, 0.5))
    acc = np.zeros_like(phase)
    wsum = 0.0
    for k, w in taps:
        ax = phase + k * smear                             # low freq ALONG arm
        ay = reff * rfreq - flow                           # high freq ACROSS arm
        acc += w * fbm(ax, ay, seed, octaves=OCTAVES, xperiod=XPERIOD)
        wsum += w
    return acc / wsum

def vortex_field(u, v, p, seed, angle_channel=0.0):
    """Return (intensity, hotness, r) per pixel for progress p.
    angle_channel: tiny angular offset used for chromatic dispersion."""
    d_x = u - 0.5
    d_y = v - 0.5
    r = np.sqrt(d_x * d_x + d_y * d_y)
    theta = np.arctan2(d_y, d_x)

    # timing envelopes
    spin_env = ease_in_out(min(p / 0.6, 1.0)) - 0.4 * smoothstep(0.7, 1.0, p)  # up then down
    rot = TOTAL_TURNS * 2 * np.pi * ease_out(p)
    outer_r = OUTER_R0 + (OUTER_R1 - OUTER_R0) * ease_out(p)

    reff = np.maximum(r, 1e-3)
    # angle with differential swirl (tighter near eye) + spin + chroma offset
    ang = theta + rot + SWIRL / reff + angle_channel
    logr = np.log(reff)

    # --- big spiral arms: seamless because ARMS is int and sin is 2pi-periodic
    arm = ang * ARMS - LOG_SPIRAL * logr
    bands = 0.5 + 0.5 * np.sin(arm)
    bands = smoothstep(0.35, 1.0, bands)                   # sharpen arms

    # --- seamless periodic filament detail (phase wraps mod XPERIOD)
    phase = (ang / (2 * np.pi)) * XPERIOD - (LOG_SPIRAL / (2 * np.pi)) * XPERIOD * logr
    flow = rot * 0.6
    streak = _streak_noise(phase, reff, seed, flow)                       # broad filaments
    stri = _streak_noise(phase * 2.7 + 7.0, reff, seed + 11.0, flow * 1.5,
                         rfreq=46.0, smear=0.05)                          # fine striations

    # filaments live INSIDE the arms; striations carve them so arms aren't ribbons
    detail = smoothstep(0.4, 0.85, streak)
    carve = 0.45 + 0.55 * smoothstep(0.32, 0.85, stri)                    # 0.45..1 multiplicative
    body = bands * (0.15 + 0.85 * detail) * carve
    # frayed trailing/inner edge: break the arm into wisps toward the eye
    fray = smoothstep(INNER_R, outer_r, r) * 0.5 + 0.5
    body *= (0.55 + 0.45 * detail) ** (1.0 - fray + 0.3)
    core = (bands * smoothstep(0.66, 0.96, streak) * carve) ** 1.7        # thin hot filament cores
    fil = body ** 1.25

    # radial ring mask (hollow eye) -- soft inner, crisp bright outer edge
    inner = smoothstep(INNER_R, INNER_R + EDGE_SOFT, r)
    outer = 1.0 - smoothstep(outer_r - EDGE_SOFT * 0.5, outer_r, r)
    ring = inner * outer

    # crisp bright leading arc right at the outer rim, modulated by arms
    rim = smoothstep(outer_r - 0.05, outer_r - 0.012, r) * outer
    rim *= (0.3 + 0.7 * bands)

    # faint volumetric haze fills the annulus (body without hiding the eye)
    haze = ring * (0.10 + 0.10 * bands)

    intensity = fil * ring * 1.15 + rim * 1.35 + core * ring * 1.9 + haze

    # front-loaded life fade
    life = ease_out(min(p / 0.22, 1.0)) * (1.0 - smoothstep(0.62, 1.0, p))
    intensity *= (0.6 + 0.4 * spin_env) * (life + 0.04)

    hotness = (core * ring * 1.9 + rim * 1.0) * (life + 0.04)
    return intensity, hotness, r

# ----------------------------------------------------------------------------
def render_frame(p, size=FRAME):
    ys, xs = np.mgrid[0:size, 0:size]
    u = xs / (size - 1)
    v = ys / (size - 1)

    # small, CORRELATED chromatic dispersion: tiny angle offset for R and B
    # (keeps noise correlated -> clean edge fringing, not rainbow speckle)
    iR, hR, r = vortex_field(u, v, p, SEED, angle_channel=+0.018)
    iG, hG, _ = vortex_field(u, v, p, SEED, angle_channel=0.0)
    iB, hB, _ = vortex_field(u, v, p, SEED, angle_channel=-0.018)

    # purple energy palette: violet body -> magenta mid -> near-white hot core
    violet = np.array([0.42, 0.12, 0.95])
    magenta = np.array([0.95, 0.30, 1.0])
    hot     = np.array([1.0, 0.92, 1.0])

    # body color graded by intensity, then pushed to white by hotness
    t = np.clip(iG[..., None], 0, 1)
    body_col = violet[None, None, :] * (1 - t) + magenta[None, None, :] * t
    h = np.clip(hG[..., None] * 2.2, 0, 1)
    col = body_col * (1 - h) + hot[None, None, :] * h

    # apply per-channel glow (the chroma split) on top of the graded color
    glow = np.stack([iR, iG, iB], axis=-1)
    rgb = col * glow * 3.1   # HDR: core can exceed 1 -> bloom in engine

    alpha = np.clip(iG * 1.8, 0, 1)
    return rgb, alpha

# ----------------------------------------------------------------------------
def backdrop(size):
    """Dark tiled stone backdrop ~#20242c with subtle variation + vignette."""
    ys, xs = np.mgrid[0:size, 0:size]
    u = xs / (size - 1); v = ys / (size - 1)
    base = np.array([0x20, 0x24, 0x2c]) / 255.0
    tile = 0.5 + 0.5 * np.sin(xs / 12.0) * np.sin(ys / 12.0)
    n = fbm(u * 5, v * 5, 99.0, octaves=3)
    shade = 0.82 + 0.12 * tile * n
    img = base[None, None, :] * shade[..., None]
    # vignette
    dx = u - 0.5; dy = v - 0.5
    vig = 1.0 - 0.5 * np.clip(np.sqrt(dx*dx+dy*dy) * 1.6, 0, 1)
    img *= vig[..., None]
    return img

def add_hero(img, size):
    """Bright hero marker (~10px) at the eye/origin."""
    ys, xs = np.mgrid[0:size, 0:size]
    cx = cy = size / 2
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    core = np.exp(-(d / 3.0) ** 2)
    halo = np.exp(-(d / 7.0) ** 2) * 0.5
    hero_col = np.array([1.0, 0.95, 0.8])
    img = img + hero_col[None, None, :] * (core + halo)[..., None]
    return img

# ----------------------------------------------------------------------------
def main():
    size = FRAME
    gap = 8
    sheet_w = size * len(PROGS) + gap * (len(PROGS) + 1)
    sheet_h = size + gap * 2
    sheet = np.zeros((sheet_h, sheet_w, 3))

    for i, p in enumerate(PROGS):
        bg = backdrop(size)
        bg = add_hero(bg, size)          # hero UNDER the effect
        rgb, alpha = render_frame(p)
        comp = bg + rgb                  # additive blend over scene
        comp = np.clip(comp, 0, 1)

        x0 = gap + i * (size + gap)
        sheet[gap:gap + size, x0:x0 + size, :] = comp

    out = (np.clip(sheet, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save("contact_sheet.png")
    print("wrote contact_sheet.png", out.shape)

if __name__ == "__main__":
    main()
