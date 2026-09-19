"""arena.mask.v1 — the action mask is ONE rule in five runtimes (R50, 2026-09-19).

The mask decides which of the seven action logits a policy may pick from, given
only its observation and two body constants. It has to be bit-identical in the
torch trainer (what pi_theta is optimized as), the numpy twin, the GDScript
arena, dh::sim::Arena::mlp_act (the frozen self-play opponent) and the env
parity probe — otherwise "the policy" means different things in different
places, which is the exact failure this rule was written to end.

Python pins Python here; the same cases are written to
game/arena/tests/fixtures/action_mask_v1.json for the GDScript twin
(game/arena/tests/mask_parity_test.gd) and are hand-mirrored in
sim/tests/test_main.cpp::test_arena_action_mask_is_one_rule.

    ml/.venv/bin/python -m pytest ml/tests/test_action_mask.py
    ml/.venv/bin/python -m ml.tests.test_action_mask --write   # refresh the fixture
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ml.env.dh_env import (ACT_DODGE, ACTION_LOGITS, MASK_NEG, MASK_SCHEMA,  # noqa: E402
                           OBS_DIM, action_mask, dodge_allowed)
from ml.training.policy_net import HEAD_DIM, decode                        # noqa: E402

FIXTURE = ROOT / "game" / "arena" / "tests" / "fixtures" / "action_mask_v1.json"


def _obs(attack=0.0, special=0.0, kits=(0.0, 0.0, 0.0, 0.0), dodge=0.0) -> list[float]:
    o = [0.0] * OBS_DIM
    o[5], o[6], o[12] = attack, special, dodge
    for k, v in enumerate(kits):
        o[7 + k] = v
    return o


def _y(move=(0.0, 0.0), logits=(0.0,) * ACTION_LOGITS, dodge=0.0) -> list[float]:
    return [*move, *logits, dodge]


def fixture_cases() -> list[dict]:
    """Every value is a multiple of 1/16: exact in float32, float64 and JSON,
    so the GDScript twin sees the SAME numbers and a tie is a tie there too."""
    q = 1.0 / 16.0
    cases = []
    # (label, obs, y, kit_count, is_player)
    raw = [
        # nothing on cooldown: the plain argmax survives
        ("all ready, kit 2 wins", _obs(), _y(logits=(0, 1, 2, 3, 9, 4, 5)), 4, False),
        # the kit it wants is on cooldown -> next best, not a refused pick
        ("kit on cd falls to attack", _obs(kits=(1.0, 0, 0, 0)),
         _y(logits=(0, 8, 1, 9, 2, 3, 4)), 4, False),
        # creature special shares the ATTACK cooldown (fighter.gd -> bot_attack)
        ("creature special masked by attack cd", _obs(attack=0.5),
         _y(logits=(1, 9, 8, 0, 0, 0, 0)), 4, False),
        # player special has its OWN cooldown channel
        ("player special free while attack on cd", _obs(attack=0.5),
         _y(logits=(1, 9, 8, 0, 0, 0, 0)), 4, True),
        ("player special on cd", _obs(special=q), _y(logits=(1, 2, 8, 0, 0, 0, 0)), 4, True),
        # slots that do not exist are never picked, whatever the logit says
        ("kit_count 2 hides slots 3,4", _obs(), _y(logits=(0, 0, 0, 1, 2, 9, 8)), 2, False),
        ("kit_count 0 hides every kit", _obs(), _y(logits=(0, 1, 0, 9, 9, 9, 9)), 0, False),
        # everything masked but noop -> noop, not a refused kit
        ("only noop left", _obs(attack=1.0, kits=(1.0, 1.0, 1.0, 1.0)),
         _y(logits=(-5, 9, 9, 9, 9, 9, 9)), 4, False),
        # ties: the FIRST max among the available logits wins everywhere
        ("tie attack/kit1 -> attack", _obs(), _y(logits=(0, 7, 0, 7, 0, 0, 0)), 4, False),
        ("tie broken by mask -> kit1", _obs(attack=q), _y(logits=(0, 7, 0, 7, 0, 0, 0)), 4, False),
        ("all-zero head -> noop", _obs(), _y(), 4, False),
        # a cooldown fraction is EXACTLY 0.0 when ready; the smallest step masks
        ("one sixteenth still masks", _obs(kits=(q, 0, 0, 0)),
         _y(logits=(0, 0, 0, 9, 8, 0, 0)), 4, False),
        # dodge: the flag needs a visible charge
        ("dodge logit up, no charges", _obs(), _y(logits=(9, 0, 0, 0, 0, 0, 0), dodge=3.0), 4, False),
        ("dodge logit up, a charge", _obs(dodge=1.0 / 3.0 if False else 0.25),
         _y(logits=(9, 0, 0, 0, 0, 0, 0), dodge=3.0), 4, True),
        ("dodge logit down, a charge", _obs(dodge=1.0),
         _y(logits=(9, 0, 0, 0, 0, 0, 0), dodge=-q), 4, True),
        ("dodge logit exactly 0 is not a dodge", _obs(dodge=1.0),
         _y(logits=(9, 0, 0, 0, 0, 0, 0), dodge=0.0), 4, True),
        # the move passes through clipped, never masked
        ("move clipped", _obs(), _y(move=(2.0, -3.0), logits=(1, 0, 0, 0, 0, 0, 0)), 4, False),
        # v2-style extra channels do not matter: only 5,6,7..10,12 are read
        ("other channels ignored", [q * (i % 7) for i in range(OBS_DIM)][:5] + [0.0, 0.0, 0, 0, 0, 0, 0, 0] + [q] * (OBS_DIM - 13),
         _y(logits=(0, 3, 2, 1, 1, 1, 1)), 4, False),
    ]
    for label, obs, y, kit_count, is_player in raw:
        obs = [float(v) for v in obs]
        y = [float(v) for v in y]
        assert len(obs) == OBS_DIM and len(y) == HEAD_DIM
        allowed = action_mask(np.array(obs, dtype=np.float32), kit_count, is_player)
        move, pick, dodge = decode(np.array(y, dtype=np.float32),
                                   np.array(obs, dtype=np.float32), kit_count, is_player)
        cases.append({"label": label, "obs": obs, "y": y, "kit_count": kit_count,
                      "is_player": is_player, "allowed": [bool(a) for a in allowed],
                      "pick": int(pick), "dodge": bool(dodge),
                      "move": [float(move[0]), float(move[1])],
                      "env_act": int(pick + ACT_DODGE * int(dodge))})
    return cases


def fixture_text() -> str:
    return json.dumps({"schema": MASK_SCHEMA, "obs_dim": OBS_DIM, "head_dim": HEAD_DIM,
                       "action_logits": ACTION_LOGITS,
                       "rule": {"0": "always", "1": "o[5] <= 0", "2": "player: o[6] <= 0; "
                                "creature: o[5] <= 0", "3+k": "k < kit_count and o[7+k] <= 0",
                                "dodge": "y[9] > 0 and o[12] > 0", "tie": "first max wins"},
                       "cases": fixture_cases()}, indent=1) + "\n"


# ---- the rule, case by case ---------------------------------------------------

def test_hand_cases_match_the_rule():
    by = {c["label"]: c for c in fixture_cases()}
    assert by["all ready, kit 2 wins"]["pick"] == 4
    assert by["kit on cd falls to attack"]["pick"] == 1
    assert by["creature special masked by attack cd"]["pick"] == 0
    assert by["player special free while attack on cd"]["pick"] == 2
    assert by["player special on cd"]["pick"] == 1
    assert by["kit_count 2 hides slots 3,4"]["pick"] == 4
    assert by["kit_count 0 hides every kit"]["pick"] == 1
    assert by["only noop left"]["pick"] == 0
    assert by["tie attack/kit1 -> attack"]["pick"] == 1
    assert by["tie broken by mask -> kit1"]["pick"] == 3
    assert by["all-zero head -> noop"]["pick"] == 0
    assert by["one sixteenth still masks"]["pick"] == 4
    assert by["dodge logit up, no charges"]["dodge"] is False
    assert by["dodge logit up, a charge"]["dodge"] is True
    assert by["dodge logit down, a charge"]["dodge"] is False
    assert by["dodge logit exactly 0 is not a dodge"]["dodge"] is False
    assert by["move clipped"]["move"] == [1.0, -1.0]
    assert by["dodge logit up, a charge"]["env_act"] == 0 + ACT_DODGE


def test_noop_is_never_masked_and_a_pick_is_never_masked():
    rng = np.random.default_rng(20260919)
    for _ in range(500):
        obs = np.zeros(OBS_DIM, dtype=np.float32)
        obs[5:13] = rng.choice([0.0, 0.25, 1.0], size=8)
        kit_count = int(rng.integers(0, 5))
        is_player = bool(rng.integers(0, 2))
        y = rng.normal(size=HEAD_DIM).astype(np.float32)
        allowed = action_mask(obs, kit_count, is_player)
        assert allowed[0]
        _, pick, dodge = decode(y, obs, kit_count, is_player)
        assert allowed[pick]
        if dodge:
            assert obs[12] > 0.0 and y[2 + ACTION_LOGITS] > 0.0


def test_batched_numpy_equals_per_row():
    rng = np.random.default_rng(3)
    obs = np.zeros((64, OBS_DIM), dtype=np.float32)
    obs[:, 5:13] = rng.choice([0.0, 0.5, 1.0], size=(64, 8))
    for kit_count in range(5):
        for is_player in (False, True):
            batched = action_mask(obs, kit_count, is_player)
            rows = np.stack([action_mask(o, kit_count, is_player) for o in obs])
            assert (batched == rows).all()
    assert (dodge_allowed(obs) == (obs[:, 12] > 0)).all()


# ---- torch == numpy -------------------------------------------------------------

def test_torch_mask_heads_equals_numpy_rule():
    import torch
    from ml.training.torch_policy import mask_heads
    rng = np.random.default_rng(11)
    obs = np.zeros((256, OBS_DIM), dtype=np.float32)
    obs[:, 5:13] = rng.choice([0.0, 1.0 / 16.0, 0.5, 1.0], size=(256, 8))
    logits = rng.normal(size=(256, ACTION_LOGITS)).astype(np.float32)
    dodge = rng.normal(size=256).astype(np.float32)
    for kit_count in range(5):
        for is_player in (False, True):
            ml, md = mask_heads(torch.from_numpy(logits), torch.from_numpy(dodge),
                                torch.from_numpy(obs), kit_count, is_player)
            allowed = action_mask(obs, kit_count, is_player)
            assert ((ml.numpy() == MASK_NEG) == ~allowed).all()
            assert (ml.numpy()[allowed] == logits[allowed]).all()
            assert ((md.numpy() == MASK_NEG) == ~dodge_allowed(obs)).all()
            # and the trainer's argmax is the serving decode's pick
            picks = ml.argmax(-1).numpy()
            for i in range(0, 256, 17):
                assert picks[i] == decode(np.concatenate([[0, 0], logits[i], [dodge[i]]]),
                                          obs[i], kit_count, is_player)[1]


def test_mask_neg_is_a_zero_probability_and_stays_finite():
    """The trainer must never see nan from the mask: probability exactly 0,
    log-prob of the sampled (unmasked) action finite, entropy finite, and the
    masked Bernoulli samples 0 with log-prob 0."""
    import torch
    logits = torch.tensor([[1.0, MASK_NEG, 0.5, MASK_NEG, -1.0, MASK_NEG, MASK_NEG]])
    cat = torch.distributions.Categorical(logits=logits)
    p = cat.probs[0]
    assert p[1] == 0.0 and p[3] == 0.0 and p[5] == 0.0 and p[6] == 0.0
    assert torch.isfinite(cat.entropy()).all()
    for _ in range(64):
        a = cat.sample()
        assert a.item() in (0, 2, 4)
        assert torch.isfinite(cat.log_prob(a)).all()
    bern = torch.distributions.Bernoulli(logits=torch.tensor([MASK_NEG]))
    d = bern.sample()
    assert d.item() == 0.0
    assert bern.log_prob(d).item() == 0.0


# ---- env_parity's decode IS policy_net's --------------------------------------------

def test_env_parity_act_from_is_decode():
    from ml.eval.env_parity import act_from
    rng = np.random.default_rng(5)
    for _ in range(200):
        obs = np.zeros(OBS_DIM, dtype=np.float32)
        obs[5:13] = rng.choice([0.0, 0.5], size=8)
        y = rng.normal(size=HEAD_DIM).astype(np.float32)
        kit_count, is_player = int(rng.integers(0, 5)), bool(rng.integers(0, 2))
        move, act = act_from(y, obs, kit_count, is_player)
        m2, pick, dodge = decode(y, obs, kit_count, is_player)
        assert act == pick + ACT_DODGE * int(dodge)
        assert move == (float(m2[0]), float(m2[1]))


# ---- the fixture the GDScript twin reads is current ----------------------------------

def test_fixture_on_disk_is_current():
    assert FIXTURE.exists(), f"missing {FIXTURE} — run: python -m ml.tests.test_action_mask --write"
    assert FIXTURE.read_text() == fixture_text(), \
        "game/arena/tests/fixtures/action_mask_v1.json is stale — " \
        "run: ml/.venv/bin/python -m ml.tests.test_action_mask --write"


if __name__ == "__main__":
    if "--write" in sys.argv:
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(fixture_text())
        print(f"wrote {FIXTURE} ({len(fixture_cases())} cases)")
    else:
        print(fixture_text())
