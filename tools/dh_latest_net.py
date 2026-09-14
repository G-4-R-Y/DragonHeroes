#!/usr/bin/env python3
"""Newest exported net for a key in a run's registry, or "" if there is none.

Its own file rather than a heredoc inside tools/train_run.sh: a `PY` marker
nested inside another heredoc terminates the OUTER one, and a shell script that
silently loses half its body is a worse problem than an extra file.
"""
import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("", end="")
        return 0
    reg_path, key = Path(sys.argv[1]), sys.argv[2]
    if not reg_path.exists():
        print("", end="")
        return 0
    try:
        reg = json.loads(reg_path.read_text())
    except (json.JSONDecodeError, OSError):
        print("", end="")
        return 0
    mine = [p for p in reg.get("policies", [])
            if p.get("key") == key and p.get("game_json")]
    if not mine:
        print("", end="")
        return 0
    best = max(mine, key=lambda p: float(p.get("version", 0)))
    print(str(best["game_json"]), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
