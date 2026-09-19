"""Creature descriptions for the master prompt's first slot.

Each spec is what the model is told about the creature plus what the
POST-PROCESS needs to know that a prompt cannot guarantee: which hue the
emissive core is (so the Emissive Channel Mask isolates the right pixels)
and whether the creature has one at all. Descriptions follow canon/design
lore where it exists (Orun: design/26; the arena roster: content/core/arena).
Keys match the arena roster and the prototype bundles so a hifi bundle can
replace a baked actor sheet one for one.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .spec import EXAMPLE_CREATURE, GRID_PX, PromptSpec, build_prompt


@dataclass(frozen=True)
class CreatureSpec:
    key: str
    name: str
    description: str
    emissive_hue_deg: Optional[float]      # OKLab hue of the glow; None = no core
    emissive_label: str = ""
    grid_px: int = GRID_PX
    ramps: int = 6                         # material ramps the palette builder targets
    tags: List[str] = field(default_factory=list)

    @property
    def has_emissive(self) -> bool:
        return self.emissive_hue_deg is not None

    def prompt(self, stance: Optional[str] = None) -> PromptSpec:
        return build_prompt(self.description, stance=stance, grid_px=self.grid_px)


# OKLab hue anchors (degrees): cyan ~195, teal ~180, amber ~70, ember ~40,
# violet ~300, acid green ~135, bone white has no hue (None).
CYAN, TEAL, AMBER, EMBER, VIOLET, ACID = 195.0, 180.0, 70.0, 40.0, 300.0, 135.0

_SPECS: List[CreatureSpec] = [
    CreatureSpec(
        "orun", "Orun, the Last Bellwether",
        # design/26: lean moss-armored cervid, cracked bronze bell between the
        # antlers, visible Lumen heart. The brief's example is the same animal.
        "Orun the Last Bellwether: lean ancient moss-armored guardian stag boss, "
        "massive petrified wood antlers carrying a cracked hanging bronze bell, "
        "shelf mushrooms and ivory fungus on the back, hanging moss, four cervid "
        "legs, long bone-pale face, glowing turquoise Lumen crystal core in chest",
        CYAN, "turquoise Lumen heart", tags=["boss", "gloamfen", "bellwether"]),
    CreatureSpec(
        "bellwether_example", "The brief's worked example (verbatim)",
        EXAMPLE_CREATURE, CYAN, "glowing crystal core", tags=["example"]),
    CreatureSpec(
        "fen_boar", "Fen Boar Alpha",
        "Fen Boar Alpha: hulking marsh boar, mud-caked bristled hide, cracked "
        "tusks wrapped in reed cord, moss and peat clinging to the shoulders, "
        "small ember-lit eyes, low charging bulk",
        EMBER, "ember eyes", tags=["gloamfen", "arena"]),
    CreatureSpec(
        "gloamfen_stalker", "Gloamfen Stalker",
        "Gloamfen Stalker: gaunt long-limbed swamp predator, wet black fur over "
        "ridged bone plates, hooked claws, lantern-like bioluminescent eyes and "
        "glowing teal spore sacs along the spine, prowling low",
        TEAL, "teal spore sacs", tags=["gloamfen", "arena"]),
    CreatureSpec(
        "cinder_drake", "Cinder Drake",
        "Cinder Drake: lean four-legged marsh drake, charcoal scales cracked "
        "with glowing ember seams, tattered membranous wings folded, smoking "
        "jaw, molten orange fire core burning in the throat",
        EMBER, "ember seams and throat fire", tags=["cinderwastes", "arena"]),
    CreatureSpec(
        "bog_golem", "Bog Golem",
        "Bog Golem: squat massive construct of sunken stone and packed peat, "
        "roots and rusted chains binding the boulders, runes glowing sickly "
        "acid-green in the chest cavity, dripping bog water",
        ACID, "acid-green runes", tags=["gloamfen", "arena"]),
    CreatureSpec(
        "mire_serpent", "Mire Serpent",
        "Mire Serpent: thick coiled swamp serpent, oily green-black scales with "
        "pale belly plates, fanned bony hood, dripping fangs, glowing violet "
        "venom glands under the jaw",
        VIOLET, "violet venom glands", tags=["gloamfen", "arena"]),
    CreatureSpec(
        "grave_shade", "Grave Shade",
        "Grave Shade: hunched spectral wraith in rotted burial shroud, hollow "
        "ribcage showing through torn cloth, long grasping fingers, single cold "
        "cyan soul-flame burning where the heart was",
        CYAN, "cyan soul-flame", tags=["undead", "arena"]),
    CreatureSpec(
        "gloam_wisp", "Gloam Wisp",
        "Gloam Wisp: small drifting marsh spirit, a knot of dark thorn and wet "
        "reed around a blazing teal will-o'-wisp core, trailing motes",
        TEAL, "teal wisp core", tags=["gloamfen", "arena"]),
    CreatureSpec(
        "fenwitch_hag", "Fenwitch Hag",
        "Fenwitch Hag: stooped ancient swamp witch, ragged layered robes of moss "
        "and hide, crooked staff of black willow hung with bone charms, long "
        "grey hair, eyes and clutched hex-lantern burning violet",
        VIOLET, "violet hex-lantern", tags=["boss", "gloamfen"]),
    CreatureSpec(
        "pyre_sovereign", "Pyre Sovereign",
        "Pyre Sovereign: towering armored fire lord, blackened iron plate over "
        "cracked obsidian skin, crown of jagged basalt, a great two-handed "
        "blade, molten amber fire raging through the seams and the eye slits",
        AMBER, "molten amber seams", tags=["boss", "cinderwastes"]),
    CreatureSpec(
        "terravore_colossus", "Terravore Colossus",
        "Terravore Colossus: colossal stone-plated beast, shoulders like cliff "
        "faces, moss and stunted trees rooted in its back, four pillar legs, "
        "small deep-set eyes and rune scars glowing acid-green",
        ACID, "acid-green rune scars", tags=["boss"]),
    CreatureSpec(
        "ashwing_matriarch", "Ashwing Matriarch",
        "Ashwing Matriarch: vast ash-grey dragon matriarch, wings ragged and "
        "scorched, horned skull crest, sagging jaw lit by ember breath, chest "
        "furnace glowing orange through cracked plates",
        EMBER, "chest furnace", tags=["boss"]),
]

REGISTRY: Dict[str, CreatureSpec] = {s.key: s for s in _SPECS}


def get(key: str) -> CreatureSpec:
    try:
        return REGISTRY[key]
    except KeyError:
        raise KeyError(f"unknown creature '{key}'; known: {sorted(REGISTRY)}") from None


def custom(description: str, emissive_hue_deg: Optional[float], key: str = "custom",
           grid_px: int = GRID_PX, ramps: int = 6) -> CreatureSpec:
    """An ad-hoc creature (CLI --describe)."""
    return CreatureSpec(key, key, description, emissive_hue_deg, grid_px=grid_px, ramps=ramps)
