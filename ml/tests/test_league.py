"""League/registry/gate unit tests — arena subprocesses are mocked."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "training"))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "eval"))

import league  # noqa: E402
import gate  # noqa: E402
from gate import run_gate  # noqa: E402


def _result(wins_a=3, wins_b=1, draws=0, hp_a=0.6, hp_b=0.2, episodes=4):
    eps = [{"hp_a": hp_a, "hp_b": hp_b, "winner": "a"} for _ in range(episodes)]
    return {"wins_a": wins_a, "wins_b": wins_b, "draws": draws, "episodes": eps}


def test_fitness_rewards_winning_and_margin():
    strong = league.fitness(_result(wins_a=4, hp_a=0.8, hp_b=0.1))
    weak = league.fitness(_result(wins_a=1, wins_b=3, hp_a=0.2, hp_b=0.7))
    assert strong > weak
    assert strong > 1.0  # win rate 1.0 + positive margin shaping


def test_registry_lifecycle(tmp_path, monkeypatch):
    monkeypatch.setattr(league, "REGISTRY", tmp_path / "registry.json")
    monkeypatch.setattr(league, "WEIGHTS_DIR", tmp_path / "weights")
    reg = league.load_registry()
    assert reg["schema"] == "arena.registry.v1"
    e1 = league.registry_add(reg, "fen_boar", "species", None)
    e1["deployed"] = True
    e2 = league.registry_add(reg, "fen_boar", "species", "v1")
    assert e2["version"] == 2 and e2["parent"] == "v1"
    assert league.deployed(reg, "fen_boar")["version"] == 1
    league.save_registry(reg)
    back = league.load_registry()
    assert len(back["policies"]) == 2


def test_gate_passes_strong_candidate(monkeypatch, tmp_path):
    monkeypatch.setattr(league, "EPISODES_DIR", tmp_path)
    monkeypatch.setattr(gate, "run_match", lambda *a, **k: _result())
    reg = {"policies": []}
    cand = {"key": "fen_boar", "version": 1, "game_json": "x.json",
            "deployed": False, "eval": {}}
    assert run_gate(reg, cand, "core.arena.fen_boar_alpha", episodes=4)
    assert cand["deployed"]
    assert cand["eval"]["checks"]["suite_scripted"]["pass"]


def test_gate_rejects_broken_candidate(monkeypatch, tmp_path):
    monkeypatch.setattr(league, "EPISODES_DIR", tmp_path)
    monkeypatch.setattr(gate, "run_match",
                        lambda *a, **k: _result(wins_a=0, wins_b=4, hp_a=1.0, hp_b=1.0))
    reg = {"policies": []}
    cand = {"key": "fen_boar", "version": 1, "game_json": "x.json",
            "deployed": False, "eval": {}}
    assert not run_gate(reg, cand, "core.arena.fen_boar_alpha", episodes=4)
    assert not cand["deployed"]  # fleet stays on the previous pin (boring by design)


def test_evaluate_candidates_parallel_and_mirror(monkeypatch, tmp_path):
    """Every (candidate x opponent) pair runs once; mirror mode swaps side A."""
    monkeypatch.setattr(league, "WEIGHTS_DIR", tmp_path)
    calls = []

    def fake_match(a, b, pa, pb, episodes, seed, **kw):
        calls.append((a, b, pb))
        return _result()

    monkeypatch.setattr(league, "run_match", fake_match)
    import policy_net
    cands = [policy_net.PolicyNet(seed=i) for i in range(3)]
    for c in cands:
        c.ensure_embedding("*", 0)
    scores = league.evaluate_candidates(
        cands, "core.arena.fen_boar_alpha",
        [("native", None), ("scripted", "core.arena.dusk_revenant")],
        episodes=2, seed=1, jobs=4)
    assert len(scores) == 3
    assert len(calls) == 3 * 2            # every candidate x every opponent
    assert all(s > 0 for s in scores)
    # mirror mode: side A follows the opponent's build (global net plays AS it)
    calls.clear()
    league.evaluate_candidates(
        cands[:1], "core.arena.fen_boar_alpha",
        [("native", "core.arena.dusk_revenant")],
        episodes=2, seed=1, jobs=2, mirror=True)
    assert calls[0][0] == "core.arena.dusk_revenant"


# ---- checkpoint / resume ---------------------------------------------------------
# Ricardo, 2026-09-13: a 1000-generation run was killed at generation 488 with
# nothing on disk, because train_es registers its net only after the loop. The
# contract these tests hold: a resumed run is the run that WOULD have happened,
# not an approximation of it.


def _fake_evaluate(monkeypatch):
    """Deterministic stand-in for the Godot match set: fitness is a fixed
    function of the candidate's weights, so the whole ES loop is reproducible
    without spawning anything."""
    def fake(cands, build, opponents, episodes, seed, jobs, progress=None, g=0,
             speed="max", **kw):
        return [float(c.flat().sum() % 1.0) for c in cands]
    monkeypatch.setattr(league, "evaluate_candidates", fake)


def _train(tmp_path, monkeypatch, generations, resume=False, checkpoint_every=2):
    monkeypatch.setattr(league, "REGISTRY", tmp_path / "registry.json")
    monkeypatch.setattr(league, "WEIGHTS_DIR", tmp_path / "weights")
    _fake_evaluate(monkeypatch)
    return league.train_es("ckpt_key", "core.arena.fen_boar_alpha", generations,
                           pop=4, episodes=1, sigma=0.02, lr=0.02, seed=7,
                           opponents=[("native", None)], jobs=1,
                           checkpoint_every=checkpoint_every, resume=resume)


def test_checkpoint_is_written_and_cleared_on_completion(tmp_path, monkeypatch):
    _train(tmp_path, monkeypatch, generations=4, checkpoint_every=2)
    # a finished search leaves nothing to resume
    assert not league.checkpoint_path("ckpt_key").exists()


def test_resume_reproduces_the_uninterrupted_run(tmp_path, monkeypatch):
    """Six generations straight through must equal three, a KILL, then a resume.

    The kill is simulated where a real one lands: inside the match evaluation,
    after the previous generation checkpointed and before this one finishes, so
    the registration at the end of train_es never happens.
    """
    import numpy as np

    whole = tmp_path / "whole"
    entry = _train(whole, monkeypatch, generations=6, checkpoint_every=3)
    straight = np.load(entry["npz"])

    split = tmp_path / "split"
    monkeypatch.setattr(league, "REGISTRY", split / "registry.json")
    monkeypatch.setattr(league, "WEIGHTS_DIR", split / "weights")

    def fake_then_die(cands, build, opponents, episodes, seed, jobs, progress=None,
                      g=0, speed="max", **kw):
        if g >= 3:
            raise KeyboardInterrupt("simulated kill mid-generation")
        return [float(c.flat().sum() % 1.0) for c in cands]
    monkeypatch.setattr(league, "evaluate_candidates", fake_then_die)
    try:
        league.train_es("ckpt_key", "core.arena.fen_boar_alpha", 6, pop=4, episodes=1,
                        sigma=0.02, lr=0.02, seed=7, opponents=[("native", None)],
                        jobs=1, checkpoint_every=3, resume=False)
        raise AssertionError("the simulated kill did not fire")
    except KeyboardInterrupt:
        pass
    assert league.checkpoint_path("ckpt_key").exists(), "a killed run left no checkpoint"
    state = league.read_checkpoint("ckpt_key")
    assert state["next_g"] == 3 and state["key"] == "ckpt_key"
    assert not (split / "registry.json").exists(), "a killed run must register nothing"

    # ...now resume: generations 3..5 run, 0..2 must not repeat
    seen_gens = []

    def fake_record(cands, build, opponents, episodes, seed, jobs, progress=None,
                    g=0, speed="max", **kw):
        seen_gens.append(g)
        return [float(c.flat().sum() % 1.0) for c in cands]
    monkeypatch.setattr(league, "evaluate_candidates", fake_record)
    entry2 = league.train_es("ckpt_key", "core.arena.fen_boar_alpha", 6, pop=4,
                             episodes=1, sigma=0.02, lr=0.02, seed=7,
                             opponents=[("native", None)], jobs=1,
                             checkpoint_every=3, resume=True)
    assert seen_gens == [3, 4, 5], f"resume re-ran generations {seen_gens}"
    resumed = np.load(entry2["npz"])
    for name in straight.files:
        assert np.array_equal(straight[name], resumed[name]), \
            f"resumed run diverged from the uninterrupted one at '{name}'"


def test_resume_ignores_a_checkpoint_from_a_different_net_shape(tmp_path, monkeypatch):
    _train(tmp_path, monkeypatch, generations=2, checkpoint_every=1)
    # the completed run cleared it; forge a stale one of the wrong size
    import numpy as np
    league.save_checkpoint("ckpt_key", np.zeros(3), next_g=1,
                           rng=np.random.default_rng(0), meta={})
    assert league.load_checkpoint("ckpt_key", theta_size=999, generations=5) is None


def test_resume_declines_a_finished_checkpoint(tmp_path, monkeypatch):
    monkeypatch.setattr(league, "WEIGHTS_DIR", tmp_path / "weights")
    import numpy as np
    rng = np.random.default_rng(1)
    theta = rng.normal(size=8)
    league.save_checkpoint("done_key", theta, next_g=10, rng=rng, meta={})
    assert league.load_checkpoint("done_key", theta_size=8, generations=10) is None
    assert league.load_checkpoint("done_key", theta_size=8, generations=20) is not None


def test_checkpoint_commits_in_a_single_rename(tmp_path, monkeypatch):
    """The torn-write guard: theta and its metadata must land together.

    When they were two files, a kill between the two renames left weights from
    generation N beside metadata claiming N-k, and the resume silently replayed
    work it had already done. One file means the checkpoint is either wholly
    there or wholly absent — so assert nothing else is left beside it.
    """
    import numpy as np
    monkeypatch.setattr(league, "WEIGHTS_DIR", tmp_path / "weights")
    rng = np.random.default_rng(3)
    league.save_checkpoint("solo", rng.normal(size=8), next_g=4, rng=rng, meta={})
    written = sorted(p.name for p in (tmp_path / "weights").iterdir())
    assert written == ["_ckpt_solo.npz"], f"checkpoint is not one file: {written}"
    league.clear_checkpoint("solo")
    assert sorted((tmp_path / "weights").iterdir()) == [], "clearing left a sidecar"
