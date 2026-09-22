# UI identity — actual OpenGL captures

2026-09-12 first UI identity pass: bronze/ivory/Lumen shared theme, shrine
backdrops, engraved framing, rune-shaped volume sliders, keyboard focus and
artifact collection cards. These are actual game captures, not generated
mockups. The shrine source and original generation provenance remain under
`docs/art/playable-shrine/`; the frame and slider are code/vector artwork.

- [Main menu](main-menu.png) and [Portuguese](main-menu-pt.png)
- [Options](options.png)
- [Artifact collection](collection.png)
- [Haven](haven.png)

The sidecar JSON files record a short 1280×720 desktop sample on Intel Mesa
using `gl_compatibility`, the 640×360 integer UI grid, a 60 FPS cap and 120
settling frames. All five samples report 60 FPS; process CPU varies from
1.278 to 7.363ms, with 27–68 draw calls. This is a snapshot of process CPU,
not complete GPU frame time or a sustained/mobile performance claim.
The menu backdrop reuses the existing shrine texture. Engraving is a single
cached CanvasItem redrawn only on resize; there is no new frame callback.

Reproduce with isolated `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`
so captures never alter a player's language, volume or saves:

```bash
UI_WAIT=120 UI_TAG=identity_menu UI_LANG=en \
  UI_SCENE=res://prototype/ui/main_menu.tscn \
  godot --path game --rendering-method gl_compatibility --max-fps 60 \
  res://prototype/tests/ui_capture.tscn
```

`UI_TAG=cue*` (R64) stages the skill-cooldown cues: it logs a throwaway
`cue_capture` hunter carrying four different skill kinds, puts all four slots in
different cue states through the shipping path (one deep in cooldown, one
denied, one mid-bloom, one calm) and writes the frame plus two
nearest-neighbour insets at 4x the logical pixel — `_feet` (the ground fan) and
`_hotbar` (the chips it must agree with). The insets cross canvas coordinates
into window space by the integer stretch factor first, so they stay correct
whatever `window_width_override` is. The JSON carries `cue_arcs` (budget: 12).

Use `UI_LANG=pt` for Portuguese, `UI_OPTIONS=1` for the options modal,
`UI_SCENE=res://living/lair_menu.tscn` for the collection, or
`UI_SCENE=res://prototype/ui/haven.tscn UI_TAG=haven_identity` for Haven.
Captures and JSON first land in `game/prototype/tests/captures/`; use unique
tags to preserve older reference captures. The Haven tag initializes a hunter
inside the isolated profile. UI follow-ups are tracked in design/26 and the
roadmap (production HUD, class sigils, bestiary and ordinary gear migration).

[Combat with the shared theme](practice.png) and [its metrics](practice.json)
were captured after the compatibility suite. Compare against the earlier
practice frame and metrics in `../lair-journey/`; no combat rules or pools
changed in this presentation pass.
