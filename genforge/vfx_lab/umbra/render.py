#!/usr/bin/env python3
"""
UMBRA / DARKNESS-SMOKE VFX — numpy preview renderer.
Mirrors the exact fragment math of umbra.gdshader so the shader is a 1:1 port.

THE key difference from every other lab effect: this is a MIX-BLEND medium,
not additive light. Darkness must OCCLUDE the scene (additive darkness is
physically impossible), so the preview composites `scene*(1-a) + smoke*a`
and only the violet rims add on top.

Components:
  1. Curling smoke density: domain-warped fBm advected slowly upward, radial
     falloff blob, boundary eaten by noise (fractal edge, never a disc).
  2. Erosion dissolve: the density threshold RISES over life, so the cloud
     burns away organically instead of alpha-fading.
  3. Violet rim-light: a glow band where density crosses the threshold
     (the "edge of the void" read) + a few drifting bright motes.
"""
import numpy as np
from PIL import Image

# ---------------------------------------------------------------- config
RES = 256
FRAMES = [0.0, 0.15, 0.3, 0.5, 0.75, 1.0]
SEED = 11.0
SMOKE_DEEP = np.array([0.016, 0.008, 0.045])   # near-black violet core
SMOKE_MID = np.array([0.10, 0.05, 0.19])       # lit smoke folds
RIM_COLOR = np.array([0.60, 0.26, 1.00])       # violet-magenta void edge

# ---------------------------------------------------------------- noise
def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def hash2(ix, iy, seed):
    n = np.sin((ix * 127.1 + iy * 311.7) + seed * 13.0) * 43758.5453
    return n - np.floor(n)

def value_noise(x, y, seed):
    ix = np.floor(x); iy = np.floor(y)
    fx = x - ix;      fy = y - iy
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    a = hash2(ix,     iy,     seed)
    b = hash2(ix + 1, iy,     seed)
    c = hash2(ix,     iy + 1, seed)
    d = hash2(ix + 1, iy + 1, seed)
    return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy

def fbm(x, y, seed, octaves=4):
    v = np.zeros_like(x); amp = 0.5; freq = 1.0
    for _ in range(octaves):
        v += amp * value_noise(x * freq, y * freq, seed)
        freq *= 2.0; amp *= 0.5
    return v

# ---------------------------------------------------------------- effect
def umbra(uv, p, seed=SEED):
    """Returns (smoke_rgb, smoke_alpha, rim_rgb). Composite:
    out = scene * (1 - a) + smoke_rgb * a; out += rim_rgb (additive)."""
    x = uv[..., 0]; y = uv[..., 1]
    r = np.sqrt(x * x + y * y)

    # --- envelope: fast swell in, long organic dissolve out ---
    swell = smoothstep(0.0, 0.14, p)
    # cloud radius breathes outward over life
    R = 0.62 + 0.30 * smoothstep(0.0, 0.55, p)

    # --- advection: darkness curls and rises SLOWLY (looming, not licking) ---
    adv = p * 0.85 + seed * 0.13
    q = fbm(x * 1.7 + seed, y * 1.7 - adv * 0.55, seed + 2.0, 3)
    # second warp layer gives the interior its curl "folds"
    dn = fbm(x * 2.6 + (q - 0.5) * 2.1, y * 2.6 - adv + (q - 0.5) * 1.5,
             seed + 5.0, 4)

    # --- density: radial blob eaten by noise ---
    fall = smoothstep(R, R * 0.28, r)              # soft radial body
    # noise-dominant mix so late-life break-up is PATCHY wisps, not one clump
    raw = dn * 0.85 + fall * 0.30
    # erosion dissolve: threshold rises over life -> smoke burns off in patches
    thr = 0.36 + 0.40 * smoothstep(0.35, 1.0, p)
    density = smoothstep(thr, thr + 0.22, raw) * fall * swell
    end_fade = 1.0 - smoothstep(0.88, 1.0, p)      # guarantee a clean exit
    density *= end_fade
    # occluding alpha — REAL darkness (mix blend), capped so world reads through edges
    alpha = np.clip(density * 1.25, 0.0, 0.90)

    # --- smoke color: near-black core, faint violet in the folds ---
    folds = smoothstep(0.35, 0.9, dn)
    smoke_rgb = SMOKE_DEEP[None, None, :] * (1 - folds[..., None]) \
        + SMOKE_MID[None, None, :] * folds[..., None]

    # --- violet rim: glow band where density crosses the erosion threshold ---
    # narrow band; NEVER gain-boosted late (a wide bright rim over a dissolving
    # cloud reads as a flat lavender blob — the hard-shape sin all over again)
    band = smoothstep(thr - 0.07, thr, raw) * (1.0 - smoothstep(thr, thr + 0.09, raw))
    rim = band * fall * swell * end_fade
    rim_gain = 0.9 + 0.45 * smoothstep(0.45, 0.8, p)
    rim_rgb = rim[..., None] * RIM_COLOR[None, None, :] * rim_gain

    # --- drifting motes: sparse bright specks orbiting inside the cloud ---
    N = 7.0
    gx = x * N * 0.5 + 3.0
    gy = y * N * 0.5 - adv * 1.6 + 7.0
    cell_x = np.floor(gx); cell_y = np.floor(gy)
    jx = hash2(cell_x, cell_y, seed + 4.0) - 0.5
    jy = hash2(cell_x, cell_y, seed + 6.0) - 0.5
    px = (gx - cell_x - 0.5 - jx * 0.7)
    py = (gy - cell_y - 0.5 - jy * 0.7)
    md = np.sqrt(px * px + py * py)
    keep = smoothstep(0.55, 0.9, hash2(cell_x, cell_y, seed + 8.0))  # sparse
    mote = smoothstep(0.10, 0.02, md) * keep
    flick = 0.5 + 0.5 * np.sin(p * 21.0 + hash2(cell_x, cell_y, seed + 9.0) * 6.28)
    mote_i = mote * fall * swell * (1.0 - smoothstep(0.7, 1.0, p)) * flick * end_fade
    rim_rgb += mote_i[..., None] * (RIM_COLOR * 1.6)[None, None, :]

    return smoke_rgb, alpha, rim_rgb

