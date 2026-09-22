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


def test_creature_builds_carry_their_archetype_and_windup(doc):
    """R55 (2026-09-19): the swing's shape is per BODY. creature.gd::
    setup_from_entry reshapes the chassis by the bestiary archetype the build's
    bundle resolves to — lunger (0.22 s windup, pounce from 2.5-5.5 tiles),
    brute (0.55 s windup, 2.2-tile arc-free slam) or the stalker default — and
    dh-env swung every body the same way until the converged nets took 2-3x
    less damage from exactly the lunger/brute natives than in the arena.
    A specs.json without these keys makes ml/env/dh_env.py fall back to the
    stalker swing for everyone, silently. So: never without them again."""
    for build_id, spec in doc["builds"].items():
        if spec.get("kind") != "creature":
            continue
        assert "archetype" in spec and "windup_time" in spec, (
            f"{build_id} has no archetype/windup_time: specs.json predates R55 "
            f"— re-dump with game/arena/tools/dump_specs.gd")
        assert spec["archetype"] in ("stalker", "lunger", "brute"), build_id
        assert 0.1 <= spec["windup_time"] <= 1.0, (build_id, spec["windup_time"])


def test_the_archetype_canaries(doc):
    """Numbers, not just keys. The first bestiary_normal.json entry riding each
    bundle decides the archetype (fighter.gd::_find_entry): marsh_drake ->
    lunger, fen_boar -> brute. If either flips, the arena body changed under
    the trainer — re-dump AND re-run ml.eval.env_parity."""
    drake = doc["builds"].get("core.arena.cinder_drake")
    boar = doc["builds"].get("core.arena.fen_boar_alpha")
    if drake is None or boar is None:
        pytest.skip("canary builds are not in the catalog any more")
    assert drake["archetype"] == "lunger" and abs(drake["windup_time"] - 0.22) < 1e-6
    assert boar["archetype"] == "brute" and abs(boar["windup_time"] - 0.55) < 1e-6


def test_creature_builds_carry_their_elite_affix(doc):
    """R55-b (2026-09-21): the ELITE AFFIX. creature.gd::setup_archetype gives
    an elite one of four, and three of them — Brutal (damage x1.5), Swift
    (move_speed x1.4, attack_cd x0.75), Bulwark (max_hp x1.8) — are stat edits
    dump_specs.gd already reads off the finished body. `Fiery` is the odd one:
    it sets a FLAG, and _strike then follows every landed bite with a second
    packet worth half the swing as a "fire" element string, which proxy.gd
    books as BOLT damage. Four of the six arena creatures wear an affix.

    Without this key dh-env fights a drake that hits for two thirds of what the
    arena's does: measured on the converged net, the arena's native cinder_drake
    landed 58.2 bolt damage per 10 s and dh-env landed 30.9 (tech/39 §2)."""
    for build_id, spec in doc["builds"].items():
        if spec.get("kind") != "creature":
            continue
        assert "fiery" in spec, (
            f"{build_id} has no `fiery`: specs.json predates R55-b — re-dump "
            f"with game/arena/tools/dump_specs.gd")
        assert isinstance(spec["fiery"], bool), build_id


def test_the_fiery_canary(doc):
    """cinder_drake is the arena's one Fiery build (game/arena/data/builds.json).
    If this flips, the affix moved under the trainer — re-dump AND re-run
    ml.eval.env_parity, because half of that body's melee output is this flag."""
    drake = doc["builds"].get("core.arena.cinder_drake")
    if drake is None:
        pytest.skip("cinder_drake is not in the catalog any more")
    assert drake["fiery"] is True
    fiery = [b for b, s in doc["builds"].items() if s.get("fiery")]
    assert fiery == ["core.arena.cinder_drake"], fiery
