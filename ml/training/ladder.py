"""The global rank: every net against every other, in the SAME body.

Ricardo, 2026-09-14: "and a global rank for the all vs all, where every model
net compete for the top in a balance fight".

WHY THIS IS NOT `league round-robin`
------------------------------------
`round-robin` fights DEPLOYED policies across DIFFERENT builds. A fen_boar net
plays as a fen_boar and a bog_golem net plays as a bog_golem, so the table it
would produce ranks the CREATURE — its stats, its reach, its cooldowns — with
the policy as a rounding error. That is a balance report, not a net ranking.

A ranking of NETS has to remove the body from the comparison. So:

  1. Both sides play the SAME arena build. The only thing that differs between
     side A and side B is the policy driving it. A net trained for a bog_golem
     driving a fen_boar is not a mistake here — it is the point: the question is
     "which brain plays this body better", asked of one body at a time.
  2. Every pair plays BOTH ORIENTATIONS. Spawn position, first-move order and
     the aim-noise stream are not symmetric between sides; playing i-as-A then
     i-as-B cancels whatever side bias the arena has instead of baking it into
     the table.
  3. Every entrant meets every other entrant in every arena. No seeding, no
     byes, no strength-of-schedule to correct for.

Entrants are every net in the registry that has exported weights (every key,
every version, deployed or candidate) plus the `native` and `scripted`
baselines, which are the floor the table is read against.

SCORING
-------
Per (pair, arena) the two orientations are summed into one result. The pairing
awards 3 points to whoever won more EPISODES, 1 each if they tied.

  points      the league reading — 3/1/0 per pairing
  win_rate    episodes won / episodes decided (draws excluded)
  hp_margin   mean (own hp - opponent hp) at episode end: HOW it won
  rating      Bradley-Terry strength fitted over the whole episode matrix by MM
              iteration, printed on the Elo scale (400 * log10 s). Order
              independent, uses every episode rather than only who won a
              pairing, and stays meaningful if a pair never met.

The table sorts by points, then rating, then hp margin. Verdicts land in
ml/data/benchmarks/ as `arena.ladder.v1` and the training console reads them.

    python3 -m ml.training.ladder --arena core.arena.bog_golem --jobs 16
    python3 -m ml.training.ladder --all-arenas --episodes 2 --jobs 16
    python3 -m ml.training.ladder --keys bog_golem,fen_boar --dry-run
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from itertools import combinations
from pathlib import Path

from . import league
from .tournament import creature_builds

ROOT = league.ROOT
BENCH_DIR = league.BENCH_DIR
BASELINES = ("native", "scripted")


# ---- entrants ---------------------------------------------------------------------


def registry_entrants(keys: list[str] | None, deployed_only: bool) -> list[dict]:
    """Every net with exported weights, newest version first within a key.

    A net with no `game_json` (a GRU or squad net) cannot be driven by the arena
    at all, so it is skipped with a reason rather than crashing the ladder.
    """
    reg = league.load_registry()
    out, skipped = [], []
    for p in reg.get("policies", []):
        key = str(p.get("key", ""))
        if keys and key not in keys:
            continue
        if deployed_only and not p.get("deployed"):
            continue
        game_json = p.get("game_json") or ""
        if not game_json:
            skipped.append(f"{key} v{p.get('version')} (no exported weights)")
            continue
        path = Path(game_json)
        if not path.is_absolute():
            path = ROOT / path
        if not path.exists():
            skipped.append(f"{key} v{p.get('version')} (weights missing: {path})")
            continue
        tag = "deployed" if p.get("deployed") else "candidate"
        out.append({"id": f"{key}@v{p.get('version')}", "key": key,
                    "version": int(p.get("version", 0)),
                    "label": f"{key} v{p.get('version')} ({tag})",
                    "policy": str(path), "deployed": bool(p.get("deployed"))})
    for s in skipped:
        print(f"[ladder] skipped {s}", file=sys.stderr)
    out.sort(key=lambda e: (e["key"], -e["version"]))
    return out


def baseline_entrants() -> list[dict]:
    return [{"id": b, "key": "", "version": 0, "label": b, "policy": b,
             "deployed": False} for b in BASELINES]


# ---- the fight --------------------------------------------------------------------


def play_pair(x: dict, y: dict, arena: str, episodes: int, seed: int,
              speed: str | float) -> dict:
    """One pairing in one arena, BOTH orientations, summed.

    Seeds differ per orientation (a shared seed would make the second run the
    mirror image of the first and the "balance" would be a tautology)."""
    first = league.run_match(arena, arena, x["policy"], y["policy"], episodes,
                             seed, speed=speed)
    second = league.run_match(arena, arena, y["policy"], x["policy"], episodes,
                              seed + 104729, speed=speed)
    eps = list(first.get("episodes", [])) + list(second.get("episodes", []))
    wins_x = int(first.get("wins_a", 0)) + int(second.get("wins_b", 0))
    wins_y = int(first.get("wins_b", 0)) + int(second.get("wins_a", 0))
    draws = int(first.get("draws", 0)) + int(second.get("draws", 0))
    hp_x = [e["hp_a"] for e in first.get("episodes", [])] + \
           [e["hp_b"] for e in second.get("episodes", [])]
    hp_y = [e["hp_b"] for e in first.get("episodes", [])] + \
           [e["hp_a"] for e in second.get("episodes", [])]
    mean = lambda v: round(sum(v) / len(v), 4) if v else 0.0
    return {"a": x["id"], "b": y["id"], "arena": arena,
            "wins_a": wins_x, "wins_b": wins_y, "draws": draws,
            "episodes": len(eps), "hp_a": mean(hp_x), "hp_b": mean(hp_y)}


# ---- Bradley-Terry ----------------------------------------------------------------


def bt_ratings(ids: list[str], wins: dict[tuple[str, str], int],
               prior: float = 1.0, iters: int = 500) -> dict[str, float]:
    """Fit a strength per entrant by MM iteration, return it on the Elo scale.

    `prior` is half a win and half a loss against a phantom opponent of average
    strength, given to every entrant. Without it an entrant that won everything
    (or nothing) has no finite maximum-likelihood strength and the iteration
    runs away; with it the table stays readable when a net sweeps its arena.
    """
    s = {i: 1.0 for i in ids}
    total_w = {i: prior for i in ids}
    for (i, j), w in wins.items():
        total_w[i] = total_w.get(i, prior) + w
    for _ in range(iters):
        nxt = {}
        for i in ids:
            denom = prior / (s[i] + 1.0)          # the phantom, strength 1
            for j in ids:
                if j == i:
                    continue
                n = wins.get((i, j), 0) + wins.get((j, i), 0)
                if n:
                    denom += n / (s[i] + s[j])
            nxt[i] = total_w[i] / denom if denom > 0 else s[i]
        # normalise to geometric mean 1 so the scale cannot drift between runs
        logs = sum(math.log(max(v, 1e-12)) for v in nxt.values()) / max(len(nxt), 1)
        scale = math.exp(-logs)
        moved = max(abs(nxt[i] * scale - s[i]) for i in ids) if ids else 0.0
        s = {i: nxt[i] * scale for i in ids}
        if moved < 1e-9:
            break
    return {i: round(400.0 * math.log10(max(v, 1e-12)), 1) for i, v in s.items()}


# ---- the ladder -------------------------------------------------------------------


def ladder(entrants: list[dict], arenas: list[str], episodes: int, seed: int,
           jobs: int, speed: str | float, out_path: Path | None = None,
           progress: league.Progress | None = None) -> dict:
    if progress is None:
        progress = league.Progress(None)
    ids = [e["id"] for e in entrants]
    started = time.strftime("%Y-%m-%dT%H:%M:%S")
    t0 = time.monotonic()
    jobs_list = [(x, y, arena) for arena in arenas
                 for x, y in combinations(entrants, 2)]
    progress.emit("ladder_start", entrants=len(entrants), arenas=arenas,
                  pairings=len(jobs_list), episodes=episodes)
    print(f"[ladder] {len(entrants)} entrants x {len(arenas)} arena(s) = "
          f"{len(jobs_list)} pairings, {len(jobs_list) * 2} matches of "
          f"{episodes} episode(s)", flush=True)

    done = [0]

    def one(item: tuple[dict, dict, str], index: int) -> dict:
        x, y, arena = item
        row = play_pair(x, y, arena, episodes, seed + index * 7919, speed)
        done[0] += 1
        progress.emit("ladder_pairing", i=done[0], total=len(jobs_list), **row)
        print(f"[ladder] {done[0]:>4}/{len(jobs_list)}  {arena.split('.')[-1]:<16s} "
              f"{x['label']:<26s} {row['wins_a']}-{row['wins_b']} "
              f"{y['label']}", flush=True)
        return row

    if jobs <= 1:
        pairings = [one(it, i) for i, it in enumerate(jobs_list)]
    else:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            pairings = list(ex.map(lambda p: one(p[1], p[0]), enumerate(jobs_list)))

    # ---- aggregate ----------------------------------------------------------
    wins: dict[tuple[str, str], int] = {}
    stat = {e["id"]: {"played": 0, "ep_wins": 0, "ep_losses": 0, "ep_draws": 0,
                      "points": 0, "hp_sum": 0.0, "hp_n": 0} for e in entrants}
    for r in pairings:
        a, b = r["a"], r["b"]
        wins[(a, b)] = wins.get((a, b), 0) + r["wins_a"]
        wins[(b, a)] = wins.get((b, a), 0) + r["wins_b"]
        for me, opp, mine, theirs, hp_me, hp_opp in (
                (a, b, r["wins_a"], r["wins_b"], r["hp_a"], r["hp_b"]),
                (b, a, r["wins_b"], r["wins_a"], r["hp_b"], r["hp_a"])):
            s = stat[me]
            s["played"] += 1
            s["ep_wins"] += mine
            s["ep_losses"] += theirs
            s["ep_draws"] += r["draws"]
            s["points"] += 3 if mine > theirs else (1 if mine == theirs else 0)
            s["hp_sum"] += hp_me - hp_opp
            s["hp_n"] += 1

    ratings = bt_ratings(ids, wins)
    table = []
    for e in entrants:
        s = stat[e["id"]]
        decided = s["ep_wins"] + s["ep_losses"]
        table.append({
            "id": e["id"], "label": e["label"], "key": e["key"],
            "deployed": e["deployed"], "played": s["played"],
            "points": s["points"], "ep_wins": s["ep_wins"],
            "ep_losses": s["ep_losses"], "ep_draws": s["ep_draws"],
            "win_rate": round(s["ep_wins"] / decided, 4) if decided else 0.0,
            "hp_margin": round(s["hp_sum"] / s["hp_n"], 4) if s["hp_n"] else 0.0,
            "rating": ratings.get(e["id"], 0.0)})
    table.sort(key=lambda t: (-t["points"], -t["rating"], -t["hp_margin"]))
    for i, row in enumerate(table):
        row["rank"] = i + 1

    verdict = {
        "schema": "arena.ladder.v1", "started": started,
        "finished": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "wall_s": round(time.monotonic() - t0, 1),
        "arenas": arenas, "episodes_per_orientation": episodes, "seed": seed,
        "jobs": jobs, "speed": str(speed),
        "entrants": [{k: e[k] for k in ("id", "label", "key", "policy", "deployed")}
                     for e in entrants],
        "pairings": pairings, "table": table,
        "champion": table[0]["id"] if table else None,
    }
    if out_path is None:
        BENCH_DIR.mkdir(parents=True, exist_ok=True)
        out_path = BENCH_DIR / f"{time.strftime('%Y-%m-%d_%H%M%S')}__ladder.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(verdict, indent=1))
    verdict["out"] = str(out_path)
    progress.emit("ladder_done", champion=verdict["champion"], out=str(out_path))
    return verdict


def print_table(v: dict, top: int = 0) -> None:
    rows = v["table"][:top] if top else v["table"]
    print(f"\n[ladder] GLOBAL RANK — {len(v['entrants'])} entrants, "
          f"{len(v['arenas'])} arena(s), {v['wall_s']}s")
    head = "  {:>3} {:<28s} {:>4} {:>12s} {:>6s} {:>7s} {:>7s}"
    print(head.format("#", "entrant", "pts", "W-D-L", "win%", "hp±", "rating"))
    for r in rows:
        wdl = "{}-{}-{}".format(r["ep_wins"], r["ep_draws"], r["ep_losses"])
        print("  {:>3} {:<28s} {:>4} {:>12s} {:>5.1f}% {:>+7.3f} {:>7.1f}".format(
            r["rank"], r["label"], r["points"], wdl, r["win_rate"] * 100,
            r["hp_margin"], r["rating"]))
    if top and len(v["table"]) > top:
        print(f"  ... {len(v['table']) - top} more (--top 0 shows all)")


# ---- CLI --------------------------------------------------------------------------


def resolve_arenas(args: argparse.Namespace) -> list[str]:
    known = [b for _, b in creature_builds()]
    if args.all_arenas:
        return known
    wanted = [a.strip() for a in args.arena.split(",") if a.strip()] if args.arena else []
    if not wanted:
        return known[:1]                      # one body, the roster's first
    unknown = [a for a in wanted if a not in known]
    if unknown:
        raise SystemExit(f"ladder: unknown arena build(s) {','.join(unknown)} — "
                         f"known: {','.join(known)}")
    return wanted


def build_parser(ap: argparse.ArgumentParser) -> argparse.ArgumentParser:
    ap.add_argument("--arena", default="",
                    help="the build BOTH sides play (comma-separated for several); "
                         "default: the first creature build")
    ap.add_argument("--all-arenas", action="store_true",
                    help="every creature build — every pairing is replayed in each")
    ap.add_argument("--keys", default="",
                    help="only these creatures' nets enter (comma-separated)")
    ap.add_argument("--deployed-only", action="store_true",
                    help="only the deployed pins, not every candidate")
    ap.add_argument("--no-baselines", action="store_true",
                    help="leave native/scripted out of the table")
    ap.add_argument("--episodes", type=int, default=1,
                    help="episodes per ORIENTATION; a pairing plays 2x this")
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--jobs", type=int, default=1)
    ap.add_argument("--speed", default=league.DEFAULT_SPEED)
    ap.add_argument("--top", type=int, default=0, help="print only the first N rows")
    ap.add_argument("--out", default="", help="verdict path")
    ap.add_argument("--progress-file", default=None)
    ap.add_argument("--dry-run", action="store_true", help="the plan and the budget")
    return ap


def run(args: argparse.Namespace) -> int:
    keys = [k.strip() for k in args.keys.split(",") if k.strip()]
    entrants = registry_entrants(keys or None, args.deployed_only)
    if not args.no_baselines:
        entrants += baseline_entrants()
    if len(entrants) < 2:
        print(f"ladder: {len(entrants)} entrant(s) — a ranking needs at least two "
              f"(train something, or drop --deployed-only/--keys)", file=sys.stderr)
        return 2
    arenas = resolve_arenas(args)
    pairings = len(arenas) * len(entrants) * (len(entrants) - 1) // 2

    if args.dry_run:
        print(f"ladder plan — {len(entrants)} entrants x {len(arenas)} arena(s)")
        for a in arenas:
            print(f"    arena {a}")
        for e in entrants:
            print(f"    {e['id']:<24s} {e['label']}")
        print(f"\n  {pairings} pairings x 2 orientations x {args.episodes} episode(s)"
              f" = {pairings * 2} matches, {pairings * 2 * args.episodes} episodes")
        print(f"  both sides play the SAME build, and every pair plays both sides — "
              f"the only variable is the policy.")
        print("\n  nothing was run (--dry-run).")
        return 0

    progress = league.Progress(args.progress_file)
    with progress.guard():
        verdict = ladder(entrants, arenas, args.episodes, args.seed, args.jobs,
                         args.speed, Path(args.out) if args.out else None,
                         progress=progress)
    print_table(verdict, args.top)
    print(f"\n  {verdict['out']}")
    return 0


def main() -> int:
    return run(build_parser(argparse.ArgumentParser(prog="ml.training.ladder")).parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
