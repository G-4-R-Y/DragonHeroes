#!/usr/bin/env bash
# Build the Dragon Heroes consoles as their OWN applications — icons in the menu,
# not godot command lines (Ricardo, 2026-09-13: "create an execution icon binary
# as the rest ... we even have custom icons", and then, after trying to run a
# scene file from bash: "Permissão negada / yooo wtf" — a .tscn is data, not a
# program, and that is exactly the problem this removes).
#
#   tools/build_console.sh                 # both consoles + their menu entries
#   tools/build_console.sh arena           # just the training cockpit
#   tools/build_console.sh genforge        # just the content cockpit
#   tools/build_console.sh all --no-install # binaries only
#
# The shipping client already had this treatment (tools/package_build.py exports,
# stages the PNG and points at an installer); the cockpits had none of it.
#
# Like the trainer export, a release template refuses a scene path on the command
# line (disable_path_overrides), so each preset carries a custom feature and
# game/project.godot maps it to a main scene — run/main_scene.console and
# run/main_scene.genforge. The build boots the right cockpit by itself.
#
# NOTE these binaries open a WINDOW. This script never runs them that way: each
# is verified with --headless -- --selftest, the same gates docs/harness lists.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
source "$REPO/tools/dh_term.sh"

TARGET="${1:-all}"
INSTALL=1
for arg in "$@"; do [ "$arg" != "--no-install" ] || INSTALL=0; done
case "$TARGET" in arena|genforge|all|--no-install) ;; *)
  dh_err "usage: tools/build_console.sh [arena|genforge|all] [--no-install]"; exit 2;; esac
[ "$TARGET" != "--no-install" ] || TARGET=all

# target | preset | output basename | selftest sentinel
TARGETS=(
  "arena|Arena Console (Linux)|dh-arena-console.x86_64|CONSOLE SELFTEST OK"
  "genforge|Genforge Console (Linux)|dh-genforge-console.x86_64|GENFORGE CONSOLE SELFTEST OK"
)

dh_banner "CONSOLE BUILD"
command -v godot >/dev/null || { dh_err "godot not on PATH"; exit 1; }

# The icon the .desktop entries point at. build_app_icon.py renders it from the
# curated source; only regenerate when missing, so a hand-tuned PNG stays.
if [ ! -f game/branding/dragon-heroes.png ]; then
  dh_say "rendering the application icon"
  python3 tools/build_app_icon.py
fi

# A .gdextension (and any new class_name) only registers during a filesystem
# scan, and an export of an unscanned project silently ships a broken script.
godot --headless --path game --import >/dev/null 2>&1 || true

mkdir -p "$REPO/builds/console"
BUILT=()
for row in "${TARGETS[@]}"; do
  IFS='|' read -r name preset out sentinel <<< "$row"
  [ "$TARGET" = all ] || [ "$TARGET" = "$name" ] || continue
  OUT="$REPO/builds/console/$out"
  dh_rule "$name"
  dh_kv preset "$preset"
  dh_kv output "${OUT#"$REPO"/}"
  if ! godot --headless --path game --export-release "$preset" "$OUT" 2>&1 | tail -3; then
    dh_err "export failed — is the 4.6 export template installed? (Editor > Manage Export Templates)"
    exit 1
  fi
  [ -x "$OUT" ] || { dh_err "no binary at $OUT"; exit 1; }
  dh_ok "exported $(du -h "$OUT" | cut -f1)"

  # Prove the binary boots ITS OWN cockpit without opening a window: the release
  # template ignores a scene path, so a missing run/main_scene.<feature> would
  # silently produce a binary that starts the main menu instead.
  PROBE="$(mktemp -d)/selftest.txt"
  if "$OUT" --headless -- --selftest >"$PROBE" 2>&1 && grep -q "$sentinel" "$PROBE"; then
    dh_ok "boots straight into the cockpit: $(grep -o "$sentinel.*" "$PROBE" | head -1 | cut -c1-84)"
  else
    dh_err "the binary did not reach its selftest — see $PROBE"
    exit 1
  fi
  BUILT+=("$name")
done

if [ "$INSTALL" -eq 1 ]; then
  for name in "${BUILT[@]}"; do python3 tools/install_console_launcher.py "$name"; done
else
  dh_say "skipping the desktop entries (--no-install); add them later with:"
  dh_say "  python3 tools/install_console_launcher.py all"
fi
dh_say "run them from the application menu, or directly from builds/console/"
