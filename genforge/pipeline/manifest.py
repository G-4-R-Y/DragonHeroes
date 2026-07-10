"""The parts-sheet contract.

A *parts sheet* is what one image-generation call produces per entity: a single
PNG laying out every body part / accessory / VFX cell the entity needs (like a
professional concept parts sheet), plus a ``parts.json`` manifest mapping named
parts to sheet regions:

    {
      "schema_version": 1,
      "entity": "gloam_mage",
      "archetype": "humanoid",
      "sheet": "parts.png",                # relative to the manifest file
      "sheet_size": [512, 256],
      "parts": {
        "head": {
          "rect":  [x, y, w, h],           # region on the sheet, px
          "pivot": [px, py],               # attachment point, px, LOCAL to rect
          "angle_hint": 0.0                # degrees the part is pre-drawn at
        },
        ...
      }
    }

``pivot`` is where the part attaches to its bone (a forearm's pivot is its
elbow). ``angle_hint`` lets a provider draw a part at a non-neutral angle; the
baker subtracts it before applying bone rotation, so a wing sketched at 30°
still animates correctly. Rotation convention everywhere in this pipeline:
degrees, **clockwise-positive with y-down** (Godot's convention).

The JSON Schema for the manifest lives in ``schemas/parts_manifest.schema.json``
and ``validate_manifest_dict`` checks against it (plus bounds checks the schema
cannot express).
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Tuple

from PIL import Image

SCHEMA_VERSION = 1
SCHEMA_PATH = Path(__file__).parent / "schemas" / "parts_manifest.schema.json"


@dataclass
class PartRegion:
    """One named part on the sheet."""

    rect: Tuple[int, int, int, int]      # x, y, w, h on the sheet
    pivot: Tuple[float, float]           # attachment point, local to rect
    angle_hint: float = 0.0              # degrees (cw-positive) part is drawn at

    def to_dict(self) -> dict:
        return {
            "rect": list(self.rect),
            "pivot": list(self.pivot),
            "angle_hint": self.angle_hint,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "PartRegion":
        return cls(
            rect=tuple(d["rect"]),
            pivot=tuple(d["pivot"]),
            angle_hint=float(d.get("angle_hint", 0.0)),
        )


@dataclass
class PartsManifest:
    """The parts.json side of the contract; ``sheet`` is relative to the manifest."""

    entity: str
    archetype: str
    sheet: str
    sheet_size: Tuple[int, int]
    parts: Dict[str, PartRegion] = field(default_factory=dict)
    schema_version: int = SCHEMA_VERSION
    path: Path | None = None             # set when loaded from disk

    # -- (de)serialization ---------------------------------------------------
    def to_dict(self) -> dict:
        return {
            "schema_version": self.schema_version,
            "entity": self.entity,
            "archetype": self.archetype,
            "sheet": self.sheet,
            "sheet_size": list(self.sheet_size),
            "parts": {name: p.to_dict() for name, p in self.parts.items()},
        }

    def save(self, path: Path) -> Path:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict(), indent=2) + "\n")
        self.path = path
        return path

    @classmethod
    def from_dict(cls, d: dict, path: Path | None = None) -> "PartsManifest":
        validate_manifest_dict(d)
        return cls(
            entity=d["entity"],
            archetype=d["archetype"],
            sheet=d["sheet"],
            sheet_size=tuple(d["sheet_size"]),
            parts={n: PartRegion.from_dict(p) for n, p in d["parts"].items()},
            schema_version=d["schema_version"],
            path=path,
        )

    @classmethod
    def load(cls, path: Path) -> "PartsManifest":
        path = Path(path)
        return cls.from_dict(json.loads(path.read_text()), path=path)

    # -- sheet access ----------------------------------------------------------
    def sheet_path(self) -> Path:
        if self.path is None:
            return Path(self.sheet)
        return (self.path.parent / self.sheet).resolve()

    def open_sheet(self) -> Image.Image:
        img = Image.open(self.sheet_path()).convert("RGBA")
        if (img.width, img.height) != tuple(self.sheet_size):
            raise ValueError(
                f"sheet {self.sheet_path()} is {img.size}, manifest says {self.sheet_size}"
            )
        return img

    def crop(self, sheet: Image.Image, part_name: str) -> Image.Image:
        """Cut one part out of an already-open sheet image."""
        p = self.parts[part_name]
        x, y, w, h = p.rect
        return sheet.crop((x, y, x + w, y + h))


def validate_manifest_dict(d: dict) -> None:
    """Validate against the JSON Schema plus bounds checks it cannot express.

    Raises ``ValueError`` with a readable message on the first problem found.
    """
    try:
        import jsonschema

        schema = json.loads(SCHEMA_PATH.read_text())
        jsonschema.validate(d, schema)
    except ImportError:  # pragma: no cover - jsonschema is in requirements.txt
        _validate_shape_fallback(d)
    except Exception as e:  # jsonschema.ValidationError and friends
        raise ValueError(f"parts manifest failed schema validation: {e}") from e

    sw, sh = d["sheet_size"]
    for name, p in d["parts"].items():
        x, y, w, h = p["rect"]
        if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > sw or y + h > sh:
            raise ValueError(
                f"part '{name}' rect {p['rect']} outside sheet {sw}x{sh}"
            )


def _validate_shape_fallback(d: dict) -> None:
    for key in ("schema_version", "entity", "archetype", "sheet", "sheet_size", "parts"):
        if key not in d:
            raise ValueError(f"parts manifest missing key '{key}'")
    for name, p in d["parts"].items():
        if "rect" not in p or "pivot" not in p:
            raise ValueError(f"part '{name}' missing rect/pivot")
        if len(p["rect"]) != 4 or len(p["pivot"]) != 2:
            raise ValueError(f"part '{name}' rect/pivot malformed")
