"""The resident arena worker pool (league.py `--serve`).

The dangerous parts of a process pool are not the happy path: they are a worker
that hangs, a worker that dies mid-match, and workers that outlive the run. A
leaked worker here is a headless Godot holding a CPU core until the box reboots,
competing with whatever else is training. So those are tested against a FAKE
engine that speaks the same stdin/stdout protocol — fast, and it runs everywhere
even without Godot installed.

The real "a reused engine gives identical fights" check needs Godot and several
minutes of real matches, so it is gated behind DH_ARENA_IT=1:

    DH_ARENA_IT=1 python3 -m pytest ml/tests/test_arena_pool.py -q
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from ml.training import league  # noqa: E402

FAKE = '''
import json, os, sys
print("ARENA SERVE READY", flush=True)
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    req = json.loads(line)
    if req.get("quit"):
        break
    if req.get("hang"):
        while True:
            __import__("time").sleep(3600)
    out = req["out"]
    json.dump({"a": req.get("a", ""), "b": req.get("b", ""), "wins_a": 1, "wins_b": 0,
               "draws": 0, "pid": os.getpid(),
               "episodes": [{"hp_a": 1.0, "hp_b": 0.0, "duration_s": 1.0}]}, open(out, "w"))
    print("ARENA SERVE DONE " + out, flush=True)
'''


@pytest.fixture
def fake_cmd(tmp_path):
    f = tmp_path / "fake_arena.py"
    f.write_text(FAKE)
    return [sys.executable, "-u", str(f)]


@pytest.fixture(autouse=True)
def _clean_pool():
    league.shutdown_arena_pool()
    yield
    league.shutdown_arena_pool()


def test_one_worker_serves_many_matches_in_the_same_process(fake_cmd, tmp_path):
    """The whole point: the engine boots once and is reused."""
    w = league._ArenaWorker(fake_cmd)
    pids = []
    for i in range(3):
        out = tmp_path / f"r{i}.json"
        w.run({"a": "x", "b": "y", "out": str(out)}, timeout=30)
        pids.append(json.loads(out.read_text())["pid"])
    w.close()
    assert len(set(pids)) == 1, f"a new process per match defeats the pool: {pids}"
    assert pids[0] == w.proc.pid


def test_a_hung_worker_times_out_instead_of_wedging_the_sweep(fake_cmd, tmp_path):
    """readline() has no timeout — if the reader thread were not there, this
    would hang forever and take a multi-day sweep with it."""
    w = league._ArenaWorker(fake_cmd)
    t0 = time.monotonic()
    with pytest.raises(TimeoutError):
        w.run({"hang": True, "out": str(tmp_path / "never.json")}, timeout=1.5)
    assert time.monotonic() - t0 < 20, "the timeout did not fire promptly"
    league._pool_drop(w)
    assert w.proc.poll() is not None, "a dropped worker must not survive"


def test_a_dead_worker_is_reported_not_silently_retried(fake_cmd, tmp_path):
    w = league._ArenaWorker(fake_cmd)
    w.proc.kill()
    w.proc.wait(timeout=10)
    with pytest.raises((RuntimeError, TimeoutError, BrokenPipeError, OSError)):
        w.run({"a": "x", "out": str(tmp_path / "dead.json")}, timeout=10)
    league._pool_drop(w)


def test_shutdown_kills_every_resident_worker(fake_cmd):
    ws = [league._pool_take(fake_cmd[:-1] + [fake_cmd[-1]]) for _ in range(3)]
    for w in ws:
        league._POOL.put(w)
    assert all(w.proc.poll() is None for w in ws)
    league.shutdown_arena_pool()
    for w in ws:
        w.proc.wait(timeout=15)
        assert w.proc.poll() is not None, "a worker outlived shutdown — that leaks a CPU core"
    assert league._POOL.empty() and not league._POOL_LIVE


def test_pool_can_be_switched_off(monkeypatch):
    monkeypatch.setenv("DH_ARENA_POOL", "0")
    assert not league.pool_enabled()
    monkeypatch.setenv("DH_ARENA_POOL", "1")
    assert league.pool_enabled()
    monkeypatch.delenv("DH_ARENA_POOL", raising=False)
    assert league.pool_enabled(), "the pool is on by default"


@pytest.mark.skipif(not os.environ.get("DH_ARENA_IT") or not shutil.which("godot"),
                    reason="needs Godot and DH_ARENA_IT=1 (runs real matches, minutes)")
def test_a_served_match_equals_a_fresh_process(tmp_path):
    """State leaking between matches is the real risk. Send the SAME matchup
    first and last, with another in between, and demand the one-shot result."""
    case = ("core.arena.dusk_revenant", "core.arena.gloam_wisp", "scripted", "scripted", 77)
    other = ("core.arena.pyre_justiciar", "core.arena.bog_golem", "scripted", "native", 101)
    os.environ["DH_ARENA_POOL"] = "0"
    ref = league.run_match(*case[:4], 2, case[4], speed="max")
    os.environ["DH_ARENA_POOL"] = "1"
    try:
        first = league.run_match(*case[:4], 2, case[4], speed="max")
        league.run_match(*other[:4], 2, other[4], speed="max")
        last = league.run_match(*case[:4], 2, case[4], speed="max")
    finally:
        league.shutdown_arena_pool()
    assert first == ref, "the first served match already differs from a fresh process"
    assert last == ref, "a later match in the same engine diverged — state is leaking"
