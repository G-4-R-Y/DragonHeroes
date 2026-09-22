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
                          make_spec, supports_dodge_flag, tick_hz, mask_args)
from ml.training import league                       # noqa: E402
from ml.training.distill import TeacherNet           # noqa: E402
from ml.training.policy_net import ACTION_LOGITS, decode  # noqa: E402

BASELINES = ("native", "scripted")
# game/arena/scripted_policy.gd retreats below this fraction, and R55-c splits
# every episode there: EXCHANGE = spawn -> the first crossing by either side,
# CHASE = that moment -> the episode end. The residual R55 gap is a CLOCK gap
# (totals and per-channel damage agree, seconds do not), and a mean duration
# cannot say which half of the fight spends the extra time.
LOW_HP = 0.25


def deployed_json(key: str) -> str:
    """The registry's deployed net for a key — the same one the gate would run."""
    reg = json.loads((league.REGISTRY).read_text())
    for p in reg["policies"]:
        if p.get("key") == key and p.get("deployed") and p.get("game_json"):
            return str(p["game_json"])
    raise SystemExit(f"env_parity: no deployed net with a game_json for '{key}'. "
                     f"Pass --policy <path|native|scripted> explicitly.")


def act_from(y: np.ndarray, obs: np.ndarray, kit_count: int,
             is_player: bool) -> tuple[tuple[float, float], int]:
    """The runtime's decode, verbatim: clip the move, MASKED argmax the kit
    (arena.mask.v1), dodge is the last logit gated on a visible charge. It IS
    policy_net.decode — if this drifts, the probe measures its own bug instead
    of the environments'.

    The dodge logit is OR'd in as a flag rather than replacing the pick. It used
    to replace it (`7 if dodge else pick`), which is what the single-int C
    surface allowed at the time, and that is not what the shipping arena does:
    game/arena/neural_policy.gd attempts the pick and dodges only if the pick
    was refused. The difference was the bulk of this probe's own headline gap.
    """
    move, pick, dodge = decode(np.asarray(y), np.asarray(obs), kit_count, is_player)
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
    kit_count, is_player = mask_args(build)
    wins = hp_self = hp_foe = ticks = dmg_self = dmg_foe = 0.0
    exch_ticks = chase_ticks = low_hit = 0.0   # the R55-c phase split
    src_self = {k: 0.0 for k in DhEnv.SOURCES}   # by-source, in bars (R55)
    src_foe = {k: 0.0 for k in DhEnv.SOURCES}
    try:
        for e in range(episodes):
            obs = env.reset(seed + e)
            done = False
            low_tick = -1
            for _ in range(max_ticks):
                y = net.forward(np.concatenate([obs, emb])[None, :])[0]
                move, act = act_from(y, obs, kit_count, is_player)
                done, obs = env.step(move, act)
                # sampled every tick, not at the end: the threshold is crossed
                # once and the episode may end on the same tick
                if low_tick < 0 and min(env.hp_frac(0), env.hp_frac(1)) < LOW_HP:
                    low_tick = env.tick
                if done:
                    break
            wins += 1.0 if env.winner == 0 else 0.0
            hp_self += env.hp_frac(0)
            hp_foe += env.hp_frac(1)
            ticks += env.tick
            # never crossed -> the whole episode was the exchange and the
            # chase is empty, which is itself the answer for that episode
            exch_ticks += low_tick if low_tick >= 0 else env.tick
            chase_ticks += (env.tick - low_tick) if low_tick >= 0 else 0.0
            low_hit += 1.0 if low_tick >= 0 else 0.0
            # read BEFORE the next reset clears the tally
            dmg_self += env.damage_taken(0) / bar_a
            dmg_foe += env.damage_taken(1) / bar_b
            for k, v in env.damage_by_source(0).items():
                src_self[k] += v / bar_a
            for k, v in env.damage_by_source(1).items():
                src_foe[k] += v / bar_b
    finally:
        env.close()
    n = max(episodes, 1)
    # ticks -> seconds using the SIM's own rate, not a copy of it. This line
    # held a hardcoded 30 against the sim's 60 (dh::sim::kArenaDt = 1/60) and so
    # reported every dh-env episode at TWICE its real length, which made a 2x
    # duration divergence read as a perfect match.
    secs = (ticks / n) / tick_hz()
    return {"runtime": "dh-env", "episodes": episodes, "win_rate": wins / n,
            "hp_self": hp_self / n, "hp_foe": hp_foe / n,
            # the arena reports duration_s per episode; this is the same
            # quantity, so the columns compare directly
            "seconds": secs,
            # R55-c, diagnostic (not gate terms): where the seconds go.
            "exchange_s": (exch_ticks / n) / tick_hz(),
            "chase_s": (chase_ticks / n) / tick_hz(),
            "low_rate": low_hit / n,
            # damage in HEALTH BARS, not hit points: dh-env's stats come from
            # ml/env/specs.json and the arena's from the live content, so raw
            # hit points are two different units. Bars are one unit.
            "dmg_dealt": dmg_foe / n, "dmg_taken": dmg_self / n,
            "dps_dealt": (dmg_foe / n) / max(secs, 1e-6),
            "dps_taken": (dmg_self / n) / max(secs, 1e-6),
            # WHERE the bars came from (contact / bolt / field), per episode
            "src_dealt": {k: v / n for k, v in src_foe.items()},
            "src_taken": {k: v / n for k, v in src_self.items()}}


