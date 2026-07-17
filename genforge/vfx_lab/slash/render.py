"""
SLASH / CRESCENT VFX — numpy previz renderer.

Evaluates the EXACT per-pixel math a GLSL canvas_item fragment shader would run,
so the contact sheet is an honest preview of effect.gdshader.

Model:
  - Polar field around origin O (hero position).
  - Crescent lives in a radial band at mean radius R, thickness taper -> blade shape.
  - A bright LEADING EDGE sweeps across a ~120deg arc, front-loaded easing.
  - Behind the lead: a soft dissipating TRAIL.
  - Inner FILAMENTS run tangentially along the arc (value-noise driven).
  - CHROMATIC fringe: R leads / B lags the hot edge in angle.
  - Hot near-white core (HDR >1) -> saturated violet -> transparent.
  - Additive over a dark stone backdrop; hero marker stays readable.
"""

import numpy as np
from PIL import Image

# ----------------------------------------------------------------------------- config
N          = 240                    # frame size (px)
PROG       = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
DIR_ANGLE  = np.radians(-22.0)      # slash facing (down-right cleave)
SPAN       = np.radians(120.0)      # total arc swept
HALF_SPAN  = SPAN * 0.5
R_MEAN     = 0.66                   # mean radius of the arc (in [-1,1] frame units)
THICK      = 0.24                   # max half-thickness of the blade band at arc center
COLOR      = np.array([0.62, 0.30, 1.00])   # violet element tint
STONE      = np.array([0.125, 0.141, 0.172])# ~#20242c


# ----------------------------------------------------------------------------- noise
def hash2(ix, iy):
    # deterministic pseudo-random in [0,1) from integer lattice
    s = np.sin(ix * 127.1 + iy * 311.7) * 43758.5453
    return s - np.floor(s)

def value_noise(x, y):
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    ux = fx * fx * (3 - 2 * fx)
    uy = fy * fy * (3 - 2 * fy)
    a = hash2(ix,     iy)
    b = hash2(ix + 1, iy)
    c = hash2(ix,     iy + 1)
    d = hash2(ix + 1, iy + 1)
    return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy

def fbm(x, y, oct=4):
    v = np.zeros_like(x)
    amp = 0.5
    freq = 1.0
    for _ in range(oct):
        v += amp * value_noise(x * freq, y * freq)
        freq *= 2.0
        amp *= 0.5
    return v


