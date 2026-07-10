# dh-godot — GDExtension bindings (godot-cpp)

Exposes `dh-sim` to the Godot client for **local-hero prediction** (docs/tech/22 §3):
the client embeds the same simulation library as the server and replays unacknowledged
inputs on top of authoritative snapshots.

Not in the CMake build yet. Joining the build requires:

1. Vendor [godot-cpp](https://github.com/godotengine/godot-cpp) matching the Godot
   4.6+ branch (git submodule under `third_party/godot-cpp`).
2. `CMakeLists.txt` here building a `libdhgodot` shared library linking `dh-sim`,
   `dh-net`, `dh-content`.
3. A `dh_godot.gdextension` descriptor in `game/addons/dh_godot/`.

Scope discipline (canon §10): this library is *bindings only* — no gameplay rules, no
rendering logic. It marshals inputs in and replicated state out.
