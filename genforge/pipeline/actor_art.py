"""Hand-authored HIGH-FIDELITY actor parts — the prototype's five style anchors.

This is the "dramatic quality upgrade" of the stub provider's part art: instead
of the generic mage/dragon demo sheets, each of the game's key actors gets a
hand-authored programmatic parts sheet in the locked art direction
(docs/design/17): modern-day pixel-art dark fantasy — deep dark bases with
3-4 tone shading ramps per material, 1 px dark outlines, cool rim light along
the top silhouette, and pure glowing accents (cyan sigils, violet eyes,
ember smolder) stamped after shading so they never get muddied.

Parts are drawn at BAKED resolution = 2x the logical on-screen pixel size
(the game displays bundles through ImageTexture.set_size_override at half the
baked size, so every part here carries 2x the detail of the procedural
placeholder sprites in game/prototype/sprites.gd).

Actors (skeletons/poses live in pipeline/skeletons|poses/<actor>.json):

  hero                 humanoid   dark-teal hooded swordsman, cyan chest sigil
  gloamfen_stalker     quadruped  low violet pack hunter, glowing violet eyes
  gloamfen_wisp        spirit     cyan-violet spirit orb with trailing motes
  emberwing_matriarch  dragon     the great ember dragon boss
  ember_drake          dragon     rideable ember mount with a fixed saddle

The stub provider (stub_provider.py) registers these as first-class
archetypes, so the whole parts-sheet -> skeleton -> pose -> baked-strip
pipeline (and the service) runs them with zero model calls.
"""
from __future__ import annotations

from typing import Callable, Dict, List, Optional, Tuple

from PIL import Image, ImageChops, ImageDraw, ImageFilter

Color = Tuple[int, int, int]
Ramp = List[Color]
Offset = Tuple[int, int]
ShapeFn = Callable[[ImageDraw.ImageDraw, object, Offset], None]
Part = Tuple[Image.Image, Tuple[float, float], float]  # image, pivot, angle_hint


# --------------------------------------------------------------------------
# drawing kit (second generation: banded ramps + rim light + glow dots)
# --------------------------------------------------------------------------


def _pts(points: List[Tuple[float, float]], off: Offset) -> List[Tuple[float, float]]:
    return [(x + off[0], y + off[1]) for x, y in points]


def _box(b: Tuple[float, float, float, float], off: Offset):
    return (b[0] + off[0], b[1] + off[1], b[2] + off[0], b[3] + off[1])


def _px(img: Image.Image, x: int, y: int, col: Color, a: int = 255) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), tuple(col) + (a,))


def _shaded(
    size: Tuple[int, int],
    shape_fn: ShapeFn,
    ramp: Ramp,
    light: Tuple[int, int] = (-1, -1),
    outline: Optional[Color] = None,
    detail: Optional[Callable[[ImageDraw.ImageDraw], None]] = None,
    band: int = 2,
) -> Image.Image:
    """Banded-shading fill of a silhouette + clipped detail + 1px inner outline."""
    mask = Image.new("L", size, 0)
    shape_fn(ImageDraw.Draw(mask), 255, (0, 0))

    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, col in enumerate(ramp):
        shape_fn(d, tuple(col) + (255,), (light[0] * band * i, light[1] * band * i))

    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    if detail is not None:
        detail(ImageDraw.Draw(out))
        out.putalpha(ImageChops.multiply(out.getchannel("A"), mask))
    if outline is not None:
        eroded = mask.filter(ImageFilter.MinFilter(3))
        edge = ImageChops.subtract(mask, eroded)
        edge_img = Image.new("RGBA", size, tuple(outline) + (255,))
        out.paste(edge_img, (0, 0), edge)
    return out


def _rim(
    img: Image.Image,
    color: Color,
    x_range: Optional[Tuple[int, int]] = None,
    y_max: Optional[int] = None,
) -> None:
    """Rim light: recolor top-facing edge pixels (transparent above)."""
    w, h = img.size
    src = img.copy()
    for y in range(h):
        if y_max is not None and y > y_max:
            break
        for x in range(w):
            if x_range is not None and not (x_range[0] <= x <= x_range[1]):
                continue
            a = src.getpixel((x, y))[3]
            if a == 0:
                continue
            above = src.getpixel((x, y - 1))[3] if y > 0 else 0
            if above == 0:
                img.putpixel((x, y), tuple(color) + (255,))


def _outline_ext(img: Image.Image, color: Color) -> Image.Image:
    """1px OUTER outline (for hand-built images that skip _shaded)."""
    mask = img.getchannel("A").point(lambda a: 255 if a > 0 else 0)
    dil = mask.filter(ImageFilter.MaxFilter(3))
    edge = ImageChops.subtract(dil, mask)
    edge_img = Image.new("RGBA", img.size, tuple(color) + (255,))
    out = img.copy()
    out.paste(edge_img, (0, 0), edge)
    return out


def _blit(canvas: Image.Image, img: Image.Image, xy: Tuple[int, int]) -> None:
    canvas.alpha_composite(img, dest=xy)


# --------------------------------------------------------------------------
# actor palettes (style anchors, matching the prototype's world lighting)
# --------------------------------------------------------------------------

