"""The prompt contract — Ricardo's MASTER PROMPT and MANDATORY NEGATIVE PROMPT.

Both strings are VERBATIM from the repo-root ``sprites prompt.md`` (the brief's
source of truth; roadmap R52 is the index). ``verify_against_source`` pins
them: if the file changes, ``genforge/tests/test_hifi.py`` fails until these
constants are re-synced on purpose. The source marks two citations with
``^^``; those marks are not prompt text and are stripped on both sides.

Backends differ on negative prompts: a local diffusion runtime takes one
natively, the OpenAI Images API does not. ``PromptSpec.render`` folds the
negative into the positive as a hard-constraint clause when the backend has no
native slot, so every backend receives the full brief.
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_FILE = REPO_ROOT / "sprites prompt.md"

GRID_PX = 256
DEFAULT_STANCE = "profile combat stance"

# The fixed tail of the master prompt: everything after the creature slot.
MASTER_STYLE = (
    "hi-bit modern dark fantasy pixel art sprite, Dead Cells and Phantom Tower "
    "visual benchmark. 256x256 pixel grid, profile combat stance. Thick "
    "continuous solid dark-ink perimeter outline, strictly zero selective "
    "outlining (sel-out), zero lineless edges. Volumetric cluster shading with "
    "deep 8-shade color ramps, pronounced directional hue-shifting, and "
    "normal-map-ready planar depth. Dedicated high-contrast emissive core with "
    "sharp unshaded glow highlights ready for engine HDR bloom. Crisp native 1:1 "
    "pixel grid, strictly zero mixels, no algorithmic interpolation blur, no "
    "noisy dithering, no pillow shading, isolated game asset on a clean "
    "transparent background."
)

NEGATIVE_PROMPT = (
    "selective outline, sel-out, lineless, 90s low-res arcade, flat retro colors, "
    "blurry anti-aliasing, soft airbrush, 3D smooth mesh render, vector art, "
    "mixels, pillow shading, noisy dithering, faint edges, washed-out colors, "
    "compression artifacts."
)

# The brief's own worked example, kept for the docs and as the Orun baseline.
EXAMPLE_CREATURE = (
    "Ancient moss-covered guardian stag boss with massive petrified wood antlers "
    "carrying a hanging bronze bell, shelf mushrooms on back, glowing crystal "
    "core in chest"
)

# Pillar 4: 12-16 discrete key poses per cycle. These fill the stance slot when
# a clip is generated pose by pose (each pose is one generation, same seed
# family). Names match the living recipe's required clips (design/26 rule 4).
KEY_POSES: Dict[str, List[str]] = {
    "idle": ["profile combat stance, weight settled, chest rising",
             "profile combat stance, weight settled, chest fallen"],
    "move": ["profile combat stance, mid-stride contact pose",
             "profile combat stance, passing pose, legs crossed",
             "profile combat stance, opposite contact pose",
             "profile combat stance, opposite passing pose"],
    "anticipation": ["profile combat stance, coiled wind-up, weight back",
                     "profile combat stance, deep braced crouch, charged core"],
    "attack": ["profile combat stance, strike release, weight forward",
               "profile combat stance, full extension at contact",
               "profile combat stance, strike recovery"],
    "hit": ["profile combat stance, recoiling from a blow",
            "profile combat stance, staggered, bracing"],
    "death": ["profile combat stance, knees buckling",
              "collapsed on the ground, core dimmed"],
}


def _strip_marks(text: str) -> str:
    return text.replace("^^", "")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class PromptSpec:
    creature: str
    positive: str
    negative: str = NEGATIVE_PROMPT
    stance: str = DEFAULT_STANCE
    grid_px: int = GRID_PX

    @property
    def positive_sha256(self) -> str:
        return sha256_text(self.positive)

    @property
    def negative_sha256(self) -> str:
        return sha256_text(self.negative)

    def render(self, negative_native: bool) -> Dict[str, str]:
        """What a backend receives. Native negative -> two fields; otherwise
        one prompt with the negative folded in as a hard-constraint clause."""
        if negative_native:
            return {"prompt": self.positive, "negative_prompt": self.negative}
        folded = (f"{self.positive} Hard constraints — the image must contain "
                  f"none of the following: {self.negative}")
        return {"prompt": folded}

    def as_record(self) -> Dict[str, object]:
        return {
            "creature": self.creature,
            "stance": self.stance,
            "grid_px": self.grid_px,
            "positive": self.positive,
            "negative": self.negative,
            "positive_sha256": self.positive_sha256,
            "negative_sha256": self.negative_sha256,
            "source": SOURCE_FILE.name,
        }


def build_prompt(description: str, stance: Optional[str] = None,
                 grid_px: int = GRID_PX) -> PromptSpec:
    """Fill the creature slot; optionally swap the stance / grid the master
    prompt names (pose-by-pose key frames, or a 128 px ordinary creature)."""
    style = MASTER_STYLE
    stance = stance or DEFAULT_STANCE
    if stance != DEFAULT_STANCE:
        style = style.replace(DEFAULT_STANCE, stance, 1)
    if grid_px != GRID_PX:
        style = style.replace(f"{GRID_PX}x{GRID_PX}", f"{grid_px}x{grid_px}", 1)
    description = description.strip().rstrip(",.")
    return PromptSpec(creature=description, positive=f"{description}, {style}",
                      stance=stance, grid_px=grid_px)


def verify_against_source(path: Path = SOURCE_FILE) -> Dict[str, object]:
    """Pin MASTER_STYLE + NEGATIVE_PROMPT to Ricardo's file. Returns a report;
    raises ValueError naming the first constant that drifted."""
    text = _strip_marks(path.read_text(encoding="utf-8"))
    flat = re.sub(r"\s+", " ", text)
    report = {"source": str(path), "source_sha256": sha256_text(text)}
    if MASTER_STYLE not in flat:
        raise ValueError("MASTER_STYLE no longer matches sprites prompt.md")
    if NEGATIVE_PROMPT not in flat:
        raise ValueError("NEGATIVE_PROMPT no longer matches sprites prompt.md")
    if EXAMPLE_CREATURE not in flat:
        raise ValueError("EXAMPLE_CREATURE no longer matches sprites prompt.md")
    report["verified"] = True
    return report
