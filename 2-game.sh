#!/usr/bin/env bash
# 2-game — launch Dragon Heroes. Run AFTER 1-server.sh (only if you want the
# online features; solo offline and P2P/LAN work with no server at all).
# Prefers the packaged binary; falls back to the editor's godot.
set -euo pipefail
cd "$(dirname "$0")"

BIN="builds/linux/dragon-heroes.x86_64"
if [ -x "$BIN" ]; then
  echo "[2-game] launching packaged build ($BIN)"
  exec "$BIN"
elif command -v godot > /dev/null 2>&1; then
  echo "[2-game] launching from source (godot)"
  exec godot --path game
else
  echo "[2-game] no binary at $BIN and no godot on PATH —" >&2
  echo "  package first: tools/package_game.sh linux" >&2
  exit 1
fi
