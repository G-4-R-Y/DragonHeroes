#!/usr/bin/env python3
"""
Firestorm — fire/ember plume VFX prototype (numpy).
Evaluates the SAME fragment math the .gdshader ports: fBm value noise,
domain warp, upward flow, temperature color ramp, advected ember specks.
Renders a horizontal contact sheet over a dark dungeon backdrop.
"""
import numpy as np
from PIL import Image

W = H = 256          # per-frame resolution
FRAMES = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
SEED = 3.0

# ---------------------------------------------------------------- noise
def hash2(ix, iy):
    """Vectorized GLSL-style hash of integer lattice -> [0,1)."""
    # dot with irrational vector, sin, fract
    v = np.sin((ix * 127.1 + iy * 311.7) + SEED * 13.0) * 43758.5453
    return v - np.floor(v)

def value_noise(x, y):
    """Bilinear value noise with smoothstep fade."""
    ix = np.floor(x); iy = np.floor(y)
    fx = x - ix;      fy = y - iy
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    a = hash2(ix,       iy)
    b = hash2(ix + 1.0, iy)
    c = hash2(ix,       iy + 1.0)
    d = hash2(ix + 1.0, iy + 1.0)
    return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy

def fbm(x, y, octaves=5):
    total = np.zeros_like(x)
    amp = 0.5
    freq = 1.0
    for _ in range(octaves):
        total += amp * value_noise(x * freq, y * freq)
        freq *= 2.0
        amp *= 0.5
    return total

# ---------------------------------------------------------------- ramp
def temp_ramp(t):
    """Temperature 0..~1.3 -> HDR RGB. white core -> yellow -> orange -> red -> smoke."""
    t = np.clip(t, 0.0, 1.3)
    # control stops (temp, r, g, b)
    stops = np.array([
        [0.00, 0.05, 0.04, 0.06],   # smoke (dark)
        [0.22, 0.55, 0.10, 0.02],   # deep red
        [0.45, 1.15, 0.32, 0.05],   # orange
        [0.70, 1.55, 0.78, 0.18],   # yellow
        [0.92, 1.85, 1.55, 1.05],   # near white hot
        [1.30, 2.20, 2.05, 1.80],   # white core (HDR)
    ])
    r = np.interp(t, stops[:,0], stops[:,1])
    g = np.interp(t, stops[:,0], stops[:,2])
    b = np.interp(t, stops[:,0], stops[:,3])
    return np.stack([r, g, b], axis=-1)

# ---------------------------------------------------------------- flame
def flame_field(x, yup, reach, scroll, warp_amt, chroma=0.0):
    """Turbulent flame density field 0..1. chroma offsets x for R/B split."""
    xx = x + chroma
    hnorm = np.clip(yup / reach, 0, 1)             # 0 base -> 1 tip
    # whole-plume low-frequency sway so the column leans / waves, not a clean cone
    sway = (fbm(yup * 1.6 - scroll * 0.5 + 3.0, np.zeros_like(yup) + 7.0, 2) - 0.5)
    xs = xx - sway * 0.10 * hnorm
    # domain warp: strong horizontal sway, tall vertical streaks (low y-freq)
    wx = fbm(xs * 3.0 + 19.0, yup * 2.0 - scroll * 0.9, 3) - 0.5
    wy = fbm(xs * 3.0 - 5.0,  yup * 2.0 - scroll * 0.6, 3) - 0.5
    sx = xs * 7.0 + wx * warp_amt * 2.6
    sy = yup * 2.4 - scroll + wy * warp_amt * 1.3
    n = fbm(sx, sy, 5)                              # turbulent, vertically stretched
    # horizontal confinement, narrows with height (tongue plume)
    halfw = 0.155 * (1.0 - 0.5 * hnorm) + 0.02
    horiz = np.exp(-(xs / halfw) ** 2 * 1.25)
    below = np.clip(1.0 + yup / 0.06, 0, 1)         # hard cut below origin
    # flame height field: noise lifted by base gradient, carved by height
    grad = np.clip(1.0 - hnorm, 0, 1)
    field = (n * (0.55 + 0.85 * grad) + grad * 0.35) * horiz * below
    return field, hnorm, n

