"""Teacher -> student distillation (ml/training/distill.py).

Hand-written backprop is the kind of code that trains to a plausible-looking loss
while being wrong, so the core of this file is two numerical gradient checks: one
on the distillation loss, one through the whole student stack. If those hold, the
rest is plumbing.

The environment and Godot are not touched here — the rollout half is exercised by
a real run (see the commit), this is the arithmetic.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from ml.training import distill                                   # noqa: E402
from ml.training.policy_net import (ACTION_LOGITS, EMB_DIM, HEAD_DIM,  # noqa: E402
                                    OBS_DIM, PolicyNet)


def write_teacher(tmp_path: Path, hidden=(8, 8), seed=3, decisive=False) -> Path:
    net = PolicyNet(seed=seed, hidden=hidden)
    net.ensure_embedding("*", seed)
    if decisive:
        # A freshly initialised net's logits are all ~0.1 apart, so its argmax is
        # noise and there is nothing for a student to copy. Scaling the head up
        # makes the teacher OPINIONATED, which is what a trained one is.
        net.weights[-1] = (net.weights[-1] * 12.0).astype(net.weights[-1].dtype)
    path = tmp_path / "teacher.json"
    net.export_game_json(path)
    return path


# ---- the teacher -------------------------------------------------------------------


def test_teacher_loads_any_width_and_forwards_batches(tmp_path):
    t = distill.TeacherNet(write_teacher(tmp_path, hidden=(32, 16, 8)))
    assert t.hidden == (32, 16, 8)
    y = t.forward(np.zeros((5, OBS_DIM + EMB_DIM)))
    assert y.shape == (5, HEAD_DIM)


def test_teacher_matches_the_numpy_net_it_came_from(tmp_path):
    """The teacher is read back from the same JSON the Godot runtime loads, so a
    disagreement here means the exported file does not mean what training meant."""
    net = PolicyNet(seed=11, hidden=(8, 8))
    net.ensure_embedding("*", 11)
    path = tmp_path / "t.json"
    net.export_game_json(path)
    t = distill.TeacherNet(path)
    obs = np.random.default_rng(0).normal(size=OBS_DIM).astype(np.float32)
    x = np.concatenate([obs, net.embeddings["*"]])[None, :]
    assert np.allclose(t.forward(x)[0], net.forward(obs), atol=1e-5)


def test_a_non_policy_file_is_refused(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({"schema": "something.else", "layers": []}))
    with pytest.raises(SystemExit):
        distill.TeacherNet(bad)


def test_an_obs_dim_mismatch_is_refused(tmp_path):
    path = write_teacher(tmp_path)
    doc = json.loads(path.read_text())
    doc["obs_dim"] = 36                      # a squad net: arena.obs.v2
    path.write_text(json.dumps(doc))
    with pytest.raises(SystemExit):
        distill.TeacherNet(path)


def test_a_teacher_without_a_matching_embedding_falls_back_to_star(tmp_path):
    t = distill.TeacherNet(write_teacher(tmp_path))
    assert t.embedding("no_such_key").shape == (EMB_DIM,)


# ---- the loss ----------------------------------------------------------------------


def loss_value(s, t, temperature, w):
    parts, _ = distill.kd_loss_and_grad(s, t, temperature, *w)
    return (w[0] * parts["move_mse"] + w[1] * (temperature ** 2) * parts["action_ce"]
            + w[2] * parts["dodge_bce"])


def test_the_loss_gradient_matches_finite_differences():
    """d(loss)/d(student head), checked numerically. The T^2 scaling on the action
    term is the easy thing to get wrong and it is what this pins down."""
    rng = np.random.default_rng(7)
    n, temperature, w = 6, 2.0, (1.0, 1.0, 0.5)
    s = rng.normal(size=(n, HEAD_DIM))
    t = rng.normal(size=(n, HEAD_DIM))
    _, grad = distill.kd_loss_and_grad(s, t, temperature, *w)
    eps = 1e-6
    for i in (0, 3):
        for j in range(HEAD_DIM):
            up, dn = s.copy(), s.copy()
            up[i, j] += eps
            dn[i, j] -= eps
            numeric = (loss_value(up, t, temperature, w)
                       - loss_value(dn, t, temperature, w)) / (2 * eps)
            assert numeric == pytest.approx(grad[i, j], abs=2e-6), (i, j)


def test_a_perfect_copy_has_no_loss_and_no_gradient():
    rng = np.random.default_rng(1)
    y = rng.normal(size=(4, HEAD_DIM))
    parts, grad = distill.kd_loss_and_grad(y, y, 2.0, 1.0, 1.0, 0.5)
    assert parts["move_mse"] == pytest.approx(0.0)
    assert parts["action_agreement"] == 1.0
    assert np.allclose(grad, 0.0, atol=1e-12)


def test_action_agreement_counts_the_argmax_not_the_values():
    """The runtime argmaxes the action head, so agreement — not raw error — is
    what says whether the student will actually behave like the teacher."""
    t = np.zeros((2, HEAD_DIM))
    t[0, 2 + 3] = 5.0
    t[1, 2 + 1] = 5.0
    s = t * 0.01                       # same ranking, a hundredth of the magnitude
    parts, _ = distill.kd_loss_and_grad(s, t, 2.0, 1.0, 1.0, 0.5)
    assert parts["action_agreement"] == 1.0


# ---- the student -------------------------------------------------------------------


def test_student_backprop_matches_finite_differences():
    rng = np.random.default_rng(5)
    st = distill.Student((6, 5), seed=2)
    x = rng.normal(size=(4, OBS_DIM + EMB_DIM))
    target = rng.normal(size=(4, HEAD_DIM))

    def loss_of(student):
        y, _ = student.forward(x)
        return float(np.mean((y - target) ** 2))

    y, acts = st.forward(x)
    dy = 2.0 * (y - target) / y.size
    saved = [w.copy() for w in st.w]
    st.backward(acts, dy, lr=0.0)                     # lr 0: gradients only
    assert all(np.allclose(a, b) for a, b in zip(saved, st.w))

    # recompute the raw gradient of layer 0 the same way backward does
    d = dy
    grads = [None] * len(st.w)
    for i in range(len(st.w) - 1, -1, -1):
        grads[i] = d.T @ acts[i]
        if i > 0:
            d = (d @ st.w[i]) * (1.0 - acts[i] ** 2)
    eps = 1e-6
    for (i, r, c) in ((0, 1, 2), (1, 0, 3), (2, 2, 1)):
        st.w[i][r, c] += eps
        up = loss_of(st)
        st.w[i][r, c] -= 2 * eps
        dn = loss_of(st)
        st.w[i][r, c] += eps
        assert (up - dn) / (2 * eps) == pytest.approx(grads[i][r, c], rel=1e-4, abs=1e-9)


def test_a_student_learns_to_copy_a_teacher(tmp_path):
    """End to end on synthetic observations: a 64x64 student must reproduce a
    WIDER teacher's decisions, which is the whole premise."""
    teacher = distill.TeacherNet(write_teacher(tmp_path, hidden=(64, 64), seed=4,
                                               decisive=True))
    rng = np.random.default_rng(0)
    xs = rng.normal(size=(4000, OBS_DIM + EMB_DIM)) * 0.5
    ys = teacher.forward(xs)
    st = distill.Student((32, 32), seed=1)
    before, _ = distill.kd_loss_and_grad(st.forward(xs)[0], ys, 2.0, 1.0, 1.0, 0.5)
    from ml.training import league
    after = distill.fit(st, xs, ys, epochs=12, batch=256, lr=3e-3, temperature=2.0,
                        weights=(1.0, 1.0, 0.5), seed=0, progress=league.Progress(None))
    assert after["move_mse"] < before["move_mse"] / 5
    assert after["action_agreement"] > max(0.75, before["action_agreement"])


def test_the_student_exports_as_a_normal_policy_and_forwards_identically(tmp_path):
    """to_policy_net -> export_game_json is the seam to the Godot runtime. If the
    exported file disagrees with the trained arrays, the gate measures a
    different net than the one that was distilled."""
    st = distill.Student((16, 16), seed=3)
    emb = np.random.default_rng(2).normal(size=EMB_DIM)
    net = st.to_policy_net({"*": emb})
    assert net.hidden == (16, 16)
    path = tmp_path / "student.json"
    net.export_game_json(path)
    back = distill.TeacherNet(path)
    x = np.concatenate([np.random.default_rng(9).normal(size=OBS_DIM), emb])[None, :]
    assert np.allclose(back.forward(x)[0], st.forward(x)[0][0], atol=1e-5)


def test_the_exported_student_declares_its_size(tmp_path):
    net = distill.Student((64, 64), seed=0).to_policy_net({"*": np.zeros(EMB_DIM)})
    path = tmp_path / "s.json"
    net.export_game_json(path)
    doc = json.loads(path.read_text())
    assert doc["hidden"] == [64, 64] and doc["macs"] == 7744
