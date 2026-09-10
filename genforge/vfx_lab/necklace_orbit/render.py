#!/usr/bin/env python3
"""
NECKLACE ORBIT (cosmetic) -- numpy preview of the Grand Chase necklace.

3 elemental beads orbiting the hero on a tilted elliptical path (3/4 top-down:
beads pass BEHIND the hero at the top of the orbit, in FRONT at the bottom --
the preview draws them in two depth layers around the hero marker). Each bead
is a bright core + halo + a short fading trail; a faint full orbit ring reads
through. Columns = the 6 canon damage elements; rows = orbit phases.

The bead sprite math (gaussian core + halo + flicker) ports 1:1 to
necklace_bead.gdshader; the orbit motion lives in ProtoCosmetics (GDScript),
not in the shader.
"""
import numpy as np
from PIL import Image

# ---------------------------------------------------------------- tunables
FW, FH   = 150, 190
PHASES   = [0.0, 0.30, 0.60, 0.90]      # rows: orbit phase (turns)
ELEMENTS = ["fire", "frost", "storm", "venom", "umbral", "blood"]
RX, RY   = 40.0, 17.0                   # orbit ellipse radii (px)
HERO_CY  = 0.56
BEADS    = 3
TRAIL    = 8                            # trail samples behind each bead
TRAIL_STEP = 0.008                      # turns between trail samples
RING_PTS = 160
SEED     = 5.0

BEAD_COL = {
    "fire":   np.array([1.00, 0.60, 0.16]),
    "frost":  np.array([0.50, 0.85, 1.00]),
    "storm":  np.array([0.78, 0.68, 1.00]),
    "venom":  np.array([0.60, 0.92, 0.28]),
    "umbral": np.array([0.65, 0.38, 1.00]),
    "blood":  np.array([0.92, 0.16, 0.22]),
}

# ---------------------------------------------------------------- noise (shared lab pattern)
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

def fbm(x, y, seed, octaves=3):
    v = np.zeros_like(x); amp = 0.5; freq = 1.0
    for _ in range(octaves):
        v += amp * value_noise(x * freq, y * freq, seed)
        freq *= 2.0; amp *= 0.5
    return v

def hash1(n, seed=SEED):
    v = np.sin(n * 17.23 + seed * 7.7) * 43758.5453
    return v - np.floor(v)

# ---------------------------------------------------------------- scene
def backdrop():
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    u = xx / FW; v = yy / FH
    base = np.array([0x22, 0x25, 0x2e], dtype=np.float32) / 255.0
    tile = 0.5 + 0.5 * np.sin(xx / 11.0) * np.sin(yy / 11.0)
    n = fbm(u * 5.0, v * 5.0, 99.0)
    img = base[None, None, :] * (0.80 + 0.14 * tile * n)[..., None]
    dx = u - 0.5; dy = v - 0.5
    img *= (1.0 - 0.45 * np.clip(np.sqrt(dx * dx + dy * dy) * 1.5, 0, 1))[..., None]
    return np.clip(img, 0, 1)

def hero_mask(cx, cy):
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    bx = (xx - cx) / 6.0; by = (yy - (cy + 8.0)) / 13.0
    body = np.exp(-(bx * bx + by * by) ** 1.3)
    hx = (xx - cx) / 4.2; hy = (yy - (cy - 8.0)) / 4.6
    head = np.exp(-(hx * hx + hy * hy))
    return np.clip(body + head, 0, 1)

def paint_hero(img, cx, cy):
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    shx = (xx - cx) / 12.0; shy = (yy - (cy + 26.0)) / 4.5
    img *= (1.0 - 0.5 * np.exp(-(shx * shx + shy * shy)))[..., None]
    m = hero_mask(cx, cy)[..., None]
    col = np.array([0.95, 0.82, 0.62])[None, None, :]
    return img * (1.0 - m) + col * m

# ---------------------------------------------------------------- orbit bits
def orbit_pos(theta, cx, cy):
    return cx + RX * np.cos(theta), cy + RY * np.sin(theta)

