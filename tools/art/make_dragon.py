#!/usr/bin/env python3
"""Dragon Heroes terminal sigil — the art generator.

Ricardo, 2026-09-13: "Are you able to create some art? GPT Astra created our
current repo banner, show who is the best creating our terminal artistically
now." The README banner is Astra's painting; this is the terminal's own mark.

It is not hand-pasted ASCII. The dragon is a filled silhouette: closed outlines
built from cubic Beziers, scanline-filled into a 1-bit bitmap at DOUBLE the
terminal's vertical resolution, then packed two pixel rows per character cell
with the half-block glyphs (upper half, lower half, full). That buys ~2x the
detail a character grid normally holds and gives clean curves instead of
staircases of slashes -- and the whole mark can be re-shaped by moving control
points rather than nudging spaces.

    python3 tools/art/make_dragon.py           # regenerate tools/art/dragon.txt
    python3 tools/art/make_dragon.py --show    # render it here, ember-tinted
    python3 tools/art/make_dragon.py --pixels  # debug: the raw bitmap

Consumers: tools/dh_term.sh (dh_banner) and tools/train_watch.py, which tint it
with the arena palette (ember #ff9a3c, canon 12.x) as a vertical gradient.
"""
from __future__ import annotations

import argparse
from pathlib import Path

W = 74                  # character columns
H = 15                  # character rows  -> 30 pixel rows
ART = Path(__file__).resolve().parent / "dragon.txt"

UPPER, LOWER, FULL, EMPTY = "▀", "▄", "█", " "


def bez(p0, p1, p2, p3, steps=90):
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1.0 - t
        out.append((u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
                    u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1]))
    return out


class Path2D:
    """A closed outline: move/line/curve, then hand the points to the filler."""

    def __init__(self, start):
        self.pts = [start]

    def line(self, p):
        self.pts.append(p)
        return self

    def curve(self, c1, c2, p):
        self.pts.extend(bez(self.pts[-1], c1, c2, p)[1:])
        return self


class Bitmap:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[0] * w for _ in range(h)]

    def fill(self, path, value=1):
        """Even-odd scanline fill, sampled at the pixel centre."""
        pts = path.pts
        n = len(pts)
        for y in range(self.h):
            yc = y + 0.5
            xs = []
            for i in range(n):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % n]
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[0::2], xs[1::2]):
                for x in range(max(0, int(a + 0.5)), min(self.w, int(b + 0.5))):
                    self.px[y][x] = value

    def rows(self):
        out = []
        for cy in range(self.h // 2):
            top, bot = self.px[cy * 2], self.px[cy * 2 + 1]
            line = []
            for x in range(self.w):
                t, b = top[x], bot[x]
                line.append(FULL if t and b else UPPER if t else LOWER if b else EMPTY)
            out.append("".join(line).rstrip())
        return out


def draw() -> Bitmap:
    bm = Bitmap(W, H * 2)

    # Pixel space is 74 x 36 -- twice the character rows. The dragon faces
    # right so its breath runs into the title that sits under the mark.

    # ---- head and neck: crown, brow, snout, lip, cheek, throat -------------
    head = (Path2D((18, 12))                                  # back of the skull
            .curve((22, 5), (30, 3), (38, 6))                 # crown over the brow
            .curve((46, 8), (54, 11), (62, 15))               # the long snout
            .curve((66, 16), (69, 17), (69, 19))              # nose tip
            .curve((68, 21), (66, 22), (63, 22))              # under the nose
            .curve((56, 23), (50, 23), (44, 22))              # upper lip
            .curve((38, 23), (32, 24), (27, 25))              # cheek to the hinge
            .curve((21, 28), (16, 30), (11, 30))              # throat, off-frame
            .line((2, 30))
            .curve((3, 25), (7, 20), (12, 17)))               # back of the neck
    bm.fill(head)

    # ---- lower jaw: its own shape, so the open maw is real background ------
    jaw = (Path2D((22, 24))
           .curve((36, 28), (48, 29), (58, 28))               # the bite line
           .line((56, 30))
           .curve((45, 31), (33, 30), (21, 27)))
    bm.fill(jaw)

    # ---- horns: two back-swept blades ---------------------------------------
    for (bx, by), (tx, ty), bow, thick in (((21, 10), (1, 1), 6.0, 4.5),
                                           ((25, 15), (6, 10), 3.0, 3.0)):
        horn = (Path2D((bx, by))
                .curve((bx - 8, by - bow), (tx + 8, ty - bow * 0.6), (tx, ty))
                .line((tx + 2, ty + 2))
                .curve((tx + 10, ty + 2), (bx - 7, by + 2), (bx + 2, by + thick)))
        bm.fill(horn)

    # ---- plates rising off the back ridge -----------------------------------
    for x, y in ((13, 19), (9, 24), (5, 29)):
        bm.fill(Path2D((x, y)).curve((x - 2, y - 4), (x - 6, y - 4), (x - 8, y - 1))
                .line((x - 5, y + 1)).line((x, y + 2)))

    # ---- carve the face back out: eye, pupil, nostril -----------------------
    bm.fill(Path2D((32, 13)).curve((35, 10), (41, 11), (42, 14))
            .curve((40, 17), (34, 17), (32, 13)), 0)
    bm.fill(Path2D((37, 11)).line((39, 14)).line((37, 17)).line((35, 14)), 1)
    bm.fill(Path2D((63, 18)).curve((66, 18), (66, 21), (63, 21))
            .curve((61, 20), (61, 18), (63, 18)), 0)
    return bm


EMBER = [(255, 214, 148), (255, 178, 92), (255, 154, 60), (232, 118, 40),
         (198, 86, 28), (158, 60, 20), (120, 42, 14), (92, 32, 12)]


def tinted(rows):
    n = max(len(rows), 1)
    for i, line in enumerate(rows):
        r, g, b = EMBER[min(int(i / n * len(EMBER)), len(EMBER) - 1)]
        yield f"\033[38;2;{r};{g};{b}m{line}\033[0m"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--show", action="store_true")
    ap.add_argument("--pixels", action="store_true")
    a = ap.parse_args()
    bm = draw()
    if a.pixels:
        for y, row in enumerate(bm.px):
            print(f"{y:2d}|" + "".join("#" if v else "." for v in row))
        return 0
    rows = bm.rows()
    ART.write_text("\n".join(rows) + "\n", encoding="utf-8")
    if a.show:
        print("\n".join(tinted(rows)))
    else:
        print(f"wrote {ART} ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
