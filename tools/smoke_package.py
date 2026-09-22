#!/usr/bin/env python3
"""Exercise the exported Linux PCK and its adjacent C++ helper, without the editor."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def smoke(package, output):
    package = package.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="smoke-", dir=output) as temporary:
        stage = Path(temporary)
        env = dict(os.environ)
        for key in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            path = stage / key.lower()
            path.mkdir()
            env[key] = str(path)
        log_path = output / "linux-smoke.log"
        with log_path.open("w") as handle:
            try:
                result = subprocess.run([str(package / "dragon-heroes.x86_64"),
                                         "--headless", "--fixed-fps", "60", "--quit-after", "900",
                                         "--", "--package-smoke"],
                                        cwd=package, env=env, stdout=handle,
                                        stderr=subprocess.STDOUT, timeout=90)
            except subprocess.TimeoutExpired as error:
                raise RuntimeError(f"Exported Linux smoke timed out; see {log_path}") from error
        log = log_path.read_text()
        verdict_path = Path(env["XDG_DATA_HOME"]) / "Dragon Heroes/package-smoke.json"
        verdict = json.loads(verdict_path.read_text()) if verdict_path.is_file() else {}
        (output / "linux-smoke.json").write_text(json.dumps(verdict, indent=2)+"\n")
        if result.returncode or not verdict.get("passed") or "ERROR:" in log:
            raise RuntimeError(f"Exported Linux smoke failed: {verdict}\n{log[-4000:]}")
        print("PACKAGE SMOKE OK: " + verdict["detail"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    args = parser.parse_args()
    smoke(args.package, Path(__file__).resolve().parents[1] / "genforge/candidates/packaging")
