"""Bestiary batch generator — 1000 normal + 100 legendary creature catalogs.

A deterministic, seeded generator that mass-produces lore-coherent creature
DATA from component tables grounded in the world bible (genforge/lore/
world-bible.md): twelve Veilands creature families (the six the prototype
already fights — Gloamfen, Emberwing, Fenwitch, Mireborn, Pyre, Terravore —
plus the bible's Palewrought and Skyborne stubs and four new Lumen/Gloom
families: Bloomfell, Duskmaw, Cinderglass, Bloodbriar), the seven canonical
damage types (content/core/registries/damage_types.json), epithet/noun name
tables, and size/temperament stat correlation (big = slow = tanky).

Outputs (schema version 1, with a provenance header: seed, generator
version, date):

  bestiary_normal.json     1000 entries — archetype (stalker|lunger|brute|
                           wisp), art bundle key, element, tint, scale and
                           hp/dmg/speed/gold multipliers, one-line lore
  bestiary_legendary.json  100 named individuals (canon: legendaries are
                           never "a big variant") — base (dragon|colossus|
                           hag), bundle, element, tint, scale, hp/dmg
                           multipliers, a 5-10 skill kit drawn from
                           content/core/skills/, 1-2 line lore

Kit skill ids are verified against content/core/skills/ at generation time;
kits are element/base-coherent (fire dragons breathe, earth bases quake).

This is a human-invoked dev batch (same carve-out as bake_game_art.py): it
writes the canonical catalogs to content/generated/ — never content/core or
content/drops — plus prototype snapshots to game/prototype/data/ that the
game loads. Same seed, same catalogs, byte for byte (pass --date to also pin
the provenance date).

Run from the repo root:
    python3 -m genforge.pipeline.bestiary_gen --seed 2026 \
        [--out-dir content/generated] [--game-dir game/prototype/data]
"""
from __future__ import annotations

import argparse
import colorsys
import datetime as _dt
import json
import random
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

GENERATOR = "genforge.pipeline.bestiary_gen"
VERSION = "1.0.0"
GENFORGE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = GENFORGE_ROOT.parent
SKILLS_DIR = REPO_ROOT / "content" / "core" / "skills"
DEFAULT_OUT_DIR = REPO_ROOT / "content" / "generated"
DEFAULT_GAME_DIR = REPO_ROOT / "game" / "prototype" / "data"

NORMAL_COUNT = 1000
LEGENDARY_COUNT = 100

# the seven canonical damage types (content/core/registries/damage_types.json)
ELEMENTS = ("physical", "fire", "frost", "storm", "venom", "umbral", "blood")

# --------------------------------------------------------------------------
# element tint bands (HSV) — the spawner tints bundles per entry
# --------------------------------------------------------------------------

ELEMENT_TINT: Dict[str, Tuple[Tuple[float, float], Tuple[float, float],
                              Tuple[float, float]]] = {
    "physical": ((0.06, 0.11), (0.18, 0.38), (0.55, 0.78)),
    "fire":     ((0.015, 0.07), (0.72, 0.95), (0.80, 1.00)),
    "frost":    ((0.50, 0.56), (0.30, 0.55), (0.82, 1.00)),
    "storm":    ((0.58, 0.68), (0.45, 0.75), (0.75, 0.95)),
    "venom":    ((0.24, 0.36), (0.60, 0.90), (0.60, 0.88)),
    "umbral":   ((0.72, 0.80), (0.50, 0.80), (0.55, 0.85)),
    "blood":    ((0.965, 1.01), (0.70, 0.95), (0.55, 0.80)),
}

# --------------------------------------------------------------------------
# archetype tables (normals)
# --------------------------------------------------------------------------

ARCHETYPES = ("stalker", "lunger", "brute", "wisp")

# base body bundles per archetype: (bundle key, weight).
# Old bodies (gloamfen_stalker, gloamfen_wisp) + the five new bestiary bodies.
ARCHETYPE_BODIES: Dict[str, List[Tuple[str, float]]] = {
    "stalker": [("gloamfen_stalker", 0.40), ("fen_boar", 0.25),
                ("serpent", 0.20), ("marsh_drake", 0.15)],
    "lunger": [("serpent", 0.30), ("marsh_drake", 0.30),
               ("gloamfen_stalker", 0.25), ("fen_boar", 0.15)],
    "brute": [("golem", 0.45), ("fen_boar", 0.35), ("marsh_drake", 0.20)],
    "wisp": [("gloamfen_wisp", 0.50), ("shade", 0.50)],
}

# archetype -> (scale range, hp base, speed base)
ARCHETYPE_SHAPE: Dict[str, Tuple[Tuple[float, float], float, float]] = {
    "stalker": ((0.85, 1.20), 0.95, 1.08),
    "lunger": ((0.90, 1.25), 0.90, 1.15),
    "brute": ((1.05, 1.40), 1.20, 0.90),
    "wisp": ((0.80, 1.10), 0.78, 1.00),
}