def run_arena(build: str, policy: str, opp: str, episodes: int, seed: int,
              speed: str, time_limit: float) -> dict:
    """The same match set through the headless Godot arena — what the gate runs."""
    # R55-b (2026-09-21): the time limit is PASSED, not defaulted. It used to be
    # left to league.run_match's 45.0 s while dh-env ran to --max-ticks 4096 =
    # 68.3 s, so the two runtimes were measuring episodes with a third more
    # clock on one side. Every rate here is per SECOND, so a build whose fights
    # reach the cap (fen_boar_alpha vs scripted: 38.9 s in the arena) had its
    # dh-env mean stretched by episodes the arena had already truncated, and
    # the seconds/dps ratios reported an environment divergence that was the
    # harness's own asymmetry. Same wall clock both sides, always.
    row = league.run_match(build, build, policy, opp, episodes, seed,
                           time_limit=time_limit, speed=speed)
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
    # R55-c: arena.gd logs low_t_s, the clock at the first crossing of LOW_HP,
    # or -1.0 when neither side ever crossed. An arena build predating the
    # column has no key at all, and reports no phase rather than a wrong one.
    has_phase = bool(eps) and "low_t_s" in eps[0]
    lows = [(float(e["low_t_s"]), float(e["duration_s"])) for e in eps] \
        if has_phase else []
    exch = float(np.mean([d if lo < 0.0 else lo for lo, d in lows])) if lows else 0.0
    chase = float(np.mean([0.0 if lo < 0.0 else d - lo for lo, d in lows])) if lows else 0.0
    low_rate = float(np.mean([1.0 if lo >= 0.0 else 0.0 for lo, _ in lows])) if lows else 0.0
    dmg_dealt = bars("dmg_taken_b", "max_hp_b")
    dmg_taken = bars("dmg_taken_a", "max_hp_a")
    return {"runtime": "arena", "episodes": len(eps),
            "win_rate": float(row.get("wins_a", 0)) / n,
            "hp_self": mean("hp_a"), "hp_foe": mean("hp_b"),
            "seconds": secs,
            "dmg_dealt": dmg_dealt, "dmg_taken": dmg_taken,
            "dps_dealt": dmg_dealt / max(secs, 1e-6),
            "dps_taken": dmg_taken / max(secs, 1e-6),
            # by source; an arena predating the columns reports 0.0 for each
            **({"exchange_s": exch, "chase_s": chase, "low_rate": low_rate}
               if has_phase else {}),
            "src_dealt": {k: bars(f"dmg_{k}_b", "max_hp_b") for k in DhEnv.SOURCES},
            "src_taken": {k: bars(f"dmg_{k}_a", "max_hp_a") for k in DhEnv.SOURCES},
            "raw": row}


# Terms compared as an absolute difference (all are fractions in [0, 1]) and
# terms compared as a RATIO (seconds and per-second rates, where "twice as fast"
# is the meaningful statement and a raw subtraction is not).
ABS_TERMS = ("win_rate", "hp_self", "hp_foe", "dmg_dealt", "dmg_taken")
RATIO_TERMS = ("seconds", "dps_dealt", "dps_taken")
# A rate is called divergent outside [1/RATE_TOL, RATE_TOL]. 1.25 is a quarter
# either way — loose enough for 12-episode noise, tight enough that the 2.24x
# incoming-damage gap this found does not hide inside it.
RATE_TOL = 1.25
# Reported, never gated (R55-c). A chase phase can be a fraction of a second
# long, where a ratio is noise wearing a decimal point; these columns exist to
# ATTRIBUTE a divergence the gate terms already caught, not to catch one.
PHASE_TERMS = ("exchange_s", "chase_s")