HERO_PAL = {
    "cloak": [(9, 24, 30), (17, 45, 54), (29, 75, 88), (42, 98, 116)],
    "cloth_dark": [(6, 16, 20), (11, 29, 35), (19, 48, 58)],
    "face": (232, 210, 176),
    "face_sh": (207, 178, 140),
    "eye": (18, 34, 40),
    "sigil": (111, 227, 255),
    "sigil_dim": (46, 107, 118),
    "steel": [(122, 140, 146), (178, 196, 200), (223, 232, 234)],
    "steel_hi": (255, 255, 255),
    "grip": (85, 52, 31),
    "gold": (200, 164, 68),
    "rim": (126, 202, 220),
    "outline": (7, 14, 18),
}

STALKER_PAL = {
    "hide": [(26, 19, 40), (38, 29, 58), (55, 42, 82), (75, 61, 104)],
    "belly": [(16, 12, 26), (28, 21, 43), (40, 31, 60)],
    "spine": (99, 84, 134),
    "eye": (207, 157, 255),
    "brow": (150, 112, 198),
    "claw": (196, 186, 212),
    "fang": (214, 205, 226),
    "rim": (122, 104, 164),
    "outline": (13, 8, 22),
}

WISP_PAL = {
    "edge": (74, 52, 158),
    "mid": (142, 108, 240),
    "core": (217, 200, 255),
    "flare_edge": (122, 95, 216),
    "flare_mid": (189, 166, 255),
    "flare_core": (255, 255, 255),
    "cyan": (127, 231, 255),
    "cyan_dim": (89, 214, 230),
    "mote": (158, 132, 236),
    "eye": (44, 26, 92),
    "outline": (20, 11, 38),
}

MATRIARCH_PAL = {
    "scale": [(70, 24, 9), (122, 46, 16), (168, 72, 26), (208, 104, 40)],
    "rim": (240, 152, 74),
    "belly": [(108, 62, 30), (156, 100, 52), (198, 146, 88)],
    "membrane": [(92, 24, 9), (138, 46, 15), (180, 76, 26)],
    "membrane_far": [(60, 16, 7), (92, 30, 11), (122, 48, 18)],
    "bone_edge": (216, 118, 46),
    "horn": [(112, 100, 84), (178, 168, 144), (232, 222, 196)],
    "eye": (255, 209, 102),
    "fire": [(196, 44, 14), (242, 120, 26), (255, 196, 64), (255, 244, 180)],
    "ember_hot": (255, 207, 106),
    "ember": (255, 138, 51),
    "outline": (24, 10, 4),
}

DRAKE_PAL = {
    "scale": [(83, 24, 6), (119, 39, 10), (179, 79, 22), (224, 122, 48)],
    "rim": (240, 158, 84),
    "belly": [(120, 74, 34), (150, 96, 46), (198, 141, 82)],
    "membrane": [(81, 22, 5), (109, 31, 9), (140, 46, 14)],
    "membrane_far": [(58, 15, 4), (81, 22, 5), (104, 30, 9)],
    "bone_edge": (208, 104, 40),
    "horn": [(168, 144, 108), (206, 186, 152), (232, 217, 192)],
    "eye": (255, 209, 102),
    "leather": (58, 36, 19),
    "leather_hi": (110, 69, 38),
    "blanket": (29, 75, 86),
    "blanket_hi": (42, 98, 116),
    "buckle": (200, 164, 65),
    "ember_hot": (255, 207, 106),
    "ember": (255, 138, 51),
    "outline": (22, 10, 4),
}


# --------------------------------------------------------------------------
# HERO — dark-teal hooded swordsman with a cyan chest sigil (52x52 canvas)
# --------------------------------------------------------------------------


