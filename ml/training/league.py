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

train / train-global / gate also append a JSONL progress feed to
ml/data/progress/<key>.jsonl (or --progress-file) — the seam the arena training
console tails (docs/design/25 §2). stdout stays the human/script log.
"""
from __future__ import annotations

import argparse
import itertools
import json
import shutil
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))
from ml.serving_paths import (progress_dir, registry_path,  # noqa: E402
                              weights_dir)

# $DH_SERVING_DIR redirects every artifact to an isolated run folder
# (tools/train_run.sh); unset = the deployed ml/serving (ml/serving_paths.py).
REGISTRY = registry_path()
WEIGHTS_DIR = weights_dir()
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

# --speed for every headless match (arena.gd _apply_speed). "max" = CPU-bound and
# deterministic: the engine flag --fixed-fps 60 makes every frame advance exactly
# 1/60 s of sim regardless of wall time, so a match runs as fast as one core can
# step it. A number N = wall-locked N x (the legacy fast mode is "4": 240 Hz ticks
# x time_scale 4). NOTHING here touches the GPU: the trainer is numpy on a tiny
# MLP and every worker is Godot physics + GDScript — CPU-bound, so throughput =
# cores x per-core speed, and --jobs beyond pop x opponents only idles.
DEFAULT_SPEED = "max"


def parse_speed(spec: str | float) -> str:
    """'max' or a wall multiplier >= 1, normalised to the arena's --speed text."""
    if isinstance(spec, str) and spec.strip().lower() == "max":
        return "max"
    n = float(spec)
    if n < 1.0:
        raise ValueError(f"--speed must be 'max' or a multiplier >= 1, got {spec!r}")
    return f"{n:g}"


# ---- arena subprocess ---------------------------------------------------------


def run_match(a: str, b: str, policy_a: str, policy_b: str, episodes: int,
              seed: int, time_limit: float = 45.0, record: bool = False,
              timeout: float | None = None, speed: str | float = DEFAULT_SPEED) -> dict:
    """One headless match set. Policies: native | scripted | <weights.json path>.
    speed: "max" (CPU-bound, --fixed-fps 60) or a wall multiplier (see DEFAULT_SPEED)."""
    godot = shutil.which("godot")
    if godot is None:
        raise RuntimeError("godot not on PATH")
    speed = parse_speed(speed)
    out = EPISODES_DIR / f"result_{int(time.time() * 1000)}_{next(_NONCE)}.json"
    engine_opts = ["--headless"]
    if speed == "max":
        engine_opts += ["--fixed-fps", "60"]   # engine flag: must precede `--`
    cmd = [godot, *engine_opts, "--path", str(ROOT / "game"), ARENA_SCENE, "--",
           "--a", a, "--b", b, "--policy-a", policy_a, "--policy-b", policy_b,
           "--episodes", str(episodes), "--time-limit", str(time_limit),
           "--seed", str(seed), "--fast", "--speed", speed, "--out", str(out)]
    if record:
        cmd += ["--record-dir", str(EPISODES_DIR)]
    if timeout is None:
        # a hang guard, not an estimate: a wall-locked N x match never beats N x
        # (assume no better than the legacy 4x); "max" is CPU-bound, so bound it
        # by real time — an oversubscribed box still finishes well inside that
        wall = 1.0 if speed == "max" else 1.0 / min(float(speed), 4.0)
        timeout = episodes * time_limit * wall + 120.0
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


# ---- progress feed (docs/design/25 §2) ----------------------------------------------


PROGRESS_DIR = progress_dir()


class Progress:
    """The seam between this trainer and the arena training console: an
    append-only JSONL file the console tails while a run is alive. One object
    per line (`t` unix seconds, `ev` event name), flushed on every write so a
    match shows up the moment its Godot process exits — stdout stays silent for
    a whole generation. Matches are emitted from --jobs worker threads, hence
    the lock. path=None disables the feed (library callers, tests)."""

    def __init__(self, path: str | Path | None):
        self.path = Path(path) if path else None
        self._lock = threading.Lock()
        if self.path is not None:
            self.path.parent.mkdir(parents=True, exist_ok=True)

    def emit(self, ev: str, **fields) -> None:
        if self.path is None:
            return
        # numpy scalars leak in from np.mean/argsort; a feed line must never
        # take a six-hour run down, so they degrade to .item()/str.
        line = json.dumps({"t": round(time.time(), 3), "ev": ev, **fields},
                          default=lambda o: o.item() if hasattr(o, "item") else str(o))
        with self._lock, self.path.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
            f.flush()

    @contextmanager
    def guard(self):
        """An uncaught exception becomes an `error` line before it propagates,
        so the console learns why a run died instead of watching a stale file."""
        try:
            yield
        except Exception as e:
            self.emit("error", message=f"{type(e).__name__}: {e}")
            raise


def progress_path(key: str) -> Path:
    return PROGRESS_DIR / f"{key}.jsonl"


# ---- ES training ------------------------------------------------------------------