# temperament -> (dmg factor, weight)
TEMPERAMENTS: List[Tuple[str, float, float]] = [
    ("timid", 0.78, 0.10),
    ("wary", 0.90, 0.20),
    ("restless", 1.00, 0.28),
    ("feral", 1.10, 0.22),
    ("dire", 1.22, 0.13),
    ("ravening", 1.35, 0.07),
]

SHARED_EPITHETS = [
    "Dire", "Elder", "Feral", "Pale", "Hollow", "Rabid", "Grizzled", "Lesser",
    "Great", "Ancient", "Young", "Lithe", "Scarred", "Gaunt", "Bristling",
    "Sly", "Wretched", "Gorged", "Starving", "Silent", "Shrieking",
    "Lumen-touched", "Gloom-marked", "Moss-clad", "One-eyed", "Broad-backed",
    "Long-toothed", "Night-born",
]

# --------------------------------------------------------------------------
# the twelve Veilands families (world bible: cosmology, regions, stubs)
# --------------------------------------------------------------------------

FAMILIES: Dict[str, dict] = {
    "gloamfen": {
        "adj": "Gloamfen",
        "region": "the Gloamfen",
        "abundance": 1.3,
        "elements": [("umbral", 0.5), ("venom", 0.3), ("physical", 0.2)],
        "archetypes": [("stalker", 0.45), ("wisp", 0.30), ("lunger", 0.25)],
        "epithets": ["Drowned", "Fen-lit", "Reed-born", "Lantern-eyed",
                     "Mist-veiled", "Bog-bred"],
        "nouns": ["Prowler", "Lurker", "Fenshade", "Gloomcat", "Mirecreeper",
                  "Bogfang", "Reedstrider", "Lanternjaw", "Duskpad",
                  "Fenhowler", "Murkwing", "Sedgeback"],
        "lore": [
            "Hunts where the fen glows brightest; every light it follows was once somebody's last.",
            "Drawn to bioluminescence like all Gloom-touched things — it hunts prettiest where it is brightest.",
            "The drowned forest keeps its bones and lends it new ones.",
            "Fen-guides pay it tolls of meat so the lanterns stay lit.",
            "It learned patience from the peat: everything sinks eventually.",
        ],
    },
    "emberwing": {
        "adj": "Emberwing",
        "region": "the Cinderwastes",
        "abundance": 1.0,
        "elements": [("fire", 0.70), ("storm", 0.15), ("physical", 0.15)],
        "archetypes": [("lunger", 0.50), ("stalker", 0.30), ("wisp", 0.20)],
        "bodies": {"lunger": [("marsh_drake", 0.55), ("serpent", 0.25),
                              ("gloamfen_stalker", 0.20)]},
        "epithets": ["Cinder-born", "Ash-crowned", "Flame-tempered",
                     "Soot-winged", "Ember-eyed", "Char-scaled"],
        "nouns": ["Drakeling", "Cinderhatch", "Ashwing", "Flarefang",
                  "Sootscale", "Emberkit", "Charhound", "Flamepinion",
                  "Scoriawyrm", "Kindleclaw", "Smolderling", "Ashtalon"],
        "lore": [
            "Hatched in the First Fire's grave, where the ash still remembers shapes.",
            "Sworn to a matriarch's flight; it scouts the glass flowers for trespass.",
            "Proud and territorial like all Emberkin — it counts the Cinderwastes as inheritance.",
            "Its smolder never dies; Haven smiths pay well for a coal from its gullet.",
            "It preens in updrafts off the cooling lava fields.",
        ],
    },
    "fenwitch": {
        "adj": "Fenwitch",
        "region": "the deep fen",
        "abundance": 0.9,
        "elements": [("umbral", 0.45), ("venom", 0.30), ("blood", 0.25)],
        "archetypes": [("wisp", 0.50), ("stalker", 0.25), ("lunger", 0.25)],
        "bodies": {"wisp": [("shade", 0.65), ("gloamfen_wisp", 0.35)]},
        "epithets": ["Hexed", "Crone-sworn", "Thrice-cursed", "Whispering",
                     "Cauldron-born", "Wart-blessed"],
        "nouns": ["Hexling", "Curseling", "Cacklewisp", "Marshcrone",
                  "Thistlehag", "Netherimp", "Croakmaw", "Wartongue",
                  "Banewhisper", "Gallowsmoth", "Fenwidow", "Mumblethorn"],
        "lore": [
            "One of the hag-brood: it repeats curses it has overheard, badly.",
            "Carries a stitched pouch of teeth that are not its own.",
            "Hunters hear it laughing a day before they meet it.",
            "It trades in names; never tell it yours.",
            "The fen witches send it to collect what the drowned still owe.",
        ],
    },
    "mireborn": {
        "adj": "Mireborn",
        "region": "the Gloamfen shallows",
        "abundance": 1.2,
        "elements": [("venom", 0.55), ("umbral", 0.25), ("physical", 0.20)],
        "archetypes": [("stalker", 0.40), ("lunger", 0.35), ("wisp", 0.25)],
        "bodies": {"stalker": [("serpent", 0.45), ("gloamfen_stalker", 0.35),
                               ("fen_boar", 0.20)],
                   "lunger": [("serpent", 0.55), ("marsh_drake", 0.25),
                              ("gloamfen_stalker", 0.20)]},
        "epithets": ["Silt-born", "Spore-fed", "Brood-marked", "Slick",
                     "Peat-dark", "Swarm-sent"],
        "nouns": ["Sludgeling", "Mireling", "Bogswarm", "Silthopper",
                  "Marshmite", "Oozefang", "Peatcrawler", "Murkspawn",
                  "Gnatling", "Sporeback", "Slickmaw", "Wallowbrood"],
        "lore": [
            "Mireborn swarm-life: alone it is a nuisance, and it is never alone.",
            "It carries fen-rot in its bite and its brood in its wake.",
            "Born of the shallows where the Lumen pools too thick to drink.",
            "The swarm remembers every hunter who burned a nest.",
            "It sings through its skin; the whole mire answers.",
        ],
    },
    "pyre": {
        "adj": "Pyrebound",
        "region": "the Cinderwastes",
        "abundance": 0.8,
        "elements": [("fire", 0.75), ("physical", 0.15), ("blood", 0.10)],
        "archetypes": [("brute", 0.55), ("lunger", 0.30), ("wisp", 0.15)],
        "bodies": {"brute": [("golem", 0.60), ("fen_boar", 0.40)]},
        "epithets": ["Pyre-sworn", "Kiln-born", "Slag-crowned", "Coal-hearted",
                     "Worship-fed", "Altar-marked"],
        "nouns": ["Ashwalker", "Cinderhulk", "Pyreling", "Emberbrand",
                  "Charwight", "Kilnborn", "Slagbeast", "Flamekeeper",
                  "Coalheart", "Blazeborn", "Ashpriest", "Smolderhulk"],
        "lore": [
            "It tends fires nobody lit, on altars older than the Havens.",
            "A servant-line of the Pyre Sovereign, who remembers being worshipped.",
            "Where it kneels, the ash keeps the shape of prayer.",
            "It feeds the old flame with whatever the old flame asks for.",
            "Its footprints stay warm for a season.",
        ],
    },
    "terravore": {
        "adj": "Terravore",
        "region": "the ridge country",
        "abundance": 0.9,
        "elements": [("physical", 0.75), ("fire", 0.15), ("frost", 0.10)],
        "archetypes": [("brute", 0.65), ("stalker", 0.35)],
        "bodies": {"brute": [("golem", 0.65), ("fen_boar", 0.35)],
                   "stalker": [("fen_boar", 0.55), ("gloamfen_stalker", 0.45)]},
        "epithets": ["Stone-gutted", "Vale-maker", "Ore-fed", "Patient",
                     "Mountain-born", "Slow-waking"],
        "nouns": ["Gravelmaw", "Cragback", "Stonehide", "Boulderling",
                  "Quarrybeast", "Siltgrinder", "Marrowstone", "Rubblehound",
                  "Cliffchewer", "Oregnasher", "Dustback", "Shalehorn"],
        "lore": [
            "Earthbound masonry given appetite: it eats mountains and excretes valleys.",
            "Slow, patient, nearly eternal — it has outlasted every wall built against it.",
            "Prospectors follow its droppings; the ore comes out pre-crushed.",
            "It naps for decades and wakes hungry for a hillside.",
            "A calf of the colossus lines; the mountains still flinch.",
        ],
    },
    "palewrought": {
        "adj": "Palewrought",
        "region": "the Palecrown Peaks",
        "abundance": 0.8,
        "elements": [("frost", 0.70), ("storm", 0.20), ("physical", 0.10)],
        "archetypes": [("wisp", 0.35), ("brute", 0.35), ("stalker", 0.30)],
        "bodies": {"wisp": [("gloamfen_wisp", 0.45), ("shade", 0.55)],
                   "brute": [("golem", 0.70), ("fen_boar", 0.30)]},
        "epithets": ["Frost-bound", "Crown-cold", "Hoar-veiled", "Unthawed",
                     "Echo-called", "Winter-wrought"],
        "nouns": ["Icevein", "Rimehowl", "Frostwisp", "Hoarfang", "Sleetclaw",
                  "Glacierling", "Whiteout", "Icemoth", "Shiverbeast",
                  "Palehound", "Crystalhorn", "Rimeback"],
        "lore": [
            "Frost-bound where the Lumen freezes into crowns of ice.",
            "On the peaks, sound carries for miles; so does its scream.",
            "It wears last winter like armor and next winter like a promise.",
            "Climbers leave it offerings of warmth. It keeps the warmth and the climbers.",
            "Its breath writes frost-runes no enchanter has dared to read aloud.",
        ],
    },
    "skyborne": {
        "adj": "Skyborne",
        "region": "the high peaks",
        "abundance": 0.8,
        "elements": [("storm", 0.60), ("frost", 0.20), ("physical", 0.20)],
        "archetypes": [("lunger", 0.50), ("wisp", 0.30), ("stalker", 0.20)],
        "bodies": {"lunger": [("marsh_drake", 0.60), ("serpent", 0.20),
                              ("gloamfen_stalker", 0.20)]},
        "epithets": ["Gale-born", "Peak-crowned", "Thunder-marked",
                     "Cloud-fed", "Squall-riding", "Bolt-scarred"],
        "nouns": ["Galecrest", "Stormpinion", "Thunderkite", "Windshriek",
                  "Cloudtalon", "Peakraptor", "Skydancer", "Squallwing",
                  "Zephyrhawk", "Boltfeather", "Crownvulture", "Gustling"],
        "lore": [
            "An avian line of the peaks; it nests above the weather it causes.",
            "It rides the squall down and the scream up.",
            "Guild falconers have tried to bond it for nine seasons. The peaks keep score.",
            "Lightning knows it by name and gives way.",
            "It drops what it catches from a height, out of courtesy to gravity.",
        ],
    },
    "bloomfell": {
        "adj": "Bloomfell",
        "region": "the Everbloom Wilds",
        "abundance": 1.0,
        "elements": [("venom", 0.45), ("blood", 0.30), ("physical", 0.25)],
        "archetypes": [("stalker", 0.45), ("lunger", 0.35), ("brute", 0.20)],
        "bodies": {"brute": [("fen_boar", 0.65), ("golem", 0.35)]},
        "epithets": ["Petal-hidden", "Nectar-drunk", "Sweet-toothed",
                     "Garland-clad", "Bloom-fed", "Bright-lured"],
        "nouns": ["Petalmaw", "Thornhound", "Brightlure", "Nectarfang",
                  "Pollenwisp", "Rosewretch", "Sweetjaw", "Garlandcat",
                  "Blossomback", "Sapstinger", "Orchidmaw", "Trellisviper"],
        "lore": [
            "The oldest hunting songs warn of it: the sweeter the bloom, the closer the maw.",
            "It wears the Everbloom's petals the way a hook wears bait.",
            "Nothing in the Wilds is ripe by accident; it makes sure of that.",
            "Its den smells like a festival and counts like a graveyard.",
            "It pollinates. What it pollinates with is hunters.",
        ],
    },
    "duskmaw": {
        "adj": "Duskmaw",
        "region": "the Umbral Depths",
        "abundance": 0.9,
        "elements": [("umbral", 0.55), ("blood", 0.25), ("venom", 0.20)],
        "archetypes": [("wisp", 0.45), ("stalker", 0.30), ("lunger", 0.25)],
        "bodies": {"wisp": [("shade", 0.60), ("gloamfen_wisp", 0.40)],
                   "stalker": [("gloamfen_stalker", 0.50), ("serpent", 0.50)]},
        "epithets": ["Depth-lit", "Hunger-touched", "Echo-eyed", "Deep-woven",
                     "Gloom-fed", "Beautiful"],
        "nouns": ["Depthling", "Voidgleam", "Gloomeel", "Duskgazer",
                  "Shadowfin", "Nightbloom", "Echowisp", "Murklantern",
                  "Deepshade", "Hollowgaze", "Duskmoth", "Pitchcrawler"],
        "lore": [
            "From the Umbral Depths, where the deeper you go, the more beautiful it gets. It is very deep, and very beautiful.",
            "A bloodline the Gloom touched and released — it kept a fragment of the hunger.",
            "It surfaces only where the Lumen pools; beauty is its hunting license.",
            "What it eats, it first admires.",
            "Depth-guides mark its territory with mirrors, so it stays to admire itself.",
        ],
    },
    "cinderglass": {
        "adj": "Cinderglass",
        "region": "the glass fields",
        "abundance": 0.7,
        "elements": [("fire", 0.50), ("physical", 0.30), ("storm", 0.20)],
        "archetypes": [("wisp", 0.40), ("lunger", 0.30), ("brute", 0.30)],
        "bodies": {"wisp": [("gloamfen_wisp", 0.55), ("shade", 0.45)],
                   "brute": [("golem", 0.75), ("fen_boar", 0.25)]},
        "epithets": ["Glass-grown", "Shard-plumed", "Kiln-glazed", "Prism-lit",
                     "Facet-eyed", "Mirror-hearted"],
        "nouns": ["Glasspetal", "Shardwing", "Vitriolmoth", "Splintercat",
                  "Prismhusk", "Glazefang", "Slagmoth", "Facetback",
                  "Kilnwisp", "Mirrorling", "Cindershard", "Glassthorn"],
        "lore": [
            "It grazes the Cinderwastes' glass flowers and grows its armor from the cuttings.",
            "Light bends wrong around it; hunters aim at the wrong one.",
            "Born where the First Fire fused sand into gardens.",
            "Its molt sells by the shard; its temper is not for sale.",
            "When it shatters, every splinter remembers being a creature.",
        ],
    },
    "bloodbriar": {
        "adj": "Bloodbriar",
        "region": "the Everbloom's red hollows",
        "abundance": 0.7,
        "elements": [("blood", 0.60), ("venom", 0.25), ("umbral", 0.15)],
        "archetypes": [("stalker", 0.35), ("brute", 0.35), ("wisp", 0.30)],
        "bodies": {"stalker": [("serpent", 0.45), ("gloamfen_stalker", 0.55)],
                   "brute": [("golem", 0.45), ("fen_boar", 0.55)],
                   "wisp": [("shade", 0.60), ("gloamfen_wisp", 0.40)]},
        "epithets": ["Thorn-veined", "Red-rooted", "Sap-drunk", "Lash-limbed",
                     "Vine-bound", "Crimson-crowned"],
        "nouns": ["Briarfang", "Vinewretch", "Thornheart", "Redtangle",
                  "Sapdrinker", "Cruorleaf", "Bloodpetal", "Lashvine",
                  "Crimsonbur", "Veinroot", "Skeinstalker", "Garrotebloom"],
        "lore": [
            "The briars drink red in the hollows, and it is the cup-bearer.",
            "Its thorns tithe every warm thing that passes; the Gloom banks the rest.",
            "Gardeners of the red hollows prune it back yearly. It prunes back.",
            "It blooms brightest the week after a caravan goes missing.",
            "Cut it and it keeps what you spill.",
        ],
    },
}

