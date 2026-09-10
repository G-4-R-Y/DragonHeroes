"""PolicyNet unit tests — the numpy/game parity contract."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "training"))
from policy_net import EMB_DIM, HEAD_DIM, OBS_DIM, PolicyNet  # noqa: E402


def test_forward_shapes():
    net = PolicyNet(seed=1)
    net.ensure_embedding("*", 1)
    y = net.forward(np.zeros(OBS_DIM, dtype=np.float32))
    assert y.shape == (HEAD_DIM,)


def test_forward_parity_hand_computed():
    net = PolicyNet(seed=7)
    emb = net.ensure_embedding("core.arena.fen_boar_alpha", 7)
    obs = np.linspace(-0.5, 0.5, OBS_DIM, dtype=np.float32)
    y = net.forward(obs, "core.arena.fen_boar_alpha")
    x = np.concatenate([obs, emb])
    for i, (w, b) in enumerate(zip(net.weights, net.biases)):
        x = w @ x + b
        if i < len(net.weights) - 1:
            x = np.tanh(x)
    assert np.allclose(y, x)


def test_act_contract():
    net = PolicyNet(seed=2)
    net.ensure_embedding("*", 2)
    move, pick, dodge = net.act(np.zeros(OBS_DIM, dtype=np.float32))
    assert move.shape == (2,)
    assert 0 <= pick < 7
    assert isinstance(dodge, bool)


def test_new_content_is_a_new_row_not_a_new_shape():
    net = PolicyNet(seed=3)
    net.ensure_embedding("*", 3)
    before = net.flat().size
    row = net.ensure_embedding("gen.creature.new_weekly_drop", 3)
    assert row.shape == (EMB_DIM,)
    # the table mean initializes warm-start rows (canon §9 §5)
    assert np.allclose(row, net.embeddings["*"], atol=0.05)
    # forward still works on the same obs shape
    net.forward(np.zeros(OBS_DIM, dtype=np.float32), "gen.creature.new_weekly_drop")
    assert net.flat().size == before + EMB_DIM


def test_game_json_roundtrip_matches_gdscript_layout(tmp_path):
    net = PolicyNet(seed=5)
    net.ensure_embedding("*", 5)
    out = tmp_path / "p.json"
    net.export_game_json(out)
    doc = json.loads(out.read_text())
    assert doc["schema"] == "arena.policy.v1"
    assert doc["obs_dim"] == OBS_DIM and doc["emb_dim"] == EMB_DIM
    assert len(doc["layers"]) == 3
    # layer 0 is [64 x (OBS_DIM+EMB_DIM)] with tanh; the head is linear
    assert len(doc["layers"][0]["w"]) == 64
    assert len(doc["layers"][0]["w"][0]) == OBS_DIM + EMB_DIM
    assert doc["layers"][0]["act"] == "tanh"
    assert doc["layers"][-1]["act"] == "linear"
    assert len(doc["layers"][-1]["w"]) == HEAD_DIM


def test_npz_roundtrip_and_flat_update(tmp_path):
    net = PolicyNet(seed=9)
    net.ensure_embedding("*", 9)
    net.ensure_embedding("core.arena.dusk_revenant", 9)
    p = tmp_path / "n.npz"
    net.save_npz(p)
    back = PolicyNet.load_npz(p)
    obs = np.random.default_rng(0).normal(0, 1, OBS_DIM).astype(np.float32)
    assert np.allclose(net.forward(obs, "*"), back.forward(obs, "*"))
    theta = net.flat()
    net.set_flat(theta + 0.01)
    assert not np.allclose(net.flat(), theta)
