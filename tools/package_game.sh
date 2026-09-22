#!/usr/bin/env bash
# Package Dragon Heroes for friends (docs/USAGE.md §distributing).
#
# R77 (2026-09-22) — THE BUILD MERGE. This script no longer packages anything.
# It is a thin wrapper over tools/package_build.py, which is the one packager.
#
# Why: this script trusted game/export_presets.cfg to say where the export
# landed, and then zipped builds/<plat>/ regardless. The preset drifted to
# ../builds/codex/<plat>/ when the review flavour was introduced, so for ten
# days the export succeeded into one directory and the ZIP was built from
# another -- builds/dragon-heroes-{linux,windows}.zip shipped a 2026-09-12
# client while every fresh export sat unshipped in builds/codex/. The dead
# third parameter of pack() below ("exe") is the fossil of the path override
# that used to prevent exactly this.
#
# tools/package_build.py passes the output path to --export-release explicitly,
# so a preset can never drift out from under it again, and it gates the result:
# content validation, sim build + ctest, mingw cross-build, icon/manifest
# verify, a headless smoke run of the real exported binary, living-preview and
# lair-journey checks, a ZIP CRC test, and a /proc check that refuses to
# replace a directory a running process is sitting in.
#
# Kept as a wrapper rather than deleted because docs, muscle memory and
# tools/build_console.sh all still say "tools/package_game.sh". The original
# body is preserved verbatim below, commented out, as the record of what the
# broken packager actually did.
#
# One-time prerequisite: Godot export templates for 4.6 (~1 GB) -- Editor ->
# Manage Export Templates, or run this with DH_FETCH_TEMPLATES=1 to download
# them via curl into ~/.local/share/godot/export_templates/.
#
# Usage: tools/package_game.sh [windows|linux|all]   (default: all)
set -euo pipefail
cd "$(dirname "$0")/.."

fetch_templates() {
  # Official 4.6.stable export templates (.tpz) -- downloaded once per machine.
  # This is the one capability package_build.py does not have, so it stays live.
  local dir="$HOME/.local/share/godot/export_templates/4.6.stable"
  if [ -d "$dir" ] && ls "$dir" | grep -q "windows"; then return 0; fi
  echo "[package] fetching Godot 4.6 export templates (~1 GB)..."
  mkdir -p "$dir"
  local tpz
  tpz="$(mktemp -t godot_templates.XXXXXX.tpz)"
  curl -fL "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz" -o "$tpz"
  (cd "$dir" && unzip -oq "$tpz" && mv templates/* . && rmdir templates)
  rm -f "$tpz"
}

[ "${DH_FETCH_TEMPLATES:-0}" = "1" ] && fetch_templates

echo "[package] delegating to tools/package_build.py (R77: one packager)"
exec python3 tools/package_build.py "${1:-all}"

# ----------------------------------------------------------------------------
# HISTORICAL BODY -- the packager that shipped stale clients. Commented, not
# deleted (Ricardo's standing rule). Do not re-enable: pack() never told Godot
# where to export, which is the whole defect.
# ----------------------------------------------------------------------------
# cd "$(dirname "$0")/.."
# OUT=builds
# mkdir -p "$OUT"
#
# fetch_templates() {
#   # Official 4.6.stable export templates (.tpz) — downloaded once per machine.
#   local dir="$HOME/.local/share/godot/export_templates/4.6.stable"
#   if [ -d "$dir" ] && ls "$dir" | grep -q "windows"; then return 0; fi
#   echo "[package] fetching Godot 4.6 export templates (~1 GB)..."
#   mkdir -p "$dir"
#   local tpz="/tmp/opencode/godot_templates.tpz"
#   curl -fL "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz" -o "$tpz"
#   (cd "$dir" && unzip -oq "$tpz" && mv templates/* . && rmdir templates)
#   rm -f "$tpz"
# }
#
# pack() {
#   local plat="$1" preset="$2" exe="$3" dhbin="$4"
#   echo "[package] exporting $plat..."
#   mkdir -p "$OUT/$plat"
#   godot --headless --path game --export-release "$preset" 2>&1 | tail -2
#   if [ -n "$dhbin" ] && [ -f "$dhbin" ]; then
#     cp "$dhbin" "$OUT/$plat/"
#   else
#     echo "[package] WARNING: dh-server binary for $plat not found ($dhbin)"
#     echo "          co-op world parity will break for these players!"
#   fi
#   cat > "$OUT/$plat/LEIA-ME.txt" <<'EOF'
# DRAGON HEROES (dev build)
# =========================
# Run the dragon-heroes binary. No Godot installation needed.
#
# SOLO:  main menu -> name your hunter -> pick a class -> ENTER THE HUNT.
# CO-OP (P2P): menu -> CO-OP (P2P). One friend HOSTs and shares the LAN IP
# shown; up to 3 friends JOIN with it (UDP port 7377). Over the internet:
# port-forward UDP 7377 on the host or use a Tailscale-style overlay.
#
# Keep dh-server(.exe) NEXT TO the game binary — it generates the world.
# Controls: WASD move, LMB/Space attack, Shift/RMB dodge, E Q skills, 1-4 bar,
# F capture, Z mount, C character, K keybinds.
# EOF
#   # -r into an EXISTING zip updates and adds but never removes, so a file that
#   # left the export dir would ride along in the archive forever. Start clean.
#   rm -f "$OUT/dragon-heroes-$plat.zip"
#   (cd "$OUT/$plat" && zip -qr "../dragon-heroes-$plat.zip" .)
#   echo "[package] $OUT/dragon-heroes-$plat.zip"
# }
#
# [ "${DH_FETCH_TEMPLATES:-0}" = "1" ] && fetch_templates
#
# # A fresh local cross-build always wins; the committed cache is the fallback so
# # a clean clone without the mingw toolchain still produces a complete zip.
# # ORDER MATTERS, and the first entry is the one CMake actually writes. The root
# # sim/build-windows/dh-server.exe is a HAND-COPY some earlier session made and
# # the docs then enshrined; nothing rebuilds it, so on 2026-09-22 it was still a
# # 2026-09-12 binary (97 KB) shadowing a current one (287 KB) that was missing a
# # week of server code. It stays in the list, last of the build-tree entries, for
# # a tree where only that copy survives — but it must never outrank the real one.
# win_server() {
#   for c in sim/build-windows/libs/dh-server/dh-server.exe \
#            sim/build-windows/dh-server.exe \
#            builds/prebuilt/windows/dh-server.exe; do
#     [ -f "$c" ] && { echo "$c"; return 0; }
#   done
#   return 1
# }
#
# want="${1:-all}"
# case "$want" in
#   windows)
#     srv="$(win_server)" || { echo "[package] no dh-server.exe (mingw cross-build needed)"; exit 1; }
#     pack windows "Windows Desktop" dragon-heroes.exe "$srv" ;;
#   linux)   pack linux   "Linux/X11"      dragon-heroes.x86_64 "sim/build/libs/dh-server/dh-server" ;;
#   all)
#     pack linux "Linux/X11" dragon-heroes.x86_64 "sim/build/libs/dh-server/dh-server" || true
#     if srv="$(win_server)"; then
#       pack windows "Windows Desktop" dragon-heroes.exe "$srv"
#     else
#       echo "[package] skipping windows: no dh-server.exe (mingw cross-build needed)"
#     fi
#     ;;
#   *) echo "usage: $0 [windows|linux|all]"; exit 1 ;;
# esac
