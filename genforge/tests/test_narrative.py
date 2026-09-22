"""Connected weekly stories must survive authoring, validation and local builds."""
import copy
import hashlib
import json
from pathlib import Path

import pytest

from genforge.living.build import brief, build
from genforge.living.draft import draft
from genforge.living.validation import ROOT, validate

RELEASE = ROOT / "genforge/releases/bell_beneath_fen.json"


def original():
    return json.loads(RELEASE.read_text())


def test_next_chapter_preserves_and_grounds_prior_history():
    data = draft(original(), "bronze_caravan", "The bronze beyond the water")
    assert validate(data) == []
    dep = data["narrative"]["dependencies"][0]
    assert dep["sha256"] == hashlib.sha256(RELEASE.read_bytes()).hexdigest()
    request = brief(data, data["art"][0])
    assert "PINNED EARLIER CHAPTERS" in request
    assert "fen_bells.thread.the_returning_vow" in request
    assert "ferry households" in request
    assert "AUTHORING PLACEHOLDER" in request


@pytest.mark.parametrize("mutate,expected", [
    (lambda d: d.pop("narrative"), "required property"),
    (lambda d: d["narrative"]["archetypes"][0].update(creatures=[d["artifacts"][0]["id"]]), "exactly one narrative archetype"),
    (lambda d: d["narrative"]["threads"][0].update(members=[d["creatures"][0]["id"]]), "missing continuing story thread"),
    (lambda d: d["narrative"]["links"][0].update(to="missing.lore.old_story"), "unresolved narrative link"),
    (lambda d: d["narrative"]["events"][0].update(factions=[d["creatures"][0]["id"]]), "unresolved local narrative reference"),
    (lambda d: d["narrative"]["events"][0]["outcomes"][0].update(script="award_gold.py"), "Additional properties"),
    (lambda d: d["narrative"]["threads"].append(copy.deepcopy(d["narrative"]["threads"][0])), "duplicate narrative id"),
])
def test_unconnected_or_executable_lore_is_rejected(mutate, expected):
    data = original()
    mutate(data)
    assert expected in "\n".join(validate(data))


def test_pinned_history_changes_and_unused_dependencies_fail_closed():
    data = draft(original(), "bronze_caravan", "The bronze beyond the water")
    data["narrative"]["dependencies"][0]["sha256"] = "0" * 64
    assert "hash mismatch" in "\n".join(validate(data))
    data = draft(original(), "bronze_caravan", "The bronze beyond the water")
    data["narrative"]["links"].pop()
    assert "meaningful cross-release link" in "\n".join(validate(data))
    data["narrative"]["dependencies"].clear()
    assert "pinned prior-release" in "\n".join(validate(data))


def test_dependency_cycle_and_budget_are_rejected_before_recursive_work():
    data = original()
    assert "dependency cycle" in "\n".join(validate(data, _ancestors=(data["pack"],)))
    data = draft(data, "bronze_caravan", "The bronze beyond the water")
    assert "exceeds 32" in "\n".join(validate(data, _remaining=[0]))


def test_review_build_hashes_pinned_source_and_is_reproducible(tmp_path):
    data = draft(original(), "bronze_caravan", "The bronze beyond the water")
    path = tmp_path / "candidate.json"
    path.write_text(json.dumps(data))
    a = build(path, tmp_path / "a")
    b = build(path, tmp_path / "b")
    assert (a / "manifest.json").read_bytes() == (b / "manifest.json").read_bytes()
    manifest = json.loads((a / "manifest.json").read_text())
    assert manifest["sources"][str(RELEASE.relative_to(ROOT))] == hashlib.sha256(RELEASE.read_bytes()).hexdigest()
    assert manifest["publishable"] is False
