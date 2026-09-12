#!/usr/bin/env python3
"""Build the weekly candidate and run its real C++ outcome probe, without publishing."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from genforge.living.build import build


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release",nargs="?",type=Path,
                        default=ROOT/"genforge/releases/bell_beneath_fen.json")
    args=parser.parse_args()
    for command in ([sys.executable,"tools/validate_content.py"],
                    ["cmake","-S","sim","-B","sim/build","-DCMAKE_BUILD_TYPE=Release"],
                    ["cmake","--build","sim/build","-j","4"],
                    ["ctest","--test-dir","sim/build","--output-on-failure"]):
        subprocess.run(command,cwd=ROOT,check=True)
    target=build(args.release,ROOT/"genforge/candidates/living")
    result=subprocess.run([str(ROOT/"sim/build/libs/dh-server/dh-effect-lab"),
                           str(target/"effects.bin")],check=True,capture_output=True,text=True)
    report=json.loads(result.stdout)
    # Machine-specific evidence is separate from the immutable content bundle.
    evidence=ROOT/"genforge/candidates/living-evidence"
    evidence.mkdir(parents=True,exist_ok=True)
    (evidence/(target.name+".json")).write_text(json.dumps(report,indent=2)+"\n")
    print(f"EFFECT LAB OK: {len(report['traces'])} effects, "
          f"{report['ns_per_evaluation']} ns/evaluation (microbenchmark only)")
    print(f"OPEN REVIEW: {target/'index.html'}")
    print("CANDIDATE ONLY: full animation, human review, Hunt integration and device profiling remain.")


if __name__=="__main__":
    main()
