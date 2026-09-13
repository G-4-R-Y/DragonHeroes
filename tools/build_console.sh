#!/usr/bin/env bash
# Build the Arena Console as its OWN application — an icon in the menu, not a
# godot command line (Ricardo, 2026-09-13: "create an execution icon binary as
# the rest ... we even have custom icons").
#
# The codex flavour already had this treatment: tools/package_codex.py exports a
# binary, stages the PNG and points at tools/install_linux_launcher.py, which
# registers a .desktop entry. The training cockpit had none of it — you had to
# remember `godot --path game res://arena/console.tscn`. Now:
#
#   tools/build_console.sh              # export + verify + install the launcher
#   tools/build_console.sh --no-install # just the binary
#
# Like the trainer export, a release template refuses a scene path on the command
# line (disable_path_overrides), so the preset carries the custom feature
# "console" and game/project.godot sets run/main_scene.console — the build boots
# the cockpit by itself.
#
# NOTE the binary opens a WINDOW. This script never runs it that way: it verifies
# with --headless -- --selftest, which is the same gate docs/harness/README lists.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
source "$REPO/tools/dh_term.sh"

PRESET="Arena Console (Linux)"
OUT="$REPO/builds/console/dh-arena-console.x86_64"
INSTALL=1
[ "${1:-}" != "--no-install" ] || INSTALL=0
mkdir -p "$(dirname "$OUT")"

dh_banner "ARENA CONSOLE BUILD"
dh_kv preset "$PRESET"
dh_kv output "${OUT#"$REPO"/}"

command -v godot >/dev/null || { dh_err "godot not on PATH"; exit 1; }

# The icon the .desktop entry points at. build_app_icon.py renders it from the
# curated source; only regenerate when it is missing, so a hand-tuned PNG stays.
if [ ! -f game/branding/dragon-heroes.png ]; then
  dh_say "rendering the application icon"
  python3 tools/build_app_icon.py
fi

# A .gdextension (and any new class_name) only registers during a filesystem
# scan, and an export of an unscanned project silently ships a broken script.
godot --headless --path game --import >/dev/null 2>&1 || true

if ! godot --headless --path game --export-release "$PRESET" "$OUT" 2>&1 | tail -3; then
  dh_err "export failed — is the 4.6 export template installed? (Editor > Manage Export Templates)"
  exit 1
fi
[ -x "$OUT" ] || { dh_err "no binary at $OUT"; exit 1; }
dh_ok "exported $(du -h "$OUT" | cut -f1)"

# Prove the binary boots the CONSOLE on its own, without opening a window: the
# release template ignores a scene path, so a missing run/main_scene.console
# would silently produce a binary that starts the main menu instead.
PROBE="$(mktemp -d)/selftest.txt"
if "$OUT" --headless -- --selftest >"$PROBE" 2>&1 && grep -q "CONSOLE SELFTEST OK" "$PROBE"; then
  dh_ok "boots straight into the cockpit: $(grep -o 'CONSOLE SELFTEST OK.*' "$PROBE" | head -1 | cut -c1-88)"
else
  dh_err "the binary did not reach the console selftest — see $PROBE"
  exit 1
fi

if [ "$INSTALL" -eq 1 ]; then
  python3 tools/install_arena_launcher.py
else
  dh_say "skipping the desktop entry (--no-install); add it later with:"
  dh_say "  python3 tools/install_arena_launcher.py"
fi
dh_say "run it from the menu, or directly: $OUT"
