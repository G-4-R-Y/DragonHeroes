"""The method tournament (ml/training/tournament.py).

The expensive part of a tournament is training; the part that can be WRONG is
everything around it — which candidate a method contributed, what yardstick each
one was gated against, how the bracket is scored, and which net ends up pinned.
So the trainers and the arena are faked here and the bookkeeping is tested for
real. No Godot, no GPU, no minutes.

The two rules worth stating, because a regression in either is silent:

  1. every candidate is gated against the SAME pre-tournament pin. ml/eval/gate.py
     flips `deployed` on a pass and ladders against "the currently deployed net",
     so gating ES first would make ES the yardstick for PPO.
  2. exactly one entry per key ends up deployed, and it is the bracket winner —
     not "whoever was gated last", which is what the raw gate would leave behind.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from ml.training import league, tournament  # noqa: E402


def _reg(*entries: dict) -> dict:
    return {"schema": "arena.registry.v1", "policies": list(entries)}


def _pol(key: str, version: int, deployed: bool = False,
         game_json: str | None = "x.json") -> dict:
    return {"key": key, "version": version, "deployed": deployed,
            "game_json": game_json, "eval": {}}


# ---- what a method contributed -----------------------------------------------------


def test_entrant_is_the_newest_exportable_net_for_this_key():
    new = [_pol("fen_boar", 3), _pol("fen_boar", 4), _pol("other_key", 9)]
    assert tournament._pick_entrant(new, "fen_boar")["version"] == 4


def test_a_gru_net_is_not_an_entrant():
    """arch=gru and squad nets register with game_json null — the Godot runtime
    is a stateless 31-obs MLP, so they cannot fight in the bracket at all."""
    new = [_pol("fen_boar", 5, game_json=None)]
    assert tournament._pick_entrant(new, "fen_boar") is None


def test_only_entries_absent_before_the_run_count():
    before = tournament._stamp(_reg(_pol("fen_boar", 1)))
    after = _reg(_pol("fen_boar", 1), _pol("fen_boar", 2))
    assert [p["version"] for p in tournament._new_entries(before, after)] == [2]


# ---- the yardstick must not move ---------------------------------------------------


def test_gate_pin_is_snapshotted_and_restored():
    reg = _reg(_pol("k", 1, deployed=True), _pol("k", 2), _pol("k", 3))
    snap = tournament._pin_snapshot(reg, "k")
    reg["policies"][1]["deployed"] = True        # what run_gate does on a pass
    tournament._pin_restore(reg, "k", snap)
    assert [p["deployed"] for p in reg["policies"]] == [True, False, False]


def test_pin_set_leaves_exactly_one_deployed():
    reg = _reg(_pol("k", 1, deployed=True), _pol("k", 2, deployed=True),
               _pol("other", 1, deployed=True))
    tournament._pin_set(reg, "k", 2)
    assert [(p["key"], p["version"], p["deployed"]) for p in reg["policies"]] == [
        ("k", 1, False), ("k", 2, True), ("other", 1, True)]


# ---- roster ------------------------------------------------------------------------


def test_ppo_opponent_rotates_through_the_roster():
    builds = [b for _, b in tournament.creature_builds()]
    assert len(builds) > 1
    for i, b in enumerate(builds):
        assert tournament.default_opp_build(b) == builds[(i + 1) % len(builds)]


def test_unknown_build_falls_back_to_itself():
    assert tournament.default_opp_build("core.arena.nope") == "core.arena.nope"


# ---- methods -----------------------------------------------------------------------


KNOBS = {"generations": 2, "pop": 3, "episodes": 1, "jobs": 4, "seed": 7,
         "speed": "max", "opponents": "", "checkpoint_every": 25,
         "steps": 1000, "envs": 8, "arch": "mlp", "selfplay_every": 4}


def test_es_command_carries_the_knobs():
    cmd = tournament.method_command("es", "k", "b", "ob", KNOBS)
    assert cmd[2:6] == ["-m", "ml.training.league", "train", "--key"]
    assert "--generations" in cmd and cmd[cmd.index("--generations") + 1] == "2"
    assert "--opp-build" not in cmd


def test_ppo_command_needs_the_opponent_build():
    cmd = tournament.method_command("ppo", "k", "b", "ob", KNOBS)
    if cmd is None:
        pytest.skip("ml/.venv absent on this box")
    assert cmd[cmd.index("--opp-build") + 1] == "ob"


def test_a_missing_venv_skips_ppo_instead_of_killing_the_tournament(monkeypatch):
    monkeypatch.setattr(tournament, "VENV_PY", Path("/nonexistent/python"))
    row = tournament.run_method("ppo", "k", "b", "ob", KNOBS, None,
                                league.Progress(None))
    assert row["status"] == "skipped" and "venv" in row["reason"]
    assert "spec" not in row              # nothing to enter into the bracket


def test_an_unknown_method_is_reported_not_raised():
    row = tournament.run_method("telepathy", "k", "b", "ob", KNOBS, None,
                                league.Progress(None))
    assert row["status"] == "skipped" and "telepathy" in row["reason"]


# ---- the tournament itself ---------------------------------------------------------


@pytest.fixture
def staged(tmp_path, monkeypatch):
    """A registry with a deployed v1, two methods that each register a candidate,
    and a fake arena in which PPO beats ES."""
    reg_path = tmp_path / "registry.json"
    reg_path.write_text(json.dumps(_reg(_pol("k", 1, deployed=True))))
    monkeypatch.setattr(league, "REGISTRY", reg_path)
    monkeypatch.setattr(tournament, "BENCH_DIR", tmp_path / "bench")

    made = {"n": 1}

    def fake_run_method(method, key, build, opp_build, knobs, timeout, progress):
        made["n"] += 1
        v = made["n"]
        reg = league.load_registry()
        reg["policies"].append(_pol(key, v, game_json=str(tmp_path / f"{key}_v{v}.json")))
        league.save_registry(reg)
        return {"method": method, "status": "ok", "reason": "", "log": "",
                "train_wall_s": 1.0, "version": v, "spec": f"{key}@v{v}",
                "game_json": str(tmp_path / f"{key}_v{v}.json"),
                "label": f"{method} v{v}"}

    def fake_versus(a_spec, b_spec, *a, **kw):
        # b (ppo, the later version) wins 3-0
        return {"rounds_a": 0, "rounds_b": 3, "rounds_drawn": 0, "winner": "b",
                "episode_win_rate_a": 0.0, "out": str(tmp_path / "vs.json")}

    monkeypatch.setattr(tournament, "run_method", fake_run_method)
    monkeypatch.setattr(league, "versus", fake_versus)
    return tmp_path, reg_path


def test_the_bracket_winner_takes_the_pin(staged, monkeypatch):
    tmp_path, reg_path = staged
    monkeypatch.setattr("ml.eval.gate.run_gate",
                        lambda reg, cand, build, eps=4, seed=99: True)
    v = tournament.tournament("k", "b", ["es", "ppo"], KNOBS, best_of=3,
                              out_path=tmp_path / "verdict.json")
    assert v["winner"] == "ppo" and v["champion"] == "ppo" and v["deployed"]
    assert v["table"][0]["method"] == "ppo" and v["table"][0]["points"] == 3
    assert v["table"][1]["method"] == "es" and v["table"][1]["points"] == 0
    reg = json.loads(reg_path.read_text())
    assert [(p["version"], p["deployed"]) for p in reg["policies"]] == [
        (1, False), (2, False), (3, True)]


def test_every_candidate_is_gated_against_the_same_pin(staged, monkeypatch):
    """The regression this guards: gate ES, ES becomes deployed, then PPO is
    laddered against ES instead of against v1 — two candidates, two yardsticks."""
    tmp_path, _ = staged
    seen: list[int] = []

    def spy_gate(reg, cand, build, eps=4, seed=99):
        dep = [p["version"] for p in reg["policies"] if p.get("deployed")]
        seen.append(dep[0] if dep else 0)
        cand["deployed"] = True                  # exactly what the real gate does
        return True

    monkeypatch.setattr("ml.eval.gate.run_gate", spy_gate)
    tournament.tournament("k", "b", ["es", "ppo"], KNOBS, best_of=3,
                          out_path=tmp_path / "verdict.json")
    assert seen == [1, 1], f"the yardstick moved between gates: {seen}"


def test_a_bracket_winner_that_fails_the_gate_takes_no_pin(staged, monkeypatch):
    tmp_path, reg_path = staged
    monkeypatch.setattr("ml.eval.gate.run_gate",
                        lambda reg, cand, build, eps=4, seed=99: False)
    v = tournament.tournament("k", "b", ["es", "ppo"], KNOBS, best_of=3,
                              out_path=tmp_path / "verdict.json")
    assert v["champion"] == "ppo" and v["winner"] is None and not v["deployed"]
    reg = json.loads(reg_path.read_text())
    assert [p["version"] for p in reg["policies"] if p["deployed"]] == [1]


def test_a_draw_scores_one_point_each(staged, monkeypatch):
    tmp_path, _ = staged
    monkeypatch.setattr(league, "versus", lambda *a, **kw: {
        "rounds_a": 1, "rounds_b": 1, "rounds_drawn": 1, "winner": "draw",
        "episode_win_rate_a": 0.5, "out": ""})
    monkeypatch.setattr("ml.eval.gate.run_gate",
                        lambda reg, cand, build, eps=4, seed=99: True)
    v = tournament.tournament("k", "b", ["es", "ppo"], KNOBS, best_of=3,
                              out_path=tmp_path / "verdict.json")
    assert [r["points"] for r in v["table"]] == [1, 1]
    assert v["winner"] is not None            # a draw still pins one, deterministically


def test_verdict_is_written_and_shaped(staged, monkeypatch):
    tmp_path, _ = staged
    monkeypatch.setattr("ml.eval.gate.run_gate",
                        lambda reg, cand, build, eps=4, seed=99: True)
    out = tmp_path / "verdict.json"
    tournament.tournament("k", "b", ["es", "ppo"], KNOBS, best_of=3, out_path=out)
    v = json.loads(out.read_text())
    assert v["schema"] == "arena.tournament.v1"
    for field in ("key", "build", "methods", "entrants", "bracket", "table",
                  "winner", "champion", "deployed", "knobs", "wall_s"):
        assert field in v, field
