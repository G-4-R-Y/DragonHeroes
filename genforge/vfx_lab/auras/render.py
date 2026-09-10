#!/usr/bin/env python3
"""
BODY AURA (cosmetic) -- numpy preview of aura_body.gdshader.

ONE parametrized persistent body-hugging medium: rising/advected fBm flame-or-
mist filaments inside an elongated silhouette band around a hero marker,
erosion at the edges, element-tinted. Persistent (TIME-driven) -- the contact
sheet shows a row per TIME PHASE (not a life envelope) and a column per canon
damage element: fire, frost, storm, venom, umbral, blood.

Blend contract (matches aura_body.gdshader, render_mode blend_mix):
  - occlude elements (umbral, blood, venom): MIX composite -- the smoke
    OCCLUDES the scene (scene*(1-a) + smoke*a) up to max_alpha, rims/cores
    add on top. Additive darkness is physically impossible (canon 12.27).
  - glow elements (fire, frost, storm): translucent colored light, HDR cores.
Storm adds sparse jagged branching arc filaments (re-struck ~3x/s); blood is
liquid: slow DOWNWARD advection + drip streaks below the band.
"""
import numpy as np
from PIL import Image

# ---------------------------------------------------------------- tunables
FW, FH      = 150, 190          # frame px (portrait: auras are vertical)
TIMES       = [0.0, 0.9, 1.8, 2.7]   # rows: persistent-effect time phases
ELEMENTS    = ["fire", "frost", "storm", "venom", "umbral", "blood"]  # cols
RX, RY      = 30.0, 52.0        # silhouette band radii (px) around hero center
HERO_CY     = 0.60              # hero center as fraction of frame height
OCTAVES     = 3                 # fBm octaves (mobile budget, matches shader)
BAND_IN     = (0.40, 0.62)      # hollow core around the hero -> band start
BAND_OUT    = (0.82, 1.18)      # eroded outer edge
TOP_STRETCH = 1.30              # band reaches higher above the hero (licking)
SEED_BASE   = 3.0

# element table: (core, edge/rim, smoke, rise_speed, erosion, arc, occlude, max_alpha)
EL = {
    "fire":   dict(core=np.array([1.00, 0.58, 0.14]), edge=np.array([1.00, 0.86, 0.52]),
                   smoke=np.array([0.05, 0.02, 0.01]), rise=1.5,  erosion=0.36,
                   arc=0.0, occlude=0.0, alpha=0.55),
    "frost":  dict(core=np.array([0.50, 0.85, 1.00]), edge=np.array([0.90, 0.98, 1.00]),
                   smoke=np.array([0.06, 0.10, 0.14]), rise=0.9,  erosion=0.38,
                   arc=0.0, occlude=0.0, alpha=0.55),
    "storm":  dict(core=np.array([0.62, 0.52, 1.00]), edge=np.array([0.95, 0.92, 1.00]),
                   smoke=np.array([0.06, 0.05, 0.12]), rise=1.2,  erosion=0.38,
                   arc=1.0, occlude=0.0, alpha=0.55),
    "venom":  dict(core=np.array([0.55, 0.88, 0.24]), edge=np.array([0.85, 1.00, 0.55]),
                   smoke=np.array([0.04, 0.09, 0.02]), rise=0.8,  erosion=0.37,
                   arc=0.0, occlude=1.0, alpha=0.55),
    "umbral": dict(core=np.array([0.42, 0.18, 0.85]), edge=np.array([0.66, 0.32, 1.00]),
                   smoke=np.array([0.02, 0.01, 0.06]), rise=0.5,  erosion=0.36,
                   arc=0.0, occlude=1.0, alpha=0.85),
    "blood":  dict(core=np.array([0.78, 0.10, 0.14]), edge=np.array([1.00, 0.42, 0.42]),
                   smoke=np.array([0.10, 0.01, 0.03]), rise=-0.35, erosion=0.38,
                   arc=0.0, occlude=1.0, alpha=0.60),
}

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

def fbm(x, y, seed, octaves=OCTAVES):
    v = np.zeros_like(x); amp = 0.5; freq = 1.0
    for _ in range(octaves):
        v += amp * value_noise(x * freq, y * freq, seed)
        freq *= 2.0; amp *= 0.5
    return v

def hash1(n, seed):
    v = np.sin(n * 17.23 + seed * 7.7) * 43758.5453
    return v - np.floor(v)

