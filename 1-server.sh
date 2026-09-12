#!/usr/bin/env bash
# 1-server — start the Dragon Heroes backend (self-hosted Nakama + Postgres).
# Run this FIRST, then 2-game.sh. No commands to remember:
#   ./1-server.sh   (idempotent — safe to run again; starts or reports healthy)
# Stops with: tools/nakama.sh down
set -euo pipefail
cd "$(dirname "$0")"

bash tools/nakama.sh up

echo -n "[1-server] waiting for Nakama to be healthy"
for i in $(seq 1 30); do
  if curl -sf http://localhost:7350/healthcheck > /dev/null 2>&1; then
    echo " — UP"
    echo "[1-server] console: http://localhost:7351  ·  game port: 7349"
    echo "[1-server] next: ./2-game.sh"
    exit 0
  fi
  echo -n "."
  sleep 2
done
echo
echo "[1-server] Nakama did not come up in 60 s — check: tools/nakama.sh logs" >&2
exit 1
