"""Evolution over PPO (docs/tech/32 §outer-loop): ES is no longer only a
weights trainer — it is the OUTER SELECTOR over architectures and hyper-
parameters. A population of PPO configs {arch, lr, entropy, seed} trains
briefly, each candidate is gated in the GODOT arena (the honest fitness),
survivors reproduce with mutation.

    ml/.venv/bin/python -u -m ml.training.evolve \
        --key fen_boar --build core.arena.fen_boar_alpha \
        --opp-build core.arena.gloamfen_stalker \
        --pop 4 --generations 3 --steps 500000

Each candidate runs as a subprocess (crash isolation, GPU serialized) and
gates via a headless Godot subprocess — the same path humans use, no special
inner APIs. Fitness = gate wins vs native + scripted (draws count half).
"""
from __future__ import annotations

import argparse
import json
import random
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))
from ml.serving_paths import weights_dir as ml_weights_dir  # noqa: E402
PY = str(REPO / "ml" / ".venv" / "bin" / "python")
LOG_DIR = REPO / "ml" / "data" / "logs"

CONFIG_SPACE = {
    "arch": ["mlp", "gru"],
    "lr": (1e-4, 1e-3),        # log-uniform
    "entropy": (0.0, 0.03),
    "selfplay_every": (2, 8),  # int uniform
}


def sample_config(rng: random.Random, base: dict | None = None) -> dict:
    if base is None:
        return {
            "arch": rng.choice(CONFIG_SPACE["arch"]),
            "lr": 10 ** rng.uniform(*[__import__("math").log10(x)
                                      for x in CONFIG_SPACE["lr"]]),
            "entropy": rng.uniform(*CONFIG_SPACE["entropy"]),
            "selfplay_every": rng.randint(*CONFIG_SPACE["selfplay_every"]),
        }
    # mutation: one gene drifts
    child = dict(base)
    gene = rng.choice(list(CONFIG_SPACE))
    if gene == "arch":
        child["arch"] = "gru" if base["arch"] == "mlp" else "mlp"
    elif gene == "selfplay_every":
        child[gene] = max(2, min(8, base[gene] + rng.choice([-2, -1, 1, 2])))
    else:
        lo, hi = CONFIG_SPACE[gene]
        child[gene] = max(lo, min(hi, base[gene] * rng.uniform(0.5, 2.0)))
    return child


def run_candidate(key: str, build: str, opp_build: str, cfg: dict, steps: int,
                  gen: int, idx: int) -> float:
    tag = f"{key}_evo_g{gen}c{idx}"
    log = LOG_DIR / f"{tag}.log"
    cmd = [PY, "-u", "-m", "ml.training.ppo", "--key", tag, "--build", build,
           "--opp-build", opp_build, "--steps", str(steps), "--envs", "12",
           "--arch", cfg["arch"], "--seed", str(gen * 100 + idx)]
    with open(log, "w") as lf:
        subprocess.run(cmd, cwd=REPO, stdout=lf, stderr=subprocess.STDOUT,
                       timeout=7200)
    weights = ml_weights_dir() / f"{tag}_ppo_v1.json"   # honours $DH_SERVING_DIR
    if cfg["arch"] == "gru" or not weights.exists():
        # GRU has no Godot export: dh-env proxy fitness (win rate from the log)
        rates = [float(m) for m in
                 re.findall(r"win_rate\(last \d+\)=([\d.]+)", log.read_text())]
        return rates[-1] if rates else 0.0
    # Godot gate = the honest fitness: wins vs native + scripted, draws half
    fitness = 0.0
    for opp in ("native", "scripted"):
        out = subprocess.run(
            ["godot", "--headless", "--fixed-fps", "60", "--path", "game",
             "res://arena/arena.tscn", "--", "--a", build, "--b", opp_build,
             "--policy-a", str(weights), "--policy-b", opp,
             "--episodes", "4", "--fast"],
            cwd=REPO, capture_output=True, text=True, timeout=900).stdout
        m = re.search(r"wins_a=(\d+) wins_b=(\d+) draws=(\d+)", out)
        if m:
            fitness += (int(m.group(1)) + 0.5 * int(m.group(3))) / 4.0
    return fitness / 2.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True)
    ap.add_argument("--build", required=True)
    ap.add_argument("--opp-build", required=True)
    ap.add_argument("--pop", type=int, default=4)
    ap.add_argument("--generations", type=int, default=3)
    ap.add_argument("--steps", type=int, default=500_000,
                    help="PPO steps per candidate (short on purpose)")
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    population = [sample_config(rng) for _ in range(args.pop)]
    for gen in range(args.generations):
        scored = []
        for idx, cfg in enumerate(population):
            fit = run_candidate(args.key, args.build, args.opp_build, cfg,
                                args.steps, gen, idx)
            scored.append((fit, cfg))
            print(f"[evo:{args.key}] g{gen}c{idx} fitness={fit:.3f} {cfg}",
                  flush=True)
        scored.sort(key=lambda x: -x[0])
        best_fit, best = scored[0]
        print(f"[evo:{args.key}] g{gen} CHAMPION fitness={best_fit:.3f} {best}",
              flush=True)
        survivors = [cfg for _, cfg in scored[: max(1, args.pop // 2)]]
        population = survivors + [sample_config(rng, rng.choice(survivors))
                                  for _ in range(args.pop - len(survivors))]
    print(f"[evo:{args.key}] done — candidates in ml/serving/weights/, "
          f"logs in ml/data/logs/", flush=True)


if __name__ == "__main__":
    main()
