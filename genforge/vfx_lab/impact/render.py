#!/usr/bin/env python3
"""
Dragon Heroes VFX lab -- IMPACT SPARK / HIT
Pure-math procedural preview. Vectorized numpy that mirrors the GLSL frag math
in effect.gdshader (SDF ring + gaussian star streaks + noisy sunburst + CA).

Renders a 6-frame horizontal contact sheet over a dark dungeon backdrop with a
bright hero marker at the effect origin.
"""
import numpy as np
from PIL import Image

RES = 240          # per-frame px
PROG = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
GAP  = 8
SEED = 7.0

# ---------------------------------------------------------------- noise utils
def hash2(x, y):
    """Deterministic 2D value hash -> [0,1). Mirrors a GLSL fract(sin dot) hash."""
    n = np.sin(x * 127.1 + y * 311.7 + SEED * 13.13) * 43758.5453
    return n - np.floor(n)

def value_noise(x, y):
    xi, yi = np.floor(x), np.floor(y)
    xf, yf = x - xi, y - yi
    u = xf * xf * (3.0 - 2.0 * xf)
    v = yf * yf * (3.0 - 2.0 * yf)
    a = hash2(xi,     yi)
    b = hash2(xi + 1, yi)
    c = hash2(xi,     yi + 1)
    d = hash2(xi + 1, yi + 1)
    return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v

def fbm(x, y, oct=3):
    s, amp, f = 0.0, 0.5, 1.0
    for _ in range(oct):
        s = s + amp * value_noise(x * f, y * f)
        f *= 2.0
        amp *= 0.5
    return s

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

# ---------------------------------------------------------------- the effect
def intensity_field(u, v, p, scale=1.0):
    """
    Return a single-channel HDR intensity for the impact spark at coord (u,v),
    life p in [0,1]. `scale` warps the radial coordinate for chromatic split.
    u,v are centered, ~[-1,1]. Peak is at p=0 (the hit); decay is front-loaded.
    """
    u = u * scale
    v = v * scale
    r = np.sqrt(u * u + v * v) + 1e-6
    ang = np.arctan2(v, u)

    # -- front-loaded envelopes: peak at p=0, ~all action in first third ----
    core_env   = np.clip(1.0 - p / 0.30, 0.0, 1.0) ** 1.8     # gone by p=0.30
    star_env    = np.clip(1.0 - p / 0.40, 0.0, 1.0) ** 1.5    # gone by p=0.40
    ring_env    = np.clip(1.0 - p / 0.80, 0.0, 1.0) ** 1.1    # ring lingers
    streak_env  = np.clip(1.0 - p / 0.35, 0.0, 1.0) ** 1.7
    ember_env   = np.clip(1.0 - p / 0.95, 0.0, 1.0) ** 1.4    # embers trail late

    # -- 0. faint light-pop flash-disc: soft emission bloom, first instant --
    flash_env = np.clip(1.0 - p / 0.16, 0.0, 1.0) ** 2.0
    flash = flash_env * 0.42 * np.exp(-(r / 0.5) ** 2)

    # -- 1. hot core: tight gaussian point + faint halo, HDR (>>1) ----------
    # ring-biased so the exact center stays hint-through, not a solid disc
    core = core_env * (2.9 * np.exp(-(r / 0.048) ** 2)
                       + 0.8 * np.exp(-(r / 0.12) ** 2))

    # -- 2. star / cross: soft gaussian streak + razor-thin hot filament ----
    # per-axis irregular tips via cheap angular noise
    tipn = 0.80 + 0.40 * value_noise(ang * 3.0, 5.0)
    L  = 0.60 * tipn                              # along-length (full at p=0)
    tk = 0.028                                    # soft cross thickness
    tkc = tk * 0.30                               # hot filament thickness
    def streak(a_along, a_perp, ln, th):
        soft = np.exp(-(a_perp / th) ** 2) * np.exp(-(a_along / ln) ** 2)
        line = np.exp(-(a_perp / (th * 0.30)) ** 2) * np.exp(-(a_along / ln) ** 2)
        # along-length striations = internal life
        flick = 0.65 + 0.5 * value_noise(a_along * 14.0, 2.0)
        return (soft * flick + 1.3 * line)
    h  = streak(u, v, L, tk)
    ve = streak(v, u, L, tk)
    du = (u + v) * 0.70710678
    dv = (u - v) * 0.70710678
    d1 = streak(du, dv, L * 0.62, tk * 0.8)
    d2 = streak(dv, du, L * 0.62, tk * 0.8)
    star = star_env * (h + ve + 0.55 * (d1 + d2)) * 1.5

    # -- 3. noisy radial sunburst filaments (spiky, flickering) -------------
    rays = value_noise(ang * 9.0 + 17.0, 3.0)
    spikes = np.clip(rays, 0.0, 1.0) ** 5.0
    spike_len = 0.55 * (0.8 + 0.4 * value_noise(ang * 9.0, 8.0))
    radial_prof = np.exp(-((r - spike_len * 0.35) / (spike_len * 0.55)) ** 2)
    streaks = streak_env * spikes * radial_prof * 2.2

    # -- 4. expanding SDF shockwave ring: sharp leading edge, soft trail ----
    ring_r = 0.10 + 0.78 * (1.0 - (1.0 - p) ** 2.2)   # ease-out expansion
    ring_r = ring_r * (1.0 + 0.035 * (value_noise(ang * 5.0, 9.0) - 0.5))  # wobble
    thick  = 0.055 + 0.05 * p                          # trail lengthens as it fades
    aa = 0.018
    outer = 1.0 - smoothstep(ring_r, ring_r + aa, r)          # sharp outer cut
    trail = smoothstep(ring_r - thick, ring_r, r)             # soft inner ramp
    rim   = np.exp(-((r - ring_r) / (aa * 1.6)) ** 2)         # hot leading rim
    ring_noise = 0.45 + 0.95 * value_noise(ang * 7.0, 4.0)    # broken shockwave
    ring = ring_env * (outer * trail * ring_noise + 0.55 * rim) * 1.5

    # -- 5. flying ember sparks: travel out + fade = trailing life ----------
    embers = np.zeros_like(r)
    travel = 0.85 * (1.0 - (1.0 - p) ** 1.8)          # ease-out flight
    N = 10
    for i in range(N):
        a  = (i + 0.5) / N * 6.28318 + hash2(i * 3.1, 1.0) * 2.0
        sp = 0.55 + 0.5 * hash2(i * 1.7, 2.0)
        rr = travel * sp
        px = rr * np.cos(a)
        py = rr * np.sin(a)
        # radial elongation (motion streak): project into local along/perp
        ca_, sa_ = np.cos(a), np.sin(a)
        along = (u - px) * ca_ + (v - py) * sa_
        perp  = -(u - px) * sa_ + (v - py) * ca_
        e = np.exp(-(along / 0.060) ** 2) * np.exp(-(perp / 0.013) ** 2)
        embers = embers + e
    embers = ember_env * embers * 1.6

    return flash + core + star + streaks + ring + embers

