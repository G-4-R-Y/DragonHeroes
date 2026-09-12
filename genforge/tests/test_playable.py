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
    path = write_config(tmp_path, lambda config: config["lairs"][0]["phases"].pop())
    with pytest.raises(ValueError, match="complete authored creature kit"):
        preview.load_config(path)


@pytest.mark.parametrize("value", [float("nan"), float("inf"), -1, 10001])
def test_invalid_combat_number_stops_export(tmp_path, value):
    path = write_config(tmp_path, lambda config: config["lairs"][0].update(boss_hp=value))
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
    path = write_config(tmp_path, lambda config: config["lairs"][0].update(creature="fen_bells.creature.missing"))
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

@pytest.mark.parametrize("mutate, message", [
    (lambda c: c['lairs'].append(copy.deepcopy(c['lairs'][0])), 'Duplicate lair'),
    (lambda c: c['lairs'][0].update(reward_cycle=['missing.item.reward']), 'Lair reward'),
    (lambda c: c['lairs'][0].update(region_chunks=0), 'configuration'),
    (lambda c: c['rush'].update(hp_cap=100), 'configuration'),
])
def test_lair_authoring_rejects_unsafe_content(tmp_path, mutate, message):
    with pytest.raises(ValueError, match=message):
        preview.load_config(write_config(tmp_path, mutate))


def test_additional_lair_uses_existing_kit_without_engine_changes(tmp_path):
    def add(config):
        lair = copy.deepcopy(config['lairs'][0])
        lair.update(id='fen_bells.lair.deep_vigil', name='The Deep Vigil', boss_hp=1900, placement_salt=8884)
        config['lairs'].append(lair)
    config, _, _, _ = preview.load_config(write_config(tmp_path, add))
    assert len(config['lairs']) == 2
