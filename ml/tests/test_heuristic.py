"""The heuristic teacher (ml/training/heuristic.py) — the five rules Ricardo
chose to clone: "Clone the heuristic, then PPO" (2026-09-14).

Every test here pins a rule that, if it broke, would look like a training
problem rather than a teacher problem — which is how the whole collapse hid.
"""
import sys
from pathlib import Path

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from ml.training.heuristic import (HeuristicTeacher, HEAD_DIM, ACTION_LOGITS,  # noqa: E402
                                   KIT_RANGE_PX, teacher_for)

DRAKE = {"attack_reach": 28.8, "body_radius": 9.84, "is_ranged": False,
         "kits": [{"cd": 4.0}, {"cd": 8.0}]}


def _obs(dist_px=20.0, rel=(1.0, 0.0), atk_cd=0.0, spec_cd=0.0, kit_cd=(0.0, 0.0)):
    o = np.zeros(47)
    o[16], o[17] = rel[0] * dist_px / 512.0, rel[1] * dist_px / 512.0
    o[18] = dist_px / 512.0
    o[5], o[6] = atk_cd, spec_cd
    for i, c in enumerate(kit_cd):
        o[7 + i] = c
    return o[None, :]


def _pick(y):
    return int(np.argmax(y[0, 2:2 + ACTION_LOGITS]))


def test_rule_one_always_walks_at_the_foe():
    """The one line that is the entire margin over every trained net. The nets'
    move head emitted 0.110 +- 0.006 regardless of where the enemy was; this
    must emit a UNIT vector that tracks the enemy."""
    t = HeuristicTeacher(DRAKE)
    for rel in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.6, -0.8)):
        y = t.forward(_obs(dist_px=200.0, rel=rel))
        assert np.allclose(np.linalg.norm(y[0, :2]), 1.0, atol=1e-9)
        assert np.allclose(y[0, :2], np.asarray(rel) / np.linalg.norm(rel), atol=1e-9)
    # standing on top of the foe is the one case with no direction to take
    assert np.allclose(t.forward(_obs(dist_px=0.0, rel=(0.0, 0.0)))[0, :2], 0.0)


def test_kits_outrank_the_slam_which_outranks_the_attack():
    """Ranking, not one-hot: the KD temperature is only meaningful if the
    teacher expresses an ORDER, and the runtime argmaxes so the order is what
    has to survive distillation."""
    t = HeuristicTeacher(DRAKE)
    y = t.forward(_obs(dist_px=20.0))[0, 2:2 + ACTION_LOGITS]
    assert _pick(t.forward(_obs(dist_px=20.0))) == 3      # kit slot 0
    assert y[3] > y[4] > y[2] > y[1] > y[0]               # kit0 > kit1 > slam > attack > noop


def test_a_kit_on_cooldown_is_not_offered():
    t = HeuristicTeacher(DRAKE)
    assert _pick(t.forward(_obs(dist_px=20.0, kit_cd=(1.0, 0.0)))) == 4   # slot 1
    assert _pick(t.forward(_obs(dist_px=20.0, kit_cd=(1.0, 1.0)))) == 2   # slam
    assert _pick(t.forward(_obs(dist_px=20.0, kit_cd=(1.0, 1.0),
                                spec_cd=1.0))) == 1                       # attack
    assert _pick(t.forward(_obs(dist_px=20.0, kit_cd=(1.0, 1.0),
                                spec_cd=1.0, atk_cd=1.0))) == 0           # noop


def test_a_slot_this_build_does_not_own_is_never_offered():
    """build_obs only fills kit cooldowns for i < kit_count, so an UNOWNED slot
    reads 0.0 — "ready" — forever. A teacher that trusted the channel would
    teach the student to spam an action the sim always refuses, which is
    exactly the intent-vs-effect bug that cost 72x the terminal reward."""
    one_kit = HeuristicTeacher({**DRAKE, "kits": [{"cd": 4.0}]})
    y = one_kit.forward(_obs(dist_px=20.0))[0, 2:2 + ACTION_LOGITS]
    assert _pick(one_kit.forward(_obs(dist_px=20.0))) == 3
    assert y[4] == y[5] == y[6]        # slots 1..3 all equally unavailable
    assert y[4] < y[0]                 # ...and below even noop
    no_kits = HeuristicTeacher({**DRAKE, "kits": []})
    assert _pick(no_kits.forward(_obs(dist_px=20.0))) == 2   # straight to the slam


def test_everything_is_range_gated():
    t = HeuristicTeacher(DRAKE)
    assert _pick(t.forward(_obs(dist_px=KIT_RANGE_PX - 1.0))) == 3
    # past kit range but inside slam range
    assert _pick(t.forward(_obs(dist_px=KIT_RANGE_PX + 1.0))) == 0
    assert _pick(t.forward(_obs(dist_px=DRAKE["attack_reach"] + 15.0))) == 3
    assert _pick(t.forward(_obs(dist_px=400.0))) == 0        # far away: close first


def test_a_ranged_build_keeps_its_distance_band():
    ranged = HeuristicTeacher({**DRAKE, "is_ranged": True, "kits": []})
    assert ranged.band_y == 7.0 * 16.0
    assert _pick(ranged.forward(_obs(dist_px=100.0))) == 2   # slam still in band
    melee = HeuristicTeacher({**DRAKE, "kits": []})
    assert _pick(melee.forward(_obs(dist_px=100.0))) == 0    # too far for melee


def test_the_head_is_the_runtime_contract():
    """[move2, logits7, dodge1] — the same 10 floats every runtime reads."""
    t = HeuristicTeacher(DRAKE)
    y = t.forward(_obs())
    assert y.shape == (1, HEAD_DIM) == (1, 10)
    assert t.forward(np.repeat(_obs(), 5, axis=0)).shape == (5, 10)
    # silent on dodge, deliberately: the heuristic has no dodge rule, and a
    # confident "never" would be teaching something the teacher does not know
    assert y[0, 9] < 0.0
    assert np.allclose(t.embedding("anything"), 0.0)


def test_teacher_for_reads_the_real_build():
    t = teacher_for("core.arena.cinder_drake")
    assert t.kit_count == 2
    assert t.band_y == pytest.approx(28.8)
    with pytest.raises(SystemExit):
        teacher_for("core.arena.not_a_build")
