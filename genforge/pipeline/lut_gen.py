"""3D-LUT color-grade baker — Hades-style color scripting as pure data.

Bakes a declarative grade spec (lift/gamma/gain per channel, split-tone
shadow/highlight tints, saturation, contrast S-curve) into a 2D-strip LUT
PNG that game/prototype/post.gdshader samples at runtime (the project's
gl_compatibility floor has no sampler3D, so the B axis is a tile grid).

Strip format — must stay in lockstep with lut_grade() in post.gdshader:
    256x256 PNG = a 16x16 row-major grid of 16x16-px tiles.
    R -> x inside a tile  (16 levels; the sampler bilinears between texels)
    G -> y inside a tile  (16 levels; same)
    B -> tile index       (256 slices; the shader mixes two tile fetches)

Per-biome grades are pure data: add a spec to GRADES, re-run
    python3 -m genforge.pipeline.lut_gen
and hand the baked PNG to ProtoPost.set_lut() — zero engine work.

Grade op order (mirrors the analytic block post.gdshader keeps as fallback):
    lift/gamma/gain -> split-tone tint -> saturation -> S-curve -> clamp.
The S-curve runs UNCLAMPED exactly like the shader's mix(col, col*col*(3-2col))
does, so `veilands_default` reproduces the legacy analytic grade to within
the LUT's quantization.
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, Iterable, List, Tuple

from PIL import Image

TILE = 16              # px per tile side = R/G levels
GRID = 16              # tiles per strip side
SIZE = TILE * GRID     # PNG side (256)
SLICES = GRID * GRID   # B levels (256)

GENFORGE_ROOT = Path(__file__).resolve().parents[1]
LUT_DIR = GENFORGE_ROOT.parent / "game" / "prototype" / "art" / "luts"

# Every knob a grade spec may set; absent keys fall back to these no-ops, so
# the empty spec {} bakes a bit-exact identity LUT.
DEFAULT_SPEC: Dict[str, object] = {
    "lift": (0.0, 0.0, 0.0),            # per-channel shadow lift
    "gamma": (1.0, 1.0, 1.0),           # per-channel midtone power (>1 brightens)
    "gain": (1.0, 1.0, 1.0),            # per-channel multiplier
    "shadow_tint": (1.0, 1.0, 1.0),     # split-tone: multiplied in at low lum...
    "highlight_tint": (1.0, 1.0, 1.0),  # ...crossfading to this at high lum
    "split_crossover": 0.55,            # lum where the highlight tint fully wins
    "saturation": 1.0,                  # lum-preserving saturation scale
    "s_curve": 0.0,                     # contrast S-curve mix (shader used 0.18)
}

# Baked-in biome grades. `veilands_default` is an EXACT port of the analytic
# split-tone + S-curve block in post.gdshader (its lut_amount == 0 fallback);
# `ember_hollows` is the warmer/redder proof that biome grades are pure data.
GRADES: Dict[str, Dict[str, object]] = {
    "veilands_default": {
        "shadow_tint": (0.80, 0.85, 1.14),
        "highlight_tint": (1.06, 1.01, 0.93),
        "split_crossover": 0.55,
        "s_curve": 0.18,
    },
    "ember_hollows": {
        "shadow_tint": (1.04, 0.84, 0.72),
        "highlight_tint": (1.12, 1.00, 0.84),
        "split_crossover": 0.50,
        "saturation": 1.08,
        "s_curve": 0.22,
    },
}


def _smoothstep(edge0: float, edge1: float, x: float) -> float:
    """GLSL smoothstep, kept bit-compatible with the shader's grade."""
    t = (x - edge0) / (edge1 - edge0)
    t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
    return t * t * (3.0 - 2.0 * t)


def _lum(r: float, g: float, b: float) -> float:
    """The shader's Rec.601 luminance weights."""
    return 0.299 * r + 0.587 * g + 0.114 * b


def grade(rgb: Iterable[float], spec: Dict[str, object]) -> Tuple[float, float, float]:
    """Apply one grade spec to a single [0,1] RGB triple (op order: see module doc)."""
    s = {**DEFAULT_SPEC, **spec}
    # lift/gamma/gain (CDL-ish): out = (in + lift*(1-in)) * gain, then 1/gamma power
    out = []
    for c, lift, gamma, gain in zip(rgb, s["lift"], s["gamma"], s["gain"]):
        c = (c + lift * (1.0 - c)) * gain
        c = max(c, 0.0) ** (1.0 / gamma)
        out.append(c)
    # split-tone: shadows multiplied by one tint, highlights by the other
    lum = _lum(*out)
    t = _smoothstep(0.0, s["split_crossover"], lum)
    out = [c * (lo + (hi - lo) * t)
           for c, lo, hi in zip(out, s["shadow_tint"], s["highlight_tint"])]
    # lum-preserving saturation
    lum = _lum(*out)
    sat = s["saturation"]
    out = [lum + (c - lum) * sat for c in out]
    # contrast S-curve — UNCLAMPED, matching the shader's analytic block
    k = s["s_curve"]
    out = [c + (c * c * (3.0 - 2.0 * c) - c) * k for c in out]
    return tuple(min(max(c, 0.0), 1.0) for c in out)


def bake_lut(spec: Dict[str, object], out_path: Path) -> Path:
    """Bake one grade spec into a 256x256 strip PNG (creates parent dirs)."""
    merged = {**DEFAULT_SPEC, **spec}
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        g_in = (y % TILE) / (TILE - 1)
        tile_row = y // TILE
        for x in range(SIZE):
            r_in = (x % TILE) / (TILE - 1)
            b_in = (tile_row * GRID + x // TILE) / (SLICES - 1)
            r, g, b = grade((r_in, g_in, b_in), merged)
            px[x, y] = (int(round(r * 255.0)),
                        int(round(g * 255.0)),
                        int(round(b * 255.0)))
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)
    return out_path


def bake_default_luts(out_dir: Path = LUT_DIR) -> List[Path]:
    """Bake every GRADES entry into out_dir as <name>.png; returns the paths."""
    return [bake_lut(spec, Path(out_dir) / f"{name}.png")
            for name, spec in GRADES.items()]


if __name__ == "__main__":
    for path in bake_default_luts():
        print(f"baked {path}")
