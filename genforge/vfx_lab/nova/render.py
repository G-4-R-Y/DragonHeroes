#!/usr/bin/env python3
"""
NOVA / EXPLOSION VFX — numpy preview renderer.
Mirrors the exact fragment math of effect.gdshader so the shader is a 1:1 port.

Components:
  1. Expanding ring shockwave (thin bright SDF ring, striated, chromatic fringe).
  2. Radial energy shards (angular SDF spikes with hot tips, noise-varied).
  3. Turbulent fBm core flash (blooms then collapses, near-white hot core).
Global alpha decays fast (front-loaded) with trailing wisps.
"""
import numpy as np
from PIL import Image

# ---------------------------------------------------------------- config
RES = 256
FRAMES = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
SEED = 7.0
COLOR = np.array([0.35, 0.72, 1.0])       # frost-nova cyan-blue base
CORE_COLOR = np.array([0.80, 0.93, 1.0])  # near-white hot core

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

# 1D-ish angular noise (wraps): sample value noise on a circle
def angular_noise(ang, radius, seed, scale=1.0):
    cx = np.cos(ang) * scale
    cy = np.sin(ang) * scale
    return value_noise(cx + 3.0, cy + 3.0 + radius, seed)

# ---------------------------------------------------------------- effect
def nova(uv, p, seed=SEED):
    x = uv[..., 0]; y = uv[..., 1]
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)

    # --- envelopes (front-loaded) ---
    R = 1.35 * (1.0 - (1.0 - p) ** 2.3)      # ring races out, eases at end
    life = (1.0 - p) ** 1.5                   # fast fade + trailing tail
    life = np.maximum(life, 0.0)

    rgb = np.zeros(x.shape + (3,), dtype=np.float32)

    # ---------- 1. ring shockwave ----------
    th = 0.085 * (1.0 - 0.68 * p) + 0.006
    # striations around the circumference (internal life) — irregular filaments
    stri = 0.5 + 0.6 * angular_noise(ang, R * 2.0, seed + 1.0, scale=5.0)
    stri += 0.2 * angular_noise(ang, R * 3.0, seed + 8.0, scale=9.0)   # finer band
    stri *= 0.88 + 0.12 * np.sin(ang * 20.0 + seed * 3.0)   # very subtle flicker
    stri = np.clip(stri, 0.45, 1.35)
    # chromatic fringe (R leads outward -> warm outer, B trails inward -> cool)
    disp = 0.016 * (0.4 + 0.6 * p)
    ring_r = smoothstep(th, 0.0, np.abs(r - (R + disp)))
    ring_g = smoothstep(th, 0.0, np.abs(r - R))
    ring_b = smoothstep(th, 0.0, np.abs(r - (R - disp)))
    ring_i = np.stack([ring_r, ring_g, ring_b], axis=-1) * stri[..., None]
    rgb += ring_i * COLOR * (2.5 * life)
    # sharp hot leading edge (near-white core of the line)
    edge = smoothstep(th * 0.35, 0.0, np.abs(r - R)) ** 2.0
    rgb += (edge * stri)[..., None] * CORE_COLOR * (3.4 * life)

    # ---------- 2. radial energy shards (band racing behind the ring front) ----------
    shards_life = life ** 1.5                  # fade faster than the ring
    n_shards = 13.0
    awarp = 0.9 * np.sin(ang * 2.0 + seed * 3.1) + 0.5 * np.sin(ang * 5.0 - seed * 1.7)
    base = np.sin(ang * n_shards + awarp + seed * 2.0)
    shard_phase = 0.5 + 0.5 * base
    shard = shard_phase ** 9.0
    var = angular_noise(ang, 0.0, seed + 5.0, scale=n_shards / 3.0)
    shard *= 0.35 + 0.9 * var
    # radial break-up: shards fragment into beads traveling outward (kills the
    # straight-ray "clock face" read at large sizes) — shader parity
    bead = value_noise(ang * 4.0 + seed * 7.0, r * 9.0 - p * 6.0, seed + 11.0)
    shard *= 0.45 + 0.85 * bead
    shard_reach = R * 1.0 + 0.04
    # short band behind the front (not a full center-star)
    shard_body = smoothstep(shard_reach, shard_reach - 0.34, r) * smoothstep(0.02, 0.18, r)
    shard_i = shard * shard_body * (1.9 * shards_life)
    rgb += shard_i[..., None] * COLOR * np.array([0.8, 1.0, 1.25])
    # hot tips: brightest where shard meets the ring front
    tip = shard * smoothstep(shard_reach - 0.16, shard_reach, r) * smoothstep(shard_reach + 0.05, shard_reach - 0.02, r)
    rgb += (tip * 2.3 * shards_life)[..., None] * CORE_COLOR

    # ---------- 2b. debris flecks near the front ----------
    fleck_field = value_noise(np.cos(ang) * 40.0 + 5.0, np.sin(ang) * 40.0 + r * 30.0, seed + 9.0)
    flecks = smoothstep(0.86, 0.995, fleck_field)
    fleck_band = smoothstep(shard_reach + 0.12, shard_reach - 0.02, r) * smoothstep(shard_reach - 0.3, shard_reach - 0.05, r)
    rgb += (flecks * fleck_band * 2.0 * shards_life)[..., None] * (0.6 * COLOR + 0.4 * CORE_COLOR)

    # ---------- 3. turbulent fBm core flash ----------
    core_scale = 0.5 * (0.35 + 0.65 * np.sin(np.clip(p, 0, 1) * np.pi))   # bloom->collapse
    core_scale = float(np.maximum(core_scale, 0.06))
    flash = np.exp(-((p - 0.04) / 0.12) ** 2)          # hard snap flash near p=0
    # turbulent domain-warped core
    warp = fbm(x * 3.0 + p, y * 3.0 - p, seed + 2.0, octaves=3)
    turb = fbm(x * 5.0 + warp * 1.5 + p * 1.5, y * 5.0 + warp * 1.5, seed + 3.0, octaves=4)
    turb = turb ** 1.4
    core_body = smoothstep(core_scale, 0.0, r)
    core_i = core_body * (0.35 + 1.1 * turb) * (0.7 * life + 1.9 * flash)
    rgb += core_i[..., None] * CORE_COLOR
    # a tighter pure-white heart
    heart = smoothstep(core_scale * 0.45, 0.0, r) * (0.5 * life + 2.4 * flash)
    rgb += heart[..., None] * np.array([1.0, 1.0, 1.0])

    alpha = np.clip(rgb.max(axis=-1), 0.0, 1.0)
    return rgb, alpha

# ---------------------------------------------------------------- scene
def backdrop(res):
    yy, xx = np.mgrid[0:res, 0:res].astype(np.float32)
    u = xx / res; v = yy / res
    base = np.array([0x20, 0x24, 0x2c], dtype=np.float32) / 255.0
    # subtle stone via low-amplitude fbm
    stone = fbm(u * 6.0, v * 6.0, 42.0, octaves=3)
    vig = 1.0 - 0.4 * ((u - 0.5) ** 2 + (v - 0.5) ** 2)
    bg = base[None, None, :] * vig[..., None]
    bg += (stone[..., None] - 0.5) * 0.018
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

    fx_rgb, _ = nova(uv, p)
    # keep the dark scene dark; tonemap ONLY the effect for bloom, add over scene
    scene = backdrop(res) + hero_marker(res)
    fx_t = 1.0 - np.exp(-fx_rgb * 1.7)          # soft-clip: hue-preserving bloom
    out = scene + fx_t                          # additive over dark stone
    out = np.clip(out, 0, 1) ** (1.0 / 1.25)    # gentle gamma for punch, bg stays dark
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
