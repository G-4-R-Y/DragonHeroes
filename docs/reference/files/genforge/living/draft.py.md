# genforge/living/draft.py

Creates an unreviewed next-chapter draft from a validated repository release.
Remaps local IDs; pins the source JSON hash; adds a marked placeholder continuation
link to the old thread. It deliberately retains inherited art/stories for editing.
Deleting the dependency does not produce a valid new disconnected chapter.

CLI --from must live under genforge/releases; --out uses exclusive creation to
avoid overwriting another author's work. No generator/model calls and no approval
status. test_living.py and test_narrative.py prove local namespace remapping plus
preserved historical references. Law: design/28, tech/34.
