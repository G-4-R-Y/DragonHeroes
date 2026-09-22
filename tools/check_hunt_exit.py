#!/usr/bin/env python3
"""Repeat the actual Hunt boot/quit gate and reject resource/RID leaks.

Isolated saves and complete logs live under genforge/candidates/hunt-exit.
The deterministic staged-water fixture is in ground_state_probe.tscn.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=12)
    parser.add_argument("--frames", type=int, default=150)
    args = parser.parse_args()
    if not 1 <= args.runs <= 100 or not 1 <= args.frames <= 1800:
        parser.error("use 1..100 runs and 1..1800 frames")
    out = ROOT / "genforge/candidates/hunt-exit"
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    for kind in ("CONFIG", "DATA", "CACHE"):
        path = out / kind.lower()
        path.mkdir(exist_ok=True)
        env[f"XDG_{kind}_HOME"] = str(path)
    results = []
    for i in range(args.runs):
        try:
            proc = subprocess.run(["godot", "--headless", "--verbose", "--path", "game",
                                   "res://prototype/main.tscn", "--quit-after", str(args.frames)],
                                  cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
            log = proc.stdout + proc.stderr
            issues = re.findall(r"^.*(?:SCRIPT ERROR|ERROR:|leaked at exit|resources still in use|ObjectDB instances leaked).*$", log, re.M)
            ok = proc.returncode == 0 and not issues
        except subprocess.TimeoutExpired as exc:
            log = str(exc.stdout) + str(exc.stderr)
            issues, ok = ["timeout after 120 seconds"], False
        (out / f"hunt-{i+1:02d}.log").write_text(log)
        results.append({"run": i+1, "passed": ok, "issues": issues})
        (out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        print(f"HUNT EXIT {i+1}/{args.runs}: {'OK' if ok else 'FAILED'}", flush=True)
    return 0 if all(row["passed"] for row in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
