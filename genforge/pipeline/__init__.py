"""GenForge v0 pipeline: parts sheet -> programmatic skeleton -> baked frames.

One image-generation call produces a PARTS SHEET per entity (professional
concept-sheet style: head/torso/limbs/cape/weapon pieces, plus VFX strips).
A programmatic 2D skeleton rigs those parts, reusable pose libraries animate
them with STEPPED keys, and the baker composites plain frame strips + a
Godot-friendly atlas.json. No video generation anywhere: marginal cost per
animation is near zero, and baked frames preserve the per-frame hitbox
contract of docs/tech/23.

Modules
-------
manifest       the parts-sheet contract (PNG + parts.json)
skeletons      per-archetype 2D bone hierarchies (data in skeletons/*.json)
poses          reusable stepped-key animation libraries (data in poses/*.json)
assemble       the baker: parts + skeleton + poses -> strips + atlas.json
stub_provider  procedural (Pillow-drawn) parts-sheet provider — the whole
               pipeline runs today with zero image-model calls; a real
               style-locked image model plugs in behind the same interface.
"""

__version__ = "0.1.0"