# --------------------------------------------------------------------------
# legendary tables
# --------------------------------------------------------------------------

LEGENDARY_BASES: List[Tuple[str, int]] = [
    ("dragon", 40), ("colossus", 30), ("hag", 30)]

BASE_ELEMENTS: Dict[str, List[Tuple[str, float]]] = {
    "dragon": [("fire", 0.40), ("storm", 0.20), ("frost", 0.15),
               ("umbral", 0.15), ("blood", 0.10)],
    "colossus": [("physical", 0.55), ("fire", 0.20), ("frost", 0.15),
                 ("storm", 0.10)],
    "hag": [("umbral", 0.40), ("venom", 0.25), ("blood", 0.25),
            ("frost", 0.10)],
}

# dragon-base uses the baked dragon-ish bundles; colossus/hag stay on the
# prototype's procedural boss art (bundle "" -> the spawner tints).
BASE_BUNDLES: Dict[str, List[Tuple[str, float]]] = {
    "dragon": [("emberwing_matriarch", 0.55), ("marsh_drake", 0.45)],
    "colossus": [("", 1.0)],
    "hag": [("", 1.0)],
}

# base -> (scale range, hp range, dmg range) inside the schema bounds
BASE_STATS: Dict[str, Tuple[Tuple[float, float], Tuple[float, float],
                            Tuple[float, float]]] = {
    "dragon": ((1.15, 1.50), (2.8, 5.0), (1.5, 2.2)),
    "colossus": ((1.30, 1.60), (3.5, 6.0), (1.3, 1.9)),
    "hag": ((1.10, 1.35), (2.5, 4.2), (1.4, 2.0)),
}

