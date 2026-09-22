#!/usr/bin/env bash
# Package Dragon Heroes for friends (docs/USAGE.md §distributing).
# Produces builds/dragon-heroes-<platform>.zip containing:
#   - the standalone game binary (Godot export, no Godot install needed)
#   - dh-server(.exe) — the worldgen binary; REQUIRED for infinite worlds and
#     co-op world parity (world_gen finds it next to the executable)
#   - LEIA-ME / README quickstart
#
# One-time prerequisites (machine doing the packaging):
#   1. Godot export templates for 4.6 (~1 GB): Editor -> Manage Export
#      Templates, or run this script with DH_FETCH_TEMPLATES=1 to download
#      them via godot's CLI into ~/.local/share/godot/export_templates/.
#   2. sim built for the TARGET platform: Linux = `cmake --build sim/build`.
#      Windows dh-server.exe = the portable llvm-mingw cross build (no sudo):
#        cmake -S sim -B sim/build-windows \
#          -DCMAKE_TOOLCHAIN_FILE=$PWD/sim/cmake/mingw-w64-x86_64.cmake \
#          -DCMAKE_BUILD_TYPE=Release && cmake --build sim/build-windows -j
#        cp sim/build-windows/libs/dh-server/dh-server.exe sim/build-windows/
#      (toolchain lives at ~/.local/share/dh-toolchains — fetched once, ~80 MB)
#      Without the toolchain, builds/prebuilt/windows/dh-server.exe is used —
#      a committed cache so a clean clone can still ship a complete Windows zip.
#
# Usage: tools/package_game.sh [windows|linux|all]   (default: all available)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=builds
mkdir -p "$OUT"

fetch_templates() {
  # Official 4.6.stable export templates (.tpz) — downloaded once per machine.
  local dir="$HOME/.local/share/godot/export_templates/4.6.stable"
  if [ -d "$dir" ] && ls "$dir" | grep -q "windows"; then return 0; fi
  echo "[package] fetching Godot 4.6 export templates (~1 GB)..."
  mkdir -p "$dir"
  local tpz="/tmp/opencode/godot_templates.tpz"
  curl -fL "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz" -o "$tpz"
  (cd "$dir" && unzip -oq "$tpz" && mv templates/* . && rmdir templates)
  rm -f "$tpz"
}

pack() {
  local plat="$1" preset="$2" exe="$3" dhbin="$4"
  echo "[package] exporting $plat..."
  mkdir -p "$OUT/$plat"
  godot --headless --path game --export-release "$preset" 2>&1 | tail -2
  if [ -n "$dhbin" ] && [ -f "$dhbin" ]; then
    cp "$dhbin" "$OUT/$plat/"
  else
    echo "[package] WARNING: dh-server binary for $plat not found ($dhbin)"
    echo "          co-op world parity will break for these players!"
  fi
  cat > "$OUT/$plat/LEIA-ME.txt" <<'EOF'
DRAGON HEROES (dev build)
=========================
Run the dragon-heroes binary. No Godot installation needed.

SOLO:  main menu -> name your hunter -> pick a class -> ENTER THE HUNT.
CO-OP (P2P): menu -> CO-OP (P2P). One friend HOSTs and shares the LAN IP
shown; up to 3 friends JOIN with it (UDP port 7377). Over the internet:
port-forward UDP 7377 on the host or use a Tailscale-style overlay.

Keep dh-server(.exe) NEXT TO the game binary — it generates the world.
Controls: WASD move, LMB/Space attack, Shift/RMB dodge, E Q skills, 1-4 bar,
F capture, Z mount, C character, K keybinds.
EOF
  (cd "$OUT/$plat" && zip -qr "../dragon-heroes-$plat.zip" .)
  echo "[package] $OUT/dragon-heroes-$plat.zip"
}

[ "${DH_FETCH_TEMPLATES:-0}" = "1" ] && fetch_templates

# A fresh local cross-build always wins; the committed cache is the fallback so
# a clean clone without the mingw toolchain still produces a complete zip.
win_server() {
  for c in sim/build-windows/dh-server.exe \
           sim/build-windows/libs/dh-server/dh-server.exe \
           builds/prebuilt/windows/dh-server.exe; do
    [ -f "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

want="${1:-all}"
case "$want" in
  windows)
    srv="$(win_server)" || { echo "[package] no dh-server.exe (mingw cross-build needed)"; exit 1; }
    pack windows "Windows Desktop" dragon-heroes.exe "$srv" ;;
  linux)   pack linux   "Linux/X11"      dragon-heroes.x86_64 "sim/build/libs/dh-server/dh-server" ;;
  all)
    pack linux "Linux/X11" dragon-heroes.x86_64 "sim/build/libs/dh-server/dh-server" || true
    if srv="$(win_server)"; then
      pack windows "Windows Desktop" dragon-heroes.exe "$srv"
    else
      echo "[package] skipping windows: no dh-server.exe (mingw cross-build needed)"
    fi
    ;;
  *) echo "usage: $0 [windows|linux|all]"; exit 1 ;;
esac
