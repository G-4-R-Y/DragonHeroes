"""Reusable pose libraries — the animation half of the archetype contract.

One JSON file per skeleton (``poses/<skeleton>.json``), holding named
animations as frame lists of per-bone keys:

    {
      "skeleton": "humanoid",
      "animations": {
        "walk": {
          "fps": 6, "loop": true,
          "frames": [
            {"leg_l": {"rotation_deg": -18}, "leg_r": {"rotation_deg": 18},
             "torso": {"offset": [0, -1]}},
            ...
          ]
        }
      }
    }

Per-bone key fields (all optional, all STEPPED — no interpolation ever):
  rotation_deg   delta from the bone's default rotation, cw-positive
  offset         [dx, dy] delta from the bone's attach offset (parent-local)
  hidden         override visibility (used to flash VFX bones on)
  part           override which manifest part the bone draws this frame
                 (used to step through VFX strip cells)

Because animations are keyed on BONE names, not on any specific creature, a
pose library is written once per archetype and reused by every entity ever
generated on that skeleton — this is where the near-zero marginal cost per
animation comes from.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List

POSE_DIR = Path(__file__).parent / "poses"


@dataclass
class Animation:
    name: str
    fps: float
    loop: bool
    frames: List[dict] = field(default_factory=list)  # frame -> {bone: key dict}

    @property
    def frame_count(self) -> int:
        return len(self.frames)


@dataclass
class PoseLibrary:
    skeleton: str
    animations: Dict[str, Animation] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, d: dict) -> "PoseLibrary":
        anims = {}
        for name, a in d["animations"].items():
            frames = a["frames"]
            if not frames:
                raise ValueError(f"animation '{name}' has no frames")
            anims[name] = Animation(
                name=name,
                fps=float(a.get("fps", 6)),
                loop=bool(a.get("loop", False)),
                frames=frames,
            )
        return cls(skeleton=d["skeleton"], animations=anims)

    @classmethod
    def load(cls, name_or_path: str) -> "PoseLibrary":
        """Load by skeleton name (from the built-in library) or explicit path."""
        p = Path(name_or_path)
        if not p.suffix:
            p = POSE_DIR / f"{name_or_path}.json"
        return cls.from_dict(json.loads(p.read_text()))

    def validate_against(self, skeleton) -> None:
        """Every keyed bone must exist on the skeleton."""
        if self.skeleton != skeleton.name:
            raise ValueError(
                f"pose library targets '{self.skeleton}', skeleton is '{skeleton.name}'"
            )
        for anim in self.animations.values():
            for i, frame in enumerate(anim.frames):
                for bone_name in frame:
                    if bone_name not in skeleton.by_name:
                        raise ValueError(
                            f"animation '{anim.name}' frame {i} keys unknown bone "
                            f"'{bone_name}'"
                        )


def available_pose_libraries() -> List[str]:
    return sorted(p.stem for p in POSE_DIR.glob("*.json"))
