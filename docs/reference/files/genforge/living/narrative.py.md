# genforge/living/narrative.py

Offline semantic validator for narrative.schema.json. validation.py calls it
only after expansion schema validation. Checks stable typed local references,
unique story IDs, exactly one archetype per creature, creature/artifact thread
coverage, explicit cross-release links, pinned dependency hashes and namespace
collisions. Political outcomes are prose-only candidate data, never executable.

Recursion rejects cycles, more than eight ancestor chapters or 32 dependency
visits. Long-lived release history will need a reviewed compact history anchor;
this initial gate does not claim that tooling is implemented. fen_bells is the
explicit genesis grounded in the world bible. Other packs require prior history.

grounded_dependencies rechecks pinned bytes before briefs/builds and returns the
transitive story inputs so build identity includes them. No network/model calls.
Gates: genforge/tests/test_narrative.py and test_living.py. Law: design/28, tech/34.