# ---------------------------------------------------------------- aura field
def aura_field(px, py, cx, cy, t, el, seed):
    """Filament medium inside an elliptical silhouette band.
    Returns density, rim, core, band (all 0..1 arrays)."""
    ex = (px - cx) / RX
    # asymmetric ellipse: reaches higher above the hero (media licks upward)
    ry_eff = np.where(py < cy, RY * TOP_STRETCH, RY * 0.9)
    ey = (py - cy) / ry_eff
    e = np.sqrt(ex * ex + ey * ey)
    band = smoothstep(BAND_IN[0], BAND_IN[1], e) * (1.0 - smoothstep(BAND_OUT[0], BAND_OUT[1], e))

    flow = t * el["rise"]
    # low-freq sway so the whole shroud leans/waves (not a clean shell)
    sway = fbm(ey * 1.3 - flow * 0.4 + 3.0, np.full_like(ey, seed), seed + 1.0) - 0.5
    xs = ex + sway * 0.30
    # warp + tall filaments (low y frequency -> vertical streaks)
    q = fbm(xs * 2.0 + seed, ey * 1.0 - flow * 0.55, seed + 2.0)
    n = fbm(xs * 4.2 + (q - 0.5) * 2.2, ey * 1.5 - flow + (q - 0.5) * 1.4, seed + 5.0)

    # NOISE-DOMINANT: the medium breaks the silhouette shell into wisps
    raw = n * 1.05 + band * 0.22
    thr = el["erosion"] + 0.08 * (q - 0.5)          # erosion threshold wanders
    # dense noise pokes past the ellipse; sparse noise leaves holes in it
    shell = band * (0.50 + 0.70 * smoothstep(0.30, 0.75, n))
    density = smoothstep(thr, thr + 0.24, raw) * shell
    # patchy rim: never a full outline (a full outline is the hard-shape sin)
    rim = smoothstep(thr - 0.06, thr, raw) * (1.0 - smoothstep(thr, thr + 0.08, raw)) \
        * shell * smoothstep(0.38, 0.72, n)
    core = smoothstep(thr + 0.20, thr + 0.48, raw) * shell
    return density, rim, core, shell, n

# ---------------------------------------------------------------- storm arcs
def _seg_dist(px, py, ax, ay, bx, by):
    """Distance from pixel grid to segment ab."""
    vx, vy = bx - ax, by - ay
    L2 = vx * vx + vy * vy + 1e-9
    t = np.clip(((px - ax) * vx + (py - ay) * vy) / L2, 0.0, 1.0)
    dx = px - (ax + t * vx)
    dy = py - (ay + t * vy)
    return np.sqrt(dx * dx + dy * dy)

def storm_arcs(px, py, cx, cy, t, seed):
    """Sparse jagged branching bolt filaments, re-struck every ~0.34 s."""
    cell = np.floor(t / 0.34)
    if hash1(cell + 1.0, seed) < 0.25:              # sparse: some cells strike nothing
        return np.zeros_like(px)
    acc = np.zeros_like(px)
    for bolt in range(3):
        bseed = seed + bolt * 31.0 + cell * 7.0
        x = cx + (hash1(bseed, seed) - 0.5) * RX * 1.2
        y = cy - RY * 0.75
        pts = [(x, y)]
        drift = (hash1(bseed + 1.0, seed) - 0.5) * 6.0
        for k in range(9):                          # jagged walk down/outward
            x += drift + (hash1(bseed + 2.0 + k, seed) - 0.5) * 14.0
            y += 7.0 + hash1(bseed + 9.0 + k, seed) * 8.0
            pts.append((x, y))
        w_main = 1.8
        for k in range(len(pts) - 1):
            d = _seg_dist(px, py, *pts[k], *pts[k + 1])
            acc += np.exp(-(d / w_main) ** 2)
        # one branch off the middle
        bx, by = pts[4]
        bpts = [(bx, by)]
        bdir = 1.0 if hash1(bseed + 50.0, seed) > 0.5 else -1.0
        for k in range(4):
            bx += bdir * (5.0 + hash1(bseed + 60.0 + k, seed) * 7.0)
            by += 5.0 + hash1(bseed + 70.0 + k, seed) * 5.0
            bpts.append((bx, by))
        for k in range(len(bpts) - 1):
            d = _seg_dist(px, py, *bpts[k], *bpts[k + 1])
            acc += 0.7 * np.exp(-(d / 1.0) ** 2)
    return np.clip(acc, 0.0, 1.5)

# ---------------------------------------------------------------- blood drips
def blood_drips(px, py, cx, cy, t, seed):
    """Slow heavy drip streaks falling below the band (liquid read)."""
    acc = np.zeros_like(px)
    for i in range(4):
        dx0 = (hash1(i + 1.0, seed) - 0.5) * RX * 1.1
        speed = 14.0 + hash1(i + 5.0, seed) * 10.0
        off = hash1(i + 9.0, seed) * 60.0
        span = 60.0
        y0 = cy + RY * 0.35
        yy = y0 + ((t * speed + off) % span)
        fade = 1.0 - ((t * speed + off) % span) / span
        ddx = (px - (cx + dx0)) / 2.0
        ddy = (py - yy) / 7.0
        acc += np.exp(-(ddx * ddx + ddy * ddy)) * fade
    return np.clip(acc * 2.0, 0.0, 1.0)

