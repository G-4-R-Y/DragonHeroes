# genforge/living/validation.py

Entry point load_validated()/validate() checks expansion.schema.json, then the
narrative contract and existing lore, effect, skill, creature, art and rarity
references/budgets. source_path confines inputs to real files inside the supplied
repository root, including symlink resolution. Invalid candidates fail closed.

Private _ancestors/_remaining propagate narrative cycle/work limits; callers
normally supply only release and optional root. Schema checks precede property
access, so malformed candidate data yields diagnostics. No official promotion or
live save migration occurs. Gates: test_living.py, test_narrative.py, validate_content.py.
