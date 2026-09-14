"""The scoring model (ml/training/reward.py).

Ricardo specified this one precisely enough to test against his words directly,
so each test below pins one clause of what he asked for:

    "If winner, the shorter the better. If loser, the longest the better.
     'dmg_taken' is always 'lower is better', 'dmg_dealt' is always 'higher the
     better', hp_foe lower the better, hp_self higher the better, win_rate the
     higher the better."

plus the two structural properties that keep those weights meaningful: the
scale normalisation ("not compare 40 seconds with 0.087 dmg_dealt") and the
guarantee that no pretty loss outranks an ugly win.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from ml.training import reward  # noqa: E402

W = reward.load_weights()


def ep(**kw) -> dict:
    """A neutral mid-fight episode; each test perturbs exactly one field."""
    base = dict(winner_is_self=True, hp_self=0.5, hp_foe=0.5,
                dmg_dealt=0.5, dmg_taken=0.5, seconds=30.0)
    base.update(kw)
    return base


# ---- directions, one test per clause of the specification -------------------

def test_win_rate_higher_is_better():
    assert reward.episode_score(ep(winner_is_self=True), W) > \
           reward.episode_score(ep(winner_is_self=None), W) > \
           reward.episode_score(ep(winner_is_self=False), W)


def test_dmg_dealt_higher_is_better():
    assert reward.episode_score(ep(dmg_dealt=0.9), W) > \
           reward.episode_score(ep(dmg_dealt=0.1), W)


def test_dmg_taken_lower_is_better():
    assert reward.episode_score(ep(dmg_taken=0.1), W) > \
           reward.episode_score(ep(dmg_taken=0.9), W)


def test_hp_foe_lower_is_better():
    assert reward.episode_score(ep(hp_foe=0.1), W) > \
           reward.episode_score(ep(hp_foe=0.9), W)


def test_hp_self_higher_is_better():
    assert reward.episode_score(ep(hp_self=0.9), W) > \
           reward.episode_score(ep(hp_self=0.1), W)


def test_winner_prefers_the_shorter_fight():
    assert reward.episode_score(ep(winner_is_self=True, seconds=8.0), W) > \
           reward.episode_score(ep(winner_is_self=True, seconds=55.0), W)


def test_loser_prefers_the_longer_fight():
    """The clause that exposed a live defect: ppo.py subtracted R_TIME every
    tick regardless of outcome, so a losing agent was paid to die sooner."""
    assert reward.episode_score(ep(winner_is_self=False, seconds=55.0), W) > \
           reward.episode_score(ep(winner_is_self=False, seconds=8.0), W)


def test_draw_duration_is_neutral_so_stalling_never_pays():
    short = reward.episode_score(ep(winner_is_self=None, seconds=5.0), W)
    long_ = reward.episode_score(ep(winner_is_self=None, seconds=59.0), W)
    assert short == pytest.approx(long_)


# ---- scale normalisation ----------------------------------------------------

def test_every_term_is_normalised_to_the_unit_interval():
    """Ricardo: "Numbers magnitudes must be scaled tho, as to not compare 40
    seconds with 0.087 dmg_dealt." Seconds are the term most able to break
    this, being two orders of magnitude larger than the others."""
    extremes = [ep(seconds=0.0), ep(seconds=1e6), ep(dmg_dealt=1e6),
                ep(dmg_taken=1e6), ep(hp_self=5.0), ep(hp_foe=-3.0),
                ep(winner_is_self=False, seconds=1e6)]
    for e in extremes:
        for name, v in reward.episode_terms(e).items():
            assert 0.0 <= v <= 1.0, f"{name} = {v} escaped [0,1] for {e}"
        assert 0.0 <= reward.episode_score(e, W) <= 1.0


def test_a_huge_duration_cannot_swamp_the_other_terms():
    """The concrete failure Ricardo named: an unnormalised 40 would dwarf a
    0.087. Here a 100x longer episode moves the score by at most its weight."""
    a = reward.episode_score(ep(winner_is_self=False, seconds=0.4), W)
    b = reward.episode_score(ep(winner_is_self=False, seconds=40.0), W)
    assert abs(b - a) <= W["duration"] + 1e-9


# ---- structural guarantees --------------------------------------------------

def test_any_win_outranks_any_loss():
    """The ugliest possible win still beats the prettiest possible loss."""
    worst_win = ep(winner_is_self=True, hp_self=0.0, hp_foe=1.0,
                   dmg_dealt=0.0, dmg_taken=1.0, seconds=60.0)
    best_loss = ep(winner_is_self=False, hp_self=1.0, hp_foe=0.0,
                   dmg_dealt=1.0, dmg_taken=0.0, seconds=60.0)
    assert reward.episode_score(worst_win, W) > reward.episode_score(best_loss, W)


def test_shipped_weights_satisfy_the_invariants():
    reward.assert_sane_weights(W)
    assert W["dmg_dealt"] > W["dmg_taken"], \
        "offence must outweigh defence, or avoidance is a tie again"


def test_weights_that_break_the_invariants_are_refused(tmp_path):
    bad_sum = {k: 1.0 for k in reward.TERMS}
    with pytest.raises(ValueError, match="sum to 1.0"):
        reward.assert_sane_weights(bad_sum)

    # win no longer dominates: a loss could outscore a win
    weak = {"win": 0.30, "dmg_dealt": 0.25, "dmg_taken": 0.20,
            "hp_foe": 0.10, "hp_self": 0.10, "duration": 0.05}
    with pytest.raises(ValueError, match="must EXCEED"):
        reward.assert_sane_weights(weak)

    p = tmp_path / "w.json"
    p.write_text(json.dumps({"weights": {"win": 1.0}}))
    with pytest.raises(ValueError, match="missing weight"):
        reward.load_weights(p)

    p.write_text(json.dumps({"weights": dict(reward.DEFAULT_WEIGHTS,
                                             **{"nonsense": 0.0})}))
    with pytest.raises(ValueError, match="unknown term"):
        reward.load_weights(p)


def test_missing_damage_columns_fall_back_instead_of_reading_as_zero():
    """Recordings predate dmg_taken_*/max_hp_*. Scoring those as zero damage
    would rank an old champion as a policy that never landed a hit."""
    t = reward.episode_terms({"winner_is_self": True, "hp_self": 0.8,
                              "hp_foe": 0.0, "seconds": 20.0})
    assert t["dmg_dealt"] == pytest.approx(1.0)     # foe lost its whole bar
    assert t["dmg_taken"] == pytest.approx(0.8)     # goodness: took 0.2


def test_arena_rows_convert_with_damage_in_health_bars():
    """from_arena_row must divide by max_hp_*: dh-env's stats come from
    ml/env/specs.json and the arena's from live content, so raw hit points are
    two different units."""
    row = {"episodes": [{"a": "buildA", "b": "buildB", "winner": "buildA",
                         "hp_a": 0.4, "hp_b": 0.0, "duration_s": 15.0,
                         "dmg_taken_a": 120.0, "dmg_taken_b": 340.0,
                         "max_hp_a": 200.0, "max_hp_b": 340.0}]}
    eps = reward.from_arena_row(row, "a")
    assert eps[0]["winner_is_self"] is True
    assert eps[0]["dmg_dealt"] == pytest.approx(1.0)    # 340/340
    assert eps[0]["dmg_taken"] == pytest.approx(0.6)    # 120/200
    # and from B's seat the same row inverts
    epsb = reward.from_arena_row(row, "b")
    assert epsb[0]["winner_is_self"] is False
    assert epsb[0]["dmg_dealt"] == pytest.approx(0.6)


def test_empty_match_set_scores_zero_rather_than_raising():
    assert reward.score_episodes([], W) == 0.0


def test_breakdown_contributions_sum_to_the_score():
    eps = [ep(), ep(winner_is_self=False, seconds=50.0)]
    b = reward.breakdown(eps, W)
    assert b["score"] == pytest.approx(reward.score_episodes(eps, W))
    assert sum(d["contribution"] for d in b["terms"].values()) \
        == pytest.approx(b["score"])
