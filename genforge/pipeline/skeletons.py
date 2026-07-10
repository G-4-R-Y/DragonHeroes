"""Per-archetype 2D skeletons, defined as data (``skeletons/*.json``).

A skeleton is a bone hierarchy on a fixed canvas:

    {
      "name": "humanoid",
      "canvas": [128, 128],            # bake canvas, px
      "anchor": [64, 106],             # where the root bone sits (feet line)
      "bones": [
        {"name": "torso", "parent": "root", "attach": [0, -38],
         "rotation_deg": 0, "z": 30, "part": "torso"},
        ...
      ]
    }

Per bone:
  parent        parent bone name (null for the root)
  attach        offset from the parent bone's origin, in the PARENT's local
                space (rotates with the parent), pixels, y-down
  rotation_deg  default local rotation, degrees, clockwise-positive
  z             draw order (higher draws on top); bones with no part ignore it
  part          default part name in the parts manifest (null = no sprite,
                e.g. the root); poses may override per frame
  hidden        if true the bone starts invisible (VFX bones); poses unhide it

World transform is the usual forward-kinematics fold: a bone's world rotation
is the sum of local rotations up the chain; its world position is the parent's
world position plus the attach offset rotated by the parent's world rotation.
Pose keys (see poses.py) add a per-frame delta rotation and offset.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

SKELETON_DIR = Path(__file__).parent / "skeletons"


@dataclass
class Bone:
    name: str
    parent: Optional[str]
    attach: Tuple[float, float] = (0.0, 0.0)
    rotation_deg: float = 0.0
    z: int = 0
    part: Optional[str] = None
    hidden: bool = False

    @classmethod
    def from_dict(cls, d: dict) -> "Bone":
        return cls(
            name=d["name"],
            parent=d.get("parent"),
            attach=tuple(d.get("attach", (0, 0))),
            rotation_deg=float(d.get("rotation_deg", 0.0)),
            z=int(d.get("z", 0)),
            part=d.get("part"),
            hidden=bool(d.get("hidden", False)),
        )


@dataclass
class BoneWorld:
    """Resolved per-frame state of one bone."""

    pos: Tuple[float, float]
    rotation_deg: float
    part: Optional[str]
    hidden: bool
    z: int


@dataclass
class Skeleton:
    name: str
    canvas: Tuple[int, int]
    anchor: Tuple[float, float]
    bones: List[Bone] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.by_name: Dict[str, Bone] = {b.name: b for b in self.bones}
        if len(self.by_name) != len(self.bones):
            raise ValueError(f"skeleton '{self.name}' has duplicate bone names")
        for b in self.bones:
            if b.parent is not None and b.parent not in self.by_name:
                raise ValueError(
                    f"skeleton '{self.name}': bone '{b.name}' has unknown parent '{b.parent}'"
                )
        self._order = self._topological_order()

    def _topological_order(self) -> List[Bone]:
        ordered: List[Bone] = []
        placed: set = set()
        remaining = list(self.bones)
        while remaining:
            progressed = False
            for b in list(remaining):
                if b.parent is None or b.parent in placed:
                    ordered.append(b)
                    placed.add(b.name)
                    remaining.remove(b)
                    progressed = True
            if not progressed:
                names = [b.name for b in remaining]
                raise ValueError(f"skeleton '{self.name}': bone cycle among {names}")
        return ordered

    def world_transforms(
        self, pose_frame: Optional[dict] = None
    ) -> Dict[str, BoneWorld]:
        """Resolve every bone's world position/rotation for one pose frame.

        ``pose_frame`` maps bone name -> key dict with optional
        ``rotation_deg`` (delta), ``offset`` ([dx, dy], parent-local),
        ``hidden`` (bool) and ``part`` (name override). STEPPED keys: values
        apply to this frame only, no interpolation anywhere.
        """
        pose_frame = pose_frame or {}
        out: Dict[str, BoneWorld] = {}
        for bone in self._order:
            key = pose_frame.get(bone.name, {})
            d_rot = float(key.get("rotation_deg", 0.0))
            d_off = key.get("offset", (0.0, 0.0))
            hidden = bool(key.get("hidden", bone.hidden))
            part = key.get("part", bone.part)

            if bone.parent is None:
                parent_pos, parent_rot = self.anchor, 0.0
            else:
                pw = out[bone.parent]
                parent_pos, parent_rot = pw.pos, pw.rotation_deg

            ox = bone.attach[0] + d_off[0]
            oy = bone.attach[1] + d_off[1]
            # clockwise-positive rotation in y-down coordinates
            rad = math.radians(parent_rot)
            c, s = math.cos(rad), math.sin(rad)
            wx = parent_pos[0] + ox * c - oy * s
            wy = parent_pos[1] + ox * s + oy * c
            w_rot = parent_rot + bone.rotation_deg + d_rot
            out[bone.name] = BoneWorld(
                pos=(wx, wy), rotation_deg=w_rot, part=part, hidden=hidden, z=bone.z
            )
        return out

    def draw_order(self) -> List[Bone]:
        """Bones with parts, back to front."""
        return sorted((b for b in self.bones), key=lambda b: b.z)

    @classmethod
    def from_dict(cls, d: dict) -> "Skeleton":
        return cls(
            name=d["name"],
            canvas=tuple(d["canvas"]),
            anchor=tuple(d["anchor"]),
            bones=[Bone.from_dict(b) for b in d["bones"]],
        )

    @classmethod
    def load(cls, name_or_path: str) -> "Skeleton":
        p = Path(name_or_path)
        if not p.suffix:
            p = SKELETON_DIR / f"{name_or_path}.json"
        return cls.from_dict(json.loads(p.read_text()))


def available_skeletons() -> List[str]:
    return sorted(p.stem for p in SKELETON_DIR.glob("*.json"))