# ----------------------------------------------------------------------------- easing
def ease_out(p):
    return 1.0 - (1.0 - p) ** 2

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ----------------------------------------------------------------------------- one frame
def render_field(p):
    # UV grid in [-1,1], y up
    xs = np.linspace(-1, 1, N)
    ys = np.linspace(-1, 1, N)
    X, Y = np.meshgrid(xs, -ys)

    r = np.sqrt(X * X + Y * Y) + 1e-6
    a = np.arctan2(Y, X)
    arel = np.arctan2(np.sin(a - DIR_ANGLE), np.cos(a - DIR_ANGLE))   # wrapped

    t = arel / HALF_SPAN                       # along-arc coord in [-1,1]

    # sweep: leading edge crosses the arc, front-loaded, completes ~p=0.45
    sweep = ease_out(np.clip(p / 0.45, 0, 1))
    lead_t = 1.0 - 2.0 * sweep                 # sweeps +1 -> -1 (downward cleave)

    # life envelope: hard snap-in, brief hold, quick decay -> wisps
    env = smoothstep(0.0, 0.10, p) * (1.0 - smoothstep(0.45, 1.0, p))
    decay = smoothstep(0.42, 1.0, p)           # 0 while sweeping, ->1 as it dies

    # expansion: band drifts outward and puffs as it dissipates
    R_eff = R_MEAN + 0.14 * decay
    thick = THICK * (1.0 + 0.9 * decay)

    # blade thickness taper (fat middle, pointy tips)
    half_thick = np.maximum(thick * np.sqrt(np.clip(1.0 - t * t, 0, 1)), 0.010)
    ncross = (r - R_eff) / half_thick          # normalized across-band coord

    # soft angular taper so tips fade instead of hard-cutting
    tip_fade = smoothstep(1.02, 0.80, np.abs(t))

    # noise field in arc-space for filaments / turbulence
    nz = fbm(t * 6.0 + 3.1, ncross * 2.2 + 7.0, oct=4)

    # across-band profiles: crisp centerline core + soft outer glow
    across_core = np.exp(-(ncross ** 2) / (2 * 0.34 ** 2))
    across_glow = np.exp(-(ncross ** 2) / (2 * 0.72 ** 2))

    # angular: lead sweeps +1 -> -1, so covered region is t >= lead_t (already passed)
    behind = np.clip(t - lead_t, 0, 2.0)                 # how far behind the lead
    drawn = 1.0 / (1.0 + np.exp((lead_t - t) * 34.0))    # smooth step, 1 behind lead
    trail = np.exp(-behind / 0.62) * drawn               # brightest just behind lead

    # leading edge: thin bright arc segment (band-confined -> crescent front, NOT a spoke)
    edge = np.exp(-((t - lead_t) ** 2) / (2 * 0.045 ** 2)) * drawn

    # filaments: thin tangential striations running along the arc (additive detail)
    fil = 0.5 + 0.5 * np.sin(ncross * 8.5 + nz * 6.5 + t * 2.5)
    fil = fil ** 3

    # erosion: as it decays, keep only high-noise strands -> trailing wisps
    erosion = smoothstep(decay - 0.10, decay + 0.45, nz)
    keep = (1.0 - decay) + decay * erosion

    # --- body: a solid bright smear, gently turbulent, with filaments ADDED on top
    smear = trail * (0.75 * across_core + 0.40 * across_glow)
    turb  = 0.80 + 0.40 * nz                              # gentle modulation (high floor)
    fil_add = trail * across_core * fil * 0.55            # additive striations
    body = (smear * turb + fil_add) * tip_fade * env * keep

    # --- leading edge (hot, band-confined)
    edge_core = edge * across_core * tip_fade * env          # near-white core
    edge_halo = edge * across_glow * tip_fade * env          # violet halo

    # chromatic fringe: thin prismatic rim — R just ahead of edge, B just behind
    d_chroma = 0.045
    edge_R = np.exp(-((t - (lead_t - d_chroma)) ** 2) / (2 * 0.040 ** 2)) * across_core * tip_fade * env
    edge_B = np.exp(-((t - (lead_t + d_chroma)) ** 2) / (2 * 0.040 ** 2)) * drawn * across_core * tip_fade * env

    # ---- compose HDR color (additive)
    rgb = np.zeros((N, N, 3))
    for c in range(3):
        rgb[..., c] += body * COLOR[c] * 2.9                 # violet body
        rgb[..., c] += edge_halo * COLOR[c] * 1.8            # violet halo around edge
        rgb[..., c] += edge_core * 4.6                       # hot near-white core (HDR>1)
    rgb[..., 0] += edge_R * 1.3                              # chromatic red fringe (lead)
    rgb[..., 2] += edge_B * 1.5                              # chromatic blue fringe (trail)

    return rgb  # HDR, additive


# ----------------------------------------------------------------------------- backdrop
def backdrop():
    xs = np.linspace(-1, 1, N)
    ys = np.linspace(-1, 1, N)
    X, Y = np.meshgrid(xs, -ys)
    tile = 0.5 + 0.5 * np.sin(X * 40) * np.sin(Y * 40)
    grime = fbm(X * 3 + 10, Y * 3 + 10, oct=3)
    bg = np.zeros((N, N, 3))
    for c in range(3):
        bg[..., c] = STONE[c] * (0.85 + 0.20 * grime) + 0.010 * tile
    # subtle vignette
    r = np.sqrt(X * X + Y * Y)
    vig = np.clip(1.0 - 0.35 * r * r, 0, 1)
    return bg * vig[..., None]


def hero_marker(img):
    # bright dot ~10px at origin (frame center)
    xs = np.linspace(-1, 1, N)
    ys = np.linspace(-1, 1, N)
    X, Y = np.meshgrid(xs, -ys)
    d = np.sqrt(X * X + Y * Y)
    dot = np.exp(-(d ** 2) / (2 * (10.0 / N) ** 2))
    glow = np.exp(-(d ** 2) / (2 * (22.0 / N) ** 2)) * 0.4
    for c in range(3):
        img[..., c] += (dot + glow) * np.array([0.9, 0.95, 1.0])[c]
    return img


# ----------------------------------------------------------------------------- sheet
def main():
    frames = []
    for p in PROG:
        bg = backdrop()
        fx = render_field(p)
        comp = bg + fx           # additive
        comp = hero_marker(comp)
        frames.append(comp)

    pad = 6
    sheet = np.ones((N, N * len(frames) + pad * (len(frames) + 1), 3)) * 0.02
    for i, f in enumerate(frames):
        x0 = pad + i * (N + pad)
        sheet[0:N, x0:x0 + N] = np.clip(f, 0, 1)

    # stack a thin label strip? keep it pure pixels.
    img = Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8), "RGB")
    out = __file__.rsplit("/", 1)[0] + "/contact_sheet.png"
    img.save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
