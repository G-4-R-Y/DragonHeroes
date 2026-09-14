"""ml/env/specs.json is GENERATED, and the thing that makes it correct is the
LEVEL it was generated at.

creature.gd::_apply_entry scales a body's hp by 1 + 0.02*(level-1) and its
damage by 1 + 0.01*(level-1), read from Session.level once at spawn. Every
rated arena match pins that level (arena.gd: `Session.level =
_cfg.get("level", 20)`), but game/arena/tools/dump_specs.gd did not, so it
dumped level-1 bodies: core.arena.fen_boar_alpha at 339.72 max hp against the
468.8 the arena actually fields — 1.38x the hit points and 1.19x the damage.
dh-env spent every training step against a weaker creature than the gate
grades against, and nothing in the pipeline said so.

These tests are cheap and they are the only thing standing between a re-dump
at the wrong level and another silent divergence.
"""
import json
import pathlib

import pytest

SPECS = pathlib.Path(__file__).resolve().parents[2] / "ml" / "env" / "specs.json"
ARENA_LEVEL = 20        # arena.gd's default `level`, and dump_specs.gd's pin


@pytest.fixture(scope="module")
def doc():
    return json.loads(SPECS.read_text())


def test_specs_record_the_level_they_were_dumped_at(doc):
    assert "level" in doc, (
        "specs.json has no `level`: it predates the fix, or was dumped by a "
        "tool that does not pin Session.level. Re-dump with "
        "game/arena/tools/dump_specs.tscn."
    )
    assert doc["level"] == ARENA_LEVEL, (
        f"specs.json was dumped at level {doc['level']} but rated matches are "
        f"fought at {ARENA_LEVEL} (arena.gd). Every hp and damage number in it "
        f"is wrong by 1 + 0.02*(level-1) / 1 + 0.01*(level-1)."
    )


def test_specs_are_not_hand_edited(doc):
    assert doc.get("schema") == "arena.specs.v1"
    assert "GENERATED" in doc.get("note", "")


def test_every_build_carries_the_fields_dh_env_reads(doc):
    needed = {"max_hp", "damage", "move_speed", "attack_reach", "attack_cd",
              "body_radius", "special_cd", "dodge_max", "is_player",
              "is_ranged", "kits"}
    assert doc["builds"], "no builds in specs.json"
    for build_id, spec in doc["builds"].items():
        missing = needed - set(spec)
        assert not missing, f"{build_id} is missing {sorted(missing)}"
        assert spec["max_hp"] > 0.0 and spec["damage"] > 0.0, build_id


def test_the_level_scaling_is_visible_in_a_known_build(doc):
    """A regression canary with a number in it, not just a schema check.

    fen_boar_alpha is the deployed pin and the build every parity run uses.
    At level 1 its body is 339.72 max hp; at the arena's level 20 it is 468.81.
    If this ever reads ~339 again, the dump lost its level pin.
    """
    boar = doc["builds"].get("core.arena.fen_boar_alpha")
    if boar is None:
        pytest.skip("fen_boar_alpha is not in the catalog any more")
    assert boar["max_hp"] > 400.0, (
        f"fen_boar_alpha at {boar['max_hp']:.2f} max hp — that is the level-1 "
        f"body (339.72), not the level-{ARENA_LEVEL} one the arena fields."
    )
