# prototype/data/ — hand-synced content snapshots

synced by hand from content/core — replaced by dh-content at M1.
KEEP IN SYNC: every file here (except `runes.json`) must have a matching
definition under `content/core/`, and `python3 tools/validate_content.py`
must stay green.

- `reaver.json` · `cleave.json` · `stats.json` · `abyssal.json` — class, skill,
  stat registry, pet family (unchanged from the first slice)
- item bases (items.gd loot pools): `emberfang_blade` (the Matriarch's unique),
  `emberglass_staff`, `gloamhide_vest`, `fenwarden_helm`, `mirebound_boots`,
  `duskwarden_amulet`, `palecrown_signet`
- affixes (rarity rolls 0/1/2/3/4): `of_embers`, `stalwart`, `brutal`,
  `vigorous`, `of_keenness`
- `abyssal_remnant.json` — Spirit Essence (enchanting material, drops from
  abyssal kills)
- `runes.json` — PROTOTYPE-ONLY registry (runes are canon §4 but have no
  content schema yet; all rune numbers are proposals)
- boss creature snapshots (hag.gd / duo prototype numbers are these at
  prototype scale): `fenwitch_hag.json` (Elite mid-boss, 5-skill kit),
  `pyre_sovereign.json` · `terravore_colossus.json` (the Legendary duo whose
  fire + earth fields fuse into LAVA — the Duologue, canon §4)