def render_flame(p):
    """Return (rgb HDR float array HxWx3, alpha HxW) for progress p."""
    px = np.linspace(0, 1, W)
    py = np.linspace(0, 1, H)
    gx, gy = np.meshgrid(px, py)
    ox, oy = 0.5, 0.74          # hero origin in uv (center, lower)
    x = (gx - ox)
    yup = (oy - gy)

    # --- life envelope: hard snap-in, quick front-loaded decay ---
    rise = np.clip(p / 0.10, 0, 1)
    rise = rise * rise * (3 - 2 * rise)
    fall = 1.0 - np.clip((p - 0.25) / 0.75, 0, 1)
    fall = fall * fall
    env = rise * fall
    fall_s = np.sqrt(fall)
    reach = 0.28 + 0.54 * rise * (0.5 + 0.5 * fall_s)  # shoots up, then burns down/shortens
    scroll = 3.2 * p
    warp_amt = 0.55 + 0.45 * env

    chroma = 0.011 * (0.4 + 0.6 * env)              # R/B split magnitude
    field,  hnorm, n  = flame_field(x, yup, reach, scroll, warp_amt, 0.0)
    field_r, _, _     = flame_field(x, yup, reach, scroll, warp_amt, -chroma)
    field_b, _, _     = flame_field(x, yup, reach, scroll, warp_amt, +chroma)

    # two-layer: crisp bright tongues + soft outer glow halo
    core = smooth01(field, 0.40, 0.66)              # sharp leading tongues
    glow = smooth01(field, 0.16, 0.52)              # soft translucent halo
    core_r = smooth01(field_r, 0.40, 0.66)
    core_b = smooth01(field_b, 0.40, 0.66)

    # temperature: hot & white at base/core, cooling upward and at edges
    heat = env * (1.05 - 0.45 * hnorm)
    temp = (core * (1.25 - 0.5 * hnorm) + glow * 0.45) * heat
    temp = temp * (0.72 + 0.5 * n)
    # extra white-hot base bloom near origin, carved by turbulence (not a slab)
    base_hot = np.exp(-(x / 0.10) ** 2) * np.clip(1.0 - yup / 0.14, 0, 1)
    base_hot = np.clip(base_hot, 0, 1) * env * (0.45 + 0.7 * n)   # licked, not solid
    # let the hero peek: soften the exact center a touch
    center = np.exp(-((x ** 2 + (yup - 0.015) ** 2) / 0.030 ** 2))
    base_hot = base_hot * (1.0 - 0.35 * center)
    temp = temp + base_hot * 0.85

    # gate the whole flame body by the life envelope (no ghost at p=0/1)
    vis = np.clip(env * 1.25, 0, 1)
    rgb = temp_ramp(temp)
    intensity = (np.clip(core + glow * 0.55, 0, 1) ** 0.8) * vis
    rgb = rgb * intensity[..., None]

    # chromatic dispersion at hot edges: bias R/B by offset core samples
    edge = np.clip(core_r - core_b, -1, 1) * env
    rgb[..., 0] += np.clip(edge, 0, 1) * 0.85 * intensity
    rgb[..., 2] += np.clip(-edge, 0, 1) * 0.85 * intensity

    alpha = np.clip(intensity * 1.35 + base_hot * vis * 0.6, 0, 1)

    # --- trailing smoke wisps: dark, translucent, rise & outlive the flame ---
    smk_env = np.clip(p / 0.22, 0, 1) * (1.0 - np.clip((p - 0.32) / 0.68, 0, 1)) ** 1.3
    if smk_env > 0.01:
        ss = 2.6 * p + 0.4
        sn = fbm(x * 4.0 + 31.0, yup * 2.6 - ss, 4)
        s_reach = 0.30 + 0.55 * np.clip(p / 0.5, 0, 1)
        sh = np.clip(yup / s_reach, 0, 1)
        s_halfw = 0.10 + 0.16 * sh
        s_horiz = np.exp(-(x / s_halfw) ** 2 * 1.1)
        s_below = np.clip(yup / 0.05, 0, 1)                # smoke lives ABOVE the fire
        smoke = smooth01(sn * (0.6 + 0.4 * sh) * s_horiz * s_below, 0.30, 0.7)
        smoke = smoke * smk_env * (0.5 + 0.5 * sh)
        smk_col = np.array([0.16, 0.15, 0.17])
        rgb += smoke[..., None] * smk_col
        alpha = np.clip(alpha + smoke * 0.35, 0, 1)

    # --- ignition flash: radial white pop, very front-loaded ---
    fl = np.clip(1.0 - abs(p - 0.06) / 0.10, 0, 1) ** 2
    if fl > 0:
        d2 = (x ** 2 + (yup - 0.02) ** 2)
        flash = np.exp(-d2 / (0.09 ** 2)) * fl
        rgb += flash[..., None] * np.array([2.0, 1.7, 1.2])
        alpha = np.clip(alpha + flash * 0.8, 0, 1)

    # --- rising ember specks ---
    emb_rgb, emb_a = embers(x, yup, p, env)
    rgb = rgb + emb_rgb
    alpha = np.clip(alpha + emb_a, 0, 1)

    return rgb, alpha

