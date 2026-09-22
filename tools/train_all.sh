#!/usr/bin/env bash
# Compatibility entry point: every creature, isolated registry, live logs and
# resumable checkpoints. Promotion remains explicit via train_run.sh --promote.
# Default leaves CPU capacity for play; TRAIN_PROFILE=throughput opts into all
# CPUs, and explicit JOBS always wins. See docs/USAGE.md and docs/tech/37.
set -euo pipefail
cd "$(dirname "$0")/.."
exec bash tools/train_run.sh --all "$@"
