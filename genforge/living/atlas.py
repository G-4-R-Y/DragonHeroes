"""Offline animation ingest: shared scale/anchor, OKLab palette, emissive mask.

No neural calls, invented in-between frames, or synthetic normal maps. Every
output frame traces back to one source cell. Technical gates do not approve art.
"""
from __future__ import annotations

import hashlib
import math
from pathlib import Path

from PIL import Image


def oklab(rgb):
    def linear(c):
        c /= 255.0
        return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
    r, g, b = map(linear, rgb)
    l = (.4122214708*r + .5363325363*g + .0514459929*b) ** (1/3)
    m = (.2119034982*r + .6806995451*g + .1073969566*b) ** (1/3)
    s = (.0883024619*r + .2817188376*g + .6299787005*b) ** (1/3)
    return (.2104542553*l + .793617785*m - .0040720468*s,
            1.9779984951*l - 2.428592205*m + .4505937099*s,
            .0259040371*l + .7827717662*m - .808675766*s)


def rgb_hex(value):
    return tuple(bytes.fromhex(value.lstrip("#")))


def bake(source: Path, recipe: dict, style: dict, out: Path) -> dict:
    with Image.open(source) as original:
        image = original.convert("RGBA")
    cols, rows = recipe["grid"]
    if image.width < cols*16 or image.height < rows*16:
        raise ValueError("source cells must be at least 16 pixels on each side")
    frames, boxes = [], []
    for i in range(cols * rows):
        col, row = i % cols, i // cols
        # Providers may return odd dimensions. Rational boundaries consume every
        # pixel once, without silently stretching a sheet to a requested size.
        frame = image.crop((col*image.width//cols, row*image.height//rows,
                            (col+1)*image.width//cols, (row+1)*image.height//rows))
        cell_w, cell_h = frame.size
        frame.putalpha(frame.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"empty source frame {i}")
        if box == (0, 0, cell_w, cell_h):
            raise ValueError(f"frame {i} has no transparent margin; use an RGBA cutout")
        frames.append(frame)
        boxes.append(box)
    size = style["frame_px"]
    anchor_x, anchor_y = (round(a*size) for a in recipe["anchor"])
    available_w = 2*min(anchor_x-3, size-anchor_x-3)
    available_h = anchor_y-3
    if available_w <= 0 or available_h <= 0 or anchor_y > size-3:
        raise ValueError("anchor leaves no safe silhouette margin")
    scale = min(available_w/max(b[2]-b[0] for b in boxes),
                available_h/max(b[3]-b[1] for b in boxes))
    palette = [rgb_hex(c) for c in style["palette"]]
    labs = list(map(oklab, palette))
    emissive_colors = {rgb_hex(c) for c in style["emissive_colors"]}
    cache = {}
    errors = []

    def quantize(rgb):
        if rgb not in cache:
            lab = oklab(rgb)
            distances = [sum((a-b)**2 for a,b in zip(lab, p)) for p in labs]
            index = min(range(len(palette)), key=distances.__getitem__)
            cache[rgb] = palette[index], math.sqrt(distances[index])
        return cache[rgb]

    normalized, emission, areas = [], [], []
    for frame, box in zip(frames, boxes):
        cropped = frame.crop(box).resize((max(1, round((box[2]-box[0])*scale)),
                                        max(1, round((box[3]-box[1])*scale))), Image.NEAREST)
        canvas = Image.new("RGBA", (size, size))
        canvas.alpha_composite(cropped, (anchor_x-cropped.width//2, anchor_y-cropped.height))
        colors, glow = [], []
        for r, g, b, a in canvas.getdata():
            if a == 0:
                colors.append((0,0,0,0)); glow.append((0,0,0,0))
            else:
                color, error = quantize((r,g,b))
                errors.append(error)
                colors.append((*color, 255))
                glow.append((*color, 255) if color in emissive_colors else (0,0,0,0))
        canvas.putdata(colors)
        mask = Image.new("RGBA", (size,size)); mask.putdata(glow)
        normalized.append(canvas); emission.append(mask)
        areas.append(sum(a > 0 for a in canvas.getchannel("A").getdata()))
    max_frames = max(len(c["frames"]) for c in recipe["clips"])
    stride, gutter = size+4, 2
    dimensions = (stride*max_frames, stride*len(recipe["clips"]))
    memory = dimensions[0]*dimensions[1]*4*2  # albedo + emissive, uncompressed RGBA
    if memory > style["max_atlas_bytes"]:
        raise ValueError(f"atlas exceeds decoded memory budget: {memory}")
    sheet = Image.new("RGBA", dimensions); glow_sheet = Image.new("RGBA", dimensions)
    clips = []
    for row, clip in enumerate(recipe["clips"]):
        rects = []
        for col, index in enumerate(clip["frames"]):
            x, y = col*stride+gutter, row*stride+gutter
            sheet.alpha_composite(normalized[index], (x,y))
            glow_sheet.alpha_composite(emission[index], (x,y))
            rects.append([x,y,size,size])
        ticks = [round((i+1)*30/clip["fps"])-round(i*30/clip["fps"])
                 for i in range(len(clip["frames"]))]
        clips.append({**clip, "rects": rects, "frame_ticks": ticks})
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / "albedo.png"); glow_sheet.save(out / "emissive.png")
    blockers = [f"missing clip: {name}" for name in recipe["required_clips"]
                if name not in {c["name"] for c in clips}]
    unique = len({hashlib.sha256(f.tobytes()).hexdigest() for f in normalized})
    if unique == 1 and len(normalized) > 1:
        blockers.append("animation contains only identical frames")
    # Review flags, not anatomy/quality scores. Quantization cannot prove beauty.
    area_delta = (max(areas)-min(areas))/max(areas)
    if area_delta > .25:
        blockers.append("silhouette area varies >25%; review anatomy and temporal stability")
    if max(errors, default=0) > .2:
        blockers.append("large palette projection error; review lost material detail")
    return {"id": recipe["id"], "frame_px": size, "anchor": [anchor_x,anchor_y],
            "albedo": "albedo.png", "emissive": "emissive.png", "clips": clips,
            "metrics": {"decoded_bytes": memory, "unique_frames": unique,
                        "area_variation": round(area_delta,4),
                        "mean_oklab_error": round(sum(errors)/max(1,len(errors)),4)},
            "blockers": blockers, "review_status": "candidate"}
