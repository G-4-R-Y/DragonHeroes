"""Arena self-play league + ES trainer (docs/design/23, docs/tech/25 §4.2).

Drives the observable arena (game/arena) headlessly: every evaluation is a set
of real Godot matches whose episodes are recorded as obs+action JSONL (the R0
dataset). Two policy lineages share the loop:

  - per-species nets ("fine-tuned per creature type"): one PolicyNet per
    species/build key, embedding row "*", trained by self-play ES against the
    scripted baseline, the native AI, and its own frozen past checkpoints
    (the AlphaStar league shape: main agent + past selves + exploiters).
  - the GLOBAL net: one weight set with an embedding row per content id,
    evaluated across mixed matchups so every episode from every creature and
    every build updates the same network.

ES is deliberately simple (OpenAI-ES: sigma-noise perturbations, centered-rank
update) — it runs at Godot-in-the-loop throughputs TODAY, and the whole loop
(registry, gate, recorded datasets) ports unchanged to PufferLib PPO once
dh-env (the C++ vectorized sim) lands. Canon §9 compute budget assumes the C++
env; ES here is the bootstrap, not the endgame.

Usage:
  python3 -m ml.training.league roster
  python3 -m ml.training.league init --key fen_boar
  python3 -m ml.training.league train --key fen_boar --build core.arena.fen_boar_alpha \
      --generations 3 --pop 6 --episodes 4
  python3 -m ml.training.league train-global --builds core.arena.fen_boar_alpha,core.arena.dusk_revenant
  python3 -m ml.training.league gate --key fen_boar
  python3 -m ml.training.league round-robin --episodes 2
"""
from __future__ import annotations

import argparse
import itertools
import json
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent.parent
REGISTRY = ROOT / "ml" / "serving" / "registry.json"
WEIGHTS_DIR = ROOT / "ml" / "serving" / "weights"
EPISODES_DIR = ROOT / "ml" / "data" / "episodes"
BUILDS_JSON = ROOT / "game" / "arena" / "data" / "builds.json"
ARENA_SCENE = "res://arena/arena.tscn"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from policy_net import PolicyNet  # noqa: E402

DEFAULT_OPPONENTS = [
    ("native", None),      # the built-in creature/boss AI — the baseline
    ("scripted", None),    # the utility baseline every policy must beat
]

_NONCE = itertools.count()   # unique result filenames under parallel workers


# ---- arena subprocess ---------------------------------------------------------


def run_match(a: str, b: str, policy_a: str, policy_b: str, episodes: int,
              seed: int, time_limit: float = 45.0, record: bool = False,
              timeout: float | None = None) -> dict:
    """One headless match set. Policies: native | scripted | <weights.json path>."""
    godot = shutil.which("godot")
    if godot is None:
        raise RuntimeError("godot not on PATH")
    out = EPISODES_DIR / f"result_{int(time.time() * 1000)}_{next(_NONCE)}.json"
    cmd = [godot, "--headless", "--path", str(ROOT / "game"), ARENA_SCENE, "--",
           "--a", a, "--b", b, "--policy-a", policy_a, "--policy-b", policy_b,
           "--episodes", str(episodes), "--time-limit", str(time_limit),
           "--seed", str(seed), "--fast", "--out", str(out)]
    if record:
        cmd += ["--record-dir", str(EPISODES_DIR)]
    if timeout is None:
        timeout = episodes * time_limit / 4.0 + 120.0   # fast mode ~4x wall
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if not out.exists():
        raise RuntimeError(f"arena produced no result (rc={proc.returncode}):\n"
                           f"{proc.stdout[-2000:]}\n{proc.stderr[-2000:]}")
    result = json.loads(out.read_text())
    out.unlink()
    return result


