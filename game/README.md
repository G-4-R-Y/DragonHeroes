# game/ — Godot client (presentation only)

Canon §10 rule 2: **zero gameplay rules here.** The client renders replicated state,
plays animations, and forwards inputs. If a number affects combat, it lives in
`content/` and executes in `sim/`.

- `scenes/` — UI, HUD, menus.
- `presentation/` — entity views, VFX, palette-LUT shaders, animation drivers.
- `autoload/` — session/bootstrap singletons (GDScript glue only).
- `addons/dh_godot/` — arrives when `sim/libs/dh-godot` joins the build (local-hero
  prediction embeds the same simulation library the server runs).

Display baseline: 640×360 viewport, integer scaling, nearest filtering (pixel art),
`mobile` renderer — locked 60 FPS on mid-range mobile is a canon mandate; every
visual feature ships with a frame-time budget (docs/design/17).
