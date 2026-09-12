# Playable bell shrine

The [shrine backdrop](../../../game/living/shrine.png) is an original
2120×742 environment plate generated with built-in `image_gen`. The model
identity is not exposed by the tool. [Exact prompt](prompt.txt) and
[source hash/provenance](provenance.json) are preserved here. The original
PNG is unchanged; Godot draws it inside the trial's 640×224 arena rectangle.
Existing repository art licensing applies.

[Trial capture](trial-capture.png) is an actual 1280×720 OpenGL game frame,
with the generated Orun atlas, authoritative encounter and HUD composited.
This capture is distinct from the generated environment artwork.

Reproduce a frame: `python3 tools/check_living_preview.py --capture`.

[Main-menu capture](menu-capture.png) shows the direct playable-content entry.
