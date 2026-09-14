"""Configurable net hyperparameters (ml/training/arch.py).

Ricardo, 2026-09-13: "net hyperparams should be configurable, as to test new
architectures." The risk in that sentence is not the flag — it is that FOUR
runtimes have to agree about what a net is, and three of them are compiled:

    ml/training/policy_net.py      numpy — ES and the distillation student
    ml/training/torch_policy.py    torch — the PPO learner
    game/arena/neural_policy.gd  } the arena, bit-for-bit — gated separately by
    sim/libs/dh-godot            } game/arena/tests/policy_parity_test.tscn
    sim/libs/dh-sim Arena        PPO's frozen self-play opponent (here)

So this file checks the two things that can go silently wrong: the numpy forward
really applies the activation it claims, and the activation codes really reach
the C++ opponent.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from ml.training.arch import (ACT_CODE, ACTIVATIONS, Arch, LEAKY_SLOPE,  # noqa: E402
                              activation_grad, apply_activation, normalize_act,
                              presets, resolve)
from ml.training.policy_net import PolicyNet, macs  # noqa: E402


# ---- the registry ------------------------------------------------------------

def test_every_shipped_preset_is_valid():
    for name in presets():
        a = resolve(name)
        assert a.activation in ACTIVATIONS
        assert a.hidden and all(n > 0 for n in a.hidden)


def test_the_default_preset_is_what_ships_today():
    """Every net in ml/serving is 47-64-64-10 tanh. If the default moves, they
    all become 'some other architecture' without anything being retrained."""
    a = resolve("default")
    assert a.hidden == (64, 64) and a.activation == "tanh"
    assert macs(a.hidden) == 7744


def test_flags_override_the_preset():
    a = resolve("wide", activation="relu")
    assert a.hidden == (256, 256) and a.activation == "relu"
    assert resolve("", hidden="8,8,8").hidden == (8, 8, 8)


def test_an_unknown_preset_or_activation_is_refused():
    with pytest.raises(SystemExit):
        resolve("enormous")
    with pytest.raises(ValueError):
        Arch(activation="gelu")
    with pytest.raises(ValueError):
        Arch(init="orthogonal")


def test_logits_is_read_as_linear():
    """Four nets in ml/serving/weights were exported with act "logits" by the old
    PPO exporter. It always meant linear; refusing it would retire them."""
    assert normalize_act("logits") == "linear"
    with pytest.raises(ValueError):
        normalize_act("gelu")


# ---- the activations themselves ---------------------------------------------

@pytest.mark.parametrize("name", ACTIVATIONS)
def test_activation_and_its_gradient_agree_numerically(name):
    x = np.linspace(-3.0, 3.0, 61)
    eps = 1e-6
    num = (apply_activation(x + eps, name) - apply_activation(x - eps, name)) / (2 * eps)
    ana = activation_grad(apply_activation(x, name), name)
    # relu/leaky are kinked at 0; skip the sample that straddles it
    ok = np.abs(x) > 1e-3
    assert np.allclose(num[ok], ana[ok], atol=1e-5)


def test_leaky_uses_the_slope_both_runtimes_hard_code():
    assert LEAKY_SLOPE == 0.01
    assert apply_activation(np.array([-2.0]), "leaky_relu")[0] == pytest.approx(-0.02)


def test_the_activation_codes_are_the_wire_format():
    """These integers cross into C++ (dh-godot DhPolicyNet::Activation and
    dh-sim Arena::MlpAct). Reordering them silently repurposes every net."""
    assert ACT_CODE == {"linear": 0, "tanh": 1, "relu": 2, "leaky_relu": 3}


# ---- the numpy net -----------------------------------------------------------

@pytest.mark.parametrize("name", ["default", "relu", "wide", "deep"])
def test_forward_applies_the_arch_activation(name):
    arch = resolve(name)
    net = PolicyNet(seed=3, arch=arch)
    net.ensure_embedding("*")
    obs = np.linspace(-1.0, 1.0, 31).astype(np.float32)
    x = np.concatenate([obs, net.embeddings["*"]])
    for w, b, a in zip(net.weights, net.biases, net.acts):
        x = apply_activation(w @ x + b, a)
    assert np.allclose(net.forward(obs, "*"), x)
    assert net.acts == [arch.activation] * len(arch.hidden) + ["linear"]


@pytest.mark.parametrize("name", ["default", "relu", "deep"])
def test_a_net_reloads_as_the_same_architecture(tmp_path, name):
    """A relu teacher that reloaded as a tanh teacher would be a DIFFERENT net
    wearing the same weights — and nothing would say so."""
    net = PolicyNet(seed=5, arch=resolve(name))
    net.ensure_embedding("k")
    obs = np.full(31, 0.3, dtype=np.float32)
    npz = tmp_path / "net.npz"
    net.save_npz(npz)
    back = PolicyNet.load_npz(npz)
    assert back.arch.activation == net.arch.activation
    assert back.arch.hidden == net.arch.hidden
    assert np.allclose(back.forward(obs, "k"), net.forward(obs, "k"))


def test_a_net_saved_before_arch_existed_still_loads_as_tanh(tmp_path):
    net = PolicyNet(seed=1)
    net.ensure_embedding("*")
    npz = tmp_path / "old.npz"
    net.save_npz(npz)
    data = {k: v for k, v in np.load(npz).items() if k not in ("arch", "hidden")}
    np.savez(npz, **data)
    back = PolicyNet.load_npz(npz)
    assert back.arch.activation == "tanh" and back.hidden == (64, 64)


def test_the_exported_json_names_every_activation(tmp_path):
    net = PolicyNet(seed=2, arch=resolve("deep"))
    net.ensure_embedding("*")
    out = tmp_path / "net.json"
    net.export_game_json(out)
    doc = json.loads(out.read_text())
    assert [l["act"] for l in doc["layers"]] == ["relu", "relu", "relu", "linear"]
    assert doc["arch"]["activation"] == "relu"
    assert doc["macs"] == macs((128, 128, 128))


def test_init_scales_with_fan_in():
    """he/xavier exist so a relu trunk does not start half-dead. The check is the
    std, not the exact draw."""
    wide = resolve("wide")          # xavier, 256 wide
    rng = np.random.default_rng(0)
    w = wide.init_weight(rng, 256, 256)
    assert 0.8 < w.std() / np.sqrt(1.0 / 256) < 1.2
    he = resolve("relu-wide")
    w = he.init_weight(rng, 256, 256)
    assert 0.8 < w.std() / np.sqrt(2.0 / 256) < 1.2


# ---- PPO's frozen self-play opponent (sim/libs/dh-sim Arena::mlp_act) --------
#
# This one is worth a real env. The opponent used to hard-code "tanh on every
# hidden layer", so a relu policy handed to it played as tanh: PPO would train
# against an opponent that is not the net it froze, and NOTHING in the metrics
# would look wrong.

def _lib_or_skip():
    try:
        from ml.env.dh_env import lib
        return lib()
    except Exception as e:                                   # not built here
        pytest.skip(f"libdh-env.so unavailable: {e}")


def _packed(seed: int = 1):
    """A net whose action stream actually separates the four activations. Bias
    spread matters: with tiny biases a relu net is nearly positively homogeneous,
    so relu and leaky_relu(0.01) pick the same argmax every tick and the episode
    is identical — a true fact about the net, not about the plumbing."""
    rng = np.random.default_rng(seed)
    sizes = [47, 64, 64, 10]
    params, li, lo = [], [], []
    for i in range(3):
        w = rng.normal(0, 0.35, (sizes[i + 1], sizes[i])).astype(np.float32)
        b = rng.normal(0, 0.6, sizes[i + 1]).astype(np.float32)
        params += [w.ravel(), b]
        li.append(sizes[i])
        lo.append(sizes[i + 1])
    return (np.concatenate(params).astype(np.float32), np.array(li, np.int32),
            np.array(lo, np.int32), rng.normal(0, 0.1, 16).astype(np.float32))


def _episode_digest(acts) -> str:
    import hashlib
    from ml.env.dh_env import DhEnv, set_opp_weights
    env = DhEnv("core.arena.fen_boar_alpha", "core.arena.gloamfen_stalker",
                opp="mlp", seed=5)
    pk = _packed()
    assert set_opp_weights(env._handle, pk[0], pk[1], pk[2], pk[3],
                           None if acts is None else np.array(acts, np.int32))
    obs = env.reset(11)
    h = hashlib.sha256()
    for _ in range(600):
        done, obs = env.step((0.0, 0.0), 0)
        h.update(np.asarray(obs, dtype=np.float32).tobytes())
        if done:
            break
    return h.hexdigest()


def test_the_frozen_opponent_runs_the_activation_it_was_given():
    lib = _lib_or_skip()
    if not hasattr(lib, "dh_env_set_opp_weights_acts"):
        pytest.skip("libdh-env.so predates per-layer activations — rebuild sim/build")
    digests = {name: _episode_digest([code, code, ACT_CODE["linear"]])
               for name, code in ACT_CODE.items()}
    assert len(set(digests.values())) == 4, \
        f"activations did not reach Arena::mlp_act: {digests}"


def test_no_acts_still_means_tanh_hidden_linear_head():
    """The old five-argument entry point is what every existing caller and every
    tanh net uses. It must not have moved a bit."""
    _lib_or_skip()
    assert _episode_digest(None) == _episode_digest(
        [ACT_CODE["tanh"], ACT_CODE["tanh"], ACT_CODE["linear"]])


# ---- the distillation student, on every activation ---------------------------
#
# ml/tests/test_distill.py already proves the backward pass against finite
# differences — for tanh. The activation derivative is exactly the line that had
# to change (it was a hard-coded 1-y^2), so it gets the same treatment for the
# rest of the set.

@pytest.mark.parametrize("name", ["tanh", "relu", "leaky_relu"])
def test_student_backprop_matches_finite_differences_per_activation(name):
    from ml.training import distill
    from ml.training.policy_net import EMB_DIM, HEAD_DIM, OBS_DIM

    rng = np.random.default_rng(5)
    st = distill.Student((6, 5), seed=2, arch=Arch(hidden=(6, 5), activation=name))
    # Offset away from 0: relu's kink is not differentiable, and a sample that
    # straddles it makes the central difference disagree for a true reason.
    x = rng.normal(size=(4, OBS_DIM + EMB_DIM)) + 0.5
    target = rng.normal(size=(4, HEAD_DIM))

    def loss_of() -> float:
        y, _ = st.forward(x)
        return float(np.mean((y - target) ** 2))

    y, acts = st.forward(x)
    dy = 2.0 * (y - target) / y.size
    d, grads = dy, [None] * len(st.w)
    for i in range(len(st.w) - 1, -1, -1):
        grads[i] = d.T @ acts[i]
        if i > 0:
            d = (d @ st.w[i]) * activation_grad(acts[i], st.acts[i - 1])
    eps = 1e-6
    for (i, r, c) in ((0, 1, 2), (1, 0, 3), (2, 2, 1)):
        st.w[i][r, c] += eps
        up = loss_of()
        st.w[i][r, c] -= 2 * eps
        dn = loss_of()
        st.w[i][r, c] += eps
        assert (up - dn) / (2 * eps) == pytest.approx(grads[i][r, c], rel=1e-4, abs=1e-9)


def test_the_teacher_forwards_whatever_it_was_exported_with(tmp_path):
    """A relu teacher read as a tanh teacher would hand the student perfectly
    consistent labels for the wrong function."""
    from ml.training import distill
    net = PolicyNet(seed=4, arch=resolve("relu"))
    net.ensure_embedding("*")
    path = tmp_path / "teacher.json"
    net.export_game_json(path)
    t = distill.TeacherNet(path)
    assert t.acts == ["relu", "relu", "linear"] and t.activation == "relu"
    obs = np.linspace(-1, 1, 31).astype(np.float32)
    x = np.concatenate([obs, net.embeddings["*"]])[None, :]
    assert np.allclose(t.forward(x)[0], net.forward(obs, "*"), atol=1e-6)


def test_a_teacher_with_an_unknown_activation_is_refused(tmp_path):
    from ml.training import distill
    net = PolicyNet(seed=4)
    net.ensure_embedding("*")
    path = tmp_path / "teacher.json"
    net.export_game_json(path)
    doc = json.loads(path.read_text())
    doc["layers"][0]["act"] = "gelu"
    path.write_text(json.dumps(doc))
    with pytest.raises(SystemExit):
        distill.TeacherNet(path)
