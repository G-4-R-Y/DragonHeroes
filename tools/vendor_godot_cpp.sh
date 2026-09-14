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

# Upstream fixes we carry. The checkout is untracked and re-clonable, so a
# patch that lives only in the working tree is lost on the next vendor; each
# one goes here, idempotent, and is re-applied on every run.
patch_godot_cpp() {
  # src/godot.cpp calls realloc()/free() but includes only <stdio.h>. glibc's
  # libstdc++ drags <stdlib.h> in transitively so the Linux build never notices;
  # llvm-mingw's libc++ does not, so the Windows cross-build fails with
  # "use of undeclared identifier 'realloc'". (godot-4.5-stable, 2026-09-13.)
  local f="$DEST/src/godot.cpp"
  if [ -f "$f" ] && ! grep -q '^#include <stdlib.h>' "$f"; then
    sed -i 's|^#include <stdio.h>$|#include <stdio.h>\n#include <stdlib.h>|' "$f"
    echo "patched $f (+<stdlib.h> for realloc/free)"
  fi
}

if [ -d "$DEST/.git" ]; then
  echo "godot-cpp already vendored at $DEST ($(git -C "$DEST" describe --tags 2>/dev/null || echo unknown))"
  patch_godot_cpp
  exit 0
fi
mkdir -p "$(dirname "$DEST")"
git clone --depth 1 --branch "$TAG" https://github.com/godotengine/godot-cpp "$DEST"
patch_godot_cpp
echo "vendored godot-cpp $TAG -> $DEST"