# ---------------------------------------------------------------- scene
def backdrop():
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    u = xx / FW; v = yy / FH
    base = np.array([0x2e, 0x31, 0x3a], dtype=np.float32) / 255.0
    tile = 0.5 + 0.5 * np.sin(xx / 11.0) * np.sin(yy / 11.0)
    n = fbm(u * 5.0, v * 5.0, 99.0)
    img = base[None, None, :] * (0.80 + 0.14 * tile * n)[..., None]
    dx = u - 0.5; dy = v - 0.5
    img *= (1.0 - 0.45 * np.clip(np.sqrt(dx * dx + dy * dy) * 1.5, 0, 1))[..., None]
    return np.clip(img, 0, 1)

def add_hero(img, cx, cy):
    """Small bright hero marker (shadow + capsule body + head) the aura hugs."""
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    # ground shadow
    shx = (xx - cx) / 12.0; shy = (yy - (cy + 26.0)) / 4.5
    img *= (1.0 - 0.5 * np.exp(-(shx * shx + shy * shy)))[..., None]
    # body capsule
    bx = (xx - cx) / 6.0
    by = (yy - (cy + 8.0)) / 13.0
    body = np.exp(-(bx * bx + by * by) ** 1.3)
    # head
    hx = (xx - cx) / 4.2; hy = (yy - (cy - 8.0)) / 4.6
    head = np.exp(-(hx * hx + hy * hy))
    m = np.clip(body + head, 0, 1)[..., None]
    col = np.array([0.95, 0.82, 0.62])[None, None, :]
    return img * (1.0 - m) + col * m

# ---------------------------------------------------------------- frame
def render_frame(el_name, t, col_idx):
    el = EL[el_name]
    seed = SEED_BASE + col_idx * 13.7
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    cx = FW / 2.0; cy = FH * HERO_CY

    density, rim, core, band, n = aura_field(xx, yy, cx, cy, t, el, seed)
    glow = rim[..., None] * el["edge"][None, None, :] * 0.8 \
         + core[..., None] * el["core"][None, None, :] * 1.7

    if el["arc"] > 0.0:
        # arcs strike THROUGH the band, not clipped by it
        arc = storm_arcs(xx, yy, cx, cy, t, seed) * (0.35 + 0.65 * band) * el["arc"]
        glow += arc[..., None] * el["edge"][None, None, :] * 1.6
        density = np.clip(density + arc * 0.3, 0, 1)
    if el["rise"] < 0.0:                             # blood: liquid drips
        drip = blood_drips(xx, yy, cx, cy, t, seed)
        glow += drip[..., None] * el["core"][None, None, :] * 1.4
        density = np.clip(density + drip * 0.5, 0, 1)

    scene = add_hero(backdrop(), cx, cy)
    if el["occlude"] > 0.0:
        # MIX composite: smoke occludes, glow adds on top (umbra pattern)
        folds = smoothstep(0.35, 0.9, n)
        smoke_rgb = el["smoke"][None, None, :] * (0.6 + 0.8 * folds[..., None])
        a = np.clip(density * 1.3, 0.0, el["alpha"])[..., None]
        out = scene * (1.0 - a) + smoke_rgb * a
        out = out + (1.0 - np.exp(-glow * 1.6))
    else:
        # translucent light (the shader is blend_mix; HDR cores fake the pop)
        out = scene + glow
    return np.clip(out, 0, 1) ** (1.0 / 1.2)

# ---------------------------------------------------------------- sheet
def main():
    gap = 6
    W = FW * len(ELEMENTS) + gap * (len(ELEMENTS) + 1)
    H = FH * len(TIMES) + gap * (len(TIMES) + 1)
    sheet = np.full((H, W, 3), np.array([10, 11, 14], dtype=np.float32) / 255.0)
    for r, t in enumerate(TIMES):
        for c, name in enumerate(ELEMENTS):
            f = render_frame(name, t, c)
            y0 = gap + r * (FH + gap); x0 = gap + c * (FW + gap)
            sheet[y0:y0 + FH, x0:x0 + FW] = f
    out = (np.clip(sheet, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save("contact_sheet.png")
    print("wrote contact_sheet.png", out.shape, "cols:", ELEMENTS, "rows t:", TIMES)

if __name__ == "__main__":
    main()