def build_hero_parts() -> Dict[str, Part]:
    pal = HERO_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # -- head: pointed hood, shadowed face opening, one pale-lit eye ---------
    def hood(d, fill, o):
        d.polygon(_pts([(8, 0), (12, 3), (15, 8), (16, 16), (9, 17),
                        (2, 15), (2, 8), (4, 3)], o), fill=fill)

    def hood_detail(d):
        d.polygon([(9, 7), (15, 8), (15, 14), (9, 14)], fill=(6, 11, 16, 255))
        d.rectangle((11, 8, 14, 12), fill=pal["face"] + (255,))
        d.rectangle((11, 11, 14, 12), fill=pal["face_sh"] + (255,))
        d.rectangle((13, 9, 14, 10), fill=pal["eye"] + (255,))
        # hood lip catches the light around the opening
        d.line([(9, 7), (15, 8)], fill=pal["cloak"][3] + (255,), width=1)
        d.line([(9, 8), (9, 14)], fill=pal["cloak"][0] + (255,), width=1)

    head = _shaded((17, 18), hood, pal["cloak"], outline=out, detail=hood_detail)
    _rim(head, pal["rim"], x_range=(4, 12))
    parts["head"] = (head, (8.0, 17.0), 0.0)

    # -- torso: cloak with belt, center seam, glowing sigil ------------------
    def robe(d, fill, o):
        d.polygon(_pts([(6, 0), (14, 0), (17, 4), (18, 18), (10, 19),
                        (2, 18), (3, 4)], o), fill=fill)

    def robe_detail(d):
        d.line([(10, 1), (10, 18)], fill=pal["cloak"][0] + (255,), width=1)
        d.rectangle((3, 12, 17, 13), fill=(50, 32, 17, 255))          # belt
        d.rectangle((9, 12, 11, 13), fill=pal["gold"] + (255,))       # buckle
        d.line([(4, 17), (16, 17)], fill=pal["cloth_dark"][0] + (255,), width=1)

    torso = _shaded((20, 20), robe, pal["cloak"], outline=out, detail=robe_detail)
    _rim(torso, pal["rim"], x_range=(6, 16))
    # cyan sigil — stamped after shading so it stays pure light
    _px(torso, 12, 6, pal["sigil"])
    _px(torso, 13, 6, pal["sigil"])
    _px(torso, 12, 7, pal["sigil_dim"])
    _px(torso, 13, 7, pal["sigil_dim"])
    _px(torso, 12, 5, pal["sigil_dim"])
    parts["torso"] = (torso, (10.0, 10.0), 0.0)

    # -- leg: dark legging + boot (shared by both leg bones) -----------------
    def leg(d, fill, o):
        d.polygon(_pts([(2, 0), (6, 0), (6, 7), (7, 10), (7, 13),
                        (1, 13), (1, 10), (2, 7)], o), fill=fill)

    def leg_detail(d):
        d.polygon([(1, 10), (7, 10), (7, 13), (1, 13)], fill=(8, 18, 22, 255))
        d.line([(2, 10), (6, 10)], fill=(29, 60, 70, 255), width=1)   # boot cuff

    leg_img = _shaded((9, 14), leg, pal["cloth_dark"], outline=out, detail=leg_detail)
    parts["leg"] = (leg_img, (4.0, 1.0), 0.0)

    # -- arms: near sleeve (cloak ramp) and far sleeve (shadow ramp) ---------
    def sleeve(d, fill, o):
        d.polygon(_pts([(1, 0), (5, 0), (6, 6), (6, 10), (4, 12), (1, 10)], o),
                  fill=fill)

    def sleeve_detail(d):
        d.line([(1, 8), (6, 8)], fill=pal["cloak"][0] + (255,), width=1)
        d.ellipse((2, 9, 6, 12), fill=(22, 38, 46, 255))              # glove

    arm = _shaded((8, 13), sleeve, pal["cloak"], outline=out, detail=sleeve_detail)
    _rim(arm, pal["rim"], x_range=(2, 5), y_max=2)
    parts["arm"] = (arm, (3.0, 2.0), 0.0)
    arm_far = _shaded((8, 13), sleeve, pal["cloth_dark"], outline=out,
                      detail=sleeve_detail)
    parts["arm_far"] = (arm_far, (3.0, 2.0), 0.0)

    # -- cape: ragged night-shadow cloth behind the torso --------------------
    def cape(d, fill, o):
        d.polygon(_pts([(3, 0), (12, 0), (14, 8), (13, 17), (10, 14),
                        (8, 18), (5, 14), (2, 17), (1, 8)], o), fill=fill)

    cape_img = _shaded((16, 19), cape, pal["cloth_dark"], light=(1, -1),
                       outline=out)
    parts["cape"] = (cape_img, (7.0, 2.0), 0.0)

    # -- sword: pale steel blade drawn point-DOWN, grip at the top -----------
    sword = Image.new("RGBA", (12, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(sword)
    d.polygon([(5, 8), (7, 8), (7, 25), (6, 29), (5, 25)],
              fill=pal["steel"][1] + (255,))
    d.line([(5, 8), (5, 24)], fill=pal["steel"][0] + (255,), width=1)
    d.line([(7, 8), (7, 24)], fill=pal["steel"][2] + (255,), width=1)  # bright edge
    d.rectangle((3, 6, 9, 7), fill=(64, 76, 82, 255))                  # crossguard
    d.point((3, 6), fill=pal["steel"][2] + (255,))
    d.point((9, 6), fill=pal["steel"][2] + (255,))
    d.rectangle((5, 1, 7, 5), fill=pal["grip"] + (255,))
    d.line([(6, 1), (6, 5)], fill=(120, 76, 46, 255), width=1)
    d.point((6, 0), fill=pal["gold"] + (255,))                         # pommel
    sword = _outline_ext(sword, out)
    _px(sword, 7, 26, pal["steel_hi"])                                 # tip glint
    _px(sword, 6, 29, pal["steel_hi"])
    parts["sword"] = (sword, (6.0, 3.0), 0.0)

    return parts


# --------------------------------------------------------------------------
# GLOAMFEN STALKER — low violet quadruped, glowing violet eyes (56x36 canvas)
# --------------------------------------------------------------------------


def build_stalker_parts() -> Dict[str, Part]:
    pal = STALKER_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # -- body: long low mass with ridge spines, dark belly -------------------
    def body(d, fill, o):
        d.polygon(_pts([(2, 9), (6, 5), (14, 3), (26, 4), (33, 7), (34, 12),
                        (30, 16), (12, 17), (4, 14)], o), fill=fill)
        d.polygon(_pts([(10, 5), (12, 0), (15, 5)], o), fill=fill)   # spines
        d.polygon(_pts([(17, 4), (19, 0), (22, 4)], o), fill=fill)
        d.polygon(_pts([(24, 5), (26, 1), (28, 5)], o), fill=fill)

    def body_detail(d):
        d.line([(4, 14), (29, 15)], fill=pal["belly"][1] + (255,), width=1)
        d.line([(6, 15), (28, 16)], fill=pal["belly"][0] + (255,), width=1)
        # flank mottle
        for x, y in ((12, 9), (18, 11), (24, 8), (9, 11), (27, 12)):
            d.point((x, y), fill=pal["hide"][0] + (255,))
        # lit spine ridges
        d.point((12, 1), fill=pal["spine"] + (255,))
        d.point((19, 1), fill=pal["spine"] + (255,))
        d.point((26, 2), fill=pal["spine"] + (255,))

    body_img = _shaded((36, 18), body, pal["hide"], outline=out, detail=body_detail)
    _rim(body_img, pal["rim"], x_range=(6, 30), y_max=8)
    parts["body"] = (body_img, (18.0, 9.0), 0.0)

    # -- head: wedge skull + neck base + snout, twin glowing eyes, ear spike --
    def head(d, fill, o):
        d.polygon(_pts([(0, 5), (5, 3), (10, 4), (15, 8), (15, 11),
                        (8, 12), (3, 14), (0, 14)], o), fill=fill)
        d.polygon(_pts([(3, 4), (5, 0), (7, 4)], o), fill=fill)       # ear spike

    def head_detail(d):
        d.line([(9, 11), (15, 10)], fill=pal["belly"][0] + (255,), width=1)  # mouth
        d.point((14, 9), fill=pal["belly"][2] + (255,))               # nose glint

    head_img = _shaded((16, 15), head, pal["hide"], outline=out, detail=head_detail)
    _rim(head_img, pal["rim"], x_range=(2, 11), y_max=6)
    # glowing violet eyes + brow bleed — pure, after shading
    for ex, ey in ((7, 6), (8, 6), (7, 7), (8, 7)):
        _px(head_img, ex, ey, pal["eye"])
    for ex, ey in ((11, 7), (12, 7), (11, 8), (12, 8)):
        _px(head_img, ex, ey, pal["eye"])
    _px(head_img, 7, 5, pal["brow"])
    _px(head_img, 11, 6, pal["brow"])
    parts["head"] = (head_img, (2.0, 9.0), 0.0)

    # -- jaw: lower fang wedge (opens on the lunge) ---------------------------
    def jaw(d, fill, o):
        d.polygon(_pts([(0, 1), (9, 2), (9, 4), (4, 6), (0, 4)], o), fill=fill)

    def jaw_detail(d):
        d.point((4, 2), fill=pal["fang"] + (255,))
        d.point((7, 2), fill=pal["fang"] + (255,))

    parts["jaw"] = (
        _shaded((10, 7), jaw, pal["belly"], outline=out, detail=jaw_detail),
        (1.0, 1.0), 0.0,
    )

    # -- tail: tapering whip with a barb ---------------------------------------
    def tail(d, fill, o):
        d.polygon(_pts([(15, 2), (7, 1), (2, 3), (0, 6), (4, 7), (10, 6),
                        (15, 6)], o), fill=fill)

    def tail_detail(d):
        d.point((3, 3), fill=pal["spine"] + (255,))

    parts["tail"] = (
        _shaded((16, 9), tail, pal["hide"], outline=out, detail=tail_detail),
        (14.0, 4.0), 0.0,
    )

    # -- legs: near (full ramp) and far (shadow ramp), clawed paws ------------
    def leg(d, fill, o):
        d.ellipse(_box((0, 0, 6, 6), o), fill=fill)                   # haunch
        d.polygon(_pts([(2, 4), (5, 4), (5, 9), (6, 11), (1, 11), (2, 9)], o),
                  fill=fill)

    def leg_detail(d):
        d.point((2, 10), fill=pal["claw"] + (255,))
        d.point((5, 10), fill=pal["claw"] + (255,))

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
# GLOAMFEN WISP — cyan-violet spirit orb + trailing motes (28x36 canvas)
# --------------------------------------------------------------------------


def _wisp_core(size: int, r: float, edge: Color, mid: Color, core: Color,
               pal: dict, rays: bool = False) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2.0
    if rays:
        for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0),
                       (-0.7, -0.7), (0.7, -0.7), (-0.7, 0.7), (0.7, 0.7)):
            d.line([(c, c), (c + dx * (r + 4), c + dy * (r + 4))],
                   fill=pal["flare_mid"] + (255,), width=1)
    d.ellipse((c - r, c - r * 0.94, c + r, c + r * 0.94), fill=edge + (255,))
    r2 = r * 0.68
    d.ellipse((c - r2 - 1, c - r2 - 1.4, c + r2 - 1, c + r2 - 1.4),
              fill=mid + (255,))
    r3 = r * 0.38
    d.ellipse((c - r3 - 1, c - r3 - 2, c + r3 - 1, c + r3 - 2),
              fill=core + (255,))
    # dim eye motes — a spirit "face" hollowed out of the glow
    ey = int(c) - 1
    d.rectangle((int(c) - 4, ey, int(c) - 3, ey + 1), fill=pal["eye"] + (255,))
    d.rectangle((int(c) + 2, ey, int(c) + 3, ey + 1), fill=pal["eye"] + (255,))
    # cyan glints
    _px(img, int(c) - 2, int(c) - int(r) + 1, pal["cyan"])
    _px(img, int(c) - 3, int(c) - int(r) + 2, pal["cyan_dim"])
    _px(img, int(c) + 2, int(c) + 2, pal["cyan_dim"])
    return _outline_ext(img, pal["outline"])


