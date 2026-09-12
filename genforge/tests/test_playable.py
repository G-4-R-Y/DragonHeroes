"""Authoring failures must stop a playable export, rather than silently lose skills."""
import copy
import json
import pytest
from tools import stage_living_preview as preview


def write_config(tmp_path, mutate):
    config = json.loads((preview.ROOT / "genforge/playable/fen_bells.json").read_text())
    mutate(config)
    path = tmp_path / "preview.json"
    path.write_text(json.dumps(config))
    return path


def test_missing_boss_phase_cannot_be_exported(tmp_path):
    path = write_config(tmp_path, lambda config: config["phases"].pop())
    with pytest.raises(ValueError, match="complete authored creature kit"):
        preview.load_config(path)


@pytest.mark.parametrize("value", [float("nan"), float("inf"), -1, 10001])
def test_invalid_combat_number_stops_export(tmp_path, value):
    path = write_config(tmp_path, lambda config: config.update(boss_hp=value))
    with pytest.raises(ValueError):
        preview.load_config(path)


def test_unimplemented_effect_is_not_advertised_as_playable(monkeypatch):
    _, release, _, _ = preview.load_config()
    modified = copy.deepcopy(release)
    modified["effects"][0]["action"] = "burst"
    monkeypatch.setattr(preview, "load_validated", lambda path: modified)
    with pytest.raises(ValueError, match="does not implement"):
        preview.load_config()


def test_unresolved_creature_stops_export(tmp_path):
    path = write_config(tmp_path, lambda config: config.update(creature="fen_bells.creature.missing"))
    with pytest.raises(ValueError, match="does not exist"):
        preview.load_config(path)


@pytest.mark.parametrize("patch", [
    {"trigger": "field_combo"}, {"tags": ["frost"]}, {"tags": ["storm", "melee"]},
    {"requires": ["marked"]}, {"max_targets": 2}
])
def test_unsupplied_combat_conditions_stop_export(monkeypatch, patch):
    _, release, _, _ = preview.load_config()
    modified = copy.deepcopy(release)
    modified["effects"][0].update(patch)
    monkeypatch.setattr(preview, "load_validated", lambda path: modified)
    with pytest.raises(ValueError, match="Preview"):
        preview.load_config()