def smooth01(v, a, b):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def embers(x, yup, p, env):
    """Bright points advected upward with flicker."""
    rgb = np.zeros((H, W, 3))
    a = np.zeros((H, W))
    n_emb = 26
    rng = np.random.default_rng(int(SEED * 100) + 7)
    for i in range(n_emb):
        ex0 = (rng.random() - 0.5) * 0.34
        speed = 0.55 + rng.random() * 0.9
        life_off = rng.random()
        phase = (p * speed + life_off) % 1.0
        ey = phase * 0.62                       # rises from origin
        # horizontal drift sway
        ex = ex0 + 0.05 * np.sin((phase * 6.0 + i) * 3.14) * phase
        size = 0.006 + rng.random() * 0.010
        # vertical motion-streak: stretch the gaussian along travel (speed feel)
        stretch = 2.0 + 1.5 * speed
        d2 = ((x - ex) ** 2 + ((yup - ey) / stretch) ** 2) / (size ** 2)
        spark = np.exp(-d2)
        flick = 0.5 + 0.5 * np.sin((p * 40 + i * 2.3))
        bright = env * (1.0 - phase) * (0.6 + 0.4 * flick)
        # hottest sparks are near-white, cooling to orange as they rise
        heat = 1.0 - 0.7 * phase
        col = np.array([1.9, 0.9 + 0.7 * heat, 0.25 + 0.55 * heat])
        rgb += spark[..., None] * col * bright
        a += spark * bright
    return rgb, np.clip(a, 0, 1)

# ---------------------------------------------------------------- backdrop
def backdrop():
    px = np.linspace(0, 1, W)
    py = np.linspace(0, 1, H)
    gx, gy = np.meshgrid(px, py)
    base = np.array([0x20, 0x24, 0x2c]) / 255.0
    # subtle tiled stone + vignette
    tile = 0.5 + 0.5 * np.sin(gx * np.pi * 8) * np.sin(gy * np.pi * 8)
    stone = value_noise(gx * 10, gy * 10) * 0.06 + tile * 0.015
    vig = 1.0 - 0.35 * ((gx - 0.5) ** 2 + (gy - 0.5) ** 2) * 2.0
    bg = base[None, None, :] * (0.85 + stone[..., None]) * vig[..., None]
    return np.clip(bg, 0, 1)

def hero_marker(bg):
    px = np.linspace(0, 1, W)
    py = np.linspace(0, 1, H)
    gx, gy = np.meshgrid(px, py)
    d2 = ((gx - 0.5) ** 2 + (gy - 0.72) ** 2)
    dot = np.exp(-d2 / (0.018 ** 2))
    glow = np.exp(-d2 / (0.05 ** 2)) * 0.4
    col = np.array([0.75, 0.82, 0.95])
    return np.clip(bg + (dot + glow)[..., None] * col, 0, 1)

# ---------------------------------------------------------------- compose
def compose_frame(p):
    bg = backdrop()
    bg = hero_marker(bg)
    rgb, alpha = render_flame(p)
    # additive glow over backdrop (HDR then clamp for preview)
    out = bg + rgb
    out = np.clip(out, 0, 1)
    return (out * 255).astype(np.uint8)

def main():
    pad = 6
    sheet = np.zeros((H, W * len(FRAMES) + pad * (len(FRAMES) + 1), 3), dtype=np.uint8)
    sheet[:] = np.array([12, 12, 16])
    for i, p in enumerate(FRAMES):
        frame = compose_frame(p)
        x0 = pad + i * (W + pad)
        sheet[0:H, x0:x0 + W] = frame
    Image.fromarray(sheet, 'RGB').save('contact_sheet.png')
    print('wrote contact_sheet.png', sheet.shape)

if __name__ == '__main__':
    main()