def ratio_of(a: float, b: float) -> float:
    """b/a, oriented so it always reads >= 1 ("N times"), sign-free."""
    if a <= 1e-9 or b <= 1e-9:
        return 1.0 if abs(a - b) <= 1e-9 else float("inf")
    return max(a, b) / min(a, b)


def compare(a: dict, b: dict, tolerance: float) -> dict:
    """Absolute gaps on the fraction terms, ratios on time and the rates.

    Rates are compared SEPARATELY from totals on purpose: a total and a rate can
    disagree in opposite directions when the episodes are different lengths, and
    the rate is the one that describes the combat. Exactly that happened here —
    dmg_taken totals agreed (1.074 vs 0.943, inside tolerance) while the rate
    was off 2.24x, because the dh-env episode ended in half the time.
    """
    gaps = {f: round(abs(a[f] - b[f]), 4) for f in ABS_TERMS}
    ratios = {f: round(ratio_of(a.get(f, 0.0), b.get(f, 0.0)), 3)
              for f in RATIO_TERMS}
    worst = max(gaps.values()) if gaps else 0.0
    worst_ratio = max(ratios.values()) if ratios else 1.0
    # diagnostic only: absent from worst_ratio and from `agree` on purpose
    phases = {f: round(ratio_of(a[f], b[f]), 3)
              for f in PHASE_TERMS if f in a and f in b}
    return {"gaps": gaps, "ratios": ratios, "worst": worst,
            "worst_ratio": worst_ratio, "phase_ratios": phases,
            "agree": worst <= tolerance and worst_ratio <= RATE_TOL}


def diagnose(dh: dict, ar: dict, tolerance: float) -> list[str]:
    """Turn "the two runtimes disagree" into "THIS term disagrees".

    The two ways a fight can go differently call for opposite fixes: hits that
    land RARELY (reach, cooldown, tracking, hit detection) versus hits that land
    SOFTLY (damage numbers, scaling, mitigation). Damage per second separates
    them from a damage total, because it divides episode length out.

    Nothing here decides which runtime is correct — that is a content question.
    """
    out: list[str] = []
    for label, total, rate in (("DEALT by the policy", "dmg_dealt", "dps_dealt"),
                               ("TAKEN by the policy", "dmg_taken", "dps_taken")):
        d_tot, a_tot = dh.get(total, 0.0), ar.get(total, 0.0)
        d_rate, a_rate = dh.get(rate, 0.0), ar.get(rate, 0.0)
        tot_off = abs(d_tot - a_tot) > tolerance
        rate_off = ratio_of(d_rate, a_rate) > RATE_TOL
        if not tot_off and not rate_off:
            continue
        out.append("{}: {:.3f} bars in dh-env vs {:.3f} in the arena; "
                   "{:.3f} vs {:.3f} bars/s.".format(label, d_tot, a_tot,
                                                     d_rate, a_rate))
        if tot_off and not rate_off:
            out.append("  The totals differ but the RATES agree — the episodes "
                       "are different lengths,")
            out.append("  and the combat itself is not the disagreement. Look "
                       "at what ends the episode.")
        elif rate_off and not tot_off:
            out.append("  The totals agree but the RATES differ {:.2f}x — the "
                       "episodes are different".format(ratio_of(d_rate, a_rate)))
            out.append("  lengths and that is hiding it. This IS the combat.")
        else:
            out.append("  Totals and rates both differ ({:.2f}x per second) — "
                       "look at reach, cooldown".format(ratio_of(d_rate, a_rate)))
            out.append("  and damage for this build in both runtimes.")
    sec_ratio = ratio_of(dh.get("seconds", 0.0), ar.get("seconds", 0.0))
    if sec_ratio > RATE_TOL:
        out.append("EPISODE LENGTH: {:.1f}s in dh-env vs {:.1f}s in the arena "
                   "({:.2f}x).".format(dh.get("seconds", 0.0),
                                       ar.get("seconds", 0.0), sec_ratio))
        out.extend(attribute_phase(dh, ar))
    if not out:
        return out
    out.append("Neither runtime is assumed correct here. The arena is what the "
               "game ships, so it")
    out.append("is the reference for CONTENT; dh-env is what PPO trains in, so "
               "it is the one to")
    out.append("move, unless the arena is the one that is wrong.")
    return out


