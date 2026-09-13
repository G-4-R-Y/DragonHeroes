#!/usr/bin/env bash
# Build the dh-godot GDExtension and install it into game/addons/dh_godot/.
#
# What it buys (measured 2026-09-13, idle box, neural vs neural):
#   nested-Array GDScript   ~986 us/tick   (the original)
#   flat GDScript            566 us/tick   (1.74x)
#   C++ (this)               105 us/tick   (5.39x more, 9.4x total)
# Fights are bit-identical at every step — verified, because the registry's nets
# were trained against the GDScript runtime.
#
# Both godot-cpp targets are built: template_debug is what the Godot EDITOR
# binary loads (training uses that today) and template_release is what the
# release trainer export needs (tools/build_arena.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
source "$REPO/tools/dh_term.sh"

dh_banner "DH-GODOT EXTENSION"

[ -f sim/libs/dh-godot/third_party/godot-cpp/CMakeLists.txt ] || {
  dh_say "godot-cpp not vendored — fetching it"
  tools/vendor_godot_cpp.sh
}

ADDON="$REPO/game/addons/dh_godot"
mkdir -p "$ADDON"
for TARGET in template_debug template_release; do
  BUILD="sim/build-godot-${TARGET#template_}"
  dh_kv building "$TARGET"
  cmake -S sim -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DDH_GODOT_TARGET="$TARGET" >/dev/null
  cmake --build "$BUILD" --target dhgodot -j "$(nproc)" >/dev/null
  cp "$BUILD/libs/dh-godot/libdhgodot.linux.$TARGET.x86_64.so" "$ADDON/"
done

# Godot registers a .gdextension during a filesystem scan, not on first run: a
# freshly built .so is invisible until the project is imported once.
godot --headless --path game --import >/dev/null 2>&1 || true

if grep -q "dh_godot.gdextension" game/.godot/extension_list.cfg 2>/dev/null; then
  dh_ok "extension registered with the project"
else
  dh_err "Godot did not register the extension — check game/addons/dh_godot/"
  exit 1
fi
dh_ok "built: $(ls "$ADDON"/*.so | wc -l) libraries in game/addons/dh_godot/"
dh_say "the arena uses it automatically; without it the GDScript path runs instead"