def ring_layer(cx, cy, back):
    """Faint full orbit ellipse, split into back/front halves (two depth layers)."""
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    th = np.linspace(0, 2 * np.pi, RING_PTS, endpoint=False)
    acc = np.zeros((FH, FW), dtype=np.float32)
    for a in th:
        is_back = np.sin(a) < 0
        if is_back != back:
            continue
        px, py = orbit_pos(a, cx, cy)
        d2 = (xx - px) ** 2 + (yy - py) ** 2
        acc = np.maximum(acc, np.exp(-d2 / (0.8 ** 2)))
    return acc * (0.030 if back else 0.065)

def bead_layer(cx, cy, phase, col, back, bead_scale_gain=1.0):
    """Beads (+ trails) on one depth layer. back=True -> top half of orbit."""
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    acc = np.zeros((FH, FW), dtype=np.float32)
    for i in range(BEADS):
        th = 2 * np.pi * (phase + i / BEADS)
        front = np.sin(th) >= 0
        if front == back:
            continue
        flick = 1.0 + 0.15 * np.sin(phase * 43.0 + i * 2.1) \
                    + 0.07 * np.sin(phase * 91.0 + i * 5.7)
        depth = (np.sin(th) + 1.0) * 0.5              # 0 back .. 1 front
        scale = (0.80 + 0.35 * depth) * bead_scale_gain \
              * (1.0 + 0.10 * np.sin(phase * 31.0 + i * 2.0))
        for k in range(TRAIL, -1, -1):
            tk = th - k * TRAIL_STEP * 2 * np.pi
            px, py = orbit_pos(tk, cx, cy)
            fade = 0.60 ** k
            sig_c = 1.6 * scale * (1.0 - 0.05 * k)
            sig_h = 4.6 * scale * (1.0 - 0.04 * k)
            d2 = (xx - px) ** 2 + (yy - py) ** 2
            core = np.exp(-d2 / (2.0 * sig_c * sig_c)) * 2.6
            halo = np.exp(-d2 / (2.0 * sig_h * sig_h)) * 0.55
            acc += (core + halo) * fade * (flick if k == 0 else 1.0)
    # core pushes toward white, halo keeps the element hue
    hot = np.clip(acc, 0, 2.4)
    whiten = np.clip(hot * 0.45, 0, 0.85)[..., None]
    rgb = col[None, None, :] * (1.0 - whiten) + np.ones(3)[None, None, :] * whiten
    return rgb * hot[..., None]

# ---------------------------------------------------------------- frame
def render_frame(el_name, phase):
    cx = FW / 2.0; cy = FH * HERO_CY
    col = BEAD_COL[el_name]
    img = backdrop()
    img += ring_layer(cx, cy, back=True)[..., None] * col[None, None, :]
    img += bead_layer(cx, cy, phase, col, back=True)
    img = paint_hero(img, cx, cy)
    img += ring_layer(cx, cy, back=False)[..., None] * col[None, None, :]
    img += bead_layer(cx, cy, phase, col, back=False)
    return np.clip(img, 0, 1) ** (1.0 / 1.2)

# ---------------------------------------------------------------- sheet
def main():
    gap = 6
    W = FW * len(ELEMENTS) + gap * (len(ELEMENTS) + 1)
    H = FH * len(PHASES) + gap * (len(PHASES) + 1)
    sheet = np.full((H, W, 3), np.array([10, 11, 14], dtype=np.float32) / 255.0)
    for r, ph in enumerate(PHASES):
        for c, name in enumerate(ELEMENTS):
            f = render_frame(name, ph)
            y0 = gap + r * (FH + gap); x0 = gap + c * (FW + gap)
            sheet[y0:y0 + FH, x0:x0 + FW] = f
    out = (np.clip(sheet, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save("contact_sheet.png")
    print("wrote contact_sheet.png", out.shape, "cols:", ELEMENTS, "rows phase:", PHASES)

if __name__ == "__main__":
    main()
