# Prompt template — creature generation

Every creature request composes, in order:

1. **Lore grounding** — relevant sections of `../lore/world-bible.md`: the target
   family's entry (mandatory), the target biome's entry (mandatory), plus the hard
   lore rules block (always).
2. **Season grounding** — the active season file from `../seasons/`: themes,
   narrative, palette bias.
3. **Mechanical constraints** — the JSON Schema `content/schemas/creature.schema.json`
   verbatim, plus canon rules restated: tier skill counts (normal ≥1, elite ≥5,
   legendary 5–10 with optional duo_partners), the seven damage types, archetype list,
   stat bands for the target tier/rarity (from the design bible), family skill-pool
   coherence (new family-shared skills must be justified by the family's lore entry).
4. **The request** — `{biome, family, tier, rarity, archetype?, theme_tags}`.
5. **Output contract** — return: (a) `definition.json` conforming to the schema,
   (b) a `description` field written in the world's voice (see bible tone), (c) a
   `sprite_brief` for the image stage: silhouette description, palette (biome accent +
   family colors), animation set required by the archetype rig, telegraph color
   compliance (design/17 §6.1), (d) `lore_refs`: which bible sections it drew on.

Post-conditions enforced by the pipeline, not trust: `tools/validate_content.py`
gauntlet, balance lints, human curation, RL exploit-finder pass.