def fitness(result: dict, side: str = "a") -> float:
    """Win rate + hp margin shaping (annealed away as leagues mature, tech/25 §4.2)."""
    n = max(len(result["episodes"]), 1)
    wins = result["wins_a" if side == "a" else "wins_b"] / n
    hp = np.mean([e[f"hp_{side}"] for e in result["episodes"]]) if result["episodes"] else 0.0
    foe = "b" if side == "a" else "a"
    foe_hp = np.mean([e[f"hp_{foe}"] for e in result["episodes"]]) if result["episodes"] else 0.0
    return float(wins + 0.1 * (hp - foe_hp))


# ---- registry -------------------------------------------------------------------


def load_registry() -> dict:
    if REGISTRY.exists():
        return json.loads(REGISTRY.read_text())
    return {"schema": "arena.registry.v1", "policies": []}


def save_registry(reg: dict) -> None:
    REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    REGISTRY.write_text(json.dumps(reg, indent=2))


def registry_add(reg: dict, key: str, kind: str, parent: str | None) -> dict:
    versions = [p["version"] for p in reg["policies"] if p["key"] == key]
    entry = {"key": key, "kind": kind, "version": (max(versions) + 1 if versions else 1),
             "parent": parent, "created": time.strftime("%Y-%m-%dT%H:%M:%S"),
             "npz": str(WEIGHTS_DIR / f"{key}_v{(max(versions) + 1 if versions else 1)}.npz"),
             "game_json": str(WEIGHTS_DIR / f"{key}_v{(max(versions) + 1 if versions else 1)}.json"),
             "deployed": False, "eval": {}}
    reg["policies"].append(entry)
    return entry


def deployed(reg: dict, key: str) -> dict | None:
    for p in reversed(reg["policies"]):
        if p["key"] == key and p.get("deployed"):
            return p
    return None


def save_net(net: PolicyNet, entry: dict) -> None:
    WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)
    net.save_npz(entry["npz"])
    net.export_game_json(entry["game_json"])


# ---- ES training ------------------------------------------------------------------


def evaluate(net: PolicyNet, key: str, build: str, opponents: list[tuple[str, str | None]],
             episodes: int, seed: int, record: bool = False, jobs: int = 1) -> float:
    """Fitness = mean over opponents of (win rate + hp-margin shaping).
    The candidate always plays side A as `build` with its game-JSON weights."""
    entry = {"game_json": str(WEIGHTS_DIR / "_candidate.json"),
             "npz": str(WEIGHTS_DIR / "_candidate.npz")}
    save_net(net, entry)
    if jobs <= 1:
        scores = [fitness(run_match(build, opp_build or build, entry["game_json"],
                                    opp_policy, episodes, seed + 17 * i, record=record), "a")
                  for i, (opp_policy, opp_build) in enumerate(opponents)]
    else:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            futs = [ex.submit(run_match, build, opp_build or build, entry["game_json"],
                              opp_policy, episodes, seed + 17 * i)
                    for i, (opp_policy, opp_build) in enumerate(opponents)]
            scores = [fitness(f.result(), "a") for f in futs]
    return float(np.mean(scores))


def evaluate_candidates(cands: list[PolicyNet], build: str,
                        opponents: list[tuple[str, str | None]], episodes: int,
                        seed: int, jobs: int, mirror: bool = False) -> list[float]:
    """The parallel speedup that matters: ALL ES perturbations x ALL opponents in
    one worker pool. Each candidate gets its own weights file (no path races).
    mirror=True (global net): side A plays the opponent's build too — the net is
    evaluated AS every build against its native mirror."""
    pairs: list[tuple[int, str, str, str]] = []   # (cand_idx, policy_a, policy_b, build_b)
    for i, cand in enumerate(cands):
        path = str(WEIGHTS_DIR / f"_cand_{i}.json")
        cand.export_game_json(path)
        for opp_policy, opp_build in opponents:
            pairs.append((i, path, opp_policy, opp_build or build))

    def one(p: tuple[int, str, str, str]) -> tuple[int, float]:
        i, policy_a, opp_policy, build_b = p
        build_a = build_b if mirror else build
        return i, fitness(run_match(build_a, build_b, policy_a, opp_policy,
                                    episodes, seed + i * 977), "a")

    scores = [[] for _ in cands]
    if jobs <= 1:
        for p in pairs:
            i, s = one(p)
            scores[i].append(s)
    else:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            for i, s in ex.map(one, pairs):
                scores[i].append(s)
    return [float(np.mean(s)) for s in scores]


