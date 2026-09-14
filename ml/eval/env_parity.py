#!/usr/bin/env python3
"""ENVIRONMENT parity: does the C++ dh-env behave like the Godot arena?

The policy parity gate (game/arena/tests/policy_parity_test.tscn) already proves
the NETWORK matches across runtimes — same weights, same numbers, bit-for-bit.
Nothing has ever checked the ENVIRONMENT those numbers are spent in, and that is
the seam the roadmap's PPO investigation ran into: ml/training/ppo.py trains
entirely in dh-env and is then gated in the arena, while ml/training/league.py
(ES) computes fitness with run_match() and so optimises exactly what the gate
measures. A net can compute identical outputs in two worlds where identical
outputs mean different things.

This is the missing measurement, and it deliberately takes NO position on which
side is right. It runs ONE fixed policy against ONE fixed opponent in BOTH
runtimes with the same seeds and reports the gap:

    dh-env : ml.env.dh_env.DhEnv(build, build, opp=OPP), the net forwarded in
             numpy through ml.training.distill.TeacherNet
    arena  : ml.training.league.run_match(..., policy_b=OPP), a headless Godot

A fixed policy is the point: neither side is learning, so any difference in win
rate, surviving HP or episode length is the ENVIRONMENTS disagreeing, not noise
in a trainer. Baselines (`native`, `scripted`) can be driven directly too, with
--policy scripted, which removes the net from the comparison entirely.

    python3 -m ml.eval.env_parity --key fen_boar --build core.arena.fen_boar
    python3 -m ml.eval.env_parity --build core.arena.fen_boar --policy scripted \
        --opp native --episodes 20

Exit code is 0 when the two runtimes agree inside --tolerance, 1 when they do
not. It is a measurement first and a gate second: run it before believing any
number that crossed the boundary.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from ml.env.dh_env import (ACT_DODGE, DhEnv, balance_specs,   # noqa: E402
                          make_spec, supports_dodge_flag)
from ml.training import league                       # noqa: E402
from ml.training.distill import TeacherNet           # noqa: E402
from ml.training.policy_net import ACTION_LOGITS     # noqa: E402

BASELINES = ("native", "scripted")


def deployed_json(key: str) -> str:
    """The registry's deployed net for a key — the same one the gate would run."""
    reg = json.loads((league.REGISTRY).read_text())
    for p in reg["policies"]:
        if p.get("key") == key and p.get("deployed") and p.get("game_json"):
            return str(p["game_json"])
    raise SystemExit(f"env_parity: no deployed net with a game_json for '{key}'. "
                     f"Pass --policy <path|native|scripted> explicitly.")


def act_from(y: np.ndarray) -> tuple[tuple[float, float], int]:
    """The runtime's decode, verbatim: clip the move, argmax the kit, dodge is
    the last logit. Mirrors policy_net.act — if this drifts, the probe measures
    its own bug instead of the environments'.

    The dodge logit is OR'd in as a flag rather than replacing the pick. It used
    to replace it (`7 if dodge else pick`), which is what the single-int C
    surface allowed at the time, and that is not what the shipping arena does:
    game/arena/neural_policy.gd attempts the pick and dodges only if the pick
    was refused. The difference was the bulk of this probe's own headline gap.
    """
    move = np.clip(y[0:2], -1.0, 1.0)
    pick = int(np.argmax(y[2:2 + ACTION_LOGITS]))
    dodge = bool(y[2 + ACTION_LOGITS] > 0.0)
    return (float(move[0]), float(move[1])), (pick + ACT_DODGE * int(dodge))


