#!/usr/bin/env python3
"""Run the real playable trial, with isolated saves and an optional GL capture."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def check(package=None, capture=False):
    output = ROOT / "genforge/candidates/playable"
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="session-", dir=output) as temporary:
        folder = Path(temporary)
        env = dict(os.environ)
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            path = folder / key.lower()
            path.mkdir()
            env[key] = str(path)
        command = [str(package.resolve()/"dragon-heroes-codex.x86_64")] if package else ["godot", "--path", str(ROOT/"game")]
        command += ["--rendering-method", "gl_compatibility", "--max-fps", "60"]
        if not capture:
            command.append("--headless")
        command += ["--", "--living-capture" if capture else "--living-selftest"]
        name = "capture" if capture else ("exported" if package else "dev")
        log_path = output / f"{name}.log"
        with log_path.open("w") as log:
            result = subprocess.run(command, cwd=package or ROOT, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=40)
        log = log_path.read_text()
        if result.returncode or "ERROR:" in log:
            raise RuntimeError(f"Playable trial failed; {log_path}\n{log[-3500:]}")
        data = Path(env["XDG_DATA_HOME"])/"Dragon Heroes Codex"
        if capture:
            shutil.copyfile(data/"living-trial.png", output/"living-trial.png")
            shutil.copyfile(data/"living-render.json", output/"living-render.json")
            print(f"LIVING CAPTURE OK: {output/'living-trial.png'}")
        else:
            report = json.loads((data/"living-smoke.json").read_text())
            (output/f"{name}.json").write_text(json.dumps(report,indent=2)+"\n")
            if not report.get("passed") or report.get("atlas_frames", 0) < 2:
                raise RuntimeError(f"Playable trial outcome failed: {report}")
            print(f"LIVING PLAYTEST OK: {name}: {report}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    check(args.package, args.capture)
