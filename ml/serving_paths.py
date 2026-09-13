"""Where a training run writes its artifacts (Ricardo, 2026-09-13: "can't we
have a test backup so i can test freely and cumulatively without overwriting
stuff?").

Every trainer used to hard-code `ml/serving/` — so two experiments, or two
Claude sessions, silently overwrote each other's registry and weights. These
helpers resolve the same paths through **`DH_SERVING_DIR`**:

    DH_SERVING_DIR=ml/runs/2026-09-13_1930__fen_boar__g20_p8_e4 \
        python3 -m ml.training.league train --key fen_boar ...

Unset (the normal case) it is `ml/serving/` — the DEPLOYED registry the game
and the training console read. `tools/train_run.sh` creates the dated run
folder, seeds it from the deployed registry so runs are cumulative, and can
promote a winner back. Progress feeds follow the same switch, so an isolated
run never disturbs the console's live tail.
"""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SERVING = ROOT / "ml" / "serving"
DEFAULT_PROGRESS = ROOT / "ml" / "data" / "progress"


def serving_dir() -> Path:
    """The run's artifact root: $DH_SERVING_DIR, else ml/serving."""
    env = os.environ.get("DH_SERVING_DIR", "").strip()
    return (Path(env).expanduser().resolve() if env else DEFAULT_SERVING)


def registry_path() -> Path:
    return serving_dir() / "registry.json"


def weights_dir() -> Path:
    return serving_dir() / "weights"


def progress_dir() -> Path:
    """Isolated runs keep their progress JSONL beside their weights."""
    if os.environ.get("DH_SERVING_DIR", "").strip():
        return serving_dir() / "progress"
    return DEFAULT_PROGRESS


def is_isolated() -> bool:
    return bool(os.environ.get("DH_SERVING_DIR", "").strip())
