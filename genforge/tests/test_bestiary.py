"""Validation of the generated bestiary catalogs + the generator itself.

Checks the checked-in catalogs (content/generated/, canonical, plus the
game/prototype/data/ snapshots the prototype loads): entry counts, id/name
uniqueness, schema fields and ranges, kit skill referential integrity
against content/core/skills/, tint parsability, art-bundle references
against the baked bundles in game/prototype/art/, and generator determinism.

Run from the repo root:
    python3 -m pytest genforge/tests/test_bestiary.py -v
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from genforge.pipeline import bestiary_gen  # noqa: E402

GENERATED_DIR = REPO_ROOT / "content" / "generated"
GAME_DATA_DIR = REPO_ROOT / "game" / "prototype" / "data"
GAME_ART_DIR = REPO_ROOT / "game" / "prototype" / "art"
SKILLS_DIR = REPO_ROOT / "content" / "core" / "skills"

ELEMENTS = {"physical", "fire", "frost", "storm", "venom", "umbral", "blood"}
ARCHETYPES = {"stalker", "lunger", "brute", "wisp"}
BASES = {"dragon", "colossus", "hag"}

NORMAL_RANGES = {
    "scale": (0.8, 1.4),
    "hp_mult": (0.7, 1.6),
    "dmg_mult": (0.7, 1.5),
    "speed_mult": (0.8, 1.3),
    "gold_mult": (0.8, 2.0),
}
LEGENDARY_RANGES = {
    "scale": (1.1, 1.6),
    "hp_mult": (2.5, 6.0),
    "dmg_mult": (1.3, 2.2),
}


@pytest.fixture(scope="module")
def normal():
    return json.loads((GENERATED_DIR / "bestiary_normal.json").read_text())


@pytest.fixture(scope="module")
def legendary():
    return json.loads((GENERATED_DIR / "bestiary_legendary.json").read_text())


@pytest.fixture(scope="module")
def skill_ids():
    ids = {}
    for p in SKILLS_DIR.glob("*.json"):
        ids[json.loads(p.read_text())["id"]] = p
    return ids


# ---------------------------------------------------------------------------
# wrapper: version + provenance header
# ---------------------------------------------------------------------------

def _assert_wrapper(doc):
    assert doc["version"] == 1
    prov = doc["provenance"]
    for key in ("generator", "version", "seed", "date"):
        assert key in prov, f"provenance lacks '{key}'"
    assert prov["generator"] == "genforge.pipeline.bestiary_gen"


def test_wrappers(normal, legendary):
    _assert_wrapper(normal)
    _assert_wrapper(legendary)


# ---------------------------------------------------------------------------
# counts + uniqueness
# ---------------------------------------------------------------------------

def test_counts(normal, legendary):
    assert len(normal["entries"]) == 1000
    assert len(legendary["entries"]) == 100


def test_unique_ids_and_names(normal, legendary):
    entries = normal["entries"] + legendary["entries"]
    ids = [e["id"] for e in entries]
    names = [e["name"] for e in entries]
    assert len(set(ids)) == len(ids), "duplicate ids"
    assert len(set(names)) == len(names), "duplicate names"


# ---------------------------------------------------------------------------
# schema fields + ranges
# ---------------------------------------------------------------------------

def _assert_common(e):
    assert e["id"].startswith("gen.creature."), e["id"]
    assert isinstance(e["name"], str) and e["name"]
    assert e["element"] in ELEMENTS, e["element"]
    assert isinstance(e["lore"], str) and e["lore"]
    tint = e["tint"]
    assert isinstance(tint, str) and len(tint) == 6, tint
    int(tint, 16)  # parses as hex


def test_normal_schema(normal):
    for e in normal["entries"]:
        _assert_common(e)
        assert e["archetype"] in ARCHETYPES, e["archetype"]
        assert isinstance(e["bundle"], str)
        for field, (lo, hi) in NORMAL_RANGES.items():
            assert lo <= e[field] <= hi, f"{e['id']}: {field}={e[field]}"


def test_legendary_schema(legendary):
    for e in legendary["entries"]:
        _assert_common(e)
        assert e["base"] in BASES, e["base"]
        assert isinstance(e["bundle"], str)
        for field, (lo, hi) in LEGENDARY_RANGES.items():
            assert lo <= e[field] <= hi, f"{e['id']}: {field}={e[field]}"


# ---------------------------------------------------------------------------
# kits: 5-10 unique skills, all shipped in content/core/skills/
# ---------------------------------------------------------------------------

def test_legendary_kits(legendary, skill_ids):
    for e in legendary["entries"]:
        kit = e["kit"]
        assert 5 <= len(kit) <= 10, f"{e['id']}: kit size {len(kit)}"
        assert len(set(kit)) == len(kit), f"{e['id']}: duplicate kit skills"
        for sid in kit:
            assert sid in skill_ids, f"{e['id']}: unknown skill '{sid}'"


# ---------------------------------------------------------------------------
# art-bundle references: every named bundle is baked with the anims the
# entry's archetype plays (bundle "" = procedural boss art, spawner tints)
# ---------------------------------------------------------------------------

def _bundle_anims(bundle: str) -> set:
    atlas_path = GAME_ART_DIR / bundle / "atlas.json"
    assert atlas_path.exists(), f"bundle '{bundle}' has no baked atlas"
    return set(json.loads(atlas_path.read_text())["animations"])


def test_normal_bundles_exist(normal):
    for bundle in {e["bundle"] for e in normal["entries"]}:
        assert bundle, "normals always carry an art bundle"
        assert {"idle", "walk", "lunge"} <= _bundle_anims(bundle), bundle


def test_legendary_bundles_exist(legendary):
    for e in legendary["entries"]:
        if e["base"] == "dragon":
            anims = _bundle_anims(e["bundle"])
            assert {"idle", "walk"} <= anims, e["bundle"]
            assert anims & {"attack", "lunge", "fly"}, e["bundle"]
        else:  # colossus/hag ride the prototype's procedural boss art
            assert e["bundle"] == "", e["id"]


def test_normals_use_old_and_new_bodies(normal):
    used = {e["bundle"] for e in normal["entries"]}
    assert {"gloamfen_stalker", "gloamfen_wisp"} <= used, "old bodies unused"
    assert {"serpent", "shade", "golem", "fen_boar", "marsh_drake"} <= used, \
        "new bodies unused"


# ---------------------------------------------------------------------------
# stat correlation: big = slow = tanky holds in aggregate
# ---------------------------------------------------------------------------

def test_size_speed_hp_correlation(normal):
    entries = normal["entries"]
    big = [e for e in entries if e["scale"] >= 1.25]
    small = [e for e in entries if e["scale"] <= 0.95]
    assert big and small

    def avg(rows, key):
        return sum(r[key] for r in rows) / len(rows)

    assert avg(big, "hp_mult") > avg(small, "hp_mult")
    assert avg(big, "speed_mult") < avg(small, "speed_mult")


# ---------------------------------------------------------------------------
# copies: the game/prototype/data snapshots match the canonical catalogs
# ---------------------------------------------------------------------------

def test_game_snapshots_match_canonical():
    for fname in ("bestiary_normal.json", "bestiary_legendary.json"):
        canonical = (GENERATED_DIR / fname).read_text()
        snapshot = (GAME_DATA_DIR / fname).read_text()
        assert canonical == snapshot, f"{fname}: snapshot drifted"


# ---------------------------------------------------------------------------
# generator determinism: same seed -> same catalogs (and the checked-in
# catalogs are exactly seed 2026)
# ---------------------------------------------------------------------------

def test_generator_is_deterministic(normal, legendary):
    seed = normal["provenance"]["seed"]
    a_n, a_l = bestiary_gen.build_catalogs(seed, date="pinned")
    b_n, b_l = bestiary_gen.build_catalogs(seed, date="pinned")
    assert a_n == b_n and a_l == b_l, "same seed produced different catalogs"
    assert a_n["entries"] == normal["entries"], \
        "checked-in normal catalog does not reproduce from its seed"
    assert a_l["entries"] == legendary["entries"], \
        "checked-in legendary catalog does not reproduce from its seed"
