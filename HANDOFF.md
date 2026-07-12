# Handoff — running state (updated 2026-07-12, v0.1.8)

Read `CLAUDE.md` + `docs/00-canon.md` first (decisions log §12 is current through
item 22). This file is the delta: exactly where work stopped and what's next.

## v0.1.8 delta (2026-07-12) — UI/feel/PT-BR

- **Visual skill tree** (character_panel.gd): drawn prerequisite connectors,
  kind-icon chips w/ element accents, pulsing learnable states, pinned detail
  card (live stat numbers, synergy highlight, Learn/assign 1-4). Fresh
  hunters start w/ 3 points + two level-1 actives per class.
- **Haven nav**: 2-wide grid — QUIT was cropped off-screen; now test-guarded.
  Forge/enchanter action buttons above the fold; vendor leads with selling.
- **Animation juice** (player/creature/bosses/projectiles): swing leans, cast
  wind-ups, dodge afterimages (pooled ghosts), hit squash, death collapses,
  boss anticipation tells; ~50-60 concurrent tweens worst case, 60 FPS holds.
- **PT-BR** (ui/lang.gd ProtoLang): 330-key EN/PT chrome table + _pt data
  twins; skill trees 145/145 nodes bilingual; toggle in menu + Haven,
  persisted in user://settings.json; EN default (CI-safe). CODEX registry
  PT twins = planned (registry "content_pt_twins").

## v0.1.7 delta (2026-07-11) — skill trees + flow tuning

- **Class skill trees** (canon §12.21): registries/skill_trees.json — per class
  20 actives + 8 passives + root (145 nodes), ONE generic executor in player.gd
  (projectile/nova/cone/melee_arc/dash_strike/buff/field/chain), data-expressed
  synergies (bonus_vs/consumes, Ignite spread/detonate, Shatter, Attunement and
  Combo charges), new statuses Bleed/Expose/Stagger on creatures, skill bar on
  1-4 + learn/assign in CHARACTER -> Skills, loadout saved.
- **Flow tuning** (canon §12.20, v0.1.6): hitboxes follow sprite scale;
  legendary HP normalized (x1.4-3.0 of 900 budget — no 13.8k walls); items
  roll at hunter level (+4%/level, ilvl stamped), boss/legendary drops
  quality-floored (0.35/0.5).

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
3. **Sixth class** (design/10 names six at launch; five are live) + per-class
   resources beyond Attunement/Combo charges.
4. Skill-tree balance pass after play (100 actives are fresh); message log;
   R bestial slot; 7-element bolt flavors (storm/venom/blood wisps currently
   fall back to umbral — see registry `wisp_element_flavor`).

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
- Git: v0.1 tag → v0.1.5 mass content → 2133327 v0.1.6 tuning → a8f37a4 v0.1.7
  skill trees. Rollback points exist at every step.
