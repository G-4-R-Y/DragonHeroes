"""Bestiary base bodies — five NEW hand-authored actor part sets.

The v0.1.4 prototype renders five style-anchor actors (actor_art.py). The
bestiary catalogs (bestiary_gen.py) populate the Veilands with 1100 creatures,
so visual diversity needs more base BODIES: this module hand-authors five new
silhouettes in the same locked art direction (docs/design/17 — deep dark
ramps, 1px outlines, cool rim light, pure glow stamps after shading):

  serpent      slither    fen serpent: coil chain, hooded head, venom eyes
  shade        floating   tattered wraith: cowl, fluttering shroud, claw wisps
  golem        brute      blocky stone hulk, lumen-crack seams, rune eye
  fen_boar     quadruped  tusked bristle-back charger
  marsh_drake  quadruped  wingless dragonling with a venom-breath strip

Each body ships the animations its archetype contract needs (BESTIARY_ANIMS);
skeletons/poses live in pipeline/skeletons|poses/<body>.json. Bodies are kept
family-neutral in hue-midtone terms so the spawner's per-entry tint + scale
(bestiary catalogs) multiplies the variety.

This is a human-invoked dev bake for prototype CLIENT art, same carve-out as
bake_game_art.py — presentation only, no gameplay data, so the GenForge
candidate contract for content/ is untouched. It never touches the five
existing actor bundles.

Run from the repo root:
    python3 -m genforge.pipeline.bestiary_art [--previews DIR] [--bodies a,b]
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Callable, Dict, List, Optional

from PIL import Image, ImageDraw

try:
    from .actor_art import (
        Part,
        _box,
        _outline_ext,
        _pts,
        _px,
        _rim,
        _shaded,
    )
    from .assemble import Assembler
    from .manifest import PartsManifest
    from .poses import PoseLibrary
    from .skeletons import Skeleton
    from .stub_provider import pack_parts
except ImportError:  # invoked as a plain script path, not as a module
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from genforge.pipeline.actor_art import (
        Part,
        _box,
        _outline_ext,
        _pts,
        _px,
        _rim,
        _shaded,
    )
    from genforge.pipeline.assemble import Assembler
    from genforge.pipeline.manifest import PartsManifest
    from genforge.pipeline.poses import PoseLibrary
    from genforge.pipeline.skeletons import Skeleton
    from genforge.pipeline.stub_provider import pack_parts

GENFORGE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = GENFORGE_ROOT.parent
PARTS_ROOT = GENFORGE_ROOT / "candidates" / "game_art"
GAME_ART_ROOT = REPO_ROOT / "game" / "prototype" / "art"

# body -> animations to bake (the archetype animation contract)
BESTIARY_ANIMS: Dict[str, List[str]] = {
    "serpent": ["idle", "walk", "lunge"],
    "shade": ["idle", "walk", "lunge"],
    "golem": ["idle", "walk", "lunge"],
    "fen_boar": ["idle", "walk", "lunge"],
    "marsh_drake": ["idle", "walk", "attack", "lunge"],
}


# --------------------------------------------------------------------------
# palettes (family-neutral midtones; catalogs tint per entry)
# --------------------------------------------------------------------------

SERPENT_PAL = {
    "hide": [(12, 30, 24), (22, 50, 38), (36, 76, 54), (54, 102, 70)],
    "belly": [(30, 44, 30), (52, 72, 46), (80, 104, 64)],
    "hood": (74, 128, 92),
    "eye": (190, 255, 120),
    "brow": (120, 200, 96),
    "fang": (224, 220, 196),
    "tongue": (156, 60, 84),
    "rim": (108, 168, 120),
    "outline": (6, 16, 12),
}

SHADE_PAL = {
    "shroud": [(10, 10, 24), (20, 19, 44), (36, 33, 70), (54, 50, 100)],
    "shroud_dark": [(7, 7, 17), (14, 13, 32), (26, 24, 52)],
    "eye": (196, 240, 255),
    "eye_dim": (110, 170, 190),
    "core": (150, 220, 244),
    "core_hot": (232, 250, 255),
    "claw": (172, 186, 214),
    "rim": (96, 104, 160),
    "outline": (4, 4, 12),
}

GOLEM_PAL = {
    "stone": [(32, 30, 28), (54, 50, 44), (80, 74, 64), (108, 100, 86)],
    "stone_dark": [(22, 20, 19), (38, 35, 31), (58, 53, 47)],
    "moss": (56, 92, 52),
    "moss_hi": (88, 132, 72),
    "crack": (122, 226, 255),
    "crack_dim": (58, 118, 134),
    "eye": (140, 236, 255),
    "rim": (140, 134, 118),
    "outline": (10, 9, 8),
}

BOAR_PAL = {
    "hide": [(28, 20, 15), (48, 35, 24), (72, 54, 36), (98, 76, 52)],
    "belly": [(18, 13, 10), (34, 25, 18), (52, 39, 27)],
    "bristle": (16, 11, 8),
    "bristle_hi": (120, 96, 66),
    "tusk": (222, 210, 178),
    "tusk_sh": (176, 162, 128),
    "eye": (255, 146, 62),
    "snout": (66, 44, 34),
    "hoof": (20, 14, 11),
    "moss": (74, 118, 88),
    "rim": (128, 104, 74),
    "outline": (9, 6, 4),
}

DRAKE_PAL = {
    "scale": [(16, 38, 27), (28, 62, 41), (46, 90, 57), (68, 120, 75)],
    "belly": [(96, 92, 58), (140, 132, 86), (186, 176, 118)],
    "fin": [(12, 46, 48), (22, 74, 74), (36, 104, 98)],
    "horn": [(130, 126, 100), (182, 176, 144), (226, 220, 188)],
    "eye": (255, 202, 92),
    "spot": (94, 150, 92),
    "fire": [(46, 120, 34), (96, 186, 52), (170, 235, 110), (236, 255, 196)],
    "rim": (116, 172, 118),
    "outline": (6, 14, 9),
}


# --------------------------------------------------------------------------
# SERPENT — fen serpent, coil chain + hooded head (60x32 canvas)
# --------------------------------------------------------------------------


def build_serpent_parts() -> Dict[str, Part]:
    pal = SERPENT_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    def coil(w: int, h: int, ridge: bool = True) -> Image.Image:
        def shape(d, fill, o):
            d.ellipse(_box((0, 0, w - 1, h - 1), o), fill=fill)

        def detail(d):
            # belly strip along the bottom
            d.ellipse((1, h - 4, w - 2, h - 1), fill=pal["belly"][1] + (255,))
            d.line([(2, h - 2), (w - 3, h - 2)], fill=pal["belly"][0] + (255,))
            # scale mottle
            for x in range(3, w - 3, 4):
                d.point((x, 3 + (x // 4) % 2), fill=pal["hide"][0] + (255,))
            if ridge:
                d.line([(3, 1), (w - 4, 1)], fill=pal["hood"] + (255,))

        img = _shaded((w, h), shape, pal["hide"], outline=out, detail=detail)
        _rim(img, pal["rim"], x_range=(2, w - 3))
        return img

    parts["coil_a"] = (coil(20, 13), (10.0, 6.0), 0.0)
    parts["coil_b"] = (coil(17, 11), (8.0, 5.0), 0.0)
    parts["coil_c"] = (coil(14, 9), (7.0, 4.0), 0.0)

    # tail tip: taper with a pale barb, extends LEFT of its pivot
    def tail(d, fill, o):
        d.polygon(_pts([(11, 1), (4, 0), (0, 3), (4, 6), (11, 6)], o), fill=fill)

    tail_img = _shaded((12, 8), tail, pal["hide"], outline=out)
    _px(tail_img, 1, 3, pal["fang"])  # barb glint
    parts["tail_tip"] = (tail_img, (10.0, 3.0), 0.0)

    # head: hood flare + wedge snout, glowing venom eyes
    def head(d, fill, o):
        d.polygon(_pts([(2, 8), (4, 3), (9, 0), (14, 2), (17, 6), (21, 8),
                        (21, 11), (16, 13), (8, 14), (3, 12)], o), fill=fill)

    def head_detail(d):
        d.line([(12, 12), (21, 10)], fill=pal["belly"][0] + (255,))   # mouth
        d.line([(4, 4), (8, 1)], fill=pal["hood"] + (255,))           # hood edge
        d.point((20, 9), fill=pal["belly"][2] + (255,))               # nose glint

    head_img = _shaded((22, 15), head, pal["hide"], outline=out,
                       detail=head_detail)
    _rim(head_img, pal["rim"], x_range=(4, 18), y_max=6)
    for ex, ey in ((9, 5), (10, 5), (9, 6), (10, 6)):
        _px(head_img, ex, ey, pal["eye"])
    _px(head_img, 9, 4, pal["brow"])
    for ex, ey in ((13, 6), (14, 6)):
        _px(head_img, ex, ey, pal["eye"])
    parts["head"] = (head_img, (3.0, 8.0), 0.0)

    # jaw: fanged lower wedge (opens on the strike)
    def jaw(d, fill, o):
        d.polygon(_pts([(0, 1), (9, 2), (9, 4), (4, 6), (0, 4)], o), fill=fill)

    def jaw_detail(d):
        d.point((3, 2), fill=pal["fang"] + (255,))
        d.point((7, 2), fill=pal["fang"] + (255,))
        d.point((8, 3), fill=pal["tongue"] + (255,))

    parts["jaw"] = (
        _shaded((10, 7), jaw, pal["belly"], outline=out, detail=jaw_detail),
        (1.0, 1.0), 0.0,
    )
    return parts


# --------------------------------------------------------------------------
# SHADE — floating tattered wraith (36x44 canvas)
# --------------------------------------------------------------------------


def build_shade_parts() -> Dict[str, Part]:
    pal = SHADE_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # cowl head: peaked hood, hollow face, twin pale eyes
    def cowl(d, fill, o):
        d.polygon(_pts([(6, 0), (9, 2), (11, 5), (12, 10), (12, 14), (6, 15),
                        (1, 14), (1, 10), (2, 5), (4, 2)], o), fill=fill)

    def cowl_detail(d):
        d.polygon([(3, 7), (10, 7), (11, 13), (6, 14), (2, 13)],
                  fill=(3, 3, 9, 255))                                # hollow
        d.line([(3, 7), (10, 7)], fill=pal["shroud"][3] + (255,))     # cowl lip
        d.line([(2, 8), (2, 12)], fill=pal["shroud"][0] + (255,))

    head = _shaded((13, 16), cowl, pal["shroud"], outline=out,
                   detail=cowl_detail)
    _rim(head, pal["rim"], x_range=(2, 10))
    for ex, ey in ((4, 9), (5, 9)):
        _px(head, ex, ey, pal["eye"])
    for ex, ey in ((8, 9), (9, 9)):
        _px(head, ex, ey, pal["eye"])
    _px(head, 4, 10, pal["eye_dim"])
    _px(head, 9, 10, pal["eye_dim"])
    parts["head"] = (head, (6.0, 13.0), 0.0)

    # shroud: three flutter variants with different ragged hems
    hems = [
        [(18, 14), (17, 22), (14, 18), (12, 23), (9, 18), (6, 23), (3, 18),
         (2, 22), (1, 14)],
        [(18, 14), (18, 21), (15, 17), (13, 22), (10, 17), (7, 23), (4, 17),
         (2, 23), (1, 14)],
        [(18, 14), (16, 23), (14, 17), (11, 22), (8, 17), (5, 22), (3, 17),
         (2, 21), (1, 14)],
    ]
    for i, hem in enumerate(hems):
        def shroud(d, fill, o, hem=hem):
            d.polygon(_pts([(5, 0), (14, 0), (17, 4)] + hem + [(2, 4)], o),
                      fill=fill)

        def shroud_detail(d):
            d.line([(9, 1), (9, 16)], fill=pal["shroud_dark"][0] + (255,))
            d.line([(5, 2), (4, 14)], fill=pal["shroud_dark"][1] + (255,))

        img = _shaded((19, 24), shroud, pal["shroud"], outline=out,
                      detail=shroud_detail)
        _rim(img, pal["rim"], x_range=(4, 15))
        parts[f"shroud_{i}"] = (img, (9.0, 4.0), 0.0)

    # arms: trailing claw wisps (near bright / far shadow)
    def arm(d, fill, o):
        d.polygon(_pts([(1, 0), (5, 1), (8, 5), (10, 10), (8, 9), (9, 13),
                        (6, 11), (6, 14), (3, 10), (1, 5)], o), fill=fill)

    arm_near = _shaded((11, 15), arm, pal["shroud"], outline=out)
    for cx, cy in ((9, 10), (8, 12), (6, 13)):
        _px(arm_near, cx, cy, pal["claw"])
    parts["arm_near"] = (arm_near, (2.0, 1.0), 0.0)
    arm_far = _shaded((11, 15), arm, pal["shroud_dark"], outline=out)
    parts["arm_far"] = (arm_far, (2.0, 1.0), 0.0)

    # chest core: dim ember and lunge flare
    def orb(size: int, edge, mid, hot) -> Image.Image:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse((0, 0, size - 1, size - 1), fill=edge + (255,))
        d.ellipse((1, 1, size - 2, size - 2), fill=mid + (255,))
        c = size // 2
        _px(img, c, c - 1, hot)
        _px(img, c - 1, c, hot)
        return _outline_ext(img, out)

    parts["core"] = (
        orb(6, pal["shroud"][2], pal["core"], pal["core_hot"]), (3.0, 3.0), 0.0)
    flare = orb(10, pal["core"], pal["core_hot"], pal["core_hot"])
    d = ImageDraw.Draw(flare)
    for dx, dy in ((0, -5), (0, 5), (-5, 0), (5, 0)):
        d.line([(5, 5), (5 + dx, 5 + dy)], fill=pal["core"] + (255,), width=1)
    parts["core_flare"] = (flare, (5.0, 5.0), 0.0)
    return parts


# --------------------------------------------------------------------------
# GOLEM — blocky stone brute, lumen-crack seams (48x46 canvas)
# --------------------------------------------------------------------------


def build_golem_parts() -> Dict[str, Part]:
    pal = GOLEM_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # torso: stacked slab boulder with glowing seams + moss cap
    def torso(d, fill, o):
        d.polygon(_pts([(4, 4), (12, 0), (24, 1), (27, 7), (26, 16),
                        (23, 22), (8, 23), (2, 17), (1, 9)], o), fill=fill)

    def torso_detail(d):
        d.line([(6, 8), (13, 10)], fill=pal["stone_dark"][0] + (255,))
        d.line([(16, 5), (22, 8)], fill=pal["stone_dark"][0] + (255,))
        d.line([(10, 15), (19, 17)], fill=pal["stone_dark"][0] + (255,))
        d.line([(12, 1), (20, 2)], fill=pal["moss"] + (255,))        # moss cap
        d.point((14, 2), fill=pal["moss_hi"] + (255,))
        d.point((19, 2), fill=pal["moss_hi"] + (255,))

    torso_img = _shaded((28, 24), torso, pal["stone"], outline=out,
                        detail=torso_detail)
    _rim(torso_img, pal["rim"], x_range=(6, 24))
    # lumen cracks — pure glow after shading
    for x, y in ((9, 12), (10, 13), (11, 13), (17, 9), (18, 10)):
        _px(torso_img, x, y, pal["crack"])
    _px(torso_img, 8, 11, pal["crack_dim"])
    _px(torso_img, 19, 11, pal["crack_dim"])
    parts["torso"] = (torso_img, (14.0, 13.0), 0.0)

    # head: small block, single glowing rune eye
    def head(d, fill, o):
        d.polygon(_pts([(2, 2), (6, 0), (11, 1), (12, 6), (10, 9),
                        (3, 9), (1, 6)], o), fill=fill)

    def head_detail(d):
        d.line([(3, 3), (5, 4)], fill=pal["stone_dark"][0] + (255,))

    head_img = _shaded((13, 10), head, pal["stone"], outline=out,
                       detail=head_detail)
    _rim(head_img, pal["rim"], x_range=(3, 10))
    for ex, ey in ((7, 4), (8, 4), (7, 5), (8, 5)):
        _px(head_img, ex, ey, pal["eye"])
    parts["head"] = (head_img, (5.0, 9.0), 0.0)

    # arms: massive slab arms, knuckle boulders (near/far ramps)
    def arm(d, fill, o):
        d.polygon(_pts([(2, 0), (9, 1), (10, 8), (11, 13), (9, 15),
                        (3, 15), (1, 8)], o), fill=fill)
        d.ellipse(_box((1, 13, 11, 21), o), fill=fill)                # fist

    def arm_detail(d):
        d.line([(3, 7), (9, 8)], fill=pal["stone_dark"][0] + (255,))
        d.point((4, 17), fill=pal["stone_dark"][0] + (255,))
        d.point((7, 18), fill=pal["stone_dark"][0] + (255,))

    arm_near = _shaded((12, 22), arm, pal["stone"], outline=out,
                       detail=arm_detail)
    _px(arm_near, 6, 15, pal["crack_dim"])
    parts["arm_near"] = (arm_near, (5.0, 2.0), 0.0)
    parts["arm_far"] = (
        _shaded((12, 22), arm, pal["stone_dark"], outline=out,
                detail=arm_detail),
        (5.0, 2.0), 0.0,
    )

    # legs: stumpy plinths
    def leg(d, fill, o):
        d.polygon(_pts([(1, 0), (7, 0), (8, 6), (9, 11), (0, 11), (1, 6)], o),
                  fill=fill)

    def leg_detail(d):
        d.line([(1, 8), (8, 8)], fill=pal["stone_dark"][0] + (255,))

    parts["leg_near"] = (
        _shaded((10, 12), leg, pal["stone"], outline=out, detail=leg_detail),
        (4.0, 1.0), 0.0,
    )
    parts["leg_far"] = (
        _shaded((10, 12), leg, pal["stone_dark"], outline=out,
                detail=leg_detail),
        (4.0, 1.0), 0.0,
    )
    return parts


# --------------------------------------------------------------------------
# FEN BOAR — tusked bristle-back charger (52x34 canvas)
# --------------------------------------------------------------------------


def build_fen_boar_parts() -> Dict[str, Part]:
    pal = BOAR_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # body: heavy barrel, bristle ridge, mud belly
    def body(d, fill, o):
        d.ellipse(_box((0, 5, 35, 21), o), fill=fill)
        for sx in (7, 13, 19, 25):                                    # bristles
            d.polygon(_pts([(sx, 7), (sx + 3, 1), (sx + 6, 7)], o), fill=fill)

    def body_detail(d):
        d.ellipse((3, 16, 32, 21), fill=pal["belly"][1] + (255,))
        d.line([(5, 20), (30, 20)], fill=pal["belly"][0] + (255,))
        for sx in (7, 13, 19, 25):
            d.polygon([(sx + 1, 6), (sx + 3, 3), (sx + 5, 6)],
                      fill=pal["bristle"] + (255,))
            d.point((sx + 3, 2), fill=pal["bristle_hi"] + (255,))
        for x, y in ((10, 11), (18, 13), (26, 10)):                   # mud mottle
            d.point((x, y), fill=pal["hide"][0] + (255,))

    body_img = _shaded((36, 22), body, pal["hide"], outline=out,
                       detail=body_detail)
    _rim(body_img, pal["rim"], x_range=(4, 31), y_max=9)
    _px(body_img, 22, 8, pal["moss"])                                 # moss fleck
    _px(body_img, 12, 9, pal["moss"])
    parts["body"] = (body_img, (18.0, 11.0), 0.0)

    # head: snout wedge + up-curved pale tusk + ear
    def head(d, fill, o):
        d.polygon(_pts([(0, 4), (6, 1), (12, 3), (18, 8), (18, 12),
                        (12, 14), (4, 13), (0, 11)], o), fill=fill)
        d.polygon(_pts([(3, 3), (5, 0), (8, 3)], o), fill=fill)       # ear

    def head_detail(d):
        d.rectangle((16, 8, 18, 12), fill=pal["snout"] + (255,))      # snout pad
        d.point((17, 9), fill=(14, 9, 7, 255))                        # nostril
        d.line([(10, 12), (16, 13)], fill=pal["belly"][0] + (255,))   # mouth

    head_img = _shaded((19, 15), head, pal["hide"], outline=out,
                       detail=head_detail)
    _rim(head_img, pal["rim"], x_range=(2, 13), y_max=5)
    for ex, ey in ((9, 6), (10, 6)):
        _px(head_img, ex, ey, pal["eye"])
    # tusk: pure pale stamp curving up from the jawline
    _px(head_img, 13, 12, pal["tusk_sh"])
    _px(head_img, 14, 11, pal["tusk"])
    _px(head_img, 15, 10, pal["tusk"])
    _px(head_img, 15, 9, pal["tusk"])
    parts["head"] = (head_img, (2.0, 8.0), 0.0)

    # jaw: lower chops with a second tusk nub
    def jaw(d, fill, o):
        d.polygon(_pts([(0, 1), (8, 1), (9, 3), (5, 5), (0, 4)], o), fill=fill)

    def jaw_detail(d):
        d.point((7, 1), fill=pal["tusk"] + (255,))
        d.point((8, 0), fill=pal["tusk"] + (255,))

    parts["jaw"] = (
        _shaded((10, 6), jaw, pal["belly"], outline=out, detail=jaw_detail),
        (1.0, 1.0), 0.0,
    )

    # tail: little curl
    def tail(d, fill, o):
        d.polygon(_pts([(8, 2), (4, 0), (1, 2), (2, 5), (5, 6), (8, 5)], o),
                  fill=fill)

    tail_img = _shaded((9, 7), tail, pal["hide"], outline=out)
    parts["tail"] = (tail_img, (8.0, 3.0), 0.0)

    # legs: stubby, hoofed (near/far ramps)
    def leg(d, fill, o):
        d.ellipse(_box((0, 0, 6, 5), o), fill=fill)                   # haunch
        d.polygon(_pts([(2, 3), (5, 3), (6, 8), (6, 11), (1, 11), (1, 8)], o),
                  fill=fill)

    def leg_detail(d):
        d.rectangle((1, 9, 6, 11), fill=pal["hoof"] + (255,))

    parts["leg_near"] = (
        _shaded((8, 12), leg, pal["hide"], outline=out, detail=leg_detail),
        (3.0, 1.0), 0.0,
    )
    parts["leg_far"] = (
        _shaded((8, 12), leg, pal["belly"], outline=out, detail=leg_detail),
        (3.0, 1.0), 0.0,
    )
    return parts


# --------------------------------------------------------------------------
# MARSH DRAKE — wingless dragonling, venom breath (68x46 canvas)
# --------------------------------------------------------------------------


def build_marsh_drake_parts() -> Dict[str, Part]:
    pal = DRAKE_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # body: scaled mass with a dorsal fin ridge, belly band
    def body(d, fill, o):
        d.ellipse(_box((0, 6, 35, 21), o), fill=fill)
        for sx in (6, 14, 22):                                        # fin spikes
            d.polygon(_pts([(sx, 9), (sx + 4, 1), (sx + 8, 9)], o), fill=fill)

    def body_detail(d):
        for i, col in enumerate(pal["belly"]):
            d.ellipse((4 - i, 14 - i, 32, 20), fill=col + (255,))
        for x in range(8, 30, 5):
            d.line([(x, 17), (x + 3, 16)], fill=pal["belly"][0] + (255,))
        for sx in (6, 14, 22):
            d.polygon([(sx + 2, 8), (sx + 4, 3), (sx + 6, 8)],
                      fill=pal["fin"][1] + (255,))
        for x, y in ((9, 11), (19, 12), (27, 10)):                    # spots
            d.point((x, y), fill=pal["spot"] + (255,))

    body_img = _shaded((36, 22), body, pal["scale"], outline=out,
                       detail=body_detail)
    _rim(body_img, pal["rim"], x_range=(3, 32))
    parts["body"] = (body_img, (18.0, 12.0), 0.0)

    # neck: vertical taper, throat strip
    def neck(d, fill, o):
        d.polygon(_pts([(3, 0), (10, 0), (12, 15), (1, 15)], o), fill=fill)
        d.polygon(_pts([(3, 3), (0, 5), (3, 8)], o), fill=fill)       # nape spike

    def neck_detail(d):
        d.polygon([(8, 1), (10, 1), (11, 14), (8, 14)],
                  fill=pal["belly"][1] + (255,))

    parts["neck"] = (
        _shaded((13, 16), neck, pal["scale"], outline=out, detail=neck_detail),
        (6.0, 14.0), 0.0,
    )

    # head: short-horned skull + snout, amber eye
    horn1 = [(7, 7), (1, 2), (3, 0), (10, 5)]

    def head(d, fill, o):
        d.polygon(_pts(horn1, o), fill=fill)                          # horn
        d.ellipse(_box((2, 5, 14, 15), o), fill=fill)                 # cranium
        d.polygon(_pts([(11, 7), (22, 9), (22, 12), (11, 14)], o), fill=fill)
        d.polygon(_pts([(4, 6), (8, 4), (10, 8)], o), fill=fill)      # brow

    def head_detail(d):
        d.polygon(horn1, fill=pal["horn"][1] + (255,))
        d.line([(12, 13), (21, 11)], fill=pal["scale"][0] + (255,))   # mouth
        d.point((20, 10), fill=(12, 6, 4, 255))                       # nostril

    head_img = _shaded((23, 16), head, pal["scale"], outline=out,
                       detail=head_detail)
    _rim(head_img, pal["rim"], x_range=(8, 20), y_max=8)
    _px(head_img, 8, 9, (20, 10, 4))                                  # socket
    _px(head_img, 9, 9, pal["eye"])
    _px(head_img, 10, 9, pal["eye"])
    parts["head"] = (head_img, (5.0, 10.0), 0.0)

    # jaw: toothed lower wedge
    def jaw(d, fill, o):
        d.polygon(_pts([(0, 1), (11, 2), (11, 4), (4, 6), (0, 4)], o), fill=fill)

    def jaw_detail(d):
        for x in (4, 7):
            d.polygon([(x, 2), (x + 1, 3), (x + 2, 2)],
                      fill=pal["horn"][2] + (255,))

    parts["jaw"] = (
        _shaded((12, 7), jaw, pal["belly"], outline=out, detail=jaw_detail),
        (1.0, 1.0), 0.0,
    )

    # tail: two segments, fin tip
    def tail1(d, fill, o):
        d.polygon(_pts([(17, 1), (4, 3), (0, 5), (4, 8), (17, 9)], o), fill=fill)
        d.polygon(_pts([(7, 3), (10, 0), (13, 3)], o), fill=fill)

    parts["tail_1"] = (
        _shaded((18, 10), tail1, pal["scale"], outline=out), (16.0, 5.0), 0.0)

    def tail2(d, fill, o):
        d.polygon(_pts([(12, 3), (5, 4), (3, 5), (5, 7), (12, 8)], o), fill=fill)
        d.polygon(_pts([(5, 0), (0, 5), (5, 10), (3, 5)], o), fill=fill)  # fin

    tail2_img = _shaded((13, 11), tail2, pal["scale"], outline=out)
    _px(tail2_img, 1, 4, pal["rim"])
    parts["tail_2"] = (tail2_img, (12.0, 5.0), 0.0)

    # legs: near pair full ramp, far shadow ramp, pale claws
    def make_leg(size, haunch, shin, foot, claws, ramp):
        def leg(d, fill, o):
            d.ellipse(_box(haunch, o), fill=fill)
            d.polygon(_pts(shin, o), fill=fill)
            d.polygon(_pts(foot, o), fill=fill)

        def leg_detail(d):
            fy = foot[-1][1]
            for cx in claws:
                d.polygon([(cx, fy - 2), (cx - 1, fy), (cx + 1, fy - 1)],
                          fill=pal["horn"][2] + (255,))

        return _shaded(size, leg, ramp, outline=out, detail=leg_detail)

    parts["leg_front"] = (
        make_leg((10, 17), (1, 0, 8, 8), [(3, 6), (7, 6), (6, 13), (3, 13)],
                 [(1, 12), (7, 12), (8, 16), (1, 16)], (3, 6), pal["scale"]),
        (4.0, 2.0), 0.0,
    )
    parts["leg_back"] = (
        make_leg((12, 18), (0, 0, 10, 10), [(4, 7), (9, 7), (7, 14), (4, 14)],
                 [(2, 13), (9, 13), (10, 17), (1, 17)], (3, 7), pal["scale"]),
        (5.0, 2.0), 0.0,
    )
    parts["leg_far"] = (
        make_leg((10, 15), (1, 0, 8, 8), [(3, 5), (7, 5), (6, 12), (3, 12)],
                 [(1, 11), (7, 11), (8, 14), (1, 14)], (3, 6), pal["fin"]),
        (4.0, 2.0), 0.0,
    )

    # VFX: venom-breath puffs, 3 cells (no outline — pure light)
    for i, (w, h) in enumerate(((9, 7), (12, 9), (15, 11))):
        cell = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(cell)
        cy = h / 2.0
        for j, col in enumerate(pal["fire"]):
            frac = 1.0 - j * 0.24
            d.polygon(
                [(0, cy), (w * 0.45 * frac + 2, cy - (h / 2 - 1) * frac),
                 (w * frac - 1, cy - (h / 2 - 1) * frac * 0.3),
                 (w * frac - 1, cy + (h / 2 - 1) * frac * 0.3),
                 (w * 0.45 * frac + 2, cy + (h / 2 - 1) * frac)],
                fill=col + (255,),
            )
        parts[f"vfx_breath_{i}"] = (cell, (1.0, cell.height / 2.0), 0.0)
    return parts


# --------------------------------------------------------------------------
# registry + bake entry point (mirrors bake_game_art, new bodies only)
# --------------------------------------------------------------------------

BESTIARY_BUILDERS: Dict[str, Callable[[], Dict[str, Part]]] = {
    "serpent": build_serpent_parts,
    "shade": build_shade_parts,
    "golem": build_golem_parts,
    "fen_boar": build_fen_boar_parts,
    "marsh_drake": build_marsh_drake_parts,
}


def bake_body(body: str, out_root: Path = GAME_ART_ROOT) -> dict:
    """Parts -> manifest -> baked bundle for one bestiary body."""
    parts = BESTIARY_BUILDERS[body]()
    sheet, regions = pack_parts(parts)
    parts_dir = PARTS_ROOT / body / "parts"
    parts_dir.mkdir(parents=True, exist_ok=True)
    sheet.save(parts_dir / "parts.png")
    manifest = PartsManifest(
        entity=body,
        archetype=body,
        sheet="parts.png",
        sheet_size=(sheet.width, sheet.height),
        parts=regions,
    )
    manifest.save(parts_dir / "parts.json")

    skeleton = Skeleton.load(body)
    poses = PoseLibrary.load(body)
    out_dir = out_root / body
    if out_dir.exists():
        shutil.rmtree(out_dir)
    assembler = Assembler(manifest, skeleton, poses, supersample=True)
    atlas = assembler.bake(out_dir, BESTIARY_ANIMS[body])
    fw, fh = atlas["frame_size"]
    atlas["logical_size"] = [fw // 2, fh // 2]   # loader contract (bundle_art.gd)
    (out_dir / "atlas.json").write_text(json.dumps(atlas, indent=2) + "\n")
    return atlas


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python -m genforge.pipeline.bestiary_art",
        description="Bake the five NEW bestiary body bundles into game/prototype/art/.",
    )
    ap.add_argument("--bodies", default=None,
                    help="comma-separated subset (default: all five new bodies)")
    ap.add_argument("--previews", default=None,
                    help="also write 4x-nearest preview PNGs into this directory")
    args = ap.parse_args(argv)

    bodies = args.bodies.split(",") if args.bodies else list(BESTIARY_BUILDERS)
    for body in bodies:
        if body not in BESTIARY_BUILDERS:
            raise SystemExit(
                f"unknown body '{body}' (have: {list(BESTIARY_BUILDERS)})")

    for body in bodies:
        atlas = bake_body(body)
        fw, fh = atlas["frame_size"]
        lw, lh = atlas["logical_size"]
        anims = ", ".join(
            f"{n}:{a['frames']}f@{a['fps']:g}" for n, a in atlas["animations"].items())
        print(f"  {body}: {fw}x{fh} baked -> {lw}x{lh} logical | {anims}")
        if args.previews:
            from .bake_game_art import write_preview

            p = write_preview(body, atlas, Path(args.previews))
            print(f"    preview: {p}")
    print(f"  bundles: {GAME_ART_ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