def train_es(key: str, build: str, generations: int, pop: int, episodes: int,
             sigma: float, lr: float, seed: int, opponents: list[tuple[str, str | None]],
             jobs: int = 1) -> dict:
    reg = load_registry()
    dep = deployed(reg, key)
    if dep and Path(dep["npz"]).exists():
        base = PolicyNet.load_npz(dep["npz"])
        print(f"[train:{key}] warm-start from v{dep['version']}")
    else:
        base = PolicyNet(seed=seed)
        base.ensure_embedding("*", seed)
        print(f"[train:{key}] fresh net")
    base.ensure_embedding("*", seed)
    rng = np.random.default_rng(seed)
    theta = base.flat()
    for g in range(generations):
        noises = [rng.normal(0.0, 1.0, theta.size) for _ in range(pop)]
        cands = []
        for noise in noises:
            cand = base.clone()
            cand.set_flat(theta + sigma * noise)
            cands.append(cand)
        scores = evaluate_candidates(cands, build, opponents, episodes,
                                     seed + g * 1000, jobs)
        for i, s in enumerate(scores):
            print(f"[train:{key}] g{g} cand{i} fitness={s:.3f}")
        ranks = np.argsort(np.argsort(scores))
        centered = (ranks - (pop - 1) / 2.0) / max((pop - 1) / 2.0, 1.0)
        theta = theta + (lr / (pop * sigma)) * sum(c * n for c, n in zip(centered, noises))
        base.set_flat(theta)
        print(f"[train:{key}] g{g} best={max(scores):.3f} mean={np.mean(scores):.3f}")
    entry = registry_add(reg, key, "species" if key != "global" else "global",
                         f"v{dep['version']}" if dep else None)
    save_net(base, entry)
    save_registry(reg)
    print(f"[train:{key}] registered v{entry['version']} (candidate — run the gate)")
    return entry


def parse_opponents(spec: str) -> list[tuple[str, str | None]]:
    """'native@<build>,scripted@<build>,/path/weights.json@<build>' entries."""
    out = []
    for part in spec.split(","):
        pol, _, bld = part.partition("@")
        out.append((pol.strip(), bld.strip() or None))
    return out