def render_frame(p):
    lin = (np.arange(RES) + 0.5) / RES * 2.0 - 1.0     # [-1,1]
    u, v = np.meshgrid(lin, lin)

    # chromatic aberration: radial split, stronger at edges (scale is radial,
    # so tips shift more than the calm center)
    ca = 0.013
    Ir = intensity_field(u, v, p, scale=1.0 - ca)
    Ig = intensity_field(u, v, p, scale=1.0)
    Ib = intensity_field(u, v, p, scale=1.0 + ca)

    # tint: white-hot core -> amber/gold. multiply by warm color then clip.
    col_hot = np.array([1.0, 0.86, 0.55])   # gold
    eff = np.stack([Ir * col_hot[0], Ig * col_hot[1], Ib * col_hot[2]], axis=-1)

    # ---- backdrop: dark stone ~#20242c, subtle noise + vignette -----------
    base = np.array([0x20, 0x24, 0x2c]) / 255.0
    stone = fbm(u * 40.0, v * 40.0, oct=3)[..., None] * 0.06
    vig = (1.0 - 0.5 * (u * u + v * v))[..., None]
    bg = np.clip(base[None, None, :] * vig + stone, 0.0, 1.0)
    bg = np.broadcast_to(bg, (RES, RES, 3)).copy()

    # hero marker: small bright pale-blue dot ~10px
    r = np.sqrt(u * u + v * v)
    marker_r = 10.0 / RES
    marker = np.exp(-(r / marker_r) ** 2) * 0.9
    mcol = np.array([0.7, 0.85, 1.0])
    bg = bg + marker[..., None] * mcol[None, None, :]

    # ---- additive composite (bloom-ready) ---------------------------------
    out = bg + eff
    out = np.clip(out, 0.0, 1.0)
    return (out * 255).astype(np.uint8)

def main():
    frames = [render_frame(p) for p in PROG]
    W = RES * len(frames) + GAP * (len(frames) - 1)
    sheet = np.zeros((RES, W, 3), dtype=np.uint8)
    sheet[:] = np.array([10, 11, 14])
    x = 0
    for f in frames:
        sheet[:, x:x + RES] = f
        x += RES + GAP
    out = "./contact_sheet.png"
    Image.fromarray(sheet, "RGB").save(out)
    print("wrote", out)

if __name__ == "__main__":
    main()
