"""Procedural parts-sheet provider — runs the whole pipeline with zero API calls.

This module defines the provider interface (``PartsProvider``) that the real
image model will implement, plus ``StubPartsProvider``, a Pillow-drawn first
implementation that produces decent-quality parts sheets today:

  * humanoid — a hooded mage in dark violet + gold (the approved concept vibe)
  * dragon   — a red dragon: shaded body masses, membrane wings, fire VFX strip

WHERE THE REAL IMAGE MODEL PLUGS IN
-----------------------------------
``PartsProvider.generate_parts(request, out_dir)`` is the single seam. A real
provider (style-locked model fine-tuned on our approved art, per
docs/design/17 §5) generates ONE parts-sheet image per entity from the
composed lore/season/sprite-brief prompt, then either (a) emits region
metadata itself by generating onto a fixed template layout, or (b) runs a
segmentation pass to produce the same ``parts.json``. Everything downstream —
skeletons, pose libraries, the baker, the atlas contract — is identical for
stub and real providers; swapping providers is config plus a provenance
version bump (docs/tech/28 §9).

Drawing approach (stub): every part is a silhouette shape filled with a
banded-shading ramp (dark base, mid and light bands offset toward the light),
clipped details (trim, eyes, claws, wing fingers), and a 1px inner outline
computed by mask erosion. Fully deterministic — same request, same pixels.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, List, Optional, Protocol, Tuple

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from .actor_art import ACTOR_BUILDERS
from .manifest import PartRegion, PartsManifest

Color = Tuple[int, int, int]
Ramp = List[Color]
Offset = Tuple[int, int]
ShapeFn = Callable[[ImageDraw.ImageDraw, object, Offset], None]

# --------------------------------------------------------------------------
# provider interface
# --------------------------------------------------------------------------


@dataclass
class GenerationRequest:
    """What the service asks a provider for (one entity -> one parts sheet)."""

    archetype: str                                # 'humanoid' | 'dragon' (v0)
    family: str = "unnamed"
    tier: str = "normal"
    palette_hints: List[str] = field(default_factory=list)
    theme_tags: List[str] = field(default_factory=list)
    entity: Optional[str] = None                  # slug; derived when None

    def entity_slug(self) -> str:
        if self.entity:
            return self.entity
        base = f"{self.family}_{self.archetype}".lower()
        return "".join(c if c.isalnum() or c == "_" else "_" for c in base)


@dataclass
class PartsBundle:
    """A provider's output: the sheet PNG + its manifest, on disk."""

    sheet_path: Path
    manifest_path: Path
    manifest: PartsManifest


class PartsProvider(Protocol):
    """The seam a real image model implements. See module docstring."""

    name: str
    version: str

    def generate_parts(self, request: GenerationRequest, out_dir: Path) -> PartsBundle:
        ...


# --------------------------------------------------------------------------
# drawing helpers
# --------------------------------------------------------------------------


def _pts(points: List[Tuple[float, float]], off: Offset) -> List[Tuple[float, float]]:
    return [(x + off[0], y + off[1]) for x, y in points]


def _box(b: Tuple[float, float, float, float], off: Offset):
    return (b[0] + off[0], b[1] + off[1], b[2] + off[0], b[3] + off[1])


def _shaded(
    size: Tuple[int, int],
    shape_fn: ShapeFn,
    ramp: Ramp,
    light: Tuple[int, int] = (-1, -1),
    outline: Optional[Color] = None,
    detail: Optional[Callable[[ImageDraw.ImageDraw], None]] = None,
) -> Image.Image:
    """Banded-shading fill of a silhouette + clipped detail + 1px inner outline."""
    mask = Image.new("L", size, 0)
    shape_fn(ImageDraw.Draw(mask), 255, (0, 0))

    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, col in enumerate(ramp):
        shape_fn(d, tuple(col) + (255,), (light[0] * 2 * i, light[1] * 2 * i))

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


def _blit(canvas: Image.Image, img: Image.Image, xy: Tuple[int, int]) -> None:
    canvas.alpha_composite(img, dest=xy)


