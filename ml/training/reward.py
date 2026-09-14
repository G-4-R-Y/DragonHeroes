#!/usr/bin/env python3
"""The scoring model: one weighted, scale-normalized definition of "good fight".

Ricardo, 2026-09-14: "perhaps we should better model our reward model. What is
currently considered? we can get each one of the columns values, weight out
which is the most importante performance metric, and attribute weights to each
variable, sclaing values to what is most impactful. Numbers magnitudes must be
scaled tho, as to not compare 40 seconds with 0.087 dmg_dealt. If winner, the
shorter the better. If loser, the longest the better. 'dmg_taken' is always
'lower is better', 'dmg_dealt' is always 'higher the better', hp_foe lower the
better, hp_self higher the better, win_rate the higher the better."

WHAT WAS SCORED BEFORE THIS FILE, and why it needed replacing:

  league.fitness()          wins + 0.1 * (hp_self - hp_foe)
      Two terms. Duration not scored. Damage not scored. hp fraction was the
      only damage proxy, and it clamps at zero, so overkill is invisible and a
      kill is indistinguishable from a long grind that ended at the same hp.

  ppo.py per-tick           1.0 * (foe_hp_lost - self_hp_lost) - 0.002
                            + 0.02 per kit, + 0.05 per chained kit
                            + 1.0 win / -1.0 loss at the end
      Three defects, one of them Ricardo's own catch:
      (1) TIME WAS SIGNED WRONG FOR A LOSER. `- R_TIME` applied every tick
          regardless of outcome, so a losing agent was paid to die sooner.
      (2) IT WAS ALSO MIS-SCALED BY 7x. 0.002 x 3600 ticks = 7.2 over a full
          episode, against a win bonus of 1.0. The clock outweighed the result.
      (3) DEALING AND AVOIDING DAMAGE SCORED IDENTICALLY — one symmetric hp
          delta — which is the avoidance local optimum written down in code.

DESIGN, in Ricardo's terms:

  1. NORMALIZE FIRST. Every term becomes a "goodness" in [0, 1] before any
     weight touches it, so seconds and health bars stop being compared as raw
     magnitudes. Each term carries its own reference scale (a full health bar,
     the episode cap) rather than a shared guess.
  2. DIRECTIONS ARE DECLARED, not implied by a sign buried in an expression —
     see TERMS below. Anything "lower is better" is normalized as 1 - x.
  3. DURATION IS CONDITIONAL ON THE OUTCOME: shorter is better when you win,
     longer is better when you lose. A draw is neutral, deliberately: giving a
     draw the loser's rule would pay an agent to stall to the time limit, which
     is the degenerate policy the gate's sanity check already rejects.
  4. THE OUTCOME OUTWEIGHS EVERYTHING ELSE COMBINED. `assert_sane_weights`
     enforces w_win > sum(all others), so no combination of damage, health and
     clock can make a lost episode score above a won one. The other terms are
     tiebreakers WITHIN an outcome, which is what they should be.

The weights live in ml/training/reward_weights.json — data, not code (canon
directive 4: content is tunable without engine work). Change them there and both
consumers move together.

    python3 -m ml.training.reward --explain     # terms, weights, worked examples
"""
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
WEIGHTS_PATH = Path(__file__).resolve().parent / "reward_weights.json"

# The full-health-bar reference. Damage arrives in bars already (see
# ml/eval/env_parity.py), so 1.0 = "an entire health bar's worth". Dealing two
# bars to a one-bar enemy is overkill, not twice the achievement, so the term
# saturates there.
DMG_REF = 1.0
# Episode cap in seconds: dh::sim::kMaxTicks / kArenaDt = 3600 / 60. The Godot
# arena's default time_limit is 90 s and its selftest uses 60 s; the duration
# term clamps, so a longer cap costs correctness nothing.
EPISODE_CAP_S = 60.0

# name -> (direction, one-line meaning). "higher"/"lower" is Ricardo's wording
# and is the single source of truth for the sign; nothing below re-derives it.
TERMS = {
    "win":       ("higher", "won the episode (1 win, 0.5 draw, 0 loss)"),
    "dmg_dealt": ("higher", "health bars taken off the opponent"),
    "dmg_taken": ("lower",  "health bars the policy absorbed"),
    "hp_foe":    ("lower",  "opponent's health at the end"),
    "hp_self":   ("higher", "policy's own health at the end"),
    "duration":  ("split",  "shorter when winning, longer when losing"),
}


