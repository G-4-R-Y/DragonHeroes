# The World Bible — v0.1 draft seed

> **Status:** starter canon for grounding generation, written 2026-07-08 — awaiting
> Ricardo's review. Everything here is *lore canon* the generators must respect;
> gameplay numbers stay in `content/` and the design docs. Grow this file forever:
> every shipped drop should add to it, so the world's history compounds.

## Cosmology — the Luminous World and the Gloom

The world — hunters call it **the Veilands** *(naming open)* — is beautiful the way a
predator is beautiful. Light here is alive: it pools in moss, drips from blossoms,
runs in the veins of beasts. That living light is called **the Lumen**, and everything
that grows, glows.

Beneath it runs **the Gloom**: not darkness but *hunger* — the appetite of an older,
unfinished world that was papered over when the Lumen bloomed. Where the Gloom seeps
up, the land stays gorgeous and becomes lethal. This is the game's core contrast made
lore: the horror is IN the beauty, never instead of it.

The world has **no edges, only unfinished places**. At the rim of every map, the
Lumen is still weaving new land out of the Gloom — which is why the world grows
outward forever, and why newly woven regions (new biomes) appear where no hunter has
walked. *(This is the lore covenant for infinite procgen + virgin-space biome drops.)*

## The Havens and the Hunt

Civilization survives in **Havens** — walled sanctuaries built around **Lumen wells**.
Havens don't farm; they *hunt*. Everything of value comes from expeditions into the
wilds: meat, hide, ore, and above all **spirits**. A hunter who dies in the wild is
not fully lost — the well recalls their spark — but what they carried feeds the Gloom
(the death-penalty lore). The **Guilds of the Hunt** organize expeditions, run the
markets, and crown champions in the seasonal tournaments.

## Spirits, Essences, and the three takings

Every creature carries a shard of Lumen — its **spirit**. When a creature falls, a
hunter may take one of three things:

1. **The body** — materials, trophies, items.
2. **The spirit** — condensed into a **Spirit Essence**, worked into gear by Haven
   enchanters (why essences are family-flavored: the spirit remembers what it was).
3. **The bond** — a living creature, weakened and offered a **Soul Snare**, may
   *choose* the hunter. Bonded creatures (**Pets**) keep their nature: their skills
   are drawn from what their bloodline knows. This is why pet skill pools are
   family-coherent, and why a perfect bond is legendary — the creature must consent
   at the exact edge of death.

**Bestial Skills** are the fourth taking, and the rarest: sometimes a dying creature's
practiced technique crystallizes whole — a **skill stone** any hunter can learn from.

## Creature families (grow this list every drop)

- **Abyssal** — bloodlines the Gloom touched and released. They share fragments of its
  hunger (family skills: *Abyssal Maw*, *Void Step*) but each species keeps its own
  discipline (the Gloamfen Stalker's *Shadow Rend*). Abyssal creatures are drawn to
  bioluminescence; they hunt prettiest where it is brightest.
- **Emberkin** — descendants of the First Fire that the Lumen caught and kept. Proud,
  territorial, matriarchal. The **Emberwing Matriarch** rules a Cinderwastes flight;
  the **Pyre Sovereign** is older than the Havens and remembers being worshipped.
- **Earthbound** — the world's own masonry given appetite. Slow, patient, nearly
  eternal. **Terravore Colossi** eat mountains and excrete valleys. When an Emberkin
  sovereign and an Earthbound colossus hunt together, the land itself melts — lava —
  which hunters call a **Duologue**. *(Lore for Legendary duo field combos.)*
- **Palewrought** — frost-bound; **Mireborn** — Gloamfen swarm-life; **Skyborne** —
  avian lines of the peaks. *(Stubs: expand when their biomes feature in a season.)*

## The five woven regions (launch biomes)

- **Everbloom Wilds** — the Lumen's showpiece; petals that never fall. The oldest
  hunting songs warn: *the sweeter the bloom, the closer the maw*.
- **Gloamfen** — a drowned forest lit from below. Every light in the fen is either
  food, lure, or eye.
- **Cinderwastes** — the First Fire's grave, still warm. Emberkin sovereignty;
  glass flowers; ash that remembers shapes.
- **Palecrown Peaks** — where the Lumen freezes into crowns of ice. Sound carries for
  miles; so do screams.
- **Umbral Depths** — the closest the living world comes to the Gloom. The deeper you
  go, the more beautiful it gets. That is a warning, not an invitation.

## Seasons and the growing world

Time in the Veilands moves in **seasons of the Hunt** (12 weeks). Each season, the
Lumen weaves differently — a theme: which families stir, which regions expand, what
the Guilds commission (season items), which techniques resurface (season skills).
Season themes live in `../seasons/` and are a REQUIRED input to every generation
request: new content must read as *this season happening to this world*.

## Hard lore rules for generators

1. Nothing is generic. Every creature/item/skill names its family, region, or Guild
   origin and fits their story.
2. Family skill-sharing is sparse and always lore-justified (canon §3).
3. The Gloom corrupts by *beautifying*. Corrupted content gets MORE luminous, not
   browner.
4. Legendaries are individuals with names and histories, never "a big variant".
5. New land is woven at the rim — new biomes never retcon walked ground.
