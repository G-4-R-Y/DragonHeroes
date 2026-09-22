# art/ — source art

Canon §10: *"source art: aseprite files, archetype rigs, palettes"*. This is the
**editable source**, not the shipped asset. Exported sheets and atlases live in
`game/` (presentation) and generated candidates in `genforge/candidates/`.

| Folder | Holds |
|---|---|
| `palettes/` | Master palettes. Recolors are palette-LUT lookups at runtime (canon: no per-variant sheets), so the palette file *is* the variant system. |
| `rigs/` | Archetype rigs — the shared skeleton/pose set a family of creatures animates on, so a new creature is a skin over an existing rig rather than a new animation set. |
| `tiles/` | Tileset sources for biome terrain. |

## Why it looks empty

It is scaffolding, deliberately. Art production today runs through **GenForge**
(`genforge/`) — style-locked, palette-enforced, human-directed generation — and
its outputs land as candidates, not as hand-authored `.aseprite` files. This tree
is where hand-authored and hand-corrected sources go as soon as there are any:
the palette a generator is locked to, the rig a family shares, the tileset a
biome is drawn from.

Keep it. An empty `palettes/` is the difference between "we have not drawn the
master palette yet" and "nobody knows where the master palette should live."

See also: `docs/art/` (art direction and per-asset provenance),
`genforge/README.md` (the generation pipeline), canon §10 (layout).