def _clamp01(x: float) -> float:
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else float(x))


def active_model(path: Path | str | None = None) -> str:
    """"v2" (the weighted model) unless the weights file says otherwise.

    Kept as data so reverting to the original two-term fitness is an edit, not a
    revert — every ES ranking in this repo's history was made with "v1", and
    comparing a new run against those means being able to run it again.
    """
    p = Path(path) if path is not None else WEIGHTS_PATH
    if not p.exists():
        return "v2"
    return str(json.loads(p.read_text()).get("model", "v2"))


def load_weights(path: Path | str | None = None) -> dict:
    """Weights as data. Missing file = the defaults below, so the trainer runs
    on a fresh checkout; a present file must be complete and sane."""
    p = Path(path) if path is not None else WEIGHTS_PATH
    if not p.exists():
        return dict(DEFAULT_WEIGHTS)
    raw = json.loads(p.read_text())
    w = raw.get("weights", raw)
    missing = [k for k in TERMS if k not in w]
    if missing:
        raise ValueError(f"{p}: missing weight(s) for {missing}")
    unknown = [k for k in w if k not in TERMS]
    if unknown:
        raise ValueError(f"{p}: unknown term(s) {unknown} — valid: {sorted(TERMS)}")
    out = {k: float(w[k]) for k in TERMS}
    assert_sane_weights(out, str(p))
    return out


# Recommended starting point, and the reasoning for each number:
#   win        the product is winning, so it dominates by construction
#   dmg_dealt  offence is the thing that has been hardest to teach (the move
#              head sat untrained for the whole PPO history); weight it above
#              defence so avoidance stops being a tie
#   dmg_taken  defence matters, but LESS than offence — deliberately asymmetric,
#              because symmetric was the avoidance local optimum
#   hp_foe     the same story as dmg_dealt but clamped and end-of-episode only,
#              so it is a coarse confirmation of it, not a second vote
#   hp_self    likewise for dmg_taken
#   duration   a tiebreaker: win faster, lose slower
DEFAULT_WEIGHTS = {
    "win": 0.55,
    "dmg_dealt": 0.15,
    "dmg_taken": 0.11,
    "hp_foe": 0.08,
    "hp_self": 0.06,
    "duration": 0.05,
}


def assert_sane_weights(w: dict, where: str = "weights") -> None:
    """The two invariants that keep the model meaningful.

    Without the first, "score" is not on a [0, 1] scale and no threshold reads
    the same twice. Without the second, a sufficiently pretty loss outranks an
    ugly win, and the agent learns to lose beautifully — which is precisely the
    degenerate timeout policy this project has already met once.
    """
    total = sum(w.values())
    if abs(total - 1.0) > 1e-6:
        raise ValueError(f"{where}: weights must sum to 1.0, got {total:.6f}")
    if any(v < 0.0 for v in w.values()):
        raise ValueError(f"{where}: weights must be non-negative: {w}")
    others = total - w["win"]
    if w["win"] <= others + 1e-9:
        raise ValueError(
            f"{where}: win weight {w['win']:.3f} must EXCEED the sum of every "
            f"other weight ({others:.3f}), or a lost episode can outscore a won "
            f"one on damage and clock alone. That is the 'lose beautifully' "
            f"failure mode, and it is not a hypothetical here.")


def episode_terms(ep: dict, cap_s: float = EPISODE_CAP_S) -> dict:
    """One episode -> each term normalized to [0, 1], higher always better.

    `ep` uses the arena's own episode-row vocabulary so nothing has to translate:
        winner_is_self  bool | None   (None = draw)
        hp_self, hp_foe                fractions in [0, 1]
        dmg_dealt, dmg_taken           HEALTH BARS (see ml/eval/env_parity.py)
        seconds                        episode length
    Missing damage keys fall back to the health fractions, so recordings made
    before dmg_taken_*/max_hp_* existed still score instead of silently reading
    as zero damage — which would look like a policy that never landed a hit.
    """
    won = ep.get("winner_is_self")
    hp_self = _clamp01(ep.get("hp_self", 0.0))
    hp_foe = _clamp01(ep.get("hp_foe", 0.0))
    dealt = ep.get("dmg_dealt")
    taken = ep.get("dmg_taken")
    if dealt is None:
        dealt = 1.0 - hp_foe          # coarse fallback: what the foe lost
    if taken is None:
        taken = 1.0 - hp_self
    frac = _clamp01(float(ep.get("seconds", cap_s)) / max(cap_s, 1e-6))
    if won is True:
        duration = 1.0 - frac         # won: the shorter the better
    elif won is False:
        duration = frac               # lost: the longer the better
    else:
        duration = 0.5                # draw: neutral, so stalling never pays
    return {
        "win": 1.0 if won is True else (0.0 if won is False else 0.5),
        "dmg_dealt": _clamp01(float(dealt) / DMG_REF),
        "dmg_taken": 1.0 - _clamp01(float(taken) / DMG_REF),
        "hp_foe": 1.0 - hp_foe,
        "hp_self": hp_self,
        "duration": duration,
    }


