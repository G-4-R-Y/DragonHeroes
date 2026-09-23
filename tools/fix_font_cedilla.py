#!/usr/bin/env python3
"""R84 — redraw lowercase ç at x-height in PixelOperator8.ttf.

The 8 px face draws `ccedilla` as a CAPITAL C with a cedilla: its bowl spans
y 100..700 and its top three contours are `C`'s, so Portuguese renders
"Lembre-se da caÇada". Lowercase `c` spans y 0..500. Nothing sits above a
cedilla, so — unlike an accented vowel, whose bounding box legitimately reaches
cap height via the accent — there is no innocent explanation for the height.
The 16 px `PixelOperator.ttf` confirms the intent: there `ccedilla`'s yMax
equals its own lowercase `c`, while `Ccedilla` is a full cap taller.

The fix rebuilds `ccedilla` from the font's own parts: the `c` outline, plus
the below-baseline hook already present in `ccedilla` (the one contour entirely
at or under the baseline). Nothing is invented and nothing is scaled, so the
result is pixel-grid exact. The advance width is never touched — `text_fit`
measures advances, and a glyph-height fix that moved them would invalidate
every budget in that gate.

PixelOperator is Jayvee Enaguas's CC0 font, so modification is permitted.

Usage:  python3 tools/fix_font_cedilla.py [--check]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

FONT = Path("game/prototype/ui/fonts/PixelOperator8.ttf")
GLYPH = "ccedilla"
BASE = "c"


def contours(pen_value):
    """Split a RecordingPen's value into per-contour command lists."""
    out, cur = [], []
    for op, args in pen_value:
        cur.append((op, args))
        if op in ("closePath", "endPath"):
            out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    return out


def max_y(contour):
    ys = [pt[1] for _, args in contour for pt in args if isinstance(pt, tuple)]
    return max(ys) if ys else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="report whether the patch is needed; change nothing")
    args = ap.parse_args()

    font = TTFont(str(FONT))
    glyf = font["glyf"]
    base_top = glyf[BASE].yMax
    before = glyf[GLYPH].yMax

    if before <= base_top:
        print(f"{FONT}: {GLYPH} yMax={before} already at or below "
              f"{BASE} yMax={base_top} — nothing to do")
        return 0
    if args.check:
        print(f"{FONT}: {GLYPH} yMax={before} exceeds {BASE} yMax={base_top} "
              f"— PATCH NEEDED")
        return 1

    glyphs = font.getGlyphSet()

    rec = RecordingPen()
    glyphs[GLYPH].draw(rec)
    hooks = [c for c in contours(rec.value) if (max_y(c) or 0) <= 0]
    if not hooks:
        print(f"ERROR: no below-baseline contour found in {GLYPH}", file=sys.stderr)
        return 2

    pen = TTGlyphPen(glyphs)
    glyphs[BASE].draw(pen)                      # the lowercase bowl, verbatim
    for contour in hooks:                       # the cedilla, verbatim
        for op, opargs in contour:
            getattr(pen, op)(*opargs)

    advance_before = font["hmtx"][GLYPH]
    glyf[GLYPH] = pen.glyph()
    glyf[GLYPH].recalcBounds(glyf)
    font["hmtx"][GLYPH] = advance_before        # explicitly unchanged

    font.save(str(FONT))
    after = TTFont(str(FONT))["glyf"][GLYPH]
    print(f"{FONT}: {GLYPH} yMax {before} -> {after.yMax} "
          f"(yMin {after.yMin}), advance {advance_before[0]} unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