def attribute_phase(dh: dict, ar: dict) -> list[str]:
    """Say WHICH half of the fight the extra seconds are in.

    An episode ends when someone dies, so a mean duration answers "the fights
    are longer" and nothing else. Split at the scripted retreat threshold and
    the same number answers a usable question: the two runtimes trade blows at
    the same rate (R55-b: per-channel damage inside ~10%), so a gap that sits
    entirely in the CHASE is a pursuit/termination problem, not a combat one --
    below LOW_HP the loser runs, both bodies move at the same speed, and the
    fight only ends when something breaks the symmetry.
    """
    if not all(f in dh and f in ar for f in PHASE_TERMS):
        return ["  (no phase split: this arena build predates low_t_s)"]
    gap = dh["seconds"] - ar["seconds"]
    d_ex, d_ch = dh["exchange_s"], dh["chase_s"]
    a_ex, a_ch = ar["exchange_s"], ar["chase_s"]
    out = ["  exchange (spawn -> first side below {:.0%} hp): {:.1f}s dh-env "
           "vs {:.1f}s arena".format(LOW_HP, d_ex, a_ex),
           "  chase    (that moment -> episode end)         : {:.1f}s dh-env "
           "vs {:.1f}s arena".format(d_ch, a_ch)]
    if dh.get("low_rate", 1.0) < 0.999 or ar.get("low_rate", 1.0) < 0.999:
        out.append("  reached the threshold in {:.0%} of dh-env episodes and "
                   "{:.0%} of arena ones;".format(dh.get("low_rate", 0.0),
                                                 ar.get("low_rate", 0.0)))
        out.append("  an episode that never reached it counts entirely as "
                   "exchange.")
    if abs(gap) < 1e-6:
        return out
    share = (d_ch - a_ch) / gap
    if share >= 0.6:
        out.append("  -> {:.0%} of the {:+.1f}s is the CHASE. The exchange "
                   "agrees; what differs is how".format(share, gap))
        out.append("     long the loser survives once it starts running.")
    elif share <= 0.4:
        out.append("  -> {:.0%} of the {:+.1f}s is the EXCHANGE. The fight "
                   "itself is slower, so look".format(1.0 - share, gap))
        out.append("     at reach, cooldown and tracking before the endgame.")
    else:
        out.append("  -> the {:+.1f}s is split across both phases ({:.0%} "
                   "chase), so it is not an".format(gap, share))
        out.append("     endgame effect alone.")
    return out