def run_dh_env(build: str, policy: str, opp: str, episodes: int,
               seed: int, max_ticks: int) -> dict:
    """N episodes in the C++ env. `policy` is a net JSON; baselines are refused
    here on purpose — dh-env drives side A externally, so a baseline A would be
    a different experiment than the arena's, not the same one."""
    if not supports_dodge_flag():
        raise SystemExit(
            "env_parity: libdh-env.so predates the dodge flag, so the policy's "
            "dodge output would be silently dropped and the measurement would "
            "be of that, not of the environments. Rebuild: "
            "cmake --build sim/build --target dh-env")
    net = TeacherNet(policy)
    emb = net.embedding(build.split(".")[-1])
    env = DhEnv(build, build, opp=opp, seed=seed)
    # The health bar damage is measured against. Mirror matchup, so the two
    # sides are the same size and balance_specs is a no-op, but go through it
    # anyway rather than assume: DhEnv applied it, and the divisor has to be
    # the pool the env actually fought with.
    sa, sb = balance_specs(make_spec(build), make_spec(build))
    bar_a, bar_b = max(float(sa.max_hp), 1.0), max(float(sb.max_hp), 1.0)
    wins = hp_self = hp_foe = ticks = dmg_self = dmg_foe = 0.0
    try:
        for e in range(episodes):
            obs = env.reset(seed + e)
            done = False
            for _ in range(max_ticks):
                y = net.forward(np.concatenate([obs, emb])[None, :])[0]
                move, act = act_from(y)
                done, obs = env.step(move, act)
                if done:
                    break
            wins += 1.0 if env.winner == 0 else 0.0
            hp_self += env.hp_frac(0)
            hp_foe += env.hp_frac(1)
            ticks += env.tick
            # read BEFORE the next reset clears the tally
            dmg_self += env.damage_taken(0) / bar_a
            dmg_foe += env.damage_taken(1) / bar_b
    finally:
        env.close()
    n = max(episodes, 1)
    secs = (ticks / n) / 30.0
    return {"runtime": "dh-env", "episodes": episodes, "win_rate": wins / n,
            "hp_self": hp_self / n, "hp_foe": hp_foe / n,
            # the arena reports wall seconds per episode; the sim is a fixed
            # 30 Hz, so ticks/30 is the same quantity and the columns compare
            "seconds": secs,
            # damage in HEALTH BARS, not hit points: dh-env's stats come from
            # ml/env/specs.json and the arena's from the live content, so raw
            # hit points are two different units. Bars are one unit.
            "dmg_dealt": dmg_foe / n, "dmg_taken": dmg_self / n,
            "dps_dealt": (dmg_foe / n) / max(secs, 1e-6)}


def run_arena(build: str, policy: str, opp: str, episodes: int, seed: int,
              speed: str) -> dict:
    """The same match set through the headless Godot arena — what the gate runs."""
    row = league.run_match(build, build, policy, opp, episodes, seed, speed=speed)
    eps = row.get("episodes", [])
    n = max(len(eps), 1)
    mean = lambda f: float(np.mean([e[f] for e in eps])) if eps else 0.0
    # bars(dmg, bar): the same normalisation dh-env does, per episode, using the
    # health pool that episode actually fought with. max_hp_a/b landed in the
    # row on 2026-09-14; an older recording has neither those nor dmg_taken_*,
    # and reports 0.0 rather than inventing a divisor.
    def bars(dmg_field: str, bar_field: str) -> float:
        if not eps or bar_field not in eps[0] or dmg_field not in eps[0]:
            return 0.0
        return float(np.mean([float(e[dmg_field]) / max(float(e[bar_field]), 1.0)
                              for e in eps]))
    secs = mean("duration_s")
    dmg_dealt = bars("dmg_taken_b", "max_hp_b")
    return {"runtime": "arena", "episodes": len(eps),
            "win_rate": float(row.get("wins_a", 0)) / n,
            "hp_self": mean("hp_a"), "hp_foe": mean("hp_b"),
            "seconds": secs,
            "dmg_dealt": dmg_dealt, "dmg_taken": bars("dmg_taken_a", "max_hp_a"),
            "dps_dealt": dmg_dealt / max(secs, 1e-6), "raw": row}


def compare(a: dict, b: dict, tolerance: float) -> dict:
    gaps = {}
    for field in ("win_rate", "hp_self", "hp_foe", "dmg_dealt", "dmg_taken"):
        gaps[field] = round(abs(a[field] - b[field]), 4)
    worst = max(gaps.values()) if gaps else 0.0
    return {"gaps": gaps, "worst": worst, "agree": worst <= tolerance}


def diagnose(dh: dict, ar: dict, tolerance: float) -> list[str]:
    """Turn "the two runtimes disagree" into "THIS term disagrees".

    hp_frac alone cannot separate the two ways a fight can go differently, and
    they call for opposite fixes: hits that land RARELY (reach, cooldown,
    tracking, hit detection) versus hits that land SOFTLY (damage numbers,
    scaling, mitigation). Damage per second separates them, because it is
    damage per episode with episode length divided out.

    Every line below is stated as a measured ratio. Nothing here decides which
    runtime is correct — that is a content question, not this probe's.
    """
    out: list[str] = []
    ratio = lambda x, y: x / y if y > 1e-6 else float("inf") if x > 1e-6 else 1.0
    for side, dealt, secs in (("DEALT by the policy", "dmg_dealt", "seconds"),
                              ("TAKEN by the policy", "dmg_taken", "seconds")):
        d_tot, a_tot = dh.get(dealt, 0.0), ar.get(dealt, 0.0)
        if abs(d_tot - a_tot) <= tolerance:
            continue
        d_sec, a_sec = dh.get(secs, 0.0), ar.get(secs, 0.0)
        d_rate, a_rate = ratio(d_tot, d_sec), ratio(a_tot, a_sec)
        out.append("{}: {:.3f} bars in dh-env vs {:.3f} in the arena "
                   "({:.2f}x).".format(side, d_tot, a_tot, ratio(a_tot, d_tot)))
        rate_gap = ratio(a_rate, d_rate)
        if 0.8 <= rate_gap <= 1.25:
            out.append("  ...but PER SECOND they agree ({:.3f} vs {:.3f} "
                       "bars/s). The episodes are different LENGTHS; the "
                       "combat itself is not the disagreement.".format(
                           d_rate, a_rate))
        else:
            out.append("  ...and PER SECOND too: {:.3f} vs {:.3f} bars/s "
                       "({:.2f}x). This is the combat, not the clock — look at "
                       "reach, cooldown and damage for this build in both "
                       "runtimes.".format(d_rate, a_rate, rate_gap))
    if not out:
        return out
    out.append("Neither runtime is assumed correct here. The arena is what the "
               "game ships,")
    out.append("so it is the reference for CONTENT; dh-env is what PPO trains "
               "in, so it is")
    out.append("the one that has to be made to match, unless the arena is the "
               "one that is wrong.")
    return out