def evaluate(net: PolicyNet, key: str, build: str, opponents: list[tuple[str, str | None]],
             episodes: int, seed: int, record: bool = False, jobs: int = 1,
             speed: str | float = DEFAULT_SPEED) -> float:
    """Fitness = mean over opponents of (win rate + hp-margin shaping).
    The candidate always plays side A as `build` with its game-JSON weights."""
    entry = {"game_json": str(WEIGHTS_DIR / "_candidate.json"),
             "npz": str(WEIGHTS_DIR / "_candidate.npz")}
    save_net(net, entry)
    if jobs <= 1:
        scores = [fitness(run_match(build, opp_build or build, entry["game_json"],
                                    opp_policy, episodes, seed + 17 * i, record=record,
                                    speed=speed), "a")
                  for i, (opp_policy, opp_build) in enumerate(opponents)]
    else:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            futs = [ex.submit(run_match, build, opp_build or build, entry["game_json"],
                              opp_policy, episodes, seed + 17 * i, speed=speed)
                    for i, (opp_policy, opp_build) in enumerate(opponents)]
            scores = [fitness(f.result(), "a") for f in futs]
    return float(np.mean(scores))


def evaluate_candidates(cands: list[PolicyNet], build: str,
                        opponents: list[tuple[str, str | None]], episodes: int,
                        seed: int, jobs: int, mirror: bool = False,
                        progress: Progress | None = None, g: int = 0,
                        speed: str | float = DEFAULT_SPEED) -> list[float]:
    """The parallel speedup that matters: ALL ES perturbations x ALL opponents in
    one worker pool. Each candidate gets its own weights file (no path races).
    mirror=True (global net): side A plays the opponent's build too — the net is
    evaluated AS every build against its native mirror. One arena run IS one
    `match` progress event (generation `g`), emitted from whichever worker
    finished it."""
    if progress is None:
        progress = Progress(None)
    WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)   # fresh checkouts have no weights/ yet
    pairs: list[tuple[int, str, str, str]] = []   # (cand_idx, policy_a, policy_b, build_b)
    for i, cand in enumerate(cands):
        path = str(WEIGHTS_DIR / f"_cand_{i}.json")
        cand.export_game_json(path)
        for opp_policy, opp_build in opponents:
            pairs.append((i, path, opp_policy, opp_build or build))

    def one(p: tuple[int, str, str, str]) -> tuple[int, float]:
        i, policy_a, opp_policy, build_b = p
        build_a = build_b if mirror else build
        t0 = time.monotonic()
        result = run_match(build_a, build_b, policy_a, opp_policy, episodes, seed + i * 977,
                           speed=speed)
        # score = plain win rate (0..1); the hp-margin shaping lives in `candidate`
        n = max(len(result["episodes"]), 1)
        progress.emit("match", g=g, cand=i, opp=build_b, policy=opp_policy,
                      wins_a=result["wins_a"], wins_b=result["wins_b"],
                      draws=result.get("draws", 0), score=round(result["wins_a"] / n, 4),
                      duration_s=round(time.monotonic() - t0, 2))
        return i, fitness(result, "a")

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
             jobs: int = 1, progress: Progress | None = None,
             speed: str | float = DEFAULT_SPEED) -> dict:
    if progress is None:
        progress = Progress(None)
    speed = parse_speed(speed)
    reg = load_registry()
    dep = deployed(reg, key)
    warm_start = None
    if dep and Path(dep["npz"]).exists():
        base = PolicyNet.load_npz(dep["npz"])
        warm_start = dep["version"]
        print(f"[train:{key}] warm-start from v{dep['version']}")
    else:
        base = PolicyNet(seed=seed)
        base.ensure_embedding("*", seed)
        print(f"[train:{key}] fresh net")
    base.ensure_embedding("*", seed)
    progress.emit("start", key=key, build=build, generations=generations, pop=pop,
                  episodes=episodes, jobs=jobs, speed=speed,
                  opponents=[[opp_build or build, opp_policy] for opp_policy, opp_build in opponents],
                  warm_start=warm_start)
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
                                     seed + g * 1000, jobs, progress=progress, g=g,
                                     speed=speed)
        for i, s in enumerate(scores):
            print(f"[train:{key}] g{g} cand{i} fitness={s:.3f}")
            progress.emit("candidate", g=g, cand=i, fitness=float(s))
        ranks = np.argsort(np.argsort(scores))
        centered = (ranks - (pop - 1) / 2.0) / max((pop - 1) / 2.0, 1.0)
        theta = theta + (lr / (pop * sigma)) * sum(c * n for c, n in zip(centered, noises))
        base.set_flat(theta)
        print(f"[train:{key}] g{g} best={max(scores):.3f} mean={np.mean(scores):.3f}")
        progress.emit("generation", g=g, best=float(max(scores)), mean=float(np.mean(scores)))
    entry = registry_add(reg, key, "species" if key != "global" else "global",
                         f"v{dep['version']}" if dep else None)
    save_net(base, entry)
    save_registry(reg)
    print(f"[train:{key}] registered v{entry['version']} (candidate — run the gate)")
    progress.emit("registered", version=entry["version"], npz=entry["npz"])
    return entry