def episode_score(ep: dict, weights: dict | None = None,
                  cap_s: float = EPISODE_CAP_S) -> float:
    """Weighted score for one episode, in [0, 1]."""
    w = weights if weights is not None else load_weights()
    t = episode_terms(ep, cap_s)
    return float(sum(w[k] * t[k] for k in TERMS))


def score_episodes(eps: list[dict], weights: dict | None = None,
                   cap_s: float = EPISODE_CAP_S) -> float:
    """Mean score over a match set. Empty set scores 0.0, not an error: an
    arena run that produced nothing should rank last, not crash the sweep."""
    if not eps:
        return 0.0
    w = weights if weights is not None else load_weights()
    return float(sum(episode_score(e, w, cap_s) for e in eps) / len(eps))


def breakdown(eps: list[dict], weights: dict | None = None,
              cap_s: float = EPISODE_CAP_S) -> dict:
    """Per-term mean value, weight and contribution — what to print when a
    number needs explaining rather than just comparing."""
    w = weights if weights is not None else load_weights()
    n = max(len(eps), 1)
    means = {k: 0.0 for k in TERMS}
    for e in eps:
        for k, v in episode_terms(e, cap_s).items():
            means[k] += v / n
    return {"score": sum(w[k] * means[k] for k in TERMS),
            "terms": {k: {"value": means[k], "weight": w[k],
                          "contribution": w[k] * means[k],
                          "direction": TERMS[k][0]} for k in TERMS},
            "episodes": len(eps)}


def _winner_is_self(e: dict, side: str, foe: str):
    """Did `side` win this episode? True / False / None for a draw.

    Resolution order, most authoritative first, because the obvious reading is
    WRONG in the most common case. `winner` names a BUILD, and a self-play suite
    is a mirror matchup where both fighters carry the same build id — so
    `winner == e["a"]` is true for every episode no matter who actually won, and
    a net that lost every fight scored as if it had won every fight (measured
    2026-09-14: win_rate 0.00 alongside fitness 0.607, which this model's own
    invariant says is impossible for a loss).
    """
    winner = e.get("winner", "draw")
    # 1. the side, stated outright (arena.gd, 2026-09-14 onward)
    if "winner_side" in e:
        ws = e["winner_side"]
        return None if ws == "draw" else (ws == side)
    if winner == "draw":
        return None
    # 2. build ids, but ONLY when they can tell the sides apart
    a_id, b_id = e.get(side), e.get(foe)
    if a_id is not None and b_id is not None and a_id != b_id:
        return winner == a_id
    # 3. mirror, or a row with no build ids: infer from health. The arena ends
    #    an episode when a fighter dies, so the side at zero is the side that
    #    lost. Only for recordings made before winner_side existed.
    hp_self = float(e.get(f"hp_{side}", e.get("hp_self", 0.0)))
    hp_foe = float(e.get(f"hp_{foe}", e.get("hp_foe", 0.0)))
    if hp_self <= 0.0 and hp_foe > 0.0:
        return False
    if hp_foe <= 0.0 and hp_self > 0.0:
        return True
    # 4. both alive or both dead and nothing else to go on: a draw is the only
    #    honest answer. Guessing here is what caused the bug above.
    if a_id is not None:
        return None
    return None if winner == "draw" else (winner == side)


