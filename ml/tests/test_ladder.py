"""The global rank (ml/training/ladder.py).

Ricardo, 2026-09-14: "and a global rank for the all vs all, where every model
net compete for the top in a balance fight".

The word that carries the weight is BALANCE. `league round-robin` fights
deployed nets across DIFFERENT builds, which ranks the creature; a ranking of
nets has to hold the body fixed. So the things worth gating here are not the
arithmetic but the fairness invariants:

    both sides always play the same build, and
    every pairing plays both orientations with different seeds,

plus the two places a table can lie: an unbeaten entrant with no finite
maximum-likelihood strength, and a scoring pass that double-counts a draw.

Every test drives ladder() with a FAKE arena, so none of this needs Godot.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from ml.training import ladder as L  # noqa: E402
from ml.training import league  # noqa: E402


def entrant(name: str, policy: str | None = None) -> dict:
    return {"id": name, "key": name.split("@")[0], "version": 1, "label": name,
            "policy": policy or f"/tmp/{name}.json", "deployed": False}


class FakeArena:
    """Records every match and decides them by a fixed strength order.

    The strength is read off the POLICY, never the side, so a ladder that forgot
    to swap orientations would still pass on wins — and fail the recorded-calls
    assertions instead, which is the point.
    """

    def __init__(self, strength: dict[str, int]):
        self.strength = strength
        self.calls: list[dict] = []

    def __call__(self, a: str, b: str, policy_a: str, policy_b: str, episodes: int,
                 seed: int, **kw) -> dict:
        self.calls.append({"a": a, "b": b, "policy_a": policy_a,
                           "policy_b": policy_b, "episodes": episodes, "seed": seed})
        sa = self.strength.get(policy_a, 0)
        sb = self.strength.get(policy_b, 0)
        eps = []
        wins_a = wins_b = draws = 0
        for _ in range(episodes):
            if sa > sb:
                wins_a += 1
                eps.append({"hp_a": 1.0, "hp_b": 0.0})
            elif sb > sa:
                wins_b += 1
                eps.append({"hp_a": 0.0, "hp_b": 1.0})
            else:
                draws += 1
                eps.append({"hp_a": 0.5, "hp_b": 0.5})
        return {"wins_a": wins_a, "wins_b": wins_b, "draws": draws, "episodes": eps}


@pytest.fixture
def arena(monkeypatch):
    def install(strength: dict[str, int]) -> FakeArena:
        fake = FakeArena(strength)
        monkeypatch.setattr(league, "run_match", fake)
        return fake
    return install


def run(entrants, arenas, fake_out, episodes=1, jobs=1):
    return L.ladder(entrants, arenas, episodes=episodes, seed=7, jobs=jobs,
                    speed="max", out_path=fake_out)


# ---- the fairness invariants ------------------------------------------------------


def test_both_sides_always_play_the_same_build(arena, tmp_path):
    fake = arena({"/tmp/a.json": 3, "/tmp/b.json": 2, "/tmp/c.json": 1})
    run([entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json"),
         entrant("c", "/tmp/c.json")], ["core.arena.bog_golem"],
        tmp_path / "v.json")
    assert fake.calls, "no matches were played"
    for c in fake.calls:
        assert c["a"] == c["b"] == "core.arena.bog_golem", (
            "a balance fight must hold the body fixed: the only variable is the "
            f"policy, but this match was {c['a']} vs {c['b']}")


def test_every_pairing_plays_both_orientations_with_different_seeds(arena, tmp_path):
    fake = arena({"/tmp/a.json": 2, "/tmp/b.json": 1})
    run([entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json")],
        ["core.arena.bog_golem"], tmp_path / "v.json")
    assert len(fake.calls) == 2
    first, second = fake.calls
    assert (first["policy_a"], first["policy_b"]) == ("/tmp/a.json", "/tmp/b.json")
    assert (second["policy_a"], second["policy_b"]) == ("/tmp/b.json", "/tmp/a.json")
    assert first["seed"] != second["seed"], (
        "a shared seed makes the second orientation the mirror of the first, so "
        "the balance is a tautology")


def test_a_pairing_is_replayed_in_every_arena(arena, tmp_path):
    fake = arena({"/tmp/a.json": 2, "/tmp/b.json": 1})
    v = run([entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json")],
            ["core.arena.bog_golem", "core.arena.fen_boar_alpha"],
            tmp_path / "v.json")
    assert len(fake.calls) == 4
    assert {c["a"] for c in fake.calls} == {"core.arena.bog_golem",
                                            "core.arena.fen_boar_alpha"}
    assert len(v["pairings"]) == 2


# ---- the table --------------------------------------------------------------------


def test_the_strongest_policy_tops_the_table(arena, tmp_path):
    arena({"/tmp/a.json": 3, "/tmp/b.json": 2, "/tmp/c.json": 1})
    v = run([entrant("c", "/tmp/c.json"), entrant("a", "/tmp/a.json"),
             entrant("b", "/tmp/b.json")], ["core.arena.bog_golem"],
            tmp_path / "v.json")
    assert [r["id"] for r in v["table"]] == ["a", "b", "c"]
    assert [r["rank"] for r in v["table"]] == [1, 2, 3]
    assert v["champion"] == "a"
    top, mid, bot = v["table"]
    assert top["points"] == 6 and top["win_rate"] == 1.0      # beat both
    assert mid["points"] == 3
    assert bot["points"] == 0 and bot["win_rate"] == 0.0
    assert top["rating"] > mid["rating"] > bot["rating"]


def test_an_unbeaten_entrant_still_gets_a_finite_rating(arena, tmp_path):
    # Without the phantom prior the MM iteration runs away for an entrant that
    # won everything, and the whole column turns to inf/nan.
    arena({"/tmp/a.json": 9, "/tmp/b.json": 1, "/tmp/c.json": 1})
    v = run([entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json"),
             entrant("c", "/tmp/c.json")], ["core.arena.bog_golem"],
            tmp_path / "v.json")
    for r in v["table"]:
        assert abs(r["rating"]) < 5000.0, r


def test_equal_policies_draw_and_score_a_point_each(arena, tmp_path):
    arena({"/tmp/a.json": 1, "/tmp/b.json": 1})
    v = run([entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json")],
            ["core.arena.bog_golem"], tmp_path / "v.json", episodes=2)
    a, b = v["table"]
    assert a["points"] == b["points"] == 1
    assert a["ep_wins"] == b["ep_wins"] == 0
    assert a["ep_draws"] == b["ep_draws"] == 4          # 2 episodes x 2 orientations
    assert a["win_rate"] == b["win_rate"] == 0.0        # no decided episode
    assert a["rating"] == b["rating"]


def test_hp_margin_follows_the_winner(arena, tmp_path):
    arena({"/tmp/a.json": 2, "/tmp/b.json": 1})
    v = run([entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json")],
            ["core.arena.bog_golem"], tmp_path / "v.json")
    a, b = v["table"]
    assert a["hp_margin"] == pytest.approx(1.0)
    assert b["hp_margin"] == pytest.approx(-1.0)


def test_the_verdict_is_a_readable_record_of_what_was_fought(arena, tmp_path):
    arena({"/tmp/a.json": 2, "/tmp/b.json": 1})
    out = tmp_path / "v.json"
    v = run([entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json")],
            ["core.arena.bog_golem"], out)
    on_disk = json.loads(out.read_text())
    assert on_disk["schema"] == "arena.ladder.v1"
    assert on_disk["arenas"] == ["core.arena.bog_golem"]
    assert on_disk["episodes_per_orientation"] == 1
    assert [e["id"] for e in on_disk["entrants"]] == ["a", "b"]
    assert on_disk["pairings"][0]["arena"] == "core.arena.bog_golem"
    assert on_disk["table"] == v["table"]


def test_jobs_does_not_change_the_table(arena, tmp_path):
    strength = {"/tmp/a.json": 3, "/tmp/b.json": 2, "/tmp/c.json": 1}
    es = [entrant("a", "/tmp/a.json"), entrant("b", "/tmp/b.json"),
          entrant("c", "/tmp/c.json")]
    arena(strength)
    serial = run(es, ["core.arena.bog_golem"], tmp_path / "s.json", jobs=1)
    arena(strength)
    parallel = run(es, ["core.arena.bog_golem"], tmp_path / "p.json", jobs=4)
    assert serial["table"] == parallel["table"]


# ---- Bradley-Terry ----------------------------------------------------------------


def test_ratings_are_order_independent():
    wins = {("a", "b"): 7, ("b", "a"): 3, ("b", "c"): 6, ("c", "b"): 4,
            ("a", "c"): 8, ("c", "a"): 2}
    one = L.bt_ratings(["a", "b", "c"], wins)
    other = L.bt_ratings(["c", "b", "a"], dict(reversed(list(wins.items()))))
    for k in one:
        assert one[k] == pytest.approx(other[k], abs=0.2)
    assert one["a"] > one["b"] > one["c"]


def test_a_pair_that_never_met_still_ranks():
    # a beat b, b beat c, a and c never played — transitivity has to carry it
    wins = {("a", "b"): 9, ("b", "a"): 1, ("b", "c"): 9, ("c", "b"): 1}
    r = L.bt_ratings(["a", "b", "c"], wins)
    assert r["a"] > r["b"] > r["c"]


# ---- entrants and arenas ----------------------------------------------------------


def test_a_net_without_exported_weights_is_skipped_not_fatal(monkeypatch, tmp_path):
    w = tmp_path / "real.json"
    w.write_text("{}")
    monkeypatch.setattr(league, "load_registry", lambda: {"policies": [
        {"key": "k", "version": 1, "game_json": str(w)},
        {"key": "k", "version": 2},                                  # GRU: no export
        {"key": "k", "version": 3, "game_json": str(tmp_path / "gone.json")}]})
    got = L.registry_entrants(None, False)
    assert [e["id"] for e in got] == ["k@v1"]


def test_an_unknown_arena_is_refused_by_name():
    args = L.build_parser(__import__("argparse").ArgumentParser()).parse_args(
        ["--arena", "core.arena.nope"])
    with pytest.raises(SystemExit) as e:
        L.resolve_arenas(args)
    assert "core.arena.nope" in str(e.value)


def test_all_arenas_means_every_creature_build():
    args = L.build_parser(__import__("argparse").ArgumentParser()).parse_args(
        ["--all-arenas"])
    from ml.training.tournament import creature_builds
    assert L.resolve_arenas(args) == [b for _, b in creature_builds()]