def build_wisp_parts() -> Dict[str, Part]:
    pal = WISP_PAL
    parts: Dict[str, Part] = {}
    # 3-cell pulse (small -> mid -> large)
    for i, r in enumerate((5.4, 6.6, 7.6)):
        img = _wisp_core(20, r, pal["edge"], pal["mid"], pal["core"], pal)
        parts[f"core_{i}"] = (img, (10.0, 10.0), 0.0)
    # 3-cell lunge flare (brighter, rays on the release cell)
    for i, r in enumerate((6.2, 7.4, 8.4)):
        img = _wisp_core(24, r, pal["flare_edge"], pal["flare_mid"],
                         pal["flare_core"], pal, rays=(i == 2))
        parts[f"flare_{i}"] = (img, (12.0, 12.0), 0.0)
    # trailing motes
    mote_a = Image.new("RGBA", (6, 6), (0, 0, 0, 0))
    da = ImageDraw.Draw(mote_a)
    da.ellipse((0, 0, 5, 5), fill=pal["edge"] + (255,))
    da.ellipse((1, 1, 4, 4), fill=pal["mote"] + (255,))
    _px(mote_a, 2, 2, pal["core"])
    parts["mote_a"] = (_outline_ext(mote_a, pal["outline"]), (3.0, 3.0), 0.0)
    mote_b = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    db = ImageDraw.Draw(mote_b)
    db.ellipse((0, 0, 4, 4), fill=pal["edge"] + (255,))
    _px(mote_b, 2, 2, pal["mote"])
    parts["mote_b"] = (_outline_ext(mote_b, pal["outline"]), (2.0, 2.0), 0.0)
    return parts