# ---------------------------------------------------------------- scene
def backdrop(res):
    yy, xx = np.mgrid[0:res, 0:res].astype(np.float32)
    u = xx / res; v = yy / res
    # brighter stone than the additive labs — occlusion must be VISIBLE
    base = np.array([0x33, 0x37, 0x40], dtype=np.float32) / 255.0
    stone = fbm(u * 6.0, v * 6.0, 42.0, octaves=3)
    vig = 1.0 - 0.4 * ((u - 0.5) ** 2 + (v - 0.5) ** 2)
    bg = base[None, None, :] * vig[..., None]
    bg += (stone[..., None] - 0.5) * 0.03
    return np.clip(bg, 0, 1)

def hero_marker(res):
    yy, xx = np.mgrid[0:res, 0:res].astype(np.float32)
    cx = cy = res / 2.0
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    dot = np.exp(-(d / 3.0) ** 2)
    glow = 0.35 * np.exp(-(d / 7.0) ** 2)
    m = np.clip(dot + glow, 0, 1)
    col = np.array([1.0, 0.95, 0.85])
    return m[..., None] * col[None, None, :]

def render_frame(p, res=RES):
    yy, xx = np.mgrid[0:res, 0:res].astype(np.float32)
    u = (xx + 0.5) / res * 2.0 - 1.0
    v = (yy + 0.5) / res * 2.0 - 1.0
    uv = np.stack([u, v], axis=-1)

    smoke_rgb, a, rim_rgb = umbra(uv, p)
    scene = backdrop(res) + hero_marker(res)
    # MIX blend: darkness occludes; rims add on top
    out = scene * (1.0 - a[..., None]) + smoke_rgb * a[..., None]
    out = out + (1.0 - np.exp(-rim_rgb * 1.7))
    out = np.clip(out, 0, 1) ** (1.0 / 1.25)
    return (np.clip(out, 0, 1) * 255).astype(np.uint8)

def main():
    frames = [render_frame(p) for p in FRAMES]
    pad = 6
    h = RES
    w = RES * len(frames) + pad * (len(frames) - 1)
    sheet = np.full((h, w, 3), np.array([10, 11, 14], dtype=np.uint8))
    x = 0
    for f in frames:
        sheet[:, x:x + RES] = f
        x += RES + pad
    Image.fromarray(sheet, 'RGB').save('./contact_sheet.png')
    print('wrote contact_sheet.png', sheet.shape)

if __name__ == '__main__':
    main()
