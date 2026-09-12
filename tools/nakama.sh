#!/usr/bin/env bash
# Self-hosted Nakama for Dragon Heroes (roadmap 6f) — one command:
#   tools/nakama.sh up       # start (first run pulls ~300 MB of images)
#   tools/nakama.sh status   # containers + health
#   tools/nakama.sh logs     # follow the nakama server log
#   tools/nakama.sh down     # stop (state persists in the postgres volume)
#   tools/nakama.sh wipe     # stop AND delete all data (careful)
#
# After `up`: web console at http://localhost:7351 (first boot asks you to
# create the admin login). Game clients connect to localhost:7349 with the
# server key from tools/nakama/docker-compose.yml (dev key — change before
# exposing anything). Solo offline and P2P/LAN never need this (roadmap 6e).
set -euo pipefail
cd "$(dirname "$0")/.."
DC=(docker compose -f tools/nakama/docker-compose.yml)

case "${1:-up}" in
  up)
    "${DC[@]}" up -d
    echo "[nakama] up — console: http://localhost:7351 · api: http://localhost:7350"
    echo "[nakama] first boot of the console asks for an admin login"
    ;;
  down)    "${DC[@]}" down ;;
  status)  "${DC[@]}" ps ;;
  logs)    "${DC[@]}" logs -f nakama ;;
  wipe)    "${DC[@]}" down -v ;;
  *) echo "usage: tools/nakama.sh [up|down|status|logs|wipe]" >&2; exit 1 ;;
esac