# --------------------------------------------------------------------------
# shared dragon-kin pieces (matriarch + drake)
# --------------------------------------------------------------------------


def _wing(state: str, ramp: Ramp, bone: Color, claw: Color, outline: Color,
          scale: float = 1.0) -> Tuple[Image.Image, Tuple[float, float]]:
    """One wing image per beat state; pivot at the wing root (right side).

    Wings extend LEFT of the root (creatures face right), like the
    procedural drake's. Finger bones + a bright leading-edge arm bone give
    the membrane structure; a pale wrist claw sells the silhouette.
    """
    if state == "up":
        size, root = (40, 32), (36.0, 30.0)
        poly = [(36, 30), (33, 18), (26, 9), (14, 2), (3, 1), (5, 8), (12, 11),
                (2, 14), (12, 17), (6, 22), (16, 23), (12, 28), (23, 28)]
        fingers = [(14, 2), (2, 14), (6, 22)]
        arm = [(36, 30), (26, 9)]
        wrist = (14, 3)
    elif state == "mid":
        size, root = (42, 22), (38.0, 9.0)
        poly = [(38, 9), (30, 3), (18, 1), (3, 3), (5, 9), (1, 13), (10, 13),
                (7, 18), (17, 16), (14, 21), (25, 18), (32, 15)]
        fingers = [(3, 3), (1, 13), (7, 18)]
        arm = [(38, 9), (18, 1)]
        wrist = (4, 4)
    else:  # down
        size, root = (34, 36), (30.0, 4.0)
        poly = [(30, 4), (21, 6), (11, 12), (4, 20), (2, 29), (8, 26), (7, 34),
                (13, 28), (15, 34), (19, 26), (23, 30), (25, 22), (30, 13)]
        fingers = [(2, 29), (7, 34), (15, 34)]
        arm = [(30, 4), (11, 12)]
        wrist = (4, 21)
    if scale != 1.0:
        size = (max(2, int(size[0] * scale)), max(2, int(size[1] * scale)))
        root = (root[0] * scale, root[1] * scale)
        poly = [(x * scale, y * scale) for x, y in poly]
        fingers = [(x * scale, y * scale) for x, y in fingers]
        arm = [(x * scale, y * scale) for x, y in arm]
        wrist = (wrist[0] * scale, wrist[1] * scale)

    def shape(d, fill, o):
        d.polygon(_pts(poly, o), fill=fill)

    def detail(d):
        for tip in fingers:
            d.line([root, tip], fill=ramp[0] + (255,), width=2)
        d.line([_pts([arm[0]], (0, 0))[0], arm[1]], fill=bone + (255,), width=3)

    img = _shaded(size, shape, ramp, light=(1, -1), outline=outline,
                  detail=detail, band=2)
    _px(img, int(wrist[0]), int(wrist[1]), claw)
    return img, root


def _beast_leg(size, haunch_box, shin_pts, foot_pts, claw_xs, ramp, claw,
               outline) -> Image.Image:
    def leg(d, fill, o):
        d.ellipse(_box(haunch_box, o), fill=fill)
        d.polygon(_pts(shin_pts, o), fill=fill)
        d.polygon(_pts(foot_pts, o), fill=fill)

    def leg_detail(d):
        fy = foot_pts[-1][1]
        for cx in claw_xs:
            d.polygon([(cx, fy - 3), (cx - 1, fy), (cx + 1, fy - 1)],
                      fill=claw + (255,))

    return _shaded(size, leg, ramp, outline=outline, detail=leg_detail)


def _fire_cells(fire: Ramp, sizes) -> List[Image.Image]:
    """Short flame bursts (mouth puffs) — concentric hot blobs, no outline."""
    cells = []
    for w, h in sizes:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cy = h / 2.0
        for j, col in enumerate(fire):
            frac = 1.0 - j * 0.24
            d.polygon(
                [(0, cy), (w * 0.45 * frac + 2, cy - (h / 2 - 1) * frac),
                 (w * frac - 1, cy - (h / 2 - 1) * frac * 0.3),
                 (w * frac - 1, cy + (h / 2 - 1) * frac * 0.3),
                 (w * 0.45 * frac + 2, cy + (h / 2 - 1) * frac)],
                fill=col + (255,),
            )
        cells.append(img)
    return cells


# --------------------------------------------------------------------------
# EMBERWING MATRIARCH — the great ember dragon boss (96x80 canvas)
# --------------------------------------------------------------------------


