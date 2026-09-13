"""The method tournament (Ricardo, 2026-09-13: "add that to fight over in the
other training methods, as to compete intra-training when train-all, as to
optimize for the best methods").

A sweep used to assume one trainer was best everywhere: `--all` ran ES on every
creature, gated it, and pinned whatever passed. The GPU toggle in the console was
a CHOICE, not a contest. This makes it a contest.

Per key:

    1. every method TRAINS the same creature, isolated, one subprocess each
       (crash isolation, and PPO needs ml/.venv while ES does not)
    2. every candidate is GATED against the SAME pre-tournament pin
    3. the candidates FIGHT each other, best-of-N, in the real arena
    4. the winner takes the deployed pin; the losers stay as candidates

Step 2 is the subtle one. `ml/eval/gate.py` flips `deployed` on a pass, and its
ladder check plays the candidate against "the currently deployed net of this
key". Gate ES first and it becomes the pin, so PPO would then be laddered
against ES instead of against what the fleet actually serves — two candidates
judged by two different yardsticks. So the pin state is snapshotted and restored
around every gate call, and the pin only moves once, at the end, to the winner.

Step 3 is the honest part: a gate verdict says "good enough to ship", it does not
say "better than the other trainer". Only a head to head does, and `versus`
already plays real arena matches, so a bracket verdict means exactly what a gate
verdict means. Rounds differ between neural sides (aim noise consumes the
per-episode seed — see league.versus's caveat), so best-of-N is a real
distribution here, not N copies of one match.

    python3 -m ml.training.tournament --key fen_boar_alpha \
        --build core.arena.fen_boar_alpha --methods es,ppo

    python3 -m ml.training.tournament --all --generations 200 --pop 10
    python3 -m ml.training.tournament --all --dry-run      # the plan + the budget

Also reachable as `python3 -m ml.training.league tournament ...`.

METHODS
    es      ml/training/league.py   — ES in the Godot arena, CPU, no venv
    ppo     ml/training/ppo.py      — PPO over dh-env, CUDA, needs ml/.venv
    evolve  ml/training/evolve.py   — NOT a bracket entrant: it registers under
            derived keys (`<key>_evo_g0c1`), not under <key>, so there is no one
            candidate to enter. Run it, then enter its champion by hand with
            `--extra <key>_evo_g2c0@candidate`.

WHAT IT WRITES
    ml/data/benchmarks/<stamp>__tournament__<key>.json   schema arena.tournament.v1
    ml/data/benchmarks/<stamp>__<a>_vs_<b>.json          one arena.versus.v1 per pair
    the registry pin for <key>                           the winner, if it gated
    ml/data/progress/<key>.jsonl                         the console's live feed

DH_SERVING_DIR is honoured throughout (isolated runs), because every path comes
from league.py, which reads it at import.
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ml.training import league                                      # noqa: E402

BENCH_DIR = league.BENCH_DIR
VENV_PY = ROOT / "ml" / ".venv" / "bin" / "python"
LOG_DIR = ROOT / "ml" / "data" / "logs"
METHODS = ("es", "ppo")

# Bracket points. Chess/football scoring rather than "count the wins": a draw is
# a fact about two nets being equal, and rounds_a == rounds_b happens often
# enough between two competent nets that dropping it would lose information.
WIN_POINTS, DRAW_POINTS = 3, 1


# ---- roster ------------------------------------------------------------------------


def creature_builds() -> list[tuple[str, str]]:
    """(key, build) for every creature in the arena roster — the same derivation
    tools/train_run.sh --all uses (the build id's last dotted segment)."""
    data = json.loads(league.BUILDS_JSON.read_text())
    return [(b["id"].split(".")[-1], b["id"])
            for b in data["builds"] if b.get("kind") == "creature"]


def default_opp_build(build: str) -> str:
    """PPO needs someone to fight. Default to the NEXT creature in the roster so
    a sweep does not train every key against the same opponent, wrapping around;
    a one-creature roster falls back to itself."""
    builds = [b for _, b in creature_builds()]
    if build not in builds or len(builds) < 2:
        return build
    return builds[(builds.index(build) + 1) % len(builds)]


# ---- registry diffing --------------------------------------------------------------


def _stamp(reg: dict) -> set[tuple[str, int]]:
    return {(p.get("key", ""), int(p.get("version", 0))) for p in reg.get("policies", [])}


def _new_entries(before: set[tuple[str, int]], reg: dict) -> list[dict]:
    return [p for p in reg.get("policies", [])
            if (p.get("key", ""), int(p.get("version", 0))) not in before]


def _pick_entrant(new: list[dict], key: str) -> dict | None:
    """The candidate a method contributed: newest version under THIS key that
    exported a game_json. A GRU or squad net registers with game_json null — the
    Godot runtime is a stateless 31-obs MLP, so it cannot fight in the bracket
    and saying so beats crashing on it later."""
    mine = [p for p in new if p.get("key") == key and p.get("game_json")]
    return max(mine, key=lambda p: int(p.get("version", 0))) if mine else None


# ---- pin isolation (see the module docstring, step 2) -------------------------------


def _pin_snapshot(reg: dict, key: str) -> dict[int, bool]:
    return {int(p["version"]): bool(p.get("deployed"))
            for p in reg["policies"] if p.get("key") == key}


def _pin_restore(reg: dict, key: str, snap: dict[int, bool]) -> None:
    for p in reg["policies"]:
        if p.get("key") != key:
            continue
        p["deployed"] = snap.get(int(p.get("version", 0)), False)


def _pin_set(reg: dict, key: str, version: int) -> None:
    """One deployed entry per key — the invariant ml/eval/gate.py documents,
    tools/train_run.sh --promote preserves, and the console's DEPLOY enforces."""
    for p in reg["policies"]:
        if p.get("key") == key:
            p["deployed"] = int(p.get("version", 0)) == version


# ---- the methods -------------------------------------------------------------------


def method_command(method: str, key: str, build: str, opp_build: str,
                   knobs: dict) -> list[str] | None:
    if method == "es":
        cmd = [sys.executable, "-u", "-m", "ml.training.league", "train",
               "--key", key, "--build", build,
               "--generations", str(knobs["generations"]), "--pop", str(knobs["pop"]),
               "--episodes", str(knobs["episodes"]), "--jobs", str(knobs["jobs"]),
               "--seed", str(knobs["seed"]), "--speed", str(knobs["speed"]),
               "--checkpoint-every", str(knobs["checkpoint_every"])]
        if knobs.get("opponents"):
            cmd += ["--opponents", knobs["opponents"]]
        return cmd
    if method == "ppo":
        if not VENV_PY.exists():
            return None
        return [str(VENV_PY), "-u", "-m", "ml.training.ppo",
                "--key", key, "--build", build, "--opp-build", opp_build,
                "--steps", str(knobs["steps"]), "--envs", str(knobs["envs"]),
                "--arch", knobs["arch"],
                "--selfplay-every", str(knobs["selfplay_every"]),
                "--seed", str(knobs["seed"])]
    return None


def run_method(method: str, key: str, build: str, opp_build: str, knobs: dict,
               timeout: float | None, progress: league.Progress) -> dict:
    """Train one method. Never raises: a method that dies is an entrant with a
    reason, not the end of the tournament — the point is to compare whoever
    finishes."""
    row: dict = {"method": method, "status": "ok", "reason": "",
                 "log": "", "train_wall_s": 0.0}
    cmd = method_command(method, key, build, opp_build, knobs)
    if cmd is None:
        row["status"] = "skipped"
        row["reason"] = (f"ml/.venv missing — PPO needs torch ({VENV_PY})"
                         if method == "ppo" else f"unknown method '{method}'")
        progress.emit("method_done", method=method, status=row["status"],
                      reason=row["reason"])
        return row

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_DIR / f"{key}__tournament__{method}.log"
    row["log"] = str(log)
    before = _stamp(league.load_registry())
    progress.emit("method_start", method=method, key=key, build=build,
                  opp_build=opp_build if method == "ppo" else "")
    print(f"[tournament:{key}] {method}: {' '.join(cmd)}", flush=True)
    t0 = time.monotonic()
    try:
        with log.open("w", encoding="utf-8") as lf:
            rc = subprocess.run(cmd, cwd=ROOT, stdout=lf, stderr=subprocess.STDOUT,
                                env=os.environ.copy(),
                                timeout=timeout if timeout else None).returncode
    except subprocess.TimeoutExpired:
        rc, row["status"], row["reason"] = -1, "timeout", f"exceeded {timeout:.0f}s"
    except Exception as e:                      # OSError, missing interpreter, ...
        rc, row["status"], row["reason"] = -1, "failed", f"{type(e).__name__}: {e}"
    row["train_wall_s"] = round(time.monotonic() - t0, 1)

    if rc != 0 and row["status"] == "ok":
        row["status"], row["reason"] = "failed", f"exit {rc} — see {log}"
    entry = _pick_entrant(_new_entries(before, league.load_registry()), key)
    if entry is None:
        if row["status"] == "ok":
            row["status"] = "no-candidate"
            row["reason"] = ("trainer finished but registered no deployable net "
                             "for this key (a GRU/squad net exports no game_json)")
    else:
        row["version"] = int(entry["version"])
        row["game_json"] = entry["game_json"]
        row["spec"] = f"{key}@v{entry['version']}"
        row["label"] = f"{method} v{entry['version']}"
    progress.emit("method_done", method=method, status=row["status"],
                  reason=row["reason"], wall_s=row["train_wall_s"],
                  version=row.get("version", 0))
    print(f"[tournament:{key}] {method}: {row['status']}"
          f"{' — ' + row['reason'] if row['reason'] else ''} "
          f"({row['train_wall_s']}s)", flush=True)
    return row


# ---- the tournament ----------------------------------------------------------------


def tournament(key: str, build: str, methods: list[str], knobs: dict,
               extras: list[str] | None = None, opp_build: str = "",
               best_of: int = 5, bracket_episodes: int = 1, gate_episodes: int = 4,
               seed: int = 2026, jobs: int = 1, speed: str | float = "max",
               do_gate: bool = True, method_timeout: float | None = None,
               out_path: Path | None = None,
               progress: league.Progress | None = None) -> dict:
    progress = progress or league.Progress(None)
    opp_build = opp_build or default_opp_build(build)
    started, t_start = time.strftime("%Y-%m-%dT%H:%M:%S"), time.monotonic()
    progress.emit("tournament_start", key=key, build=build, methods=methods,
                  best_of=best_of, extras=extras or [])
    print(f"\n[tournament:{key}] {build} — methods: {', '.join(methods)}"
          f"{' + extras ' + ','.join(extras) if extras else ''}", flush=True)

    # 1. train
    entrants = [run_method(m, key, build, opp_build, knobs, method_timeout, progress)
                for m in methods]
    for spec in (extras or []):
        try:
            policy, label = league.resolve_policy(spec)
        except SystemExit as e:
            entrants.append({"method": f"extra:{spec}", "status": "failed",
                             "reason": str(e), "log": "", "train_wall_s": 0.0})
            continue
        entrants.append({"method": f"extra:{spec}", "status": "ok", "reason": "",
                         "log": "", "train_wall_s": 0.0, "spec": spec,
                         "game_json": policy, "label": label, "pre_trained": True})

    fighters = [e for e in entrants if e.get("spec")]

    # 2. gate — every candidate against the SAME pre-tournament pin
    if do_gate:
        from ml.eval.gate import run_gate
        reg = league.load_registry()
        snap = _pin_snapshot(reg, key)
        for e in fighters:
            if e.get("pre_trained"):
                continue                       # an extra was gated when it was made
            cand = next((p for p in reg["policies"]
                         if p.get("key") == key
                         and int(p.get("version", 0)) == e["version"]), None)
            if cand is None:
                continue
            e["gate_pass"] = bool(run_gate(reg, cand, build, gate_episodes))
            e["gate_checks"] = cand.get("eval", {}).get("checks", {})
            _pin_restore(reg, key, snap)       # the yardstick must not move
            progress.emit("gate", **{"version": e["version"], "pass": e["gate_pass"],
                                     "method": e["method"],
                                     "metrics": e["gate_checks"]})
        league.save_registry(reg)

    # 3. the bracket
    bracket: list[dict] = []
    for a, b in itertools.combinations(fighters, 2):
        progress.emit("bracket_start", a=a.get("label", a["spec"]),
                      b=b.get("label", b["spec"]), best_of=best_of)
        v = league.versus(a["spec"], b["spec"], build, build, best_of,
                          bracket_episodes, seed, jobs, speed,
                          label=f"tournament {key}: {a['method']} vs {b['method']}",
                          progress=progress)
        bracket.append({"a": a["method"], "b": b["method"], "best_of": best_of,
                        "rounds_a": v["rounds_a"], "rounds_b": v["rounds_b"],
                        "rounds_drawn": v["rounds_drawn"], "winner": v["winner"],
                        "episode_win_rate_a": v["episode_win_rate_a"],
                        "out": v["out"]})
        for side in (a, b):
            side.setdefault("points", 0)
            side.setdefault("rounds_won", 0)
            side.setdefault("episode_wr", [])
        a["points"] += WIN_POINTS if v["winner"] == "a" else (
            DRAW_POINTS if v["winner"] == "draw" else 0)
        b["points"] += WIN_POINTS if v["winner"] == "b" else (
            DRAW_POINTS if v["winner"] == "draw" else 0)
        a["rounds_won"] += v["rounds_a"]
        b["rounds_won"] += v["rounds_b"]
        a["episode_wr"].append(v["episode_win_rate_a"])
        b["episode_wr"].append(round(1.0 - v["episode_win_rate_a"], 4))

    # 4. the table, and the pin
    for e in fighters:
        e.setdefault("points", 0)
        e.setdefault("rounds_won", 0)
        wr = e.setdefault("episode_wr", [])
        e["episode_win_rate"] = round(sum(wr) / len(wr), 4) if wr else 0.0
        e.pop("episode_wr", None)
    # rank: bracket points, then rounds, then episode win rate. The gate is a
    # veto on DEPLOYING, not a tiebreak — a net that wins the bracket but fails
    # the gate is still the best net of the round, and saying so is the point.
    table = sorted(fighters, key=lambda e: (e["points"], e["rounds_won"],
                                            e["episode_win_rate"]), reverse=True)
    eligible = [e for e in table
                if e.get("gate_pass", not do_gate) and not e.get("pre_trained")]
    champion = table[0] if table else None
    winner = eligible[0] if eligible else None

    deployed = False
    if winner is not None and "version" in winner:
        reg = league.load_registry()
        _pin_set(reg, key, int(winner["version"]))
        league.save_registry(reg)
        deployed = True

    verdict = {
        "schema": "arena.tournament.v1", "started": started,
        "finished": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "wall_s": round(time.monotonic() - t_start, 1),
        "key": key, "build": build, "opp_build": opp_build,
        "methods": methods, "extras": extras or [], "knobs": knobs,
        "best_of": best_of, "bracket_episodes": bracket_episodes,
        "gate_episodes": gate_episodes if do_gate else 0,
        "seed": seed, "jobs": jobs, "speed": str(speed),
        "entrants": entrants, "bracket": bracket,
        "table": [{"method": e["method"], "label": e.get("label", ""),
                   "version": e.get("version"), "points": e["points"],
                   "rounds_won": e["rounds_won"],
                   "episode_win_rate": e["episode_win_rate"],
                   "gate_pass": e.get("gate_pass")} for e in table],
        "champion": champion["method"] if champion else None,
        "winner": winner["method"] if winner else None,
        "winner_version": winner.get("version") if winner else None,
        "deployed": deployed,
    }
    if out_path is None:
        BENCH_DIR.mkdir(parents=True, exist_ok=True)
        out_path = BENCH_DIR / f"{time.strftime('%Y-%m-%d_%H%M%S')}__tournament__{key}.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(verdict, indent=1))
    verdict["out"] = str(out_path)
    progress.emit("tournament_done", key=key, winner=verdict["winner"],
                  champion=verdict["champion"], deployed=deployed, out=str(out_path))
    print_table(verdict)
    return verdict


def print_table(v: dict) -> None:
    print(f"\n[tournament:{v['key']}] RESULT after {v['wall_s']}s")
    for row in v["table"]:
        gate = {True: "gate PASS", False: "gate FAIL", None: "not gated"}[row["gate_pass"]]
        print(f"   {row['method']:<10s} pts={row['points']:<3d} "
              f"rounds={row['rounds_won']:<3d} ep_wr={row['episode_win_rate']:.3f}  {gate}")
    for e in v["entrants"]:
        if e["status"] != "ok":
            print(f"   {e['method']:<10s} {e['status']}: {e['reason']}")
    if v["winner"]:
        print(f"   -> {v['winner']} v{v['winner_version']} takes the pin"
              f" for {v['key']}")
    elif v["champion"]:
        why = ("it is an --extra reference point, not a trainable entrant"
               if str(v["champion"]).startswith("extra:")
               else "no entrant passed the gate")
        print(f"   -> {v['champion']} won the bracket but takes no pin: {why}"
              f" — the fleet stays on its previous pin")
    else:
        print("   -> no entrant produced a net; nothing changed")
    print(f"   {v['out']}", flush=True)


def plan(keys: list[tuple[str, str]], methods: list[str], knobs: dict,
         best_of: int, bracket_episodes: int, gate_episodes: int,
         extras: list[str]) -> None:
    """--dry-run. A tournament trains every key once PER METHOD, so the budget
    is the thing to look at before starting one, not after."""
    n_fight = len(methods) + len(extras)
    pairs = n_fight * (n_fight - 1) // 2
    es_matches = knobs["generations"] * knobs["pop"] * 2      # x opponents (default 2)
    print(f"tournament plan — {len(keys)} key(s) x {len(methods)} method(s)"
          f"{f' + {len(extras)} extra(s)' if extras else ''}\n")
    for key, build in keys:
        print(f"  {key:<22s} {build}   ppo opponent: {default_opp_build(build)}")
    print(f"\n  per key:")
    if "es" in methods:
        print(f"    es      {knobs['generations']} gens x pop {knobs['pop']} x 2 opponents "
              f"= {es_matches:,} matches of {knobs['episodes']} episodes, "
              f"{knobs['jobs']} jobs")
    if "ppo" in methods:
        print(f"    ppo     {knobs['steps']:,} steps x {knobs['envs']} envs, "
              f"arch {knobs['arch']}  (GPU, ml/.venv"
              f"{'' if VENV_PY.exists() else ' — MISSING, would be skipped'})")
    if gate_episodes:
        print(f"    gate    {len(methods)} x 2 suites x {gate_episodes} episodes")
    print(f"    bracket {pairs} pair(s) x best-of-{best_of} x {bracket_episodes} "
          f"episode(s) = {pairs * best_of} matches")
    print(f"\n  total across {len(keys)} key(s): "
          f"{len(keys) * pairs * best_of} bracket matches"
          f"{f', {len(keys) * es_matches:,} ES matches' if 'es' in methods else ''}")
    print("\n  nothing was run (--dry-run).", flush=True)


# ---- CLI ---------------------------------------------------------------------------


def build_parser(ap: argparse.ArgumentParser) -> argparse.ArgumentParser:
    ap.add_argument("--key", default="", help="one creature (omit with --all)")
    ap.add_argument("--build", default="", help="its arena build id")
    ap.add_argument("--all", action="store_true",
                    help="every creature in game/arena/data/builds.json")
    ap.add_argument("--methods", default=",".join(METHODS),
                    help=f"comma separated, from {','.join(METHODS)} (evolve registers "
                         f"under derived keys — enter its champion via --extra)")
    ap.add_argument("--extra", default="",
                    help="extra entrants, comma separated, in `league versus --a` "
                         "syntax: native | scripted | path.json | <key>[@v3|@candidate]")
    ap.add_argument("--opp-build", default="", help="PPO's opponent (default: the "
                                                    "next creature in the roster)")
    ap.add_argument("--best-of", type=int, default=5, help="bracket rounds per pair")
    ap.add_argument("--bracket-episodes", type=int, default=1,
                    help="episodes per bracket ROUND")
    ap.add_argument("--gate-episodes", type=int, default=4)
    ap.add_argument("--no-gate", action="store_true",
                    help="skip the gate; the bracket winner takes the pin unchecked")
    ap.add_argument("--method-timeout", type=float, default=0.0,
                    help="seconds before a trainer is given up on (0 = no limit)")
    ap.add_argument("--dry-run", action="store_true", help="print the plan and stop")
    ap.add_argument("--out", default="", help="verdict path (single key only)")
    ap.add_argument("--progress-file", default=None)
    # ES knobs
    ap.add_argument("--generations", type=int, default=20)
    ap.add_argument("--pop", type=int, default=8)
    ap.add_argument("--episodes", type=int, default=4)
    ap.add_argument("--jobs", type=int, default=1)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--speed", default=league.DEFAULT_SPEED)
    ap.add_argument("--opponents", default="")
    ap.add_argument("--checkpoint-every", type=int, default=league.CHECKPOINT_EVERY)
    # PPO knobs
    ap.add_argument("--steps", type=int, default=2_000_000)
    ap.add_argument("--envs", type=int, default=512)
    ap.add_argument("--arch", default="mlp", choices=["mlp", "gru"])
    ap.add_argument("--selfplay-every", type=int, default=4)
    return ap


def run(args: argparse.Namespace) -> int:
    methods = [m.strip() for m in args.methods.split(",") if m.strip()]
    extras = [e.strip() for e in args.extra.split(",") if e.strip()]
    unknown = [m for m in methods if m not in METHODS]
    if unknown:
        print(f"tournament: unknown method(s) {','.join(unknown)} — known: "
              f"{','.join(METHODS)}", file=sys.stderr)
        return 2
    if args.all:
        keys = creature_builds()
    elif args.key and args.build:
        keys = [(args.key, args.build)]
    else:
        print("tournament: need --all, or --key KEY --build BUILD", file=sys.stderr)
        return 2

    knobs = {"generations": args.generations, "pop": args.pop,
             "episodes": args.episodes, "jobs": args.jobs, "seed": args.seed,
             "speed": args.speed, "opponents": args.opponents,
             "checkpoint_every": args.checkpoint_every,
             "steps": args.steps, "envs": args.envs, "arch": args.arch,
             "selfplay_every": args.selfplay_every}

    if args.dry_run:
        plan(keys, methods, knobs, args.best_of, args.bracket_episodes,
             0 if args.no_gate else args.gate_episodes, extras)
        return 0

    results = []
    for key, build in keys:
        progress = league.Progress(args.progress_file or league.progress_path(key))
        with progress.guard():
            results.append(tournament(
                key, build, methods, knobs, extras=extras,
                opp_build=args.opp_build, best_of=args.best_of,
                bracket_episodes=args.bracket_episodes,
                gate_episodes=args.gate_episodes, seed=args.seed,
                jobs=args.jobs, speed=args.speed, do_gate=not args.no_gate,
                method_timeout=args.method_timeout or None,
                out_path=Path(args.out) if (args.out and len(keys) == 1) else None,
                progress=progress))
    if len(results) > 1:
        print("\n[tournament] sweep summary")
        for v in results:
            print(f"   {v['key']:<22s} winner={str(v['winner']):<10s} "
                  f"champion={str(v['champion']):<10s} "
                  f"{'pinned v' + str(v['winner_version']) if v['deployed'] else 'no pin moved'}")
    return 0


def main() -> int:
    ap = build_parser(argparse.ArgumentParser(prog="ml.training.tournament"))
    return run(ap.parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