def print_report(dh: dict, ar: dict, verdict: dict, tolerance: float) -> None:
    """One row per TERM, not per runtime: the question is always "does this
    term agree", and a term-major table puts the two numbers side by side."""
    print()
    print("  ENVIRONMENT PARITY — one fixed policy, two runtimes")
    print("  episodes: {} dh-env / {} arena".format(dh["episodes"], ar["episodes"]))
    print("  " + "-" * 62)
    print("  {:<12}{:>10}{:>10}{:>12}  {}".format(
        "term", "dh-env", "arena", "gap", "verdict"))
    print("  " + "-" * 62)
    rows = [(f, "{:.3f}".format(dh[f]), "{:.3f}".format(ar[f]),
             "{:.4f}".format(verdict["gaps"][f]),
             verdict["gaps"][f] <= tolerance) for f in ABS_TERMS]
    rows += [(f, "{:.3f}".format(dh.get(f, 0.0)), "{:.3f}".format(ar.get(f, 0.0)),
              "{:.2f}x".format(verdict["ratios"][f]),
              verdict["ratios"][f] <= RATE_TOL) for f in RATIO_TERMS]
    for name, a, b, gap, ok in rows:
        print("  {:<12}{:>10}{:>10}{:>12}  {}".format(
            name, a, b, gap, "ok" if ok else "DIVERGES"))
    print("  " + "-" * 62)
    if verdict.get("phase_ratios"):
        # diagnostic rows: printed with their ratio, never with a verdict,
        # because they are not part of `agree`
        for f in PHASE_TERMS:
            print("  {:<12}{:>10.3f}{:>10.3f}{:>12}  {}".format(
                f, dh[f], ar[f], "{:.2f}x".format(verdict["phase_ratios"][f]),
                "diag"))
        print("  " + "-" * 62)
    if "src_dealt" in dh and "src_dealt" in ar:
        # WHERE the bars came from — the column that says which mechanic the two
        # runtimes disagree on, not only that they disagree (R55).
        print("  {:<12}{:>10}{:>10}  {:<3}{:>10}{:>10}".format(
            "by source", "dealt dh", "dealt ar", "", "taken dh", "taken ar"))
        for k in DhEnv.SOURCES:
            print("  {:<12}{:>10.3f}{:>10.3f}  {:<3}{:>10.3f}{:>10.3f}".format(
                k, dh["src_dealt"].get(k, 0.0), ar["src_dealt"].get(k, 0.0), "",
                dh["src_taken"].get(k, 0.0), ar["src_taken"].get(k, 0.0)))
        print("  " + "-" * 62)
    print("  dmg/dps are HEALTH BARS (dealt to the foe / taken by the policy);")
    print("  seconds and the rates are compared as RATIOS, tolerance {:.2f}x."
          .format(RATE_TOL))
    diag = diagnose(dh, ar, tolerance)
    if diag:
        print()
        for line in diag:
            print("  " + line)
    if verdict["agree"]:
        print("\n  PARITY OK — the two runtimes agree inside {:.3f} "
              "and {:.2f}x.".format(tolerance, RATE_TOL))
    else:
        print("\n  PARITY FAILED — worst gap {:.4f} (tol {:.3f}), worst ratio "
              "{:.2f}x (tol {:.2f}x).\n  A net trained in one of these and "
              "graded in the other is being scored on\n  dynamics it never "
              "saw.".format(verdict["worst"], tolerance,
                            verdict["worst_ratio"], RATE_TOL))


def build_parser(ap: argparse.ArgumentParser) -> argparse.ArgumentParser:
    ap.add_argument("--build", required=True, help="arena build id for BOTH sides")
    ap.add_argument("--key", default="", help="take the deployed net for this key")
    ap.add_argument("--policy", default="", help="net JSON path (overrides --key)")
    ap.add_argument("--opp", default="scripted", choices=list(BASELINES))
    ap.add_argument("--episodes", type=int, default=12)
    ap.add_argument("--seed", type=int, default=2026)
    # One clock for both runtimes (R55-b). --max-ticks overrides the derived
    # dh-env budget for a deliberately asymmetric probe; leave it at 0 and the
    # two runtimes get the same wall time.
    # ap.add_argument("--max-ticks", type=int, default=4096)   # was 68.3 s vs the arena's 45
    ap.add_argument("--time-limit", type=float, default=45.0,
                    help="episode wall clock, BOTH runtimes (seconds)")
    ap.add_argument("--max-ticks", type=int, default=0,
                    help="override the dh-env tick budget (0 = time-limit * 60)")
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
    # ABSOLUTE, always. Godot resolves a bare relative path against res://, so a
    # net passed as `ml/runs/.../x.json` loads in dh-env (cwd) and NOT in the
    # arena, where the fighter then runs the whole match at zero output. That
    # reads as a total environment divergence -- side A dealing 0.000 bars in
    # every channel -- and it is a path, not an environment. Fail here instead.
    pol = Path(policy).expanduser()
    if not pol.is_file():
        raise SystemExit(f"env_parity: no policy file at {pol}")
    policy = str(pol.resolve())
    max_ticks = args.max_ticks or int(round(args.time_limit * 60.0))
    dh = run_dh_env(args.build, policy, args.opp, args.episodes,
                    args.seed, max_ticks)
    ar = run_arena(args.build, policy, args.opp, args.episodes,
                   args.seed, args.speed, args.time_limit)
    verdict = compare(dh, ar, args.tolerance)
    verdict["diagnosis"] = diagnose(dh, ar, args.tolerance)
    out = {"schema": "arena.env_parity.v1", "build": args.build,
           "policy": policy, "opponent": args.opp, "episodes": args.episodes,
           "seed": args.seed, "tolerance": args.tolerance,
           "time_limit": args.time_limit, "max_ticks": max_ticks,
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