def print_report(dh: dict, ar: dict, verdict: dict, tolerance: float) -> None:
    print()
    print("  ENVIRONMENT PARITY — one fixed policy, two runtimes")
    print("  " + "-" * 78)
    head = "  {:<8}{:>10}{:>9}{:>9}{:>9}{:>10}{:>10}{:>9}".format(
        "runtime", "win_rate", "hp_self", "hp_foe", "seconds",
        "dmg_dealt", "dmg_taken", "dps")
    print(head)
    for row in (dh, ar):
        print("  {:<8}{:>10.3f}{:>9.3f}{:>9.3f}{:>9.1f}{:>10.3f}{:>10.3f}{:>9.3f}".format(
            row["runtime"], row["win_rate"], row["hp_self"], row["hp_foe"],
            row["seconds"], row["dmg_dealt"], row["dmg_taken"], row["dps_dealt"]))
    print("  (dmg columns are HEALTH BARS dealt/taken per episode, dps is bars/s)")
    print("  " + "-" * 66)
    for field, gap in verdict["gaps"].items():
        flag = "ok" if gap <= tolerance else "DIVERGES"
        print("  {:<10} gap {:.4f}   {}".format(field, gap, flag))
    diag = diagnose(dh, ar, tolerance)
    if diag:
        print()
        for line in diag:
            print("  " + line)
    if verdict["agree"]:
        print("\n  PARITY OK — the two runtimes agree inside {:.3f}.".format(tolerance))
    else:
        print("\n  PARITY FAILED — worst gap {:.4f} > {:.3f}. A net trained in one "
              "of these\n  and graded in the other is being scored on dynamics it "
              "never saw.".format(verdict["worst"], tolerance))


def build_parser(ap: argparse.ArgumentParser) -> argparse.ArgumentParser:
    ap.add_argument("--build", required=True, help="arena build id for BOTH sides")
    ap.add_argument("--key", default="", help="take the deployed net for this key")
    ap.add_argument("--policy", default="", help="net JSON path (overrides --key)")
    ap.add_argument("--opp", default="scripted", choices=list(BASELINES))
    ap.add_argument("--episodes", type=int, default=12)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--max-ticks", type=int, default=4096)
    ap.add_argument("--tolerance", type=float, default=0.15)
    ap.add_argument("--speed", default=league.DEFAULT_SPEED)
    ap.add_argument("--out", default="", help="write the verdict JSON here")
    return ap


def run(args) -> int:
    policy = args.policy or (deployed_json(args.key) if args.key else "")
    if not policy:
        raise SystemExit("env_parity: pass --key or --policy")
    if policy in BASELINES:
        raise SystemExit("env_parity: dh-env drives side A externally, so a "
                         "baseline on side A would not be the same experiment "
                         "in both runtimes. Pass a net JSON.")
    dh = run_dh_env(args.build, policy, args.opp, args.episodes,
                    args.seed, args.max_ticks)
    ar = run_arena(args.build, policy, args.opp, args.episodes,
                   args.seed, args.speed)
    verdict = compare(dh, ar, args.tolerance)
    verdict["diagnosis"] = diagnose(dh, ar, args.tolerance)
    out = {"schema": "arena.env_parity.v1", "build": args.build,
           "policy": policy, "opponent": args.opp, "episodes": args.episodes,
           "seed": args.seed, "tolerance": args.tolerance,
           "dh_env": dh, "arena": ar, **verdict}
    print_report(dh, ar, verdict, args.tolerance)
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps(out, indent=1) + "\n")
        print("  verdict: {}".format(args.out))
    return 0 if verdict["agree"] else 1


def main() -> int:
    return run(build_parser(argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)).parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