# --------------------------------------------------------------------------
# palettes
# --------------------------------------------------------------------------

HUMANOID_PALETTES: Dict[str, dict] = {
    "violet_gold": {
        "robe": [(24, 14, 36), (52, 30, 78), (86, 52, 122), (126, 86, 168)],
        "cloth_dark": [(14, 8, 24), (34, 19, 54), (58, 34, 92)],
        "trim": [(122, 82, 20), (198, 146, 44), (255, 210, 88)],
        "glow": (255, 236, 150),
        "wood": [(40, 26, 18), (72, 48, 30), (108, 76, 46)],
        "outline": (10, 6, 16),
    },
    "ember": {
        "robe": [(40, 12, 10), (84, 28, 16), (136, 52, 22), (190, 92, 36)],
        "cloth_dark": [(26, 8, 6), (56, 18, 10), (92, 34, 16)],
        "trim": [(122, 82, 20), (198, 146, 44), (255, 210, 88)],
        "glow": (255, 220, 120),
        "wood": [(40, 26, 18), (72, 48, 30), (108, 76, 46)],
        "outline": (16, 5, 4),
    },
    "frost": {
        "robe": [(14, 26, 44), (30, 56, 88), (56, 94, 134), (96, 140, 180)],
        "cloth_dark": [(8, 16, 30), (18, 36, 60), (34, 62, 94)],
        "trim": [(110, 120, 134), (170, 182, 196), (232, 240, 250)],
        "glow": (200, 240, 255),
        "wood": [(36, 34, 44), (64, 62, 78), (96, 96, 114)],
        "outline": (5, 10, 20),
    },
}

DRAGON_PALETTES: Dict[str, dict] = {
    "red": {
        "scale": [(52, 10, 14), (108, 22, 24), (168, 42, 32), (219, 84, 48)],
        "belly": [(120, 84, 50), (178, 132, 80), (224, 178, 116)],
        "membrane": [(70, 12, 26), (120, 26, 40), (170, 48, 56)],
        "membrane_far": [(46, 8, 18), (82, 18, 28), (118, 32, 40)],
        "horn": [(110, 100, 86), (178, 168, 144), (230, 222, 196)],
        "eye": (255, 206, 64),
        "fire": [(196, 44, 14), (242, 120, 26), (255, 196, 64), (255, 244, 180)],
        "outline": (24, 5, 9),
    },
    "umbral": {
        "scale": [(24, 14, 40), (52, 30, 84), (88, 54, 132), (132, 92, 182)],
        "belly": [(64, 54, 96), (104, 90, 140), (150, 134, 186)],
        "membrane": [(36, 18, 58), (70, 38, 102), (108, 66, 146)],
        "membrane_far": [(24, 12, 40), (46, 24, 68), (72, 42, 100)],
        "horn": [(110, 100, 86), (178, 168, 144), (230, 222, 196)],
        "eye": (120, 255, 220),
        "fire": [(90, 30, 150), (150, 70, 210), (210, 140, 255), (245, 220, 255)],
        "outline": (10, 5, 20),
    },
    "frost": {
        "scale": [(14, 30, 48), (28, 62, 94), (52, 100, 140), (92, 148, 188)],
        "belly": [(120, 140, 158), (170, 190, 206), (218, 236, 248)],
        "membrane": [(20, 44, 70), (38, 78, 114), (64, 116, 158)],
        "membrane_far": [(12, 28, 46), (24, 52, 78), (42, 82, 114)],
        "horn": [(140, 150, 160), (196, 208, 218), (240, 248, 255)],
        "eye": (180, 240, 255),
        "fire": [(60, 130, 200), (110, 190, 240), (180, 230, 255), (240, 252, 255)],
        "outline": (4, 12, 22),
    },
}

_PALETTE_KEYWORDS = {
    "ember": "ember", "fire": "ember", "red": "red", "crimson": "red",
    "blood": "red", "frost": "frost", "ice": "frost", "pale": "frost",
    "umbral": "umbral", "violet": "umbral", "gloam": "umbral",
    "gold": "violet_gold",
}