def train_global(builds: list[str], generations: int, pop: int, episodes: int,
                 seed: int, jobs: int = 1, progress: Progress | None = None,
                 speed: str | float = DEFAULT_SPEED) -> dict:
    """The global net plays EVERY build against the native baseline, so one
    gradient signal aggregates episodes from every creature and build. Same
    progress events as train_es under key "global"; `build` is the --builds
    spec verbatim because in mirror mode side A wears every build in turn."""
    if progress is None:
        progress = Progress(None)
    speed = parse_speed(speed)
    reg = load_registry()
    dep = deployed(reg, "global")
    warm = bool(dep and Path(dep["npz"]).exists())
    net = PolicyNet.load_npz(dep["npz"]) if warm else PolicyNet(seed=seed)
    for b in builds:
        net.ensure_embedding(b, seed)   # content-id rows, canon §9 §5
    net.ensure_embedding("*", seed)
    opponents = [("native", b) for b in builds]
    progress.emit("start", key="global", build=",".join(builds), generations=generations,
                  pop=pop, episodes=episodes, jobs=jobs, speed=speed,
                  opponents=[[b, pol] for pol, b in opponents],
                  warm_start=dep["version"] if warm else None)
    rng = np.random.default_rng(seed)
    theta = net.flat()
    sigma, lr = 0.02, 0.02
    for g in range(generations):
        noises = [rng.normal(0.0, 1.0, theta.size) for _ in range(pop)]
        cands = []
        for noise in noises:
            cand = net.clone()
            cand.set_flat(theta + sigma * noise)
            cands.append(cand)
        scores = evaluate_candidates(cands, builds[0], opponents, episodes,
                                     seed + g * 1000, jobs, mirror=True,
                                     progress=progress, g=g, speed=speed)
        for i, s in enumerate(scores):
            print(f"[global] g{g} cand{i} fitness={s:.3f}")
            progress.emit("candidate", g=g, cand=i, fitness=float(s))
        ranks = np.argsort(np.argsort(scores))
        centered = (ranks - (pop - 1) / 2.0) / max((pop - 1) / 2.0, 1.0)
        theta = theta + (lr / (pop * sigma)) * sum(c * n for c, n in zip(centered, noises))
        net.set_flat(theta)
        print(f"[global] g{g} best={max(scores):.3f} mean={np.mean(scores):.3f}")
        progress.emit("generation", g=g, best=float(max(scores)), mean=float(np.mean(scores)))
    entry = registry_add(reg, "global", "global", f"v{dep['version']}" if dep else None)
    save_net(net, entry)
    save_registry(reg)
    print(f"[global] registered v{entry['version']} (candidate — gate to deploy)")
    progress.emit("registered", version=entry["version"], npz=entry["npz"])
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
                      help="parallel headless godot workers (docs/tech/32); useful "
                           "only up to pop x opponents = matches per generation")
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
    for p in (p_tr, p_tg, p_gate):
        p.add_argument("--progress-file", default=None,
                       help="JSONL progress feed for the training console "
                            "(docs/design/25 §2); default ml/data/progress/<key>.jsonl")
    for p in (p_tr, p_tg):
        p.add_argument("--speed", default=DEFAULT_SPEED,
                       help="per-match sim speed: 'max' (CPU-bound, deterministic; the "
                            "default) or a wall-clock multiplier such as 4 (the old 4x)")
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
        progress = Progress(args.progress_file or progress_path(args.key))
        with progress.guard():
            train_es(args.key, args.build, args.generations, args.pop, args.episodes,
                     args.sigma, args.lr, args.seed, opponents, args.jobs, progress,
                     speed=args.speed)
        return 0

    if args.cmd == "train-global":
        builds = [b.strip() for b in args.builds.split(",")]
        progress = Progress(args.progress_file or progress_path("global"))
        with progress.guard():
            train_global(builds, args.generations, args.pop, args.episodes, args.seed,
                         args.jobs, progress, speed=args.speed)
        return 0

    if args.cmd == "gate":
        from ml.eval.gate import run_gate
        progress = Progress(args.progress_file or progress_path(args.key))
        reg = load_registry()
        cand = reg["policies"][-1] if not args.key else None
        for p in reversed(reg["policies"]):
            if p["key"] == args.key and not p.get("deployed"):
                cand = p
                break
        if cand is None:
            print("[gate] no candidate to evaluate")
            progress.emit("error", message="no candidate to evaluate")
            return 1
        with progress.guard():
            ok = run_gate(reg, cand, args.build, args.episodes)
            save_registry(reg)
        # `pass` is a keyword, hence the dict splat; metrics = the gate's per-check
        # report (every value a {..., "pass": bool} dict) so the console can list it
        progress.emit("gate", **{"version": cand["version"], "pass": bool(ok),
                                 "metrics": cand["eval"].get("checks", {})})
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