# element -> skill stems (all must exist in content/core/skills/)
ELEMENT_SKILLS: Dict[str, List[str]] = {
    "fire": ["cinder_breath", "magma_breath", "ember_bolt", "ember_screech",
             "meteor_call"],
    "physical": ["cleave", "boulder_hurl", "seismic_slam", "stone_spikes",
                 "earthshatter", "stone_upheaval"],
    "umbral": ["hex_bolt", "shadow_rend", "void_step", "abyssal_maw",
               "shrieking_curse", "wispling_call"],
    "venom": ["creeping_mire", "hex_bolt"],
    "storm": ["wing_gust", "talon_dive"],
    # no frost/blood skills shipped yet — borrow the closest reskins
    # (wing_gust = blizzard gust, hex_bolt = ice-shard bolt / blood hex)
    "frost": ["wing_gust", "hex_bolt"],
    "blood": ["shadow_rend", "abyssal_maw", "hex_bolt"],
}

BASE_SKILLS: Dict[str, List[str]] = {
    "dragon": ["talon_dive", "wing_gust", "cleave"],
    "colossus": ["seismic_slam", "earthshatter", "boulder_hurl",
                 "stone_upheaval", "stone_spikes", "cleave"],
    "hag": ["hex_bolt", "shrieking_curse", "wispling_call", "creeping_mire",
            "void_step", "abyssal_maw", "shadow_rend"],
}

