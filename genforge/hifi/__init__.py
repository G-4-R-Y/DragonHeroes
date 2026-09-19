"""GenForge hi-fi sprite generator — the Dead Cells / Phantom Tower register.

Ricardo's brief (repo root ``sprites prompt.md``, indexed in
docs/harness/20-roadmap.md R52) fixes five rendering pillars, a MASTER PROMPT
and a MANDATORY NEGATIVE PROMPT. This package turns that brief into a
generator that can be judged:

  spec.py       the prompt constants, verbatim, pinned to the source file
  creatures.py  the creature descriptions that fill the prompt's first slot
  colour.py     vectorised OKLab (the same maths as living/atlas.py, batched)
  alpha.py      pillar "isolated asset": transparent background enforcement
  grid.py       pillar "1:1 pixel grid, zero mixels": pitch estimate + snap
  palette.py    pillar "8-shade ramps, directional hue-shift": indexed ramps
  outline.py    pillar 5 "Ink-Hold Perimeter": measure + repair
  emissive.py   pillar 2 "Emissive Channel Mask": separate the glow
  normal.py     pillar 1 "normal-map-ready": relief from ramps + bevel
  scorecard.py  the gate — every pillar measured, PASS/FAIL with reasons
  pipeline.py   process / generate / bundle / provenance / review page
  __main__.py   CLI: prompt · process · generate · score · bench · creatures

The model is asked for the pillars; the post-process ENFORCES the ones a model
cannot be trusted on, and the scorecard refuses what still fails. The same
scorecard grades an image from ANY generator (``score`` / ``bench``), which is
how a benchmark against another pipeline stays fair.
"""
from __future__ import annotations

PIPELINE_VERSION = "hifi.v1"
