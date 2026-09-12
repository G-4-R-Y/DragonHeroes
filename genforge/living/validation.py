"""Fail-closed candidate validation, including typed references and resource budgets."""
from __future__ import annotations

import json
from pathlib import Path

import jsonschema

ROOT = Path(__file__).resolve().parents[2]
TYPES = {"lore": "lore", "effects": "effect", "skills": "skill",
         "creatures": "creature", "artifacts": "item", "art": "art"}
RARITIES = {"legendary": 1, "relic": 2, "mythic": 3, "divine": 4}
TAGS = ("storm", "melee", "dodge", "pet", "field", "fire", "frost", "umbral")
STATUSES = ("wet", "marked", "ignited", "chilled")
TRIGGERS = ("hit", "dodge", "pet_hit", "field_combo")
ACTIONS = ("echo", "chain", "burst", "resource", "ward")


def source_path(relative: str, root: Path = ROOT) -> Path:
    """Sources must be repository files, never absolute/escaped/symlink escapes."""
    path = (root / relative).resolve()
    if Path(relative).is_absolute() or not path.is_relative_to(root.resolve()):
        raise ValueError(f"source escapes repository: {relative}")
    if not path.is_file():
        raise ValueError(f"source missing: {relative}")
    return path


def validate(data: dict, root: Path = ROOT) -> list[str]:
    schema = json.loads((ROOT / "content/schemas/expansion.schema.json").read_text())
    problems = [f"{'/'.join(map(str, e.path))}: {e.message}"
                for e in jsonschema.Draft7Validator(schema).iter_errors(data)]
    if problems:
        return sorted(problems)
    if not data["style"]["id"].startswith(f"{data['pack']}.style."):
        problems.append("style id must use the release pack.style namespace")
    ids = {}
    for group, kind in TYPES.items():
        for row in data[group]:
            fid = row["id"]
            if not fid.startswith(f"{data['pack']}.{kind}."):
                problems.append(f"{fid}: expected {data['pack']}.{kind}. namespace")
            if fid in ids:
                problems.append(f"duplicate id: {fid}")
            ids[fid] = (kind, row)

    def ref(owner, fid, kind=None):
        if fid not in ids or (kind and ids[fid][0] != kind):
            problems.append(f"{owner}: unresolved {kind or 'content'} reference {fid}")

    for group in ("skills", "creatures", "artifacts"):
        for row in data[group]:
            ref(row["id"], row["lore"], "lore")
            for field, kind in (("effects", "effect"), ("skills", "skill"),
                                ("synergy_skills", "skill")):
                for fid in row.get(field, []):
                    ref(row["id"], fid, kind)
    for row in data["lore"]:
        for fid in row["links"]:
            ref(row["id"], fid)
    for row in data["creatures"]:
        ref(row["id"], row["art"], "art")
        minimum = 3 if row["tier"] == "normal" else 5
        if not minimum <= len(row["skills"]) <= 10:
            problems.append(f"{row['id']}: kit requires {minimum}..10 distinct skills")
        roles = {ids[f][1]["role"] for f in row["skills"] if f in ids and ids[f][0] == "skill"}
        if not {"setup", "payoff"} <= roles:
            problems.append(f"{row['id']}: needs a setup and payoff")
    palette = {s.lower() for s in data["style"]["palette"]}
    if not {s.lower() for s in data["style"]["emissive_colors"]} <= palette:
        problems.append("emissive colors must be in the style palette")
    for row in data["effects"]:
        if not set(row["consumes"]) <= set(row["requires"]):
            problems.append(f"{row['id']}: consumed statuses must be required")
        if row["vfx"]["color"].lower() not in palette:
            problems.append(f"{row['id']}: VFX color outside style palette")
        # Conservative throughput proxy, NOT proof of combat balance.
        floor = max(1, (row["magnitude_permille"] * row["max_targets"] * 30
                        + row["cooldown_ticks"] * 50 - 1) // (row["cooldown_ticks"] * 50))
        if row["budget"] < floor:
            problems.append(f"{row['id']}: effect budget below throughput floor {floor}")
    for row in data["artifacts"]:
        if len(row["effects"]) != RARITIES[row["rarity"]]:
            problems.append(f"{row['id']}: {row['rarity']} requires {RARITIES[row['rarity']]} effect facets")
        fx = [ids[f][1] for f in row["effects"] if f in ids and ids[f][0] == "effect"]
        if row["affix_budget"] + sum(f["budget"] for f in fx) > 100:
            problems.append(f"{row['id']}: exceeds shared 100-point slot power ceiling")
        for field, limit in (("particles", "max_particles"), ("lights", "max_lights")):
            if sum(f["vfx"][field] for f in fx) > data["style"][limit]:
                problems.append(f"{row['id']}: exceeds {field} budget")
    paths = [data["bible"], data["season"]]
    if data.get("keyframe"):
        paths.append(data["keyframe"])
    for art in data["art"]:
        paths += [art["source"], art["prompt"]]
        names = [clip["name"] for clip in art["clips"]]
        if len(names) != len(set(names)):
            problems.append(f"{art['id']}: duplicate animation name")
        cells = art["grid"][0] * art["grid"][1]
        for clip in art["clips"]:
            if max(clip["frames"]) >= cells:
                problems.append(f"{art['id']}: frame outside source grid")
    for path in paths:
        try:
            source_path(path, root)
        except ValueError as e:
            problems.append(str(e))
    return sorted(problems)


def load_validated(path: Path, root: Path = ROOT) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    problems = validate(data, root)
    if problems:
        raise ValueError("\n".join(problems))
    return data