FILLER_SKILLS = ["cleave", "void_step"]
# pad order for thin element/base pools (legendary kits are 5-10 skills)
PAD_SKILLS = ["ember_screech", "boulder_hurl", "hex_bolt"]

# grand-name syllables per element
NAME_HEADS: Dict[str, List[str]] = {
    "fire": ["Vhal", "Zarr", "Kor", "Pyrr", "Ashk", "Brann", "Mol", "Cynd",
             "Vur", "Skal"],
    "physical": ["Grond", "Tharn", "Krag", "Dol", "Barr", "Uld", "Mag",
                 "Torr", "Grum", "Ostr"],
    "frost": ["Isyl", "Hrim", "Vael", "Skei", "Nim", "Orl", "Kald", "Syv",
              "Bryn", "Yrsa"],
    "storm": ["Torv", "Vyx", "Zeph", "Skral", "Aur", "Kyr", "Ryn", "Galv",
              "Strak", "Ael"],
    "venom": ["Ssyl", "Vess", "Mal", "Thax", "Ophi", "Zsa", "Nagh", "Ixil",
              "Sarq", "Vyr"],
    "umbral": ["Nyx", "Vel", "Morr", "Umb", "Sath", "Dru", "Ghal", "Noc",
               "Ylth", "Verm"],
    "blood": ["Cru", "Sang", "Verr", "Rhes", "Marn", "Skarn", "Hema", "Ruth",
              "Carn", "Ichr"],
}
NAME_TAILS = ["zarr", "gon", "math", "dris", "ka", "roth", "ur", "ien", "ax",
              "oth", "issa", "wen", "ild", "eth", "orn", "veig", "ai", "ul",
              "esh", "ang"]

