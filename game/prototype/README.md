# prototype/ — the playable slice (M1 placeholder harness)

**What this is:** a playable vertical slice built in one session — the real
`dh-procgen` world (dumped via `dh-server --dump-chunks 4 --out
game/prototype/chunks.json`), a hero with canon movement/cleave/dodge numbers,
Gloamfen Stalker packs backed by kiting **Gloamfen Wisps** (spirit archetype:
floating cyan-violet orbs that hold 5-7 m and fire violet umbral bolts), and the
**Emberwing Matriarch** — the Elite boss canon made playable (5-skill kit from
`content/core/creatures/emberwing_matriarch.json`: Ember Bolt, Talon Dive, Wing
Gust, Ember Screech enrage at 60%, Magma Breath fire fields at 30% — the elemental
field system's first taste). Death penalty taste (25% gold loss).

The meta loop is REAL now (numbers marked (proposal) where new):

- **Items & loot** (`items.gd`) — kills roll real item instances: base
  (`data/` snapshots of `content/core/items/`) + rarity (common/uncommon/rare/
  epic/legendary — grey/green/blue/purple/orange) + 0/1/2/3/4 affixes rolled
  from the affix pool with PoE-style per-slot spawn weights. The Matriarch
  drops the **Emberfang Blade** as a rolled legendary. Icons are generated
  per (slot, rarity) by the `sprites.gd` icon factory.
- **Real stats** (`stats.gd`) — the hero's StatBlock derives from base +
  allocated attributes (Might +2% melee dmg/pt · Agility +1% move, +2% dodge
  recharge/pt · Intellect +2% skill dmg/pt · Vitality +6 HP/pt · Willpower +1%
  resist, +2% status resist/pt — proposals) + equipped affixes + enchants.
  Damage/HP/speed/crit/armor/resists actually apply in combat; crits roll.
- **Inventory & equipment UI** — the character panel (C/Tab) has Gear/Bag/
  Attributes/Skills/Pets tabs: rarity-bordered icon grid (cap 40), inspect
  popup with affixes + vs-equipped stat diff, equip/sell, REAL attribute
  spending (+5 points per level; every 20 kills = +1 level with fanfare).
- **Forge** (Haven) — pick any owned gear: +10% to all affix values per tier
  (max +5), cost 50 × 2^tier gold, before→after preview; attempts into +4/+5
  fail 25%/40% (gold burns, item survives — soft mirror of docs/design/14).
- **Enchanter** (Haven) — **Abyssal Remnant** Spirit Essences drop from
  abyssal kills (8%) as bag materials; applying one adds/replaces an umbral
  enchant (+4-10%) on a weapon/amulet. On +4/+5 items the attempt has a 25%
  chance to DESTROY the item (clearly warned — docs/design/14 mirror).
- **Runes** (canon §4, `data/runes.json`) — Elites drop runes (guaranteed on
  the first Elite kill, then 5%): **Rune of Echoes** (skill repeats at 40%
  damage 0.25 s later), **Rune of Cinders** (hits ignite 3 dmg/s for 3 s +
  ground scorch), **Rune of the Gale** (dodge leaves a 10-damage knockback
  wind burst). Socket one per skill (cleave/rend/dodge) in the Skills tab —
  the effects are live in combat.
- **Vendor** (Haven) — sell bag items for gold, price = f(rarity, forge tier).
  The real player-to-player marketplace is WEB-ONLY and lands with
  docs/design/15 — this vendor is a stub gold sink.
- **Three pet slots** — `Session.pets` holds up to 3 bonded pets that all
  spawn and fight together. Capture (canon §3, design/13 §7.1): stalkers drop
  **Soul Snares** (~12%); press **F** on a stalker below 35% HP within 3 m
  (chance = 0.25 + 0.6 × missing-HP fraction). Success instance-rolls 2-3
  skills from the Abyssal pool plus a 70-110% attribute roll. With full slots,
  F asks for an F-again confirm (3 s) and replaces the OLDEST bond. Pets rest
  15 s at 0 HP and reset with the hunter on death — they never die.
- **Bestial skill slot (Q)** — owning a Bestial Skill stone awakens **Shadow
  Rend** (130°, 2.2 m, 5 s cooldown; damage scales with Intellect + umbral%).
  The first stalker pack guarantees a stone drop.
- **3-charge dodge** — dodging costs a charge; each refills after ~1.5 s
  (Agility-scaled), oldest first. Cyan pips under the HP bar.
- **Procedural SFX** — `sfx.gd` synthesizes every sound into a static
  AudioStreamWAV cache at startup; 8-player positional round-robin pool.
- **Day/night cycle** — a CanvasModulate cycles the world sinusoidally over ~3
  minutes; the glowing accents pop after dark.

**What this is NOT:** the architecture. Canon §10 rule 2 says gameplay rules never
live in `game/` — every script here is a hand-rolled stand-in for `dh-sim` systems
and dies the day `dh-godot` (GDExtension) lands. Numbers are hand-copied from
`content/core/` (see `data/README.md`); the shipping path loads them through
`dh-content`, and items/gold mint server-side through the economy core
(docs/tech/26) — the client never owns real state.

**Run it:**

```bash
godot --path game        # Godot 4.6+
```

Flow: Main Menu (offline login) -> Haven (game menu: character/forge/enchanter/
vendor/skills/pets/attributes) -> Hunt. The `Session` autoload
(`prototype/ui/session.gd`) carries name/level/gold/stones/snares/kills/
inventory/equipment/runes/pets across scenes; every hunt is fresh, the
character is not.

Controls: WASD move · mouse aim · LMB/Space cleave · Shift/RMB dodge (3 charges) ·
F capture (needs a Soul Snare; F again confirms a replace when slots are full) ·
Q shadow rend (once a stone is owned) · C/Tab character panel · Esc return-to-Haven.
Placeholder art is procedural pixel art (animated hero/stalker/wisp/boss/pet, tile
variants, props, item icons, minimap, ambient spores + vignette) generated at
startup into static caches — same for the procedural SFX; real art/audio arrives
via the Aseprite/atlas + gen-AI pipeline (docs/design/17).
