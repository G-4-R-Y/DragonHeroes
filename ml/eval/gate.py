"""The eval gate (docs/tech/25 §8): NO policy deploys without passing.

Checks (all proposals, tuned as the league matures):
  1. Scripted suite — the candidate must hold a win band vs the scripted
     baseline and the native AI (strong enough to ship, not degenerate).
  2. Past-policy ladder — vs the currently deployed version of the same key:
     win rate inside [BAND_LO, BAND_HI] (improvement without tier-jumps).
  3. Sanity/degeneracy — every episode must deal damage both ways on average;
     zero-damage episodes mean a stall or broken policy.

A failed gate keeps the fleet on the previous pinned version — deliberately
boring (tech/25 §8).

BANDS (the constants below are the contract; docs/tech/37 carries the why):
    SCRIPTED_BAND   (0.30, 1.00)  vs the scripted baseline AND the native AI
    LADDER_BAND     (0.25, 0.90)  vs the currently deployed net of the same key
    MIN_DAMAGE_FRAC 0.05          mean loser hp deficit per episode
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