ROLES: Dict[str, List[str]] = {
    "dragon": ["Pyre", "Wyrm", "Scourge", "Herald", "Crown", "Tempest",
               "Maw", "Terror"],
    "colossus": ["Colossus", "Mountain", "Anvil", "Foundation", "Grinder",
                 "Pillar", "Weight", "Hunger"],
    "hag": ["Hag", "Widow", "Crone", "Weaver", "Whisper", "Matron", "Curse",
            "Choir"],
}
ORDINALS = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth",
            "Seventh", "Ninth", "Hundredth", "Last", "Unnumbered"]
EVENTS = ["Taking", "Weaving", "Kindling", "Thaw", "Blooming", "Hunt",
          "Silence", "Duologue", "Waning", "Long Night"]
PLACES = ["the Cinderwastes", "the Gloamfen", "Palecrown", "the Umbral Depths",
          "the Everbloom Wilds", "the Unfinished Rim", "the Drowned Court",
          "the First Fire's Grave", "the Hundred Havens", "the Deep Weave"]
GRAND_ADJS = ["Undying", "Thrice-Bonded", "Unbonded", "Well-Cursed",
              "Lumen-Blind", "Gloom-Fed", "Ever-Burning", "Never-Thawed",
              "Half-Woven", "Star-Eaten", "Unsnared", "Hollow-Crowned"]
# element-clashing adjectives ("Ever-Burning" frost wyrms read as mistakes)
ADJ_CLASH: Dict[str, set] = {
    "frost": {"Ever-Burning"},
    "fire": {"Never-Thawed"},
}

LEGENDARY_LORE = [
    "Older than the Havens; it remembers being worshipped, and it remembers who stopped.",
    "Seventeen Guild champions have sworn to take its spirit. It keeps their skill stones in a tidy pile.",
    "The Lumen wove around it rather than through it, and it has never forgiven the courtesy.",
    "It was offered a Soul Snare once, at the exact edge of death. It chose the hunter — as a meal.",
    "Where it walks, the land stays gorgeous and becomes lethal; corruption here beautifies.",
    "It patrols the Unfinished Rim, eating the world before the Lumen finishes weaving it.",
    "The wells refuse to recall those it takes; its kills feed the Gloom directly.",
    "Every season the theme changes and every season it does not; it is the constant the songs tune against.",
    "Its spirit would enchant a Haven's whole arsenal — which is precisely why the enchanters forbid the hunt.",
    "It once fought beside another legend and the land itself melted; hunters call the scar a Duologue.",
    "Its practiced technique has crystallized into skill stones twice. Both stones scream.",
    "No bestiary agrees on its shape, because no witness account was finished.",
]


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------


def _wchoice(rng: random.Random, table: Sequence[Tuple[str, float]]) -> str:
    return rng.choices([t[0] for t in table], [t[1] for t in table])[0]


def _tint(rng: random.Random, element: str) -> str:
    (h0, h1), (s0, s1), (v0, v1) = ELEMENT_TINT[element]
    h = rng.uniform(h0, h1) % 1.0
    s = rng.uniform(s0, s1)
    v = rng.uniform(v0, v1)
    r, g, b = colorsys.hsv_to_rgb(h, s, min(v, 1.0))
    return f"{int(r * 255):02x}{int(g * 255):02x}{int(b * 255):02x}"


def _slug(name: str) -> str:
    s = "".join(c if c.isalnum() else "_" for c in name.lower())
    while "__" in s:
        s = s.replace("__", "_")
    return s.strip("_")


def _clamp(x: float, lo: float, hi: float) -> float:
    return round(max(lo, min(hi, x)), 2)


def _skill_ids() -> Dict[str, str]:
    """stem -> canonical skill id, read from content/core/skills/."""
    out = {}
    for p in sorted(SKILLS_DIR.glob("*.json")):
        data = json.loads(p.read_text())
        out[p.stem] = data["id"]
    return out


# --------------------------------------------------------------------------
# normals
# --------------------------------------------------------------------------


