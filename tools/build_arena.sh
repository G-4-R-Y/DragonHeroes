#!/usr/bin/env bash
# Build the RELEASE arena trainer binary and print the export to use it.
#
# Why this exists: training runs matches through the Godot EDITOR binary, which
# is a debug build. A release export boots faster (4.01 s -> 2.53 s per match,
# measured 2026-09-13) and is verified BIT-IDENTICAL to the editor binary, so
# nets and gate bands carry over untouched.
#
# A release template refuses a scene path on the command line
# (disable_path_overrides), so the trainer export cannot be pointed at
# res://arena/arena.tscn the way the editor binary is. Instead the preset
# carries the custom feature "trainer", and game/project.godot sets
# `run/main_scene.trainer="res://arena/arena.tscn"` — the build boots the arena
# on its own.
#
# Usage:
#   tools/build_arena.sh                      # build into builds/trainer/
#   export DH_ARENA_BIN=$PWD/builds/trainer/dh-arena.x86_64
#   tools/train_run.sh --all                  # every match now uses it
#
# Honest payoff: while the GDScript MLP dominates the tick (docs/tech/37), the
# per-tick win is near zero — this buys the startup. It becomes the big win once
# the forward pass moves to C++ (roadmap).
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
source "$REPO/tools/dh_term.sh"

PRESET="Arena Trainer (Linux)"
OUT="${1:-$REPO/builds/trainer/dh-arena.x86_64}"
mkdir -p "$(dirname "$OUT")"

dh_banner "ARENA TRAINER BUILD"
dh_kv preset "$PRESET"
dh_kv output "${OUT#"$REPO"/}"

command -v godot >/dev/null || { dh_err "godot not on PATH"; exit 1; }
if ! godot --headless --path game --export-release "$PRESET" "$OUT" 2>&1 | tail -3; then
  dh_err "export failed — is the 4.6 export template installed? (Editor > Manage Export Templates)"
  exit 1
fi
[ -x "$OUT" ] || { dh_err "no binary at $OUT"; exit 1; }

# prove it boots the arena on its own before anyone trusts it in a sweep
PROBE="$(mktemp -d)/probe.json"
"$OUT" --headless --fixed-fps 60 -- --a core.arena.fen_boar_alpha \
    --b core.arena.gloam_wisp --policy-a scripted --policy-b scripted \
    --episodes 1 --time-limit 5 --seed 4242 --fast --speed max --out "$PROBE" >/dev/null 2>&1 || true
if [ -s "$PROBE" ]; then
  dh_ok "boots straight into the arena and wrote a result"
else
  dh_err "the binary did not produce a match result — do NOT use it for training"
  exit 1
fi
# ...and that it can SERVE, which is how training actually drives it. A binary
# exported before --serve existed boots fine and then never answers, so checking
# only the one-shot path would pass a binary that stalls every match.
# The probe drives the binary through the REAL pool class, over a live pipe. An
# earlier version redirected stdout to a file and grepped it after exit, which
# passed a binary whose stdout was block-buffered — exactly the failure the pool
# then hit on every match (release builds do not flush stdout per print).
if DH_ARENA_BIN="$OUT" python3 - "$OUT" <<'PY'
import sys, tempfile, os
sys.path.insert(0, os.getcwd())
from ml.training.league import _ArenaWorker
out = os.path.join(tempfile.mkdtemp(), "serve.json")
w = _ArenaWorker([sys.argv[1], "--headless", "--fixed-fps", "60", "--",
                  "--serve", "--fast", "--speed", "max"])
try:
    w.run({"a": "core.arena.fen_boar_alpha", "b": "core.arena.gloam_wisp",
           "policy_a": "scripted", "policy_b": "scripted", "episodes": 1,
           "time_limit": 5, "seed": 4242, "speed": "max", "out": out}, timeout=120)
    sys.exit(0 if os.path.getsize(out) > 0 else 1)
finally:
    w.close()
PY
then
  dh_ok "serves matchups on stdin over a live pipe (resident worker mode)"
else
  dh_err "the binary does not answer --serve — training would stall on every match"
  exit 1
fi
dh_say "use it with:  export DH_ARENA_BIN=$OUT"
