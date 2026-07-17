"""LUT strip baker (pipeline/lut_gen.py) — identity, monotonicity, baked outputs.

All file I/O goes to tmp_path; nothing here touches game/prototype/art/luts/.
"""
from __future__ import annotations

from PIL import Image

from genforge.pipeline.lut_gen import (
    GRADES,
    GRID,
    SIZE,
    TILE,
    bake_default_luts,
    bake_lut,
    grade,
)


def test_identity_spec_bakes_identity_lut(tmp_path):
    """The empty spec must bake a bit-exact identity strip: every texel encodes
    its own strip address (255/15 == 17, so R/G levels are exact in 8-bit)."""
    path = bake_lut({}, tmp_path / "identity.png")
    img = Image.open(path)
    assert img.size == (SIZE, SIZE) and img.mode == "RGB"
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            tile = (y // TILE) * GRID + (x // TILE)
            assert px[x, y] == ((x % TILE) * 17, (y % TILE) * 17, tile), (x, y)


def test_grade_monotonic_along_each_axis():
    """For every shipped grade, each output channel must be non-decreasing
    along its own input axis (LUT interpolation in the shader relies on it —
    a non-monotone grade would band under the strip's bilinear filtering)."""
    fixed_levels = (0.15, 0.5, 0.85)
    steps = [i / 48.0 for i in range(49)]
    for name, spec in GRADES.items():
        for axis in range(3):
            for other in fixed_levels:
                prev = -1.0
                for v in steps:
                    rgb = [other, other, other]
                    rgb[axis] = v
                    out = grade(tuple(rgb), spec)[axis]
                    assert out >= prev - 1e-9, (name, axis, other, v)
                    prev = out


def test_veilands_matches_analytic_shader_grade():
    """veilands_default must reproduce the exact analytic block post.gdshader
    keeps for lut_amount == 0 (split-tone crossed at lum 0.55 + 0.18 S-curve)."""
    c = (0.30, 0.42, 0.55)
    lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    t = min(max(lum / 0.55, 0.0), 1.0)
    t = t * t * (3.0 - 2.0 * t)
    expect = []
    for v, lo, hi in zip(c, (0.80, 0.85, 1.14), (1.06, 1.01, 0.93)):
        v = v * (lo + (hi - lo) * t)
        expect.append(v + (v * v * (3.0 - 2.0 * v) - v) * 0.18)
    got = grade(c, GRADES["veilands_default"])
    for e, g in zip(expect, got):
        assert abs(e - g) < 1e-12


def test_bake_default_luts_writes_biome_files(tmp_path):
    """Both shipped biome grades bake to strip-sized PNGs — and actually differ
    (per-biome grading is data, not a copy of the default)."""
    paths = bake_default_luts(tmp_path)
    assert sorted(p.name for p in paths) == ["ember_hollows.png", "veilands_default.png"]
    images = {}
    for p in paths:
        assert p.exists()
        img = Image.open(p)
        assert img.size == (SIZE, SIZE) and img.mode == "RGB"
        images[p.name] = list(img.getdata())
    assert images["ember_hollows.png"] != images["veilands_default.png"]
