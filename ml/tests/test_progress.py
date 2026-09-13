"""Progress-feed contract tests (docs/design/25 §2) — arena subprocesses are mocked.

The console tails one JSONL file per trainee, so what matters here is the exact
event vocabulary, field names, ordering and the whole-line/flushed discipline —
not the ES math (test_league covers that).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "ml" / "training"))
sys.path.insert(0, str(ROOT))   # `ml.eval.gate`, the way league.main imports it

import league  # noqa: E402

BUILD = "core.arena.fen_boar_alpha"
FOE = "core.arena.dusk_revenant"


def _result(wins_a=3, wins_b=1, draws=0, hp_a=0.6, hp_b=0.2, episodes=4):
    eps = [{"hp_a": hp_a, "hp_b": hp_b, "winner": "a"} for _ in range(episodes)]
    return {"wins_a": wins_a, "wins_b": wins_b, "draws": draws, "episodes": eps}


def _read(path: Path) -> list[dict]:
    text = path.read_text()
    assert text.endswith("\n")   # flushed whole lines — the tail never tears
    return [json.loads(line) for line in text.splitlines()]


@pytest.fixture
def sandbox(tmp_path, monkeypatch):
    """Registry, weights and the default feed dir in tmp; every arena run is a
    fake whose score varies so best/mean are not degenerate."""
    monkeypatch.setattr(league, "REGISTRY", tmp_path / "registry.json")
    monkeypatch.setattr(league, "WEIGHTS_DIR", tmp_path / "weights")
    monkeypatch.setattr(league, "PROGRESS_DIR", tmp_path / "progress")
    calls: list[tuple[str, str, str]] = []

    def fake_match(a, b, pa, pb, episodes, seed, **kw):
        calls.append((a, b, pb))
        w = len(calls) % 5
        return _result(wins_a=w, wins_b=4 - w)

    monkeypatch.setattr(league, "run_match", fake_match)
    return tmp_path, calls


def test_progress_writer_basics(tmp_path):
    league.Progress(None).emit("start", key="x")   # disabled feed: no file, no error
    assert list(tmp_path.iterdir()) == []
    feed = tmp_path / "deep" / "er" / "k.jsonl"     # the writer creates the directory
    prog = league.Progress(feed)
    prog.emit("start", key="k")
    prog.emit("candidate", g=0, cand=1, fitness=0.5)
    events = _read(feed)
    assert [e["ev"] for e in events] == ["start", "candidate"]
    assert all(isinstance(e["t"], float) for e in events)
    # guard: the exception is reported on the feed and still propagates
    with pytest.raises(RuntimeError, match="arena produced no result"):
        with prog.guard():
            raise RuntimeError("arena produced no result (rc=1)")
    last = _read(feed)[-1]
    assert last["ev"] == "error" and last["message"].startswith("RuntimeError: arena")


def test_train_es_emits_contract_in_order(sandbox):
    tmp, calls = sandbox
    feed = tmp / "p" / "fen_boar.jsonl"
    opponents = [("native", None), ("scripted", FOE)]
    entry = league.train_es("fen_boar", BUILD, generations=2, pop=3, episodes=4,
                            sigma=0.02, lr=0.02, seed=1, opponents=opponents, jobs=2,
                            progress=league.Progress(feed))
    events = _read(feed)
    assert all(isinstance(e["t"], (int, float)) and isinstance(e["ev"], str) for e in events)
    evs = [e["ev"] for e in events]
    assert evs[0] == "start" and evs[-1] == "registered"
    assert set(evs) == {"start", "match", "candidate", "generation", "checkpoint",
                        "registered"}
    # the checkpoint that makes a long run resumable: it lands after the
    # generation whose state it saves, and the LAST one is the final generation,
    # immediately before the net is registered (league.py CHECKPOINT_EVERY)
    ckpts = [e for e in events if e["ev"] == "checkpoint"]
    assert [c["g"] for c in ckpts] == [2], [c["g"] for c in ckpts]
    assert evs[-2] == "checkpoint"
    assert evs.index("checkpoint") > evs.index("generation")

    start = events[0]
    assert start["key"] == "fen_boar" and start["build"] == BUILD
    assert (start["generations"], start["pop"], start["episodes"], start["jobs"]) == (2, 3, 4, 2)
    assert start["opponents"] == [[BUILD, "native"], [FOE, "scripted"]]   # [build, policy]
    assert start["warm_start"] is None

    matches = [e for e in events if e["ev"] == "match"]
    assert len(matches) == 2 * 3 * 2 == len(calls)   # generations x pop x opponents
    for m in matches:
        assert set(m) >= {"g", "cand", "opp", "wins_a", "wins_b", "draws", "score", "duration_s"}
        assert m["score"] == m["wins_a"] / 4 and 0.0 <= m["score"] <= 1.0
        assert m["duration_s"] >= 0.0
    assert {m["opp"] for m in matches} == {BUILD, FOE}
    assert {(m["g"], m["cand"]) for m in matches} == {(g, i) for g in range(2) for i in range(3)}

    cands = [e for e in events if e["ev"] == "candidate"]
    assert [(c["g"], c["cand"]) for c in cands] == [(g, i) for g in range(2) for i in range(3)]
    assert all(isinstance(c["fitness"], float) for c in cands)
    gens = [e for e in events if e["ev"] == "generation"]
    assert [x["g"] for x in gens] == [0, 1]
    assert all(x["best"] >= x["mean"] for x in gens)

    def where(ev: str, g: int) -> list[int]:
        return [i for i, e in enumerate(events) if e["ev"] == ev and e["g"] == g]

    # inside a generation: all matches, then all candidates, then the summary;
    # the summary precedes the next generation's first match
    for g in range(2):
        assert max(where("match", g)) < min(where("candidate", g))
        assert max(where("candidate", g)) < where("generation", g)[0]
    assert where("generation", 0)[0] < min(where("match", 1))

    reg = events[-1]
    assert reg["version"] == 1 == entry["version"]
    assert reg["npz"] == entry["npz"] and reg["npz"].endswith("fen_boar_v1.npz")


def test_warm_start_and_append_only(sandbox):
    tmp, _ = sandbox
    feed = tmp / "fen_boar.jsonl"
    first = league.train_es("fen_boar", BUILD, 1, 2, 2, 0.02, 0.02, 1,
                            [("native", None)], jobs=1, progress=league.Progress(feed))
    reg = league.load_registry()
    reg["policies"][-1]["deployed"] = True   # what a passing gate does
    league.save_registry(reg)
    second = league.train_es("fen_boar", BUILD, 1, 2, 2, 0.02, 0.02, 2,
                             [("native", None)], jobs=1, progress=league.Progress(feed))
    events = _read(feed)
    starts = [e for e in events if e["ev"] == "start"]
    assert [s["warm_start"] for s in starts] == [None, first["version"]]
    assert [e["version"] for e in events if e["ev"] == "registered"] == [1, second["version"]] == [1, 2]


def test_train_global_emits_under_global_key(sandbox):
    tmp, calls = sandbox
    feed = tmp / "global.jsonl"
    league.train_global([BUILD, FOE], generations=1, pop=2, episodes=2, seed=3, jobs=1,
                        progress=league.Progress(feed))
    events = _read(feed)
    start = events[0]
    assert start["ev"] == "start" and start["key"] == "global"
    assert start["build"] == f"{BUILD},{FOE}"
    assert start["opponents"] == [[BUILD, "native"], [FOE, "native"]]
    assert len([e for e in events if e["ev"] == "match"]) == 2 * 2
    assert events[-1]["ev"] == "registered" and events[-1]["version"] == 1
    assert all(a == b for a, b, _ in calls)   # mirror mode: side A wears the foe's build


def test_cli_train_default_feed_path_and_error_event(sandbox, monkeypatch):
    tmp, _ = sandbox
    monkeypatch.setattr(sys, "argv", ["league", "train", "--key", "fen_boar", "--build", BUILD,
                                      "--generations", "1", "--pop", "2", "--episodes", "2"])
    assert league.main() == 0
    feed = tmp / "progress" / "fen_boar.jsonl"   # PROGRESS_DIR/<key>.jsonl
    evs = [e["ev"] for e in _read(feed)]
    assert evs[0] == "start" and evs[-1] == "registered"

    def boom(*a, **k):
        raise RuntimeError("godot not on PATH")

    monkeypatch.setattr(league, "run_match", boom)
    with pytest.raises(RuntimeError):
        league.main()
    events = _read(feed)   # append-only: the crashed run follows the good one
    assert [e["ev"] for e in events].count("start") == 2
    assert events[-1]["ev"] == "error" and "godot not on PATH" in events[-1]["message"]


def test_cli_gate_emits_gate_event(sandbox, monkeypatch):
    tmp, _ = sandbox
    import ml.eval.gate as gate_mod
    monkeypatch.setattr(gate_mod, "run_match", lambda *a, **k: _result())
    reg = league.load_registry()
    league.registry_add(reg, "fen_boar", "species", None)
    league.save_registry(reg)
    feed = tmp / "gate.jsonl"
    monkeypatch.setattr(sys, "argv", ["league", "gate", "--key", "fen_boar", "--build", BUILD,
                                      "--episodes", "4", "--progress-file", str(feed)])
    assert league.main() == 0
    events = _read(feed)
    assert len(events) == 1
    g = events[0]
    assert g["ev"] == "gate" and g["version"] == 1 and g["pass"] is True
    assert g["metrics"]["suite_scripted"]["pass"] is True
    assert all("pass" in check for check in g["metrics"].values())
    assert league.deployed(league.load_registry(), "fen_boar")["version"] == 1


def test_cli_gate_without_candidate_reports_error(sandbox, monkeypatch):
    tmp, _ = sandbox
    feed = tmp / "gate.jsonl"
    monkeypatch.setattr(sys, "argv", ["league", "gate", "--key", "nobody", "--build", BUILD,
                                      "--progress-file", str(feed)])
    assert league.main() == 1
    events = _read(feed)
    assert [e["ev"] for e in events] == ["error"]
    assert "no candidate" in events[0]["message"]