def _pick_palette(archetype: str, hints: List[str]) -> Tuple[str, dict]:
    table = HUMANOID_PALETTES if archetype == "humanoid" else DRAGON_PALETTES
    default = "violet_gold" if archetype == "humanoid" else "red"
    for hint in hints:
        for token in hint.lower().replace("-", "_").split("_"):
            name = _PALETTE_KEYWORDS.get(token)
            if name and name in table:
                return name, table[name]
    return default, table[default]


# --------------------------------------------------------------------------
# humanoid (hooded mage) parts
# --------------------------------------------------------------------------

Part = Tuple[Image.Image, Tuple[float, float], float]  # image, pivot, angle_hint


def build_humanoid_parts(pal: dict) -> Dict[str, Part]:
    outline = pal["outline"]
    trim = pal["trim"]
    glow = pal["glow"]
    parts: Dict[str, Part] = {}

    # -- head: pointed hood, shadowed face, glowing eyes ----------------------
    def hood(d, fill, o):
        d.polygon(_pts([(13, 0), (18, 6), (22, 14), (24, 27), (13, 29),
                        (2, 27), (4, 14), (8, 6)], o), fill=fill)

    def hood_detail(d):
        # shadowed face opening
        d.polygon([(8, 14), (18, 14), (19, 25), (13, 27), (7, 25)],
                  fill=(8, 5, 14, 255))
        # glowing eyes
        d.rectangle((9, 18, 11, 19), fill=glow + (255,))
        d.rectangle((15, 18, 17, 19), fill=glow + (255,))
        # gold rim of the hood opening
        d.line([(7, 13), (13, 12), (19, 13)], fill=trim[2] + (255,), width=1)
        d.line([(6, 14), (7, 22)], fill=trim[1] + (255,), width=1)
        d.line([(20, 14), (19, 22)], fill=trim[1] + (255,), width=1)

    parts["head"] = (
        _shaded((26, 30), hood, pal["robe"], outline=outline, detail=hood_detail),
        (13.0, 28.0), 0.0,
    )

    # -- torso: robe with belt + center trim ---------------------------------
    def robe(d, fill, o):
        d.polygon(_pts([(9, 1), (19, 1), (23, 9), (24, 34), (14, 35),
                        (4, 34), (5, 9)], o), fill=fill)

    def robe_detail(d):
        d.line([(14, 2), (14, 34)], fill=trim[1] + (255,), width=1)
        d.rectangle((5, 18, 23, 20), fill=trim[0] + (255,))
        d.rectangle((12, 17, 16, 21), fill=trim[2] + (255,))  # buckle
        d.line([(9, 2), (9, 16)], fill=trim[0] + (255,), width=1)
        d.line([(19, 2), (19, 16)], fill=trim[0] + (255,), width=1)

    parts["torso"] = (
        _shaded((28, 36), robe, pal["robe"], outline=outline, detail=robe_detail),
        (14.0, 18.0), 0.0,
    )

    # -- leg: robe skirt + boot (shared by both leg bones) --------------------
    def leg(d, fill, o):
        d.polygon(_pts([(3, 0), (10, 0), (11, 16), (12, 21), (11, 25),
                        (2, 25), (2, 21), (3, 16)], o), fill=fill)

    def leg_detail(d):
        d.polygon([(2, 19), (12, 19), (12, 25), (2, 25)], fill=(16, 10, 26, 255))
        d.line([(3, 19), (11, 19)], fill=trim[0] + (255,), width=1)

    parts["leg"] = (
        _shaded((13, 26), leg, pal["cloth_dark"], outline=outline, detail=leg_detail),
        (6.0, 2.0), 0.0,
    )

    # -- arms: sleeve segments (shared left/right) ----------------------------
    def arm_up(d, fill, o):
        d.polygon(_pts([(2, 0), (8, 0), (10, 17), (1, 17)], o), fill=fill)

    parts["arm_upper"] = (
        _shaded((11, 19), arm_up, pal["robe"], outline=outline),
        (5.0, 2.0), 0.0,
    )

    def arm_fore(d, fill, o):
        d.polygon(_pts([(2, 0), (8, 0), (9, 10), (8, 13), (2, 13)], o), fill=fill)

    def fore_detail(d):
        d.line([(2, 3), (8, 3)], fill=trim[1] + (255,), width=1)  # cuff
        d.ellipse((3, 12, 8, 17), fill=(28, 18, 44, 255))          # gloved hand

    parts["arm_fore"] = (
        _shaded((10, 18), arm_fore, pal["robe"], outline=outline, detail=fore_detail),
        (5.0, 2.0), 0.0,
    )

    # -- cape: flowing, ragged hem --------------------------------------------
    def cape(d, fill, o):
        d.polygon(_pts([(6, 1), (28, 1), (32, 18), (30, 34), (28, 44),
                        (23, 38), (18, 44), (12, 39), (7, 44), (3, 30),
                        (2, 16)], o), fill=fill)

    def cape_detail(d):
        d.line([(6, 2), (28, 2)], fill=trim[0] + (255,), width=1)

    parts["cape"] = (
        _shaded((34, 46), cape, pal["cloth_dark"], light=(1, -1),
                outline=outline, detail=cape_detail),
        (17.0, 3.0), 0.0,
    )

    # -- weapon: staff with gold orb ------------------------------------------
    staff = Image.new("RGBA", (12, 60), (0, 0, 0, 0))

    def rod(d, fill, o):
        d.polygon(_pts([(5, 12), (7, 12), (8, 58), (4, 58)], o), fill=fill)

    _blit(staff, _shaded((12, 60), rod, pal["wood"], outline=outline), (0, 0))

    def orb(d, fill, o):
        d.ellipse(_box((2, 1, 10, 11), o), fill=fill)

    def orb_detail(d):
        d.rectangle((4, 3, 5, 4), fill=(255, 255, 255, 255))

    orb_img = _shaded((12, 14), orb, [pal["trim"][0], pal["trim"][1],
                                      pal["trim"][2], glow],
                      outline=outline, detail=orb_detail)
    # claw band holding the orb
    band = Image.new("RGBA", (12, 60), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    bd.rectangle((4, 11, 8, 14), fill=pal["trim"][1] + (255,))
    _blit(staff, band, (0, 0))
    _blit(staff, orb_img, (0, 0))
    parts["weapon"] = (staff, (6.0, 38.0), 0.0)

    # -- VFX strip: cast glow, 3 cells ----------------------------------------
    for i, r in enumerate((3, 6, 8)):
        size = (28, 28)
        cell = Image.new("RGBA", size, (0, 0, 0, 0))
        d = ImageDraw.Draw(cell)
        cx, cy = 14, 14
        if i == 2:  # rays on the release cell
            for dx, dy in ((0, -13), (0, 13), (-13, 0), (13, 0),
                           (-9, -9), (9, -9), (-9, 9), (9, 9)):
                d.line([(cx, cy), (cx + dx, cy + dy)],
                       fill=pal["trim"][2] + (255,), width=1)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=pal["trim"][1] + (255,))
        r2 = max(1, r - 3)
        d.ellipse((cx - r2, cy - r2, cx + r2, cy + r2), fill=glow + (255,))
        parts[f"vfx_cast_{i}"] = (cell, (14.0, 14.0), 0.0)

    return parts