def build_matriarch_parts() -> Dict[str, Part]:
    pal = MATRIARCH_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # -- body: scaled mass, dorsal spikes, belly band, hot back rim -----------
    def body(d, fill, o):
        d.ellipse(_box((0, 7, 45, 27), o), fill=fill)
        for sx in (8, 17, 26, 34):
            d.polygon(_pts([(sx, 10), (sx + 4, 2), (sx + 8, 10)], o), fill=fill)

    def body_detail(d):
        for i, col in enumerate(pal["belly"]):
            d.ellipse((5 - i, 18 - i, 41, 26), fill=col + (255,))
        for x in range(9, 39, 6):
            d.line([(x, 22), (x + 4, 21)], fill=pal["belly"][0] + (255,), width=1)
        for sx in (8, 17, 26, 34):
            d.polygon([(sx + 2, 9), (sx + 4, 4), (sx + 6, 9)],
                      fill=pal["scale"][3] + (255,))

    body_img = _shaded((46, 28), body, pal["scale"], outline=out,
                       detail=body_detail)
    _rim(body_img, pal["rim"], x_range=(4, 42))
    # smoldering ember specks in the hide
    for x, y in ((12, 13), (22, 15), (32, 12), (18, 17)):
        _px(body_img, x, y, pal["ember"])
    _px(body_img, 22, 14, pal["ember_hot"])
    parts["body"] = (body_img, (23.0, 15.0), 0.0)

    # -- neck: vertical taper, nape spikes, belly strip ------------------------
    def neck(d, fill, o):
        d.polygon(_pts([(4, 0), (13, 0), (15, 19), (1, 19)], o), fill=fill)
        for sy in (2, 8, 14):
            d.polygon(_pts([(4, sy), (0, sy + 2), (4, sy + 5)], o), fill=fill)

    def neck_detail(d):
        d.polygon([(10, 1), (13, 1), (14, 18), (10, 18)],
                  fill=pal["belly"][1] + (255,))
        d.line([(13, 1), (14, 18)], fill=pal["belly"][0] + (255,), width=1)

    parts["neck"] = (
        _shaded((16, 20), neck, pal["scale"], outline=out, detail=neck_detail),
        (8.0, 18.0), 0.0,
    )

    # -- head: cranium + snout; swept horns live in the SILHOUETTE -------------
    horn1 = [(9, 9), (1, 1), (4, 0), (13, 7)]
    horn2 = [(13, 8), (7, 3), (10, 2), (16, 7)]

    def head(d, fill, o):
        d.polygon(_pts(horn1, o), fill=fill)                          # horns
        d.polygon(_pts(horn2, o), fill=fill)
        d.ellipse(_box((2, 7, 18, 19), o), fill=fill)                 # cranium
        d.polygon(_pts([(14, 9), (27, 11), (27, 15), (14, 18)], o), fill=fill)
        d.polygon(_pts([(5, 8), (10, 5), (13, 10)], o), fill=fill)    # brow

    def head_detail(d):
        d.polygon(horn1, fill=pal["horn"][1] + (255,))                # horn tones
        d.polygon(horn2, fill=pal["horn"][2] + (255,))
        d.line([(15, 17), (26, 14)], fill=pal["scale"][0] + (255,), width=1)
        d.point((25, 12), fill=(16, 6, 3, 255))                       # nostril

    head_img = _shaded((28, 20), head, pal["scale"], outline=out,
                       detail=head_detail)
    _rim(head_img, pal["rim"], x_range=(11, 25), y_max=11)
    _px(head_img, 10, 11, (26, 10, 4))                                # eye socket
    _px(head_img, 11, 11, pal["eye"])
    _px(head_img, 12, 11, pal["eye"])
    _px(head_img, 11, 12, pal["eye"])
    _px(head_img, 11, 10, (232, 150, 70))                             # brow bleed
    parts["head"] = (head_img, (6.0, 13.0), 0.0)

    # -- jaw: lower wedge with pale teeth --------------------------------------
    def jaw(d, fill, o):
        d.polygon(_pts([(0, 1), (15, 2), (15, 5), (5, 7), (0, 5)], o), fill=fill)

    def jaw_detail(d):
        for x in (5, 9, 12):
            d.polygon([(x, 2), (x + 1, 4), (x + 2, 2)],
                      fill=pal["horn"][2] + (255,))

    parts["jaw"] = (
        _shaded((16, 8), jaw, pal["belly"], outline=out, detail=jaw_detail),
        (2.0, 2.0), 0.0,
    )

    # -- tail: two tapering segments, arrow fin on the tip ----------------------
    def tail1(d, fill, o):
        d.polygon(_pts([(21, 1), (4, 3), (0, 6), (4, 9), (21, 11)], o), fill=fill)
        d.polygon(_pts([(8, 3), (11, 0), (14, 3)], o), fill=fill)

    parts["tail_1"] = (
        _shaded((22, 12), tail1, pal["scale"], outline=out), (20.0, 6.0), 0.0)

    def tail2(d, fill, o):
        d.polygon(_pts([(11, 3), (5, 4), (3, 5), (5, 7), (11, 8)], o), fill=fill)
        d.polygon(_pts([(5, 0), (0, 5), (5, 10), (3, 5)], o), fill=fill)  # fin

    tail2_img = _shaded((12, 11), tail2, pal["scale"], outline=out)
    _px(tail2_img, 1, 4, pal["rim"])                                  # lit fin edge
    parts["tail_2"] = (tail2_img, (11.0, 5.0), 0.0)

    # -- wings: 3 beat states x near/far ---------------------------------------
    for state in ("up", "mid", "down"):
        img, root = _wing(state, pal["membrane"], pal["bone_edge"],
                          pal["horn"][2], out, scale=1.1)
        parts[f"wing_near_{state}"] = (img, root, 0.0)
        img_f, root_f = _wing(state, pal["membrane_far"], pal["membrane_far"][2],
                              pal["horn"][1], out, scale=0.85)
        parts[f"wing_far_{state}"] = (img_f, root_f, 0.0)

    # -- legs: near pair full ramp, far pair shadow ramp ------------------------
    parts["leg_front"] = (
        _beast_leg((13, 22), (1, 0, 11, 11), [(4, 8), (9, 8), (8, 17), (5, 17)],
                   [(2, 16), (10, 16), (11, 21), (1, 21)], (3, 6, 9),
                   pal["scale"], pal["horn"][2], out),
        (6.0, 3.0), 0.0,
    )
    parts["leg_back"] = (
        _beast_leg((15, 23), (0, 0, 13, 13), [(5, 9), (11, 9), (9, 18), (5, 18)],
                   [(2, 17), (11, 17), (13, 22), (1, 22)], (3, 7, 11),
                   pal["scale"], pal["horn"][2], out),
        (7.0, 3.0), 0.0,
    )
    parts["leg_far"] = (
        _beast_leg((12, 20), (1, 0, 10, 10), [(4, 7), (8, 7), (7, 15), (4, 15)],
                   [(2, 14), (9, 14), (10, 19), (1, 19)], (3, 6, 8),
                   pal["membrane_far"], pal["horn"][1], out),
        (5.0, 3.0), 0.0,
    )

    # -- VFX: fire burst at the mouth, 3 cells ----------------------------------
    for i, cell in enumerate(_fire_cells(pal["fire"], ((10, 8), (13, 10), (16, 12)))):
        parts[f"vfx_breath_{i}"] = (cell, (1.0, cell.height / 2.0), 0.0)

    return parts


