"""The eval gate (docs/tech/25 §8): NO policy deploys without passing.

Checks (all proposals, tuned as the league matures):
  1. Scripted suite — the candidate must hold a win band vs the scripted
     baseline and the native AI (strong enough to ship, not degenerate).
  2. Past-policy ladder — vs the currently deployed version of the same key:
     win rate inside [BAND_LO, BAND_HI] (improvement without tier-jumps).
  3. Sanity/degeneracy — every episode must deal damage both ways on average;
     zero-damage episodes mean a stall or broken policy.
  4. CONTROLS (tech/25 §5.2.2) — the candidate vs a statue (attacks, never
     moves) and vs a five-line heuristic (walks at the foe, spends kits off
     cooldown). The statue is a hard FLOOR: a net that cannot beat a body
     standing still is broken whatever its other win rates say. The heuristic
     is REPORTED, not required — a yardstick, so a collapse can never again be
     invisible.

A failed gate keeps the fleet on the previous pinned version — deliberately
boring (tech/25 §8).

BANDS (the constants below are the contract; docs/tech/37 carries the why):
    SCRIPTED_BAND   (0.30, 1.00)  vs the scripted baseline AND the native AI
    LADDER_BAND     (0.25, 0.90)  vs the currently deployed net of the same key
    MIN_DAMAGE_FRAC 0.05          mean loser hp deficit per episode
    STATUE_FLOOR    0.75          vs the statue control — ENFORCED
WHAT A VERDICT WRITES: the candidate's registry entry gains
`eval.checks = {<check>: {"win_rate": .., "pass": bool}}`, and on a pass its
`deployed` flag is set while the previous pin for that key is cleared — one
deployed entry per key is the invariant tools/train_run.sh --promote and the
training console's DEPLOY/RETIRE both preserve.
WHO READS IT: game/arena/neural_policy.gd loads the deployed pin; the console's
NETS tab shows the checks; `league versus` resolves "<key>@deployed".
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "ml" / "training"))

from league import fitness, run_match  # noqa: E402

SCRIPTED_BAND = (0.30, 1.00)     # vs scripted/native suite (proposal)
LADDER_BAND = (0.25, 0.90)       # vs the currently deployed self (proposal)
MIN_DAMAGE_FRAC = 0.05           # mean loser hp deficit per episode (sanity)
# The floor, and it is set where it is because beating a body that never moves
# should not be close. Measured 2026-09-14: the deployed fen_boar v6.0 took
# LESS health off its opponent than the statue did, in both matchups, and the
# gate of the day had no way to notice. Ricardo, on being shown that: "Add the
# statue/heuristic controls to the gate."
STATUE_FLOOR = 0.75              # vs the statue control — ENFORCED
CONTROLS = ("statue", "heuristic")


def run_gate(reg: dict, cand: dict, build: str, episodes: int = 4,
             seed: int = 99) -> bool:
    report: dict = {"build": build, "episodes": episodes, "checks": {}}
    ok_all = True

    # 1. scripted + native suite
    for suite_policy in ("scripted", "native"):
        result = run_match(build, build, cand["game_json"], suite_policy,
                           episodes, seed, record=True)
        fit = fitness(result, "a")
        wins = result["wins_a"] / max(len(result["episodes"]), 1)
        ok = SCRIPTED_BAND[0] <= wins <= SCRIPTED_BAND[1]
        ok_all &= ok
        report["checks"][f"suite_{suite_policy}"] = {
            "win_rate": round(wins, 3), "fitness": round(fit, 3), "pass": ok}
        # 3. degeneracy: damage must flow
        mean_loser_hp = sum(min(e["hp_a"], e["hp_b"]) for e in result["episodes"]) \
            / max(len(result["episodes"]), 1)
        sane = (1.0 - mean_loser_hp) >= MIN_DAMAGE_FRAC
        ok_all &= sane
        report["checks"][f"suite_{suite_policy}_sanity"] = {
            "mean_loser_hp": round(mean_loser_hp, 3), "pass": sane}

    # 4. controls: the floor and the yardstick (tech/25 §5.2.2)
    for control in CONTROLS:
        result = run_match(build, build, cand["game_json"], control,
                           episodes, seed + 7, record=True)
        wins = result["wins_a"] / max(len(result["episodes"]), 1)
        fit = fitness(result, "a")
        entry = {"win_rate": round(wins, 3), "fitness": round(fit, 3)}
        if control == "statue":
            # ENFORCED. Anything below this is not a weak policy, it is a broken
            # one, and the previous pin is better than shipping it.
            entry["floor"] = STATUE_FLOOR
            entry["pass"] = wins >= STATUE_FLOOR
            ok_all &= entry["pass"]
        else:
            # REPORTED. A net that cannot yet beat five rules is not necessarily
            # unshippable — but it must never again be invisible.
            entry["reported_only"] = True
        report["checks"][f"control_{control}"] = entry

    # 2. ladder vs deployed self
    dep = None
    for p in reversed(reg["policies"]):
        if p["key"] == cand["key"] and p.get("deployed"):
            dep = p
            break
    if dep is not None:
        result = run_match(build, build, cand["game_json"], dep["game_json"],
                           episodes, seed + 1, record=True)
        wins = result["wins_a"] / max(len(result["episodes"]), 1)
        ok = LADDER_BAND[0] <= wins <= LADDER_BAND[1]
        ok_all &= ok
        report["checks"]["ladder_vs_deployed"] = {
            "opponent": f"v{dep['version']}", "win_rate": round(wins, 3), "pass": ok}

    cand["eval"] = report
    cand["deployed"] = bool(ok_all)
    verdict = "PASS — deployed" if ok_all else "FAIL — fleet stays on previous pin"
    print(f"[gate] {cand['key']} v{cand['version']}: {verdict}")
    for name, c in report["checks"].items():
        print(f"   {name}: {c}")
    return ok_all