# --------------------------------------------------------------------------
# dragon parts
# --------------------------------------------------------------------------


def build_dragon_parts(pal: dict) -> Dict[str, Part]:
    outline = pal["outline"]
    horn = pal["horn"]
    parts: Dict[str, Part] = {}

    # -- body: big scaled mass, dorsal spikes, belly band ----------------------
    def body(d, fill, o):
        d.ellipse(_box((1, 9, 77, 47), o), fill=fill)
        for sx in (16, 28, 40, 52):  # dorsal spikes
            d.polygon(_pts([(sx, 12), (sx + 6, 2), (sx + 11, 12)], o), fill=fill)

    def body_detail(d):
        # belly band along the lower edge
        for i, col in enumerate(pal["belly"]):
            d.ellipse((8 - 2 * i, 30 - 2 * i, 70, 46), fill=col + (255,))
        for x in range(14, 64, 8):  # belly plate lines
            d.line([(x, 38), (x + 6, 36)], fill=pal["belly"][0] + (255,), width=1)
        # spike shading
        for sx in (16, 28, 40, 52):
            d.polygon([(sx + 3, 10), (sx + 6, 4), (sx + 8, 10)],
                      fill=pal["scale"][3] + (255,))

    parts["body"] = (
        _shaded((78, 48), body, pal["scale"], outline=outline, detail=body_detail),
        (39.0, 24.0), 0.0,
    )

    # -- neck: drawn vertical; skeleton default rotation leans it forward -----
    def neck(d, fill, o):
        d.polygon(_pts([(7, 1), (19, 1), (23, 31), (2, 31)], o), fill=fill)
        for sy in (4, 12, 20):  # nape spikes on the back (left) edge
            d.polygon(_pts([(7, sy), (0, sy + 3), (7, sy + 7)], o), fill=fill)

    def neck_detail(d):
        for i, col in enumerate(pal["belly"][:2]):
            d.polygon([(15 - i, 2), (19 - i, 2), (22 - i, 30), (16 - i, 30)],
                      fill=col + (255,))

    parts["neck"] = (
        _shaded((26, 34), neck, pal["scale"], outline=outline, detail=neck_detail),
        (13.0, 31.0), 0.0,
    )

    # -- head: facing right, brow, horns, glowing eye ---------------------------
    def head(d, fill, o):
        d.ellipse(_box((2, 5, 26, 25), o), fill=fill)                # cranium
        d.polygon(_pts([(18, 8), (37, 12), (38, 16), (18, 19)], o), fill=fill)  # snout
        d.polygon(_pts([(6, 8), (12, 5), (14, 10)], o), fill=fill)   # brow

    def head_detail(d):
        # horns swept back
        d.polygon([(8, 8), (0, 1), (3, 0), (12, 6)], fill=horn[1] + (255,))
        d.polygon([(12, 7), (6, 2), (8, 1), (15, 6)], fill=horn[2] + (255,))
        # eye
        d.ellipse((14, 10, 19, 14), fill=pal["eye"] + (255,))
        d.line([(16, 11), (17, 14)], fill=(10, 4, 4, 255), width=1)
        # nostril + mouth line
        d.rectangle((33, 13, 34, 14), fill=(10, 4, 4, 255))
        d.line([(20, 18), (36, 15)], fill=pal["scale"][0] + (255,), width=1)

    parts["head"] = (
        _shaded((40, 26), head, pal["scale"], outline=outline, detail=head_detail),
        (8.0, 16.0), 0.0,
    )

    # -- jaw: lower wedge with teeth -------------------------------------------
    def jaw(d, fill, o):
        d.polygon(_pts([(1, 1), (24, 3), (24, 7), (8, 10), (1, 8)], o), fill=fill)

    def jaw_detail(d):
        for x in (8, 13, 18):  # teeth along the top edge
            d.polygon([(x, 2), (x + 2, 5), (x + 4, 2)], fill=horn[2] + (255,))

    parts["jaw"] = (
        _shaded((26, 12), jaw, pal["belly"], outline=outline, detail=jaw_detail),
        (3.0, 3.0), 0.0,
    )

    # -- wings: membrane fan + finger bones; near and far variants -------------
    def wing_shape(scale: float):
        pts = [(9, 38), (8, 20), (16, 4), (24, 12), (38, 2), (44, 15),
               (58, 12), (54, 26), (46, 32), (30, 38)]
        return [(x * scale, y * scale) for x, y in pts]

    def make_wing(size, ramp, scale):
        shape_pts = wing_shape(scale)

        def wing(d, fill, o):
            d.polygon(_pts(shape_pts, o), fill=fill)

        def wing_detail(d):
            root = (9 * scale, 38 * scale)
            for tip in ((16, 4), (38, 2), (58, 12)):
                d.line([root, (tip[0] * scale, tip[1] * scale)],
                       fill=ramp[0] + (255,), width=2)
            d.line([root, (18 * scale, 6 * scale)],
                   fill=pal["scale"][1] + (255,), width=3)  # arm bone

        return _shaded(size, wing, ramp, light=(1, -1),
                       outline=outline, detail=wing_detail)

    parts["wing_near"] = (make_wing((64, 42), pal["membrane"], 1.05), (9.0, 38.0), 0.0)
    parts["wing_far"] = (make_wing((58, 38), pal["membrane_far"], 0.95), (8.6, 36.1), 0.0)

    # -- legs: haunch + shin + clawed foot --------------------------------------
    def make_leg(size, haunch_box, shin_pts, foot_pts, claw_xs):
        def leg(d, fill, o):
            d.ellipse(_box(haunch_box, o), fill=fill)
            d.polygon(_pts(shin_pts, o), fill=fill)
            d.polygon(_pts(foot_pts, o), fill=fill)

        def leg_detail(d):
            fy = foot_pts[-1][1]
            for cx in claw_xs:
                d.polygon([(cx, fy - 3), (cx - 2, fy + 1), (cx + 2, fy - 1)],
                          fill=horn[2] + (255,))

        return _shaded(size, leg, pal["scale"], outline=outline, detail=leg_detail)

    parts["leg_front"] = (
        make_leg((18, 36), (2, 1, 16, 17),
                 [(7, 12), (13, 12), (12, 29), (8, 29)],
                 [(3, 28), (15, 28), (16, 34), (2, 34)], (4, 9, 14)),
        (9.0, 4.0), 0.0,
    )
    parts["leg_back"] = (
        make_leg((22, 38), (1, 1, 21, 21),
                 [(9, 15), (16, 15), (14, 31), (9, 31)],
                 [(4, 30), (17, 30), (19, 36), (3, 36)], (5, 11, 16)),
        (11.0, 4.0), 0.0,
    )

    # -- tail: two tapering segments, arrow fin on the tip ----------------------
    def tail1(d, fill, o):
        d.polygon(_pts([(33, 1), (3, 6), (1, 10), (3, 13), (33, 17)], o), fill=fill)
        for sx in (10, 20):
            d.polygon(_pts([(sx, 5), (sx + 4, 0), (sx + 8, 4)], o), fill=fill)

    parts["tail_1"] = (
        _shaded((34, 18), tail1, pal["scale"], outline=outline),
        (31.0, 9.0), 0.0,
    )

    def tail2(d, fill, o):
        d.polygon(_pts([(29, 3), (7, 5), (5, 7), (7, 9), (29, 11)], o), fill=fill)
        d.polygon(_pts([(9, 0), (0, 7), (9, 13), (5, 7)], o), fill=fill)  # fin

    parts["tail_2"] = (
        _shaded((30, 14), tail2, pal["scale"], outline=outline),
        (27.0, 7.0), 0.0,
    )

    # -- VFX strip: fire-breath cone, 3 cells (small puff -> full cone) ---------
    fire = pal["fire"]
    for i, (w, h) in enumerate(((22, 18), (30, 24), (40, 30))):
        cell = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(cell)
        cy = h // 2
        spread = h // 2 - 1
        for j, col in enumerate(fire):
            frac = 1.0 - j * 0.22
            d.polygon(
                [(1, cy), (w * 0.55 * frac + 4, cy - spread * frac),
                 (w * frac - 1, cy - spread * frac * 0.25),
                 (w * frac - 1, cy + spread * frac * 0.25),
                 (w * 0.55 * frac + 4, cy + spread * frac)],
                fill=col + (255,),
            )
        parts[f"vfx_breath_{i}"] = (cell, (2.0, float(cy)), 0.0)

    return parts


