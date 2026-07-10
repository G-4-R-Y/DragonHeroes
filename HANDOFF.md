# Handoff — running state (updated 2026-07-10, v7)

## v7 delta (2026-07-10 evening)
Fresh world EVERY hunt (live dh-server dump, random seed); 14-pack hordes;
creature archetypes (stalker/lunger/brute w/ slam+pounce actives) + elite
affixes; wisp elements; fast 1→100 curve; classes-lite (Reaver/Emberkin/
Frostbinder); Whirlwind (E); mounts on Z (drake sprite rebuilt); character
saves incl. class/mounts/stables/skill tree; UI: bag filter/sort, sell-all,
skill cards + socket chips, stable cards, class picker; effects registry +
in-game CODEX. Git: v0.1 tag = pre-v7 snapshot.

## Top backlog (Ricardo's asks not yet landed)
1. **More bosses**: Pyre Sovereign + Terravore Colossus legendary duo (content
   JSONs exist — build the fight: meteors/earthquake/lava Duologue); Fenwitch
   Hag + Mireborn Croaker as mid-bosses.
2. **The real "100x modern visuals"**: replace procedural sprites with the
   GenForge art pipeline output (style-locked gen-AI parts sheets → skeleton
   bakes). Procedural GDScript pixels are at their ceiling. Also: Vulkan HDR
   glow path (opt-in only — a Vulkan window once crashed Ricardo's X session),
   paper-doll equipment on the hero.
3. **Full class kits** (design/10): six classes with distinct trees/resources.
4. Message log; R bestial slot; player-made field combos decision (canon opens).

# Prior handoff — v4 state (2026-07-08, written by Fable at session end)

Read `CLAUDE.md` + `docs/00-canon.md` first. This file is the delta: exactly where
v4 stopped and what's next. Delete it once absorbed into the roadmap.

## Done and verified (this session)

- **GenForge v0 — complete, 11/11 tests.** One image call → parts sheet →
  programmatic skeletons → baked strips. `genforge/`: pipeline modules, FastAPI
  service (`uvicorn genforge.service.app:app`, POST `/generate/creature`),
  `pytest genforge/tests/`. Demo bundles Ricardo can open:
  `genforge/candidates/demo/{gloam_mage,ember_drake}/baked/`. Candidates dir is
  gitignored (curation gate, docs/tech/28 §6). No video models; frame-interp only
  as a future optional post-pass.
- **Systems de-mock — complete.** Real items/affixes (items.gd), StatBlock
  (stats.gd), inventory cap 40 + equip/sell/unequip, forge upgrade (fail risk at
  +4/+5), enchanter (essence + destroy risk), vendor, runes (Echoes/Cinders/Gale,
  one socket per skill), 3-pet party w/ oldest-bond replace, level-ups (20 kills),
  attribute spending. All state in the `Session` autoload; validator green
  (36 defs / 0 problems).
- **Spectacle (partial — Fable finished inline after the agent died).**
  `fx.gd` pooled elemental VFX (22 emitters + 4 lightning Line2Ds, zero mid-fight
  allocation), `glow.gd` additive fake-bloom (+ `ProtoSprites.glow_tex()`),
  `telegraph.gd` attack telegraphs. Wired: fire fields glow/telegraph/ignite,
  kill explosions + debris, boss-death double lightning, level-up sky strike,
  dodge streak + gale tornado + Shadow Rend umbral nova, rarity-glow ground loot,
  dodge pips w/ fill + charge-complete flash + full-charge breathing, Q cooldown
  gauge w/ fill/glow/ready-blip, keybind card on K.

## Spectacle backlog (the dead agent's remaining scope)

1. Hi-fi sprite pass ×2 resolution ("128-bit", canon §4) for hero/creatures/tiles.
2. Paper-doll: equipped gear visible on the hero sprite (+ per-slot particles).
3. Pyre Sovereign + Terravore Colossus **legendary duo** — content JSONs exist
   (`content/core/creatures/`); build the fight: meteors, earthquakes, lava-tile
   Duologue (fire+earth field combo already in `registries/fields.json`).
4. Fenwitch Hag + Mireborn Croaker as new pack creatures.
5. E/R bestial skill slots (Q exists), message log (K card is separate by design).
6. Vulkan HDR glow opt-in path: launch with `--rendering-method mobile` ONLY when
   Ricardo asks — a Vulkan window crashed his X session once. Default stays
   gl_compatibility.

## Next architectural step (bigger than the backlog)

Vendor godot-cpp, build `dh-godot` GDExtension, move authority from
`game/prototype/*.gd` (marked PROTOTYPE HARNESS) into `dh-sim`. That is the moment
`game/` stops containing gameplay rules (hard rule, canon §10).

## Operational notes

- Kill the game with `pkill -x godot` — never `pkill -f` (it matches your own shell).
- Headless gates: `godot --headless --path game --quit-after 90` and
  `... res://prototype/main.tscn --quit-after 150`; grep `SCRIPT ERROR` must be empty.
  After adding a script with a new `class_name`, run `--import` once.
- `python3 tools/validate_content.py` before and after touching `content/`.
- No git commits yet by design — Ricardo asks for the first commit explicitly.