# ---- CLI -------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(prog="ml.training.league")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("roster")
    p_init = sub.add_parser("init")
    p_init.add_argument("--key", required=True)
    p_init.add_argument("--global", dest="is_global", action="store_true")
    p_tr = sub.add_parser("train")
    p_tr.add_argument("--key", required=True)
    p_tr.add_argument("--build", required=True)
    p_tr.add_argument("--generations", type=int, default=3)
    p_tr.add_argument("--pop", type=int, default=6)
    p_tr.add_argument("--episodes", type=int, default=4)
    p_tr.add_argument("--sigma", type=float, default=0.02)
    p_tr.add_argument("--lr", type=float, default=0.02)
    p_tr.add_argument("--seed", type=int, default=2026)
    p_tr.add_argument("--opponents", default="")
    p_tr.add_argument("--jobs", type=int, default=1,
                      help="parallel headless godot workers (docs/tech/32)")
    p_tg = sub.add_parser("train-global")
    p_tg.add_argument("--builds", required=True)
    p_tg.add_argument("--generations", type=int, default=3)
    p_tg.add_argument("--pop", type=int, default=6)
    p_tg.add_argument("--episodes", type=int, default=2)
    p_tg.add_argument("--seed", type=int, default=2026)
    p_tg.add_argument("--jobs", type=int, default=1)
    p_gate = sub.add_parser("gate")
    p_gate.add_argument("--key", required=True)
    p_gate.add_argument("--build", required=True)
    p_gate.add_argument("--episodes", type=int, default=4)
    p_rr = sub.add_parser("round-robin")
    p_rr.add_argument("--episodes", type=int, default=2)
    args = ap.parse_args()

    if args.cmd == "roster":
        data = json.loads(BUILDS_JSON.read_text())
        for b in data["builds"]:
            print(f"{b['id']:38s} {b['kind']:8s} {b.get('name', '')}")
        return 0

    if args.cmd == "init":
        reg = load_registry()
        net = PolicyNet(seed=2026)
        net.ensure_embedding("*", 2026)
        entry = registry_add(reg, "global" if args.is_global else args.key,
                             "global" if args.is_global else "species", None)
        save_net(net, entry)
        save_registry(reg)
        print(f"[init] {entry['key']} v{entry['version']} (candidate — gate to deploy)")
        return 0

    if args.cmd == "train":
        opponents = parse_opponents(args.opponents) if args.opponents else DEFAULT_OPPONENTS
        train_es(args.key, args.build, args.generations, args.pop, args.episodes,
                 args.sigma, args.lr, args.seed, opponents, args.jobs)
        return 0

    if args.cmd == "train-global":
        # The global net plays EVERY build against the native baseline, so one
        # gradient signal aggregates episodes from every creature and build.
        builds = [b.strip() for b in args.builds.split(",")]
        reg = load_registry()
        dep = deployed(reg, "global")
        net = PolicyNet.load_npz(dep["npz"]) if dep and Path(dep["npz"]).exists() \
            else PolicyNet(seed=args.seed)
        for b in builds:
            net.ensure_embedding(b, args.seed)   # content-id rows, canon §9 §5
        net.ensure_embedding("*", args.seed)
        rng = np.random.default_rng(args.seed)
        theta = net.flat()
        sigma, lr, pop = 0.02, 0.02, args.pop
        for g in range(args.generations):
            noises = [rng.normal(0.0, 1.0, theta.size) for _ in range(pop)]
            cands = []
            for noise in noises:
                cand = net.clone()
                cand.set_flat(theta + sigma * noise)
                cands.append(cand)
            scores = evaluate_candidates(
                cands, builds[0], [("native", b) for b in builds],
                args.episodes, args.seed + g * 1000, args.jobs, mirror=True)
            for i, s in enumerate(scores):
                print(f"[global] g{g} cand{i} fitness={s:.3f}")
            ranks = np.argsort(np.argsort(scores))
            centered = (ranks - (pop - 1) / 2.0) / max((pop - 1) / 2.0, 1.0)
            theta = theta + (lr / (pop * sigma)) * sum(c * n for c, n in zip(centered, noises))
            net.set_flat(theta)
            print(f"[global] g{g} best={max(scores):.3f} mean={np.mean(scores):.3f}")
        entry = registry_add(reg, "global", "global", f"v{dep['version']}" if dep else None)
        save_net(net, entry)
        save_registry(reg)
        print(f"[global] registered v{entry['version']} (candidate — gate to deploy)")
        return 0

    if args.cmd == "gate":
        from ml.eval.gate import run_gate
        reg = load_registry()
        cand = reg["policies"][-1] if not args.key else None
        for p in reversed(reg["policies"]):
            if p["key"] == args.key and not p.get("deployed"):
                cand = p
                break
        if cand is None:
            print("[gate] no candidate to evaluate")
            return 1
        ok = run_gate(reg, cand, args.build, args.episodes)
        save_registry(reg)
        return 0 if ok else 1

    if args.cmd == "round-robin":
        reg = load_registry()
        keys = [p["key"] for p in reg["policies"] if p.get("deployed")]
        keys = sorted(set(keys))
        print(f"[rr] deployed policies: {keys or 'none (init + train + gate first)'}")
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
