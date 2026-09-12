# Lair journey — actual game captures

1280×720 OpenGL captures from the Codex branch after integrating GitHub
`08f92d6`: seeded bell entrance, native victory/unlock, persisted collection,
boss-rush reward, current practice fight and merged main menu.

`tools/check_lair_journey.py --capture` drives ordinary movement/skill input
through the real helper, earns two items, returns to the same Hunt and starts
rush round two. `render-metrics.json` records that run: 60 FPS, 2.033 ms process
CPU, 89 draws and 277 µs peak doorway draw CPU. Short desktop sample; no mobile
or worst-case claim. The final practice capture also checks button spacing.

The doorway is a bounded code-drawn pixel prop, with C++ placement metadata.
The arena plate and Orun source/prompt provenance remain in
[playable-shrine](../playable-shrine/README.md) and the GenForge chapter. These
are game frames; no image-generation call was used for this follow-up.
