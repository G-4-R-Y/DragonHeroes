# Handoff — running state (updated 2026-07-11, v0.1.5)

Read `CLAUDE.md` + `docs/00-canon.md` first (decisions log §12 is current through
item 19). This file is the delta: exactly where work stopped and what's next.

## v0.1.5 delta (2026-07-11) — mass content

- **Bestiary as data** (canon §12.19): `content/generated/bestiary_normal.json`
  (1000 creatures: 12 world-bible families × 7 elements × archetype/tint/scale/
  stat rolls) + `bestiary_legendary.json` (100 named legendaries over
  dragon/colossus/hag chassis, 5-10-skill kits, all ids resolve to
  `content/core/skills/`). Deterministic generator:
  `python3 -m genforge.pipeline.bestiary_gen --seed 2026` (byte-reproducible,
  pytest-gated — 23 tests). Snapshots in `game/prototype/data/`.
- **Catalog-driven spawning** (main.gd/creature.gd): each hunt samples a 6-10
  species roster; packs read as one species w/ 25% strays; ONE legendary boss
  per hunt (pack 13, chassis by base, guaranteed rare+ drop, magenta minimap
  diamond). **Power scaling read at spawn**: normals HP +2%/dmg +1% per player
  level; ALL bosses +6%/+3% (scales scripted skill packets too via dmg_scale).
- **Five new baked bodies**: serpent, shade, golem, fen_boar, marsh_drake
  (`game/prototype/art/`, bestiary_art.py + skeleton/pose JSONs).
- **Five classes**: Gloam Mage (LMB Arcane Bolt projectile, E Frost Nova) and
  Veilblade rogue (LMB Swift Stab 0.25 s cadence, E Fan of Knives ×5) join
  Reaver/Emberkin/Frostbinder. Class KITS reshape LMB/E (player.gd `_kit`),
  not just stats. Friendly projectiles (projectile.gd) hit creatures.
- **VFX pass**: pooled shockwave rings + directional slash trails (fx.gd);
  pools 20/12/6, MAX_AMOUNT 40 — still zero mid-fight allocation.
- Effects registry gained "Bestiary & spawn rules" group (synced to CODEX).

## Top backlog (Ricardo's asks not yet landed)

1. **Real gen-AI image provider** into the GenForge seam (stub provider today);
   tile/texture bundles so terrain gets the same treatment as actors.
2. **Paper-doll**: equipped gear visible on the hero sprite (+ per-slot particles).
3. **Full class kits** (design/10): six classes with distinct trees/resources
   (mage/rogue trees still show the Reaver tree).
4. Message log; R bestial slot; 7-element bolt flavors (storm/venom/blood wisps
   currently fall back to umbral — see registry `wisp_element_flavor`).
5. Legendary hp_mult bias: colossus-chassis entries at hp_mult 6 reach ~13.8k HP
   at level 1 — consider biasing colossus rolls low in bestiary_gen.

## Next architectural step (bigger than the backlog)

Vendor godot-cpp, build `dh-godot` GDExtension, move authority from
`game/prototype/*.gd` (marked PROTOTYPE HARNESS) into `dh-sim`. That is the moment
`game/` stops containing gameplay rules (hard rule, canon §10).

## Operational notes

- Kill the game with `pkill -x godot` — never `pkill -f` (it matches your own shell).
- NEVER launch Vulkan windows (crashed Ricardo's X once); gl_compatibility is the
  default, `tools/run_vulkan.sh` is the opt-in.
- Headless gates: `godot --headless --path game --quit-after 150` (menu),
  `... res://prototype/main.tscn --quit-after 150` ×3 (hunt), click_test.tscn
  (must end `CLICKTEST DONE — ALL PASS`), `pytest genforge/tests/`,
  `python3 tools/validate_content.py`. After adding a `class_name` script, run
  `--import` once. `grep -c` exits 1 on zero matches — never chain gates with `&&`.
- Git: v0.1 tag → 1c9d8c4 v0.1.4 → this commit v0.1.5. Rollback points exist.