# --------------------------------------------------------------------------
# sheet packing
# --------------------------------------------------------------------------


def pack_parts(
    parts: Dict[str, Part], max_width: int = 512, pad: int = 3
) -> Tuple[Image.Image, Dict[str, PartRegion]]:
    """Greedy row packer: parts left->right, wrapping at ``max_width``."""
    regions: Dict[str, PartRegion] = {}
    placements: List[Tuple[str, int, int]] = []
    x, y, row_h = pad, pad, 0
    sheet_w = 0
    for name, (img, _pivot, _hint) in parts.items():
        if x + img.width + pad > max_width and x > pad:
            x, y = pad, y + row_h + pad
            row_h = 0
        placements.append((name, x, y))
        row_h = max(row_h, img.height)
        x += img.width + pad
        sheet_w = max(sheet_w, x)
    sheet_h = y + row_h + pad

    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
    for name, px, py in placements:
        img, pivot, hint = parts[name]
        _blit(sheet, img, (px, py))
        regions[name] = PartRegion(
            rect=(px, py, img.width, img.height), pivot=pivot, angle_hint=hint
        )
    return sheet, regions


# --------------------------------------------------------------------------
# the stub provider
# --------------------------------------------------------------------------


class StubPartsProvider:
    """Procedural Pillow-drawn parts sheets. First PartsProvider implementation.

    Two tiers of art:
      * generic archetype builders (humanoid mage / dragon) — palette-hinted
      * hand-authored HIGH-FIDELITY actor builders (actor_art.py) — the five
        style anchors (hero, gloamfen_stalker, gloamfen_wisp,
        emberwing_matriarch, ember_drake), requested by actor name
    """

    name = "stub_procedural"
    version = "0.2.0"

    BUILDERS = {
        "humanoid": (build_humanoid_parts, lambda h: _pick_palette("humanoid", h)),
        "dragon": (build_dragon_parts, lambda h: _pick_palette("dragon", h)),
    }

    def generate_parts(self, request: GenerationRequest, out_dir: Path) -> PartsBundle:
        schema_archetype = request.archetype
        if request.archetype in ACTOR_BUILDERS:
            # hand-authored actor: fixed style-anchor palette, no hints
            schema_archetype, actor_builder = ACTOR_BUILDERS[request.archetype]
            parts = actor_builder()
            palette_name = f"{request.archetype}_anchor"
            if request.entity is None:
                request.entity = request.archetype
        elif request.archetype in self.BUILDERS:
            builder, pick = self.BUILDERS[request.archetype]
            palette_name, palette = pick(request.palette_hints)
            parts = builder(palette)
        else:
            raise ValueError(
                f"stub provider supports archetypes "
                f"{list(self.BUILDERS) + list(ACTOR_BUILDERS)}, "
                f"got '{request.archetype}'"
            )
        sheet, regions = pack_parts(parts)

        out_dir = Path(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        sheet_path = out_dir / "parts.png"
        sheet.save(sheet_path)

        manifest = PartsManifest(
            entity=request.entity_slug(),
            archetype=schema_archetype,
            sheet="parts.png",
            sheet_size=(sheet.width, sheet.height),
            parts=regions,
        )
        manifest_path = manifest.save(out_dir / "parts.json")
        # metadata consumers (provenance) can ask which palette was used
        self.last_palette = palette_name
        return PartsBundle(
            sheet_path=sheet_path, manifest_path=manifest_path, manifest=manifest
        )


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python -m genforge.pipeline.stub_provider",
        description="Generate a procedural parts sheet (no image model needed).",
    )
    ap.add_argument(
        "--archetype", required=True,
        choices=["humanoid", "dragon"] + sorted(ACTOR_BUILDERS),
        help="generic archetype (palette-hinted) or a hand-authored actor name",
    )
    ap.add_argument("--out", required=True)
    ap.add_argument("--entity", default=None)
    ap.add_argument("--family", default="unnamed")
    ap.add_argument("--palette-hints", default="", help="comma-separated hints")
    args = ap.parse_args(argv)

    req = GenerationRequest(
        archetype=args.archetype,
        family=args.family,
        entity=args.entity,
        palette_hints=[h for h in args.palette_hints.split(",") if h],
    )
    bundle = StubPartsProvider().generate_parts(req, Path(args.out))
    print(f"  sheet:    {bundle.sheet_path}")
    print(f"  manifest: {bundle.manifest_path} ({len(bundle.manifest.parts)} parts)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
