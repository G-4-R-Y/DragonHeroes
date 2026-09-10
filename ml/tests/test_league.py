"""League/registry/gate unit tests — arena subprocesses are mocked."""
from __future__ import annotations

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