def generate_normals(rng: random.Random) -> List[dict]:
    fam_keys = list(FAMILIES)
    fam_weights = [FAMILIES[k]["abundance"] for k in fam_keys]
    used_names: set = set()
    used_slugs: set = set()
    entries: List[dict] = []

    while len(entries) < NORMAL_COUNT:
        fam_key = rng.choices(fam_keys, fam_weights)[0]
        fam = FAMILIES[fam_key]

        # name: epithet/adjective x family noun, collision-rejected
        name = None
        for _ in range(64):
            noun = rng.choice(fam["nouns"])
            roll = rng.random()
            if roll < 0.45:
                cand = f"{rng.choice(SHARED_EPITHETS)} {noun}"
            elif roll < 0.72:
                cand = f"{rng.choice(fam['epithets'])} {noun}"
            elif roll < 0.90:
                cand = f"{fam['adj']} {noun}"
            else:
                cand = (f"{rng.choice(SHARED_EPITHETS)} "
                        f"{rng.choice(fam['epithets'])} {noun}")
            slug = _slug(cand)
            if cand not in used_names and slug not in used_slugs:
                name = cand
                break
        if name is None:
            continue
        used_names.add(name)
        used_slugs.add(slug)

        archetype = _wchoice(rng, fam["archetypes"])
        bodies = fam.get("bodies", {}).get(archetype, ARCHETYPE_BODIES[archetype])
        bundle = _wchoice(rng, bodies)
        element = _wchoice(rng, fam["elements"])

        # stats: big = slow = tanky; temperament drives damage
        (s_lo, s_hi), hp_base, spd_base = ARCHETYPE_SHAPE[archetype]
        scale = _clamp(rng.uniform(s_lo, s_hi), 0.8, 1.4)
        dmg_f = rng.choices([t[1] for t in TEMPERAMENTS],
                            [t[2] for t in TEMPERAMENTS])[0]
        hp = _clamp(hp_base * (0.45 + 0.62 * scale) + rng.uniform(-0.06, 0.06),
                    0.7, 1.6)
        speed = _clamp(spd_base - 0.35 * (scale - 1.0) + rng.uniform(-0.05, 0.05),
                       0.8, 1.3)
        dmg = _clamp(dmg_f * (0.85 + 0.18 * (scale - 1.0)) + rng.uniform(-0.05, 0.05),
                     0.7, 1.5)
        gold = _clamp(0.55 + 0.62 * (hp * dmg) + rng.uniform(-0.05, 0.08),
                      0.8, 2.0)

        entries.append({
            "id": f"gen.creature.{slug}",
            "name": name,
            "archetype": archetype,
            "bundle": bundle,
            "element": element,
            "tint": _tint(rng, element),
            "scale": scale,
            "hp_mult": hp,
            "dmg_mult": dmg,
            "speed_mult": speed,
            "gold_mult": gold,
            "lore": rng.choice(fam["lore"]),
        })
    return entries


# --------------------------------------------------------------------------
# legendaries
# --------------------------------------------------------------------------


def _grand_name(rng: random.Random, element: str, base: str,
                used: set) -> str:
    adjs = [a for a in GRAND_ADJS if a not in ADJ_CLASH.get(element, set())]
    for _ in range(128):
        pname = rng.choice(NAME_HEADS[element]) + rng.choice(NAME_TAILS)
        roll = rng.random()
        role = rng.choice(ROLES[base])
        if roll < 0.40:
            cand = (f"{pname}, {role} of the {rng.choice(ORDINALS)} "
                    f"{rng.choice(EVENTS)}")
        elif roll < 0.65:
            cand = f"{pname}, {role} of {rng.choice(PLACES)}"
        elif roll < 0.85:
            cand = f"{pname} the {rng.choice(adjs)}"
        else:
            cand = f"{pname}, {rng.choice(adjs)} {role}"
        if cand not in used and pname not in {u.split(",")[0].split(" the ")[0]
                                              for u in used}:
            return cand
    raise RuntimeError("grand-name space exhausted")


def _kit(rng: random.Random, element: str, base: str,
         skill_ids: Dict[str, str]) -> List[str]:
    elem_pool = ELEMENT_SKILLS[element]
    pool: List[str] = []
    for stem in elem_pool + BASE_SKILLS[base] + FILLER_SKILLS:
        if stem not in pool:
            pool.append(stem)
    for stem in PAD_SKILLS:  # keep the 5-skill kit floor reachable
        if len(pool) >= 5:
            break
        if stem not in pool:
            pool.append(stem)
    for stem in pool:
        if stem not in skill_ids:
            raise RuntimeError(f"kit table references unknown skill '{stem}'")
    k = rng.randint(5, min(10, len(pool)))
    kit: List[str] = []
    if elem_pool:  # signature first: fire dragons breathe, earth bases quake
        kit.append(rng.choice(elem_pool))
    rest = [s for s in pool if s not in kit]
    rng.shuffle(rest)
    kit.extend(rest[: k - len(kit)])
    return [skill_ids[s] for s in kit]


