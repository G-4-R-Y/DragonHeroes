#!/usr/bin/env bash
# Vendor godot-cpp for the dh-godot GDExtension.
#
# Pinned to a TAG, not a branch: the bindings must match the engine, and a
# moving branch would silently change what the extension is built against.
# godot-cpp has no 4.6 branch — godot-4.5-stable is the newest tag, and
# GDExtension is forward compatible, so an extension built against 4.5 headers
# loads in Godot 4.6 (the .gdextension declares compatibility_minimum = "4.5").
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${GODOT_CPP_TAG:-godot-4.5-stable}"
DEST="sim/libs/dh-godot/third_party/godot-cpp"
if [ -d "$DEST/.git" ]; then
  echo "godot-cpp already vendored at $DEST ($(git -C "$DEST" describe --tags 2>/dev/null || echo unknown))"
  exit 0
fi
mkdir -p "$(dirname "$DEST")"
git clone --depth 1 --branch "$TAG" https://github.com/godotengine/godot-cpp "$DEST"
echo "vendored godot-cpp $TAG -> $DEST"