# --------------------------------------------------------------------------
# EMBER DRAKE — rideable ember mount with a FIXED saddle (112x88 canvas)
# --------------------------------------------------------------------------


def build_drake_parts() -> Dict[str, Part]:
    pal = DRAKE_PAL
    out = pal["outline"]
    parts: Dict[str, Part] = {}

    # -- body: barrel + chest + haunch; dorsal spines bracket the saddle -------
    def body(d, fill, o):
        d.ellipse(_box((0, 6, 51, 33), o), fill=fill)                 # barrel
        d.ellipse(_box((44, 8, 63, 32), o), fill=fill)                # chest
        d.ellipse(_box((0, 4, 21, 26), o), fill=fill)                 # haunch
        d.polygon(_pts([(4, 8), (7, 2), (10, 8)], o), fill=fill)      # spines
        d.polygon(_pts([(50, 8), (53, 3), (56, 9)], o), fill=fill)

    def body_detail(d):
        for i, col in enumerate(pal["belly"]):
            d.ellipse((6 - i, 22 - i, 58, 32), fill=col + (255,))
        for x in range(10, 56, 7):
            d.line([(x, 28), (x + 5, 27)], fill=pal["belly"][0] + (255,), width=1)
        d.ellipse((3, 8, 17, 20), fill=pal["scale"][2] + (255,))      # haunch core
        d.ellipse((5, 9, 13, 15), fill=pal["scale"][3] + (255,))

    body_img = _shaded((64, 34), body, pal["scale"], outline=out,
                       detail=body_detail)
    _rim(body_img, pal["rim"], x_range=(2, 60))
    for x, y in ((14, 12), (30, 13), (46, 14), (24, 17)):
        _px(body_img, x, y, pal["ember"])
    _px(body_img, 30, 12, pal["ember_hot"])
    parts["body"] = (body_img, (32.0, 17.0), 0.0)

    # -- saddle: rim + pad + cantle/pommel + teal blanket + girth strap --------
    saddle = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(saddle)
    d.rectangle((2, 2, 21, 6), fill=pal["leather"] + (255,))          # pad
    d.line([(2, 2), (21, 2)], fill=pal["leather_hi"] + (255,), width=1)
    d.rectangle((0, 0, 2, 6), fill=pal["leather"] + (255,))           # cantle
    d.point((1, 0), fill=pal["leather_hi"] + (255,))
    d.rectangle((21, 0, 23, 6), fill=pal["leather"] + (255,))         # pommel
    d.point((22, 0), fill=pal["leather_hi"] + (255,))
    d.rectangle((1, 7, 22, 8), fill=pal["blanket"] + (255,))          # blanket
    d.line([(1, 7), (22, 7)], fill=pal["blanket_hi"] + (255,), width=1)
    d.rectangle((11, 9, 12, 29), fill=pal["leather"] + (255,))        # girth strap
    d.point((11, 28), fill=pal["buckle"] + (255,))                    # buckle glint
    saddle = _outline_ext(saddle, out)
    parts["saddle"] = (saddle, (12.0, 2.0), 0.0)

    # -- neck: rises in front of the saddle -------------------------------------
    def neck(d, fill, o):
        d.polygon(_pts([(3, 0), (13, 0), (15, 23), (0, 23)], o), fill=fill)
        for sy in (3, 10, 17):
            d.polygon(_pts([(3, sy), (0, sy + 2), (3, sy + 5)], o), fill=fill)

    def neck_detail(d):
        d.polygon([(10, 1), (13, 1), (14, 22), (10, 22)],
                  fill=pal["belly"][2] + (255,))
        d.line([(13, 1), (14, 22)], fill=pal["belly"][0] + (255,), width=1)

    neck_img = _shaded((16, 24), neck, pal["scale"], outline=out,
                       detail=neck_detail)
    _px(neck_img, 12, 14, pal["ember"])                               # throat ember
    parts["neck"] = (neck_img, (8.0, 22.0), 0.0)

    # -- head: long horned skull, heavy brow, closed jaw with fangs ------------
    def head(d, fill, o):
        d.polygon(_pts([(4, 4), (16, 3), (18, 7), (33, 10), (33, 14),
                        (18, 16), (5, 15)], o), fill=fill)
        d.polygon(_pts([(6, 5), (10, 2), (13, 6)], o), fill=fill)     # brow

    def head_detail(d):
        # swept-back horns
        d.polygon([(8, 5), (1, -1), (4, -2), (12, 3)], fill=pal["horn"][1] + (255,))
        d.polygon([(12, 4), (7, 0), (9, -1), (15, 3)], fill=pal["horn"][2] + (255,))
        d.line([(9, 3), (16, 4)], fill=pal["rim"] + (255,), width=1)  # brow ridge
        d.line([(17, 14), (32, 12)], fill=pal["scale"][0] + (255,), width=1)  # mouth
        d.point((24, 13), fill=pal["horn"][2] + (255,))               # fangs
        d.point((29, 12), fill=pal["horn"][2] + (255,))
        d.point((31, 11), fill=(20, 8, 3, 255))                       # nostril

    head_img = _shaded((34, 20), head, pal["scale"], outline=out,
                       detail=head_detail)
    _px(head_img, 12, 7, (26, 10, 4))                                 # eye socket
    _px(head_img, 13, 7, pal["eye"])
    _px(head_img, 14, 7, pal["eye"])
    _px(head_img, 13, 6, (232, 150, 70))                              # brow bleed
    _px(head_img, 27, 13, pal["ember"])                               # jaw smolder
    parts["head"] = (head_img, (6.0, 11.0), 0.0)

    # -- tail: two segments, spade tip ------------------------------------------
    def tail1(d, fill, o):
        d.polygon(_pts([(17, 1), (4, 3), (0, 6), (4, 9), (17, 11)], o), fill=fill)
        d.polygon(_pts([(7, 3), (10, 0), (13, 3)], o), fill=fill)     # ridge spike

    parts["tail_1"] = (
        _shaded((18, 12), tail1, pal["scale"], outline=out), (16.0, 6.0), 0.0)

    def tail2(d, fill, o):
        d.polygon(_pts([(13, 3), (6, 4), (4, 5), (6, 7), (13, 8)], o), fill=fill)
        d.polygon(_pts([(5, 0), (0, 5), (5, 10), (3, 5)], o), fill=fill)  # spade

    tail2_img = _shaded((14, 11), tail2, pal["scale"], outline=out)
    _px(tail2_img, 1, 4, pal["rim"])                                  # lit spade
    parts["tail_2"] = (tail2_img, (13.0, 5.0), 0.0)

    # -- wings: 3 beat states x near/far (rooted behind the cantle) -------------
    for state in ("up", "mid", "down"):
        img, root = _wing(state, pal["membrane"], pal["bone_edge"],
                          pal["horn"][2], out, scale=1.1)
        parts[f"wing_near_{state}"] = (img, root, 0.0)
        img_f, root_f = _wing(state, pal["membrane_far"], pal["membrane_far"][2],
                              pal["horn"][1], out, scale=0.9)
        parts[f"wing_far_{state}"] = (img_f, root_f, 0.0)

    # -- legs ---------------------------------------------------------------------
    parts["leg_front"] = (
        _beast_leg((12, 24), (1, 0, 10, 10), [(4, 7), (8, 7), (8, 19), (4, 19)],
                   [(1, 18), (9, 18), (10, 23), (1, 23)], (3, 6, 8),
                   pal["scale"], pal["horn"][2], out),
        (5.0, 3.0), 0.0,
    )
    parts["leg_back"] = (
        _beast_leg((14, 24), (0, 0, 12, 12), [(5, 8), (10, 8), (9, 19), (5, 19)],
                   [(2, 18), (11, 18), (12, 23), (1, 23)], (3, 7, 10),
                   pal["scale"], pal["horn"][2], out),
        (6.0, 3.0), 0.0,
    )
    parts["leg_far"] = (
        _beast_leg((11, 21), (1, 0, 9, 9), [(3, 6), (7, 6), (7, 16), (3, 16)],
                   [(1, 15), (8, 15), (9, 20), (1, 20)], (3, 6, 8),
                   pal["membrane_far"], pal["horn"][1], out),
        (5.0, 3.0), 0.0,
    )

    return parts


# --------------------------------------------------------------------------
# registry: actor -> (schema archetype, builder)
# --------------------------------------------------------------------------

ACTOR_BUILDERS: Dict[str, Tuple[str, Callable[[], Dict[str, Part]]]] = {
    "hero": ("humanoid", build_hero_parts),
    "gloamfen_stalker": ("quadruped", build_stalker_parts),
    "gloamfen_wisp": ("spirit", build_wisp_parts),
    "emberwing_matriarch": ("dragon", build_matriarch_parts),
    "ember_drake": ("dragon", build_drake_parts),
}
