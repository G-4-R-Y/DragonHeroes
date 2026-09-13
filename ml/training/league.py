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
  python3 -m ml.training.league versus --best-of 9 \
      --a fen_boar --a-build core.arena.fen_boar_alpha \
      --b native   --b-build core.arena.fen_boar_alpha

`versus` is the head-to-head bench (Ricardo, 2026-09-13: "even put one against
the other for benchmarking (best of N)"): any two sides — a registry net, a
weights file, or the native/scripted baselines — play a best-of-N and the
verdict is written to ml/data/benchmarks/ as schema arena.versus.v1, so
comparisons accumulate instead of scrolling past. It streams the same progress
feed under the key "versus" while it runs.

KNOBS (train) — every one of these is a CLI flag; the numbers are the defaults
this module ships, not the ones tools/train_run.sh passes:
    --generations 3   ES iterations. Each costs pop x opponents matches.
    --pop 6           perturbations per generation. Fill your cores: matches
                      per generation = pop x len(opponents).
    --episodes 4      episodes per match. A neural side makes episodes differ
                      (aim noise + observation delay consume the seed), so this
                      is the variance knob; two BASELINE sides are deterministic.
    --sigma 0.02      ES noise scale       --lr 0.02   ES step size
    --seed 2026       every match seed is derived from it, so a run replays
    --jobs 1          concurrent headless Godot workers (docs/tech/32)
    --speed max       "max" = CPU-bound with --fixed-fps 60, bit-identical to
                      a wall-locked run; a number is a wall multiplier
    --opponents ""    "policy@build,..."; empty = native + scripted
    --checkpoint-every 25   save theta + the RNG stream every N generations
                      (0 disables). Without it a killed 1000-generation run
                      loses everything: the net registers only at the END.
    --resume          continue this key's checkpoint instead of restarting the
                      search. Exact, not approximate: match seeds are derived
                      from the generation index and the perturbation RNG is
                      restored from its saved state.
ARTIFACTS — what a run leaves behind and who eats it:
    ml/serving/weights/<key>_v<N>.json   arena.policy.v1, loaded by the Godot
                                         arena (game/arena/neural_policy.gd)
    ml/serving/weights/<key>_v<N>.npz    the raw net, warm-start for the next run
    ml/serving/registry.json             arena.registry.v1: every version, one
                                         `deployed` pin per key = what ships
    ml/data/progress/<key>.jsonl         this feed (below)
    ml/data/episodes/*.json              per-match results; obs+action JSONL
                                         when --record-dir is set (the R0 dataset)
    ml/data/benchmarks/*.json            arena.versus.v1 verdicts
  $DH_SERVING_DIR redirects the first three into an isolated run folder
  (ml/serving_paths.py, tools/train_run.sh) so experiments never overwrite what
  the game serves. Full reference: docs/tech/37-ml-parameter-reference.md.
GATE BANDS (ml/eval/gate.py, the only thing that lets a net deploy):
    suite vs scripted/native  win rate in [0.30, 1.00]
    ladder vs deployed self   win rate in [0.25, 0.90]
    sanity                    mean loser hp deficit >= 0.05 per episode

train / train-global / gate also append a JSONL progress feed to
ml/data/progress/<key>.jsonl (or --progress-file) — the seam the arena training
console tails (docs/design/25 §2). stdout stays the human/script log.
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
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
    speed = parse_speed(speed)
    out = EPISODES_DIR / f"result_{int(time.time() * 1000)}_{next(_NONCE)}.json"
    engine_opts = ["--headless"]
    if speed == "max":
        engine_opts += ["--fixed-fps", "60"]   # engine flag: must precede `--`
    # $DH_ARENA_BIN = the release trainer export (tools/build_arena.sh). Verified
    # bit-identical to the editor binary; it boots the arena ITSELF because a
    # release template refuses a scene path on the command line, which is why the
    # export carries a feature-tagged run/main_scene.trainer. Worth it for the
    # startup alone: 4.01 s -> 2.53 s per match, and a generation is 20 matches.
    arena_bin = os.environ.get("DH_ARENA_BIN", "").strip()
    if arena_bin and Path(arena_bin).is_file():
        cmd = [arena_bin, *engine_opts, "--"]
    else:
        godot = shutil.which("godot")
        if godot is None:
            raise RuntimeError("godot not on PATH")
        cmd = [godot, *engine_opts, "--path", str(ROOT / "game"), ARENA_SCENE, "--"]
    cmd += ["--a", a, "--b", b, "--policy-a", policy_a, "--policy-b", policy_b,
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


# ---- checkpoints: a long ES run must survive being killed -------------------------

# Ricardo, 2026-09-13, after a 10.4-hour run turned out to have nothing on disk:
# "Periodic checkpointing in the ES trainer, so a long run becomes interruptible
# instead of all-or-nothing. And a resume flag... --> do it".
#
# train_es only registered its net AFTER the whole generation loop, so killing a
# 1000-generation sweep at generation 488 discarded every hour of it. Now the
# search state (theta, the next generation, the RNG stream) lands every
# CHECKPOINT_EVERY generations, and --resume picks it back up.
#
# What makes resuming EXACT rather than approximate: every generation's match
# seeds are derived as `seed + g * 1000`, so replaying from generation g uses
# the same seeds it would have used; and the perturbation RNG is restored from
# its saved bit-generator state, so the noise draws continue the same stream
# instead of restarting it. A resumed run is the run that would have happened.
CHECKPOINT_EVERY = 25


def checkpoint_path(key: str) -> Path:
    """ONE file, deliberately. An earlier version wrote theta and the metadata
    separately; each rename was atomic but the PAIR was not, so a kill landing
    between them left weights from generation N beside metadata claiming N-k —
    and a resume would then replay generations it had already done, silently.
    Everything now lives in a single .npz written temp-then-renamed, so a
    checkpoint either exists completely or does not exist.

    It sits beside the run's other artifacts, so an isolated run
    ($DH_SERVING_DIR) checkpoints inside its own folder."""
    return WEIGHTS_DIR / f"_ckpt_{key}.npz"


def save_checkpoint(key: str, theta: np.ndarray, next_g: int, rng: np.random.Generator,
                    meta: dict) -> Path:
    path = checkpoint_path(key)
    WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)
    state = {"key": key, "next_g": int(next_g), "theta_size": int(theta.size),
             "rng_state": rng.bit_generator.state,
             "saved": time.strftime("%Y-%m-%dT%H:%M:%S"), **meta}
    # NOTE: np.savez* appends ".npz" unless the name already ends in it, so the
    # temp name has to keep that suffix or the rename below has nothing to move
    tmp = path.with_suffix(".tmp.npz")
    np.savez_compressed(tmp, theta=theta, meta=np.array(json.dumps(state, default=str)))
    tmp.replace(path)                      # the one atomic step
    return path


def read_checkpoint(key: str) -> dict | None:
    """The raw saved state, or None when there is no readable checkpoint."""
    path = checkpoint_path(key)
    if not path.exists():
        return None
    try:
        with np.load(path, allow_pickle=False) as data:
            state = json.loads(str(data["meta"]))
            state["theta"] = data["theta"]
        return state
    except Exception as e:
        print(f"[train:{key}] checkpoint unreadable ({e}) — starting fresh")
        return None


def load_checkpoint(key: str, theta_size: int, generations: int) -> dict | None:
    """The saved search state, or None when there is nothing usable. A
    checkpoint from a different net shape (the warm-start moved) or from an
    already finished run is refused rather than half-applied."""
    state = read_checkpoint(key)
    if state is None:
        return None
    theta = state["theta"]
    if int(state.get("theta_size", -1)) != theta_size or theta.size != theta_size:
        print(f"[train:{key}] checkpoint is for a {state.get('theta_size')}-parameter net, "
              f"this run has {theta_size} — starting fresh")
        return None
    if int(state.get("next_g", 0)) >= generations:
        print(f"[train:{key}] checkpoint is already at generation "
              f"{state.get('next_g')}/{generations} — nothing to resume")
        return None
    return state


def clear_checkpoint(key: str) -> None:
    """A completed run leaves no checkpoint, so a later --resume cannot pick up
    a finished search and think it has work to do."""
    checkpoint_path(key).unlink(missing_ok=True)


def train_es(key: str, build: str, generations: int, pop: int, episodes: int,
             sigma: float, lr: float, seed: int, opponents: list[tuple[str, str | None]],
             jobs: int = 1, progress: Progress | None = None,
             speed: str | float = DEFAULT_SPEED, checkpoint_every: int = CHECKPOINT_EVERY,
             resume: bool = False) -> dict:
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
    start_g = 0
    if resume:
        state = load_checkpoint(key, theta.size, generations)
        if state is not None:
            theta = state["theta"]
            base.set_flat(theta)
            start_g = int(state["next_g"])
            rng.bit_generator.state = state["rng_state"]   # continue the stream
            print(f"[train:{key}] resumed from generation {start_g}/{generations} "
                  f"(checkpoint saved {state.get('saved', '?')})")
            progress.emit("resumed", g=start_g, generations=generations,
                          saved=str(state.get("saved", "")))
    ckpt_meta = {"build": build, "seed": seed, "pop": pop, "sigma": sigma, "lr": lr,
                 "episodes": episodes, "generations": generations}
    for g in range(start_g, generations):
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
        if checkpoint_every > 0 and ((g + 1) % checkpoint_every == 0
                                     or g + 1 == generations):
            path = save_checkpoint(key, theta, g + 1, rng, ckpt_meta)
            print(f"[train:{key}] checkpoint g{g + 1} -> {path.name}")
            progress.emit("checkpoint", g=g + 1, path=str(path))
    entry = registry_add(reg, key, "species" if key != "global" else "global",
                         f"v{dep['version']}" if dep else None)
    save_net(base, entry)
    save_registry(reg)
    clear_checkpoint(key)          # the search finished; nothing left to resume
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


# ---- versus: head-to-head best-of-N -----------------------------------------------


BENCH_DIR = ROOT / "ml" / "data" / "benchmarks"


def resolve_policy(spec: str, reg: dict | None = None) -> tuple[str, str]:
    """A versus side -> (policy argument for the arena, human label).

    Accepted: "native", "scripted", a path to an arena.policy.v1 JSON, or a
    registry reference "<key>" (its deployed pin, else its newest candidate) or
    "<key>@v3" / "<key>@candidate" / "<key>@deployed" to pin one exactly.
    """
    spec = (spec or "").strip()
    if spec in ("native", "scripted"):
        return spec, spec
    path = Path(spec)
    if path.exists() and path.suffix == ".json" and path.is_file():
        return str(path), path.stem
    key, _, want = spec.partition("@")
    reg = reg if reg is not None else load_registry()
    mine = [p for p in reg.get("policies", []) if p.get("key") == key]
    if not mine:
        raise SystemExit(f"versus: cannot resolve '{spec}' — not a file, not a "
                         f"registry key, not native/scripted")
    pick = None
    if want.startswith("v") and want[1:].isdigit():
        pick = next((p for p in mine if int(p.get("version", 0)) == int(want[1:])), None)
    elif want == "deployed":
        pick = max((p for p in mine if p.get("deployed")),
                   key=lambda p: p.get("version", 0), default=None)
    elif want == "candidate":
        pick = max((p for p in mine if not p.get("deployed")),
                   key=lambda p: p.get("version", 0), default=None)
    else:                                    # default: the deployed pin, else newest
        pick = max((p for p in mine if p.get("deployed")),
                   key=lambda p: p.get("version", 0), default=None) \
            or max(mine, key=lambda p: p.get("version", 0))
    if pick is None:
        raise SystemExit(f"versus: '{spec}' matches no policy in the registry")
    game_json = pick.get("game_json") or ""
    if not game_json:
        raise SystemExit(f"versus: {key} v{pick.get('version')} has no game_json "
                         f"(train exports it; GRU/squad nets cannot be deployed yet)")
    gp = Path(game_json)
    if not gp.is_absolute():
        gp = ROOT / gp
    if not gp.exists():
        raise SystemExit(f"versus: weights missing for {key} v{pick.get('version')}: {gp}")
    tag = "deployed" if pick.get("deployed") else "candidate"
    return str(gp), f"{key} v{pick.get('version')} ({tag})"


def versus(a_spec: str, b_spec: str, a_build: str, b_build: str, best_of: int,
           episodes: int, seed: int, jobs: int, speed: str | float,
           out_path: Path | None = None, label: str = "",
           progress: Progress | None = None) -> dict:
    """Best-of-N between two sides. Every round is a real arena match set, so a
    verdict here means the same thing a gate verdict means.

    All N rounds are played even once the outcome is decided: a 5-4 and a 5-0
    are different facts, and the extra rounds cost seconds. `clinched_round` is
    still reported for anyone who wants the best-of reading.

    CAVEAT (measured 2026-09-13): a NEURAL side makes rounds differ — aim noise
    and the observation delay consume the per-episode seed, so seeds 3/777/424242
    of one net vs native gave 0-2, 0-0 and 0-1. Two BASELINE sides do not:
    scripted vs native returned a bit-identical 1-0 for every seed tried. So a
    best-of-N between native and scripted is N copies of one match — informative
    as a reference point, not as a distribution.
    """
    if progress is None:
        progress = Progress(None)
    a_policy, a_label = resolve_policy(a_spec)
    b_policy, b_label = resolve_policy(b_spec)
    started = time.strftime("%Y-%m-%dT%H:%M:%S")
    t_start = time.monotonic()
    progress.emit("versus_start", a=a_label, b=b_label, a_build=a_build,
                  b_build=b_build, best_of=best_of, episodes=episodes)

    def one(i: int) -> dict:
        t0 = time.monotonic()
        r = run_match(a_build, b_build, a_policy, b_policy, episodes,
                      seed + i * 7919, speed=speed)
        n = max(len(r["episodes"]), 1)
        row = {"i": i, "seed": seed + i * 7919,
               "wins_a": int(r["wins_a"]), "wins_b": int(r["wins_b"]),
               "draws": int(r.get("draws", 0)),
               "hp_a": float(np.mean([e["hp_a"] for e in r["episodes"]]) if r["episodes"] else 0.0),
               "hp_b": float(np.mean([e["hp_b"] for e in r["episodes"]]) if r["episodes"] else 0.0),
               "score_a": round(r["wins_a"] / n, 4),
               "duration_s": round(time.monotonic() - t0, 2)}
        progress.emit("versus_round", **row)
        return row

    rounds: list[dict] = []
    if jobs <= 1:
        rounds = [one(i) for i in range(best_of)]
    else:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            rounds = list(ex.map(one, range(best_of)))
    rounds.sort(key=lambda r: r["i"])

    wins_a = sum(1 for r in rounds if r["wins_a"] > r["wins_b"])
    wins_b = sum(1 for r in rounds if r["wins_b"] > r["wins_a"])
    draws = len(rounds) - wins_a - wins_b
    need = best_of // 2 + 1
    clinch, ca, cb = None, 0, 0
    for r in rounds:                       # the best-of reading, in round order
        if r["wins_a"] > r["wins_b"]:
            ca += 1
        elif r["wins_b"] > r["wins_a"]:
            cb += 1
        if clinch is None and (ca >= need or cb >= need):
            clinch = r["i"] + 1
    winner = "a" if wins_a > wins_b else ("b" if wins_b > wins_a else "draw")
    verdict = {
        "schema": "arena.versus.v1", "started": started,
        "finished": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "wall_s": round(time.monotonic() - t_start, 2), "label": label,
        "a": {"spec": a_spec, "policy": a_policy, "label": a_label, "build": a_build},
        "b": {"spec": b_spec, "policy": b_policy, "label": b_label, "build": b_build},
        "best_of": best_of, "episodes_per_round": episodes, "seed": seed,
        "speed": str(speed), "jobs": jobs, "rounds": rounds,
        "rounds_a": wins_a, "rounds_b": wins_b, "rounds_drawn": draws,
        "clinched_round": clinch, "winner": winner,
        "episode_win_rate_a": round(sum(r["wins_a"] for r in rounds)
                                    / max(sum(r["wins_a"] + r["wins_b"] + r["draws"]
                                              for r in rounds), 1), 4),
    }
    if out_path is None:
        BENCH_DIR.mkdir(parents=True, exist_ok=True)
        stamp = time.strftime("%Y-%m-%d_%H%M%S")     # DATE FIRST, like ml/runs/
        safe = f"{a_label}_vs_{b_label}".replace(" ", "-").replace("/", "-")
        out_path = BENCH_DIR / f"{stamp}__{safe}.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(verdict, indent=1))
    verdict["out"] = str(out_path)
    progress.emit("versus_done", winner=winner, rounds_a=wins_a, rounds_b=wins_b,
                  draws=draws, out=str(out_path))
    return verdict


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
    p_tr.add_argument("--checkpoint-every", type=int, default=CHECKPOINT_EVERY,
                      help="save the search state (theta + the RNG stream) every N "
                           "generations so a killed run is not lost; 0 disables")
    p_tr.add_argument("--resume", action="store_true",
                      help="continue from this key's checkpoint instead of starting "
                           "the search over")
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
    p_vs = sub.add_parser("versus", help="best-of-N head to head between two nets")
    p_vs.add_argument("--a", required=True,
                      help="native | scripted | path/to/policy.json | <key>[@v3|@deployed|@candidate]")
    p_vs.add_argument("--b", required=True, help="same syntax as --a")
    p_vs.add_argument("--a-build", required=True, help="the build side A plays")
    p_vs.add_argument("--b-build", default="", help="side B's build (default: --a-build)")
    p_vs.add_argument("--best-of", type=int, default=9)
    p_vs.add_argument("--episodes", type=int, default=1,
                      help="episodes per ROUND; a round goes to whoever wins more")
    p_vs.add_argument("--seed", type=int, default=2026)
    p_vs.add_argument("--jobs", type=int, default=1)
    p_vs.add_argument("--speed", default=DEFAULT_SPEED)
    p_vs.add_argument("--label", default="")
    p_vs.add_argument("--out", default="", help="where the verdict JSON lands")
    p_vs.add_argument("--progress-file", default=None)
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
                     speed=args.speed, checkpoint_every=args.checkpoint_every,
                     resume=args.resume)
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

    if args.cmd == "versus":
        progress = Progress(args.progress_file or progress_path("versus"))
        with progress.guard():
            v = versus(args.a, args.b, args.a_build, args.b_build or args.a_build,
                       args.best_of, args.episodes, args.seed, args.jobs,
                       args.speed, Path(args.out) if args.out else None,
                       args.label, progress)
        print(f"[versus] {v['a']['label']} vs {v['b']['label']} "
              f"({v['a']['build']} vs {v['b']['build']})")
        for r in v["rounds"]:
            print(f"[versus]   round {r['i'] + 1}: {r['wins_a']}-{r['wins_b']}"
                  f" hp {r['hp_a']:.2f}/{r['hp_b']:.2f}  {r['duration_s']}s")
        print(f"[versus] RESULT {v['rounds_a']}-{v['rounds_b']}"
              f"{' (' + str(v['rounds_drawn']) + ' drawn)' if v['rounds_drawn'] else ''}"
              f" — winner: {v['winner']}"
              + (f", clinched in round {v['clinched_round']}" if v["clinched_round"] else ""))
        print(f"[versus] {v['out']}")
        return 0

    if args.cmd == "round-robin":
        reg = load_registry()
        keys = [p["key"] for p in reg["policies"] if p.get("deployed")]
        keys = sorted(set(keys))
        print(f"[rr] deployed policies: {keys or 'none (init + train + gate first)'}")
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
