"""dh-env throughput benchmark (docs/tech/25 gate: >= 100k steps/s/core).

    ml/.venv/bin/python -m ml.env.bench [--seconds 5] [--opp native|scripted]

Measures the full path PPO will use — ctypes call + C++ step + obs copy —
with the chase-and-attack heuristic as the learner's policy (realistic mix of
act ids, projectiles, fields). Episodes that end are reset and keep counting.
"""
from __future__ import annotations

import argparse
import time

from ml.env.dh_env import DhEnv


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=5.0)
    ap.add_argument("--opp", default="scripted")
    args = ap.parse_args()
    env = DhEnv("core.arena.fen_boar_alpha", "core.arena.cinder_drake",
                opp=args.opp, seed=1)
    obs = env.reset(seed=1)
    steps = 0
    start = time.perf_counter()
    while time.perf_counter() - start < args.seconds:
        # chase-and-attack from the obs (the same policy the C++ tests use)
        dx, dy = float(obs[16]) * 512.0, float(obs[17]) * 512.0
        dist = (dx * dx + dy * dy) ** 0.5 or 1.0
        act = 1 if dist < 40.0 else (3 if dist < 128.0 and obs[7] == 0.0 else 0)
        done, obs = env.step((dx / dist, dy / dist), act)
        steps += 1
        if done:
            obs = env.reset(seed=env.tick + steps)
    dt = time.perf_counter() - start
    rate = steps / dt
    print(f"BENCH opp={args.opp} steps={steps} wall={dt:.2f}s "
          f"-> {rate:,.0f} steps/s ({'PASS' if rate >= 100_000 else 'FAIL'} >= 100k)")


if __name__ == "__main__":
    main()