def from_arena_row(row: dict, side: str = "a") -> list[dict]:
    """An arena result row (ml/training/league.py::run_match) -> episodes in this
    module's vocabulary. Damage is converted to health bars here, using the
    max_hp_* the arena now reports, because dh-env's stats come from
    ml/env/specs.json and the arena's from live content — raw hit points are two
    different units and must never be summed."""
    foe = "b" if side == "a" else "a"
    out = []
    for e in row.get("episodes", []):
        winner = e.get("winner", "draw")
        winner_is_self = _winner_is_self(e, side, foe)
        bar_self = float(e.get(f"max_hp_{side}", 0.0)) or None
        bar_foe = float(e.get(f"max_hp_{foe}", 0.0)) or None
        dmg_self = e.get(f"dmg_taken_{side}")
        dmg_foe = e.get(f"dmg_taken_{foe}")
        out.append({
            "winner_is_self": winner_is_self,
            "hp_self": float(e.get(f"hp_{side}", 0.0)),
            "hp_foe": float(e.get(f"hp_{foe}", 0.0)),
            "dmg_dealt": (float(dmg_foe) / bar_foe)
                         if (dmg_foe is not None and bar_foe) else None,
            "dmg_taken": (float(dmg_self) / bar_self)
                         if (dmg_self is not None and bar_self) else None,
            "seconds": float(e.get("duration_s", EPISODE_CAP_S)),
        })
    return out


def _explain() -> int:
    w = load_weights()
    print("\n  REWARD MODEL — every term normalized to [0,1], then weighted")
    print("  " + "-" * 68)
    print("  {:<12}{:<9}{:>8}  {}".format("term", "better", "weight", "meaning"))
    print("  " + "-" * 68)
    for k, (direction, meaning) in TERMS.items():
        print("  {:<12}{:<9}{:>8.2f}  {}".format(k, direction, w[k], meaning))
    print("  " + "-" * 68)
    others = sum(w.values()) - w["win"]
    print("  sum {:.2f};  win {:.2f} > all others {:.2f}, so a won episode "
          "always".format(sum(w.values()), w["win"], others))
    print("  outranks a lost one no matter how pretty the loss.")
    print("  scales: 1.0 dmg = a full health bar; duration is a fraction of "
          "{:.0f}s.".format(EPISODE_CAP_S))

    # Worked examples, including the two failure modes this model exists to rank
    # correctly against each other.
    cases = [
        ("fast clean kill", dict(winner_is_self=True, hp_self=0.85, hp_foe=0.0,
                                 dmg_dealt=1.0, dmg_taken=0.15, seconds=12.0)),
        ("slow bloody win", dict(winner_is_self=True, hp_self=0.10, hp_foe=0.0,
                                 dmg_dealt=1.0, dmg_taken=0.90, seconds=55.0)),
        ("timeout stall (both alive)",
         dict(winner_is_self=None, hp_self=0.97, hp_foe=0.97,
              dmg_dealt=0.03, dmg_taken=0.03, seconds=60.0)),
        ("long brave loss", dict(winner_is_self=False, hp_self=0.0, hp_foe=0.12,
                                 dmg_dealt=0.88, dmg_taken=1.0, seconds=52.0)),
        ("instant death", dict(winner_is_self=False, hp_self=0.0, hp_foe=1.0,
                               dmg_dealt=0.0, dmg_taken=1.0, seconds=4.0)),
    ]
    print("\n  {:<28}{:>8}   {}".format("episode", "score", "reads as"))
    print("  " + "-" * 68)
    ranked = sorted(cases, key=lambda c: -episode_score(c[1], w))
    for name, ep in ranked:
        print("  {:<28}{:>8.3f}".format(name, episode_score(ep, w)))
    print("  " + "-" * 68)
    print("  The ordering is the point: both wins above everything, the FAST win")
    print("  above the slow one, the long loss above the instant death.")
    print("  The stall sits between the wins and the losses because a draw IS")
    print("  half an outcome — it banks 0.5 of the win weight and most of the")
    print("  defensive weight for taking no damage. That is honest scoring, and")
    print("  it is NOT what stops an agent stalling: the gate's sanity check is")
    print("  (ml/eval/gate.py, mean loser hp deficit >= 0.05). A hard constraint")
    print("  rejects degenerate policies; a weight only ranks them.")

    # One case opened up, so the arithmetic is inspectable rather than asserted.
    name, ep = cases[0]
    b = breakdown([ep], w)
    print("\n  breakdown — '{}' (score {:.3f})".format(name, b["score"]))
    print("  " + "-" * 68)
    print("  {:<12}{:>9}{:>9}{:>14}".format("term", "value", "weight", "contribution"))
    for k, d in b["terms"].items():
        print("  {:<12}{:>9.3f}{:>9.2f}{:>14.3f}".format(
            k, d["value"], d["weight"], d["contribution"]))
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(_explain() if "--explain" in sys.argv or len(sys.argv) == 1
                     else _explain())