def generate_legendaries(rng: random.Random, used_names: set,
                         used_slugs: set) -> List[dict]:
    skill_ids = _skill_ids()
    bases: List[str] = []
    for base, count in LEGENDARY_BASES:
        bases.extend([base] * count)
    rng.shuffle(bases)

    entries: List[dict] = []
    for base in bases:
        element = _wchoice(rng, BASE_ELEMENTS[base])
        name = _grand_name(rng, element, base, used_names)
        slug = _slug(name)
        if slug in used_slugs:
            continue  # deterministic retry below keeps the count exact
        used_names.add(name)
        used_slugs.add(slug)

        (s_lo, s_hi), (h_lo, h_hi), (d_lo, d_hi) = BASE_STATS[base]
        lore_bits = rng.sample(LEGENDARY_LORE, 2)
        lore = lore_bits[0] if rng.random() < 0.45 else " ".join(lore_bits)

        entries.append({
            "id": f"gen.creature.{slug}",
            "name": name,
            "base": base,
            "bundle": _wchoice(rng, BASE_BUNDLES[base]),
            "element": element,
            "tint": _tint(rng, element),
            "scale": _clamp(rng.uniform(s_lo, s_hi), 1.1, 1.6),
            "hp_mult": _clamp(rng.uniform(h_lo, h_hi), 2.5, 6.0),
            "dmg_mult": _clamp(rng.uniform(d_lo, d_hi), 1.3, 2.2),
            "kit": _kit(rng, element, base, skill_ids),
            "lore": lore,
        })

    while len(entries) < LEGENDARY_COUNT:  # top up any slug collisions
        base = rng.choice([b for b, _ in LEGENDARY_BASES])
        element = _wchoice(rng, BASE_ELEMENTS[base])
        name = _grand_name(rng, element, base, used_names)
        slug = _slug(name)
        if slug in used_slugs:
            continue
        used_names.add(name)
        used_slugs.add(slug)
        (s_lo, s_hi), (h_lo, h_hi), (d_lo, d_hi) = BASE_STATS[base]
        entries.append({
            "id": f"gen.creature.{slug}",
            "name": name,
            "base": base,
            "bundle": _wchoice(rng, BASE_BUNDLES[base]),
            "element": element,
            "tint": _tint(rng, element),
            "scale": _clamp(rng.uniform(s_lo, s_hi), 1.1, 1.6),
            "hp_mult": _clamp(rng.uniform(h_lo, h_hi), 2.5, 6.0),
            "dmg_mult": _clamp(rng.uniform(d_lo, d_hi), 1.3, 2.2),
            "kit": _kit(rng, element, base, skill_ids),
            "lore": rng.choice(LEGENDARY_LORE),
        })
    return entries


# --------------------------------------------------------------------------
# catalog assembly + CLI
# --------------------------------------------------------------------------


def build_catalogs(seed: int, date: Optional[str] = None) -> Tuple[dict, dict]:
    rng = random.Random(seed)
    normals = generate_normals(rng)
    used_names = {e["name"] for e in normals}
    used_slugs = {e["id"].rsplit(".", 1)[1] for e in normals}
    legendaries = generate_legendaries(rng, used_names, used_slugs)

    provenance = {
        "generator": GENERATOR,
        "version": VERSION,
        "seed": seed,
        "date": date or _dt.date.today().isoformat(),
        "grounding": ["genforge/lore/world-bible.md",
                      "content/core/registries/damage_types.json",
                      "content/core/skills/"],
        "families": sorted(FAMILIES),
    }
    normal_doc = {"version": 1, "provenance": dict(provenance, tier="normal"),
                  "entries": normals}
    legendary_doc = {"version": 1,
                     "provenance": dict(provenance, tier="legendary"),
                     "entries": legendaries}
    return normal_doc, legendary_doc


def write_catalogs(normal_doc: dict, legendary_doc: dict,
                   out_dir: Path, game_dir: Optional[Path]) -> List[Path]:
    written: List[Path] = []
    targets = [out_dir] + ([game_dir] if game_dir else [])
    for target in targets:
        target.mkdir(parents=True, exist_ok=True)
        for fname, doc in (("bestiary_normal.json", normal_doc),
                           ("bestiary_legendary.json", legendary_doc)):
            path = target / fname
            path.write_text(json.dumps(doc, indent=1) + "\n")
            written.append(path)
    return written


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python -m genforge.pipeline.bestiary_gen",
        description="Generate the 1000-normal + 100-legendary bestiary catalogs.",
    )
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR),
                    help="canonical catalog directory (default: content/generated)")
    ap.add_argument("--game-dir", default=str(DEFAULT_GAME_DIR),
                    help="prototype snapshot directory (default: "
                         "game/prototype/data); pass '' to skip")
    ap.add_argument("--date", default=None,
                    help="pin the provenance date (default: today)")
    args = ap.parse_args(argv)

    normal_doc, legendary_doc = build_catalogs(args.seed, args.date)
    game_dir = Path(args.game_dir) if args.game_dir else None
    written = write_catalogs(normal_doc, legendary_doc, Path(args.out_dir),
                             game_dir)

    n, l = normal_doc["entries"], legendary_doc["entries"]
    print(f"  normals: {len(n)} entries | archetypes: "
          + ", ".join(f"{a}:{sum(1 for e in n if e['archetype'] == a)}"
                      for a in ARCHETYPES))
    print(f"  legendaries: {len(l)} entries | bases: "
          + ", ".join(f"{b}:{sum(1 for e in l if e['base'] == b)}"
                      for b, _ in LEGENDARY_BASES))
    print(f"  elements: "
          + ", ".join(f"{el}:{sum(1 for e in n + l if e['element'] == el)}"
                      for el in ELEMENTS))
    for p in written:
        print(f"  wrote {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
