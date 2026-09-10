#!/usr/bin/env bash
# Train a species net for EVERY creature build in the arena roster, then gate
# each one (docs/tech/32 §runbook). ES trainer over parallel headless workers.
#
# Usage:
#   tools/train_all.sh                  # full night run (defaults below)
#   GENERATIONS=2 POP=4 EPISODES=2 tools/train_all.sh   # quick smoke
#
# Env knobs: GENERATIONS (20) POP (8) EPISODES (4) JOBS (nproc) SEED (2026)
# Logs: ml/data/logs/<key>.log · weights+registry: ml/serving/ · gate per key.
set -u
cd "$(dirname "$0")/.."

GENERATIONS="${GENERATIONS:-20}"
POP="${POP:-8}"
EPISODES="${EPISODES:-4}"
JOBS="${JOBS:-$(nproc)}"
SEED="${SEED:-2026}"

# one-time: N concurrent godot instances must never race the import cache
godot --headless --path game --import >/dev/null 2>&1 || true
mkdir -p ml/data/logs

KEYS=$(python3 - <<'EOF'
import json
data = json.load(open("game/arena/data/builds.json"))
for b in data["builds"]:
    if b.get("kind") == "creature":
        print(f"{b['id'].split('.')[-1]} {b['id']}")
EOF
)

echo "[train-all] generations=$GENERATIONS pop=$POP episodes=$EPISODES jobs=$JOBS"
echo "$KEYS" | while read -r key build; do
  echo "=== $key ($build) ==="
  python3 -m ml.training.league train --key "$key" --build "$build" \
      --generations "$GENERATIONS" --pop "$POP" --episodes "$EPISODES" \
      --jobs "$JOBS" --seed "$SEED" 2>&1 | tee "ml/data/logs/$key.log" | tail -2
  python3 -m ml.training.league gate --key "$key" --build "$build" \
      --episodes "$EPISODES" 2>&1 | tee -a "ml/data/logs/$key.log" | tail -3
done
echo "[train-all] done — registry: ml/serving/registry.json"
