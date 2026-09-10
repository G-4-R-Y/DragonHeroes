#!/usr/bin/env python3
"""Dragon Heroes content validator — the CI gate for every content pack.

Checks (docs/tech/23):
  1. JSON Schema conformance (content/schemas/) per content type.
  2. ID discipline: id == "<pack>.<type>.<filename>" derived from the file's path.
  3. Global ID uniqueness across all packs.
  4. Referential integrity: every referenced id exists and has the right type;
     stats/damage_types/fields must exist in the core registries.
  5. Canon lints (docs/00-canon.md):
     - creature tier elite/legendary  => 5..10 skills (boss canon §4)
     - duo_partners only on legendary tier, and partners must be legendary
     - capturable creatures must belong to exactly one pet family
     - pet family shared skills stay sparse (schema caps at 4)

Exit code 0 = pack is shippable; 1 = violations printed below.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
SCHEMAS = CONTENT / "schemas"

# folder name -> (schema file, id type token)
TYPE_MAP = {
    "items": ("item_base.schema.json", "item"),
    "affixes": ("affix.schema.json", "affix"),
    "skills": ("skill.schema.json", "skill"),
    "creatures": ("creature.schema.json", "creature"),
    "ai-profiles": ("ai_profile.schema.json", "ai"),
    "classes": ("class.schema.json", "class"),
    "biomes": ("biome.schema.json", "biome"),
    "loot-tables": ("loot_table.schema.json", "loot"),
    "pet-families": ("pet_family.schema.json", "pet_family"),
    "spirits": ("spirit_essence.schema.json", "spirit"),
    "arena": ("arena_build.schema.json", "arena"),
}

errors: list[str] = []


def err(path: Path, msg: str) -> None:
    errors.append(f"{path.relative_to(ROOT)}: {msg}")


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        err(path, f"invalid JSON: {e}")
        return None


def main() -> int:
    try:
        import jsonschema
    except ImportError:
        jsonschema = None
        print("note: python3-jsonschema not installed — schema conformance SKIPPED "
              "(pip install jsonschema)", file=sys.stderr)

    schemas = {name: load_json(SCHEMAS / fname) for name, (fname, _) in TYPE_MAP.items()}

    # ---- pass 1: load every definition, check ids, collect the id universe ----
    defs: dict[str, tuple[Path, str, dict]] = {}  # id -> (path, type_token, data)
    registries: dict[str, dict] = {}

    packs = [p for p in sorted(CONTENT.iterdir())
             if p.is_dir() and p.name != "schemas"]
    for pack_dir in packs:
        pack_name = pack_dir.name if pack_dir.name != "drops" else None
        # drops/ nests one level deeper: drops/<pack>/<type>/
        pack_roots = sorted(pack_dir.iterdir()) if pack_name is None else [pack_dir]
        for pack_root in pack_roots:
            if not pack_root.is_dir():
                continue
            pack = pack_root.name
            for type_dir in sorted(pack_root.iterdir()):
                if not type_dir.is_dir():
                    continue
                if type_dir.name == "registries":
                    for f in sorted(type_dir.glob("*.json")):
                        data = load_json(f)
                        if data is not None:
                            registries[f.stem] = data
                    continue
                if type_dir.name not in TYPE_MAP:
                    err(type_dir, f"unknown content type folder '{type_dir.name}'")
                    continue
                schema_name, token = TYPE_MAP[type_dir.name][0], TYPE_MAP[type_dir.name][1]
                for f in sorted(type_dir.glob("*.json")):
                    data = load_json(f)
                    if data is None:
                        continue
                    expected_id = f"{pack}.{token}.{f.stem}"
                    got = data.get("id")
                    if got != expected_id:
                        err(f, f"id '{got}' != expected '{expected_id}' (path-derived)")
                    if got in defs:
                        err(f, f"duplicate id '{got}' (also in {defs[got][0].relative_to(ROOT)})")
                    if jsonschema and schemas.get(type_dir.name):
                        v = jsonschema.Draft7Validator(schemas[type_dir.name])
                        for e in sorted(v.iter_errors(data), key=str):
                            err(f, f"schema: {e.message} (at {'/'.join(map(str, e.path))})")
                    if isinstance(got, str):
                        defs[got] = (f, token, data)

    ids_of = lambda t: {i for i, (_, tok, _) in defs.items() if tok == t}
    stat_registry = set(registries.get("stats", {}).get("values", []))
    dmg_registry = set(registries.get("damage_types", {}).get("values", []))
    field_registry = set(registries.get("fields", {}).get("values", []))

    def check_ref(path: Path, ref: str, expected: str, what: str) -> None:
        if ref not in defs:
            err(path, f"{what}: '{ref}' does not exist")
        elif defs[ref][1] != expected:
            err(path, f"{what}: '{ref}' is a {defs[ref][1]}, expected {expected}")

    def check_stats(path: Path, mods, what: str) -> None:
        for m in mods or []:
            if stat_registry and m.get("stat") not in stat_registry:
                err(path, f"{what}: stat '{m.get('stat')}' not in core stats registry")

    # ---- pass 2: referential integrity + canon lints ----
    pet_membership: dict[str, list[str]] = {}
    for fid, (path, token, d) in defs.items():
        if token == "creature":
            for s in d.get("skills", []):
                check_ref(path, s, "skill", "creature skill")
            check_ref(path, d.get("ai_profile", ""), "ai", "ai_profile")
            check_ref(path, d.get("loot_table", ""), "loot", "loot_table")
            tier, nskills = d.get("tier"), len(d.get("skills", []))
            if tier in ("elite", "legendary") and nskills < 5:
                err(path, f"boss canon: {tier} tier requires >=5 signature skills, has {nskills}")
            if tier == "legendary" and nskills > 10:
                err(path, f"boss canon: legendary tier allows at most 10 skills, has {nskills}")
            for p in d.get("duo_partners", []):
                check_ref(path, p, "creature", "duo_partner")
                if tier != "legendary":
                    err(path, "duo_partners only allowed on legendary tier (canon §4)")
                elif p in defs and defs[p][2].get("tier") != "legendary":
                    err(path, f"duo_partner '{p}' must be legendary tier")
        elif token == "skill":
            dt = d.get("damage_type")
            if dt and dmg_registry and dt not in dmg_registry:
                err(path, f"damage_type '{dt}' not in registry {sorted(dmg_registry)}")
            fld = d.get("applies_field")
            if fld and field_registry and fld not in field_registry:
                err(path, f"applies_field '{fld}' not in fields registry")
        elif token == "item":
            check_stats(path, d.get("implicit_mods"), "implicit_mods")
        elif token == "affix":
            check_stats(path, d.get("tiers"), "affix tiers")
        elif token == "loot":
            for e in d.get("entries", []):
                ref = e.get("ref")
                if ref:
                    kind_type = {"item": "item", "bestial_skill": "skill",
                                 "spirit_essence": "spirit"}.get(e.get("kind"))
                    if kind_type:
                        check_ref(path, ref, kind_type, f"loot entry ({e.get('kind')})")
        elif token == "biome":
            for c in d.get("creature_set", []):
                check_ref(path, c, "creature", "biome creature_set")
        elif token == "pet_family":
            for s in d.get("family_shared_skills", []):
                check_ref(path, s, "skill", "family_shared_skill")
            for sp in d.get("species", []):
                check_ref(path, sp.get("creature", ""), "creature", "pet species")
                pet_membership.setdefault(sp.get("creature", ""), []).append(fid)
                for s in sp.get("signature_skills", []):
                    check_ref(path, s, "skill", "species signature_skill")
        elif token == "ai":
            for b in d.get("behaviors", []):
                if b.get("skill"):
                    check_ref(path, b["skill"], "skill", "ai use_skill")
        elif token == "class":
            nodes = {n.get("node") for n in d.get("skill_tree", [])}
            for n in d.get("skill_tree", []):
                if n.get("grants_skill"):
                    check_ref(path, n["grants_skill"], "skill", "skill_tree grants_skill")
                for r in n.get("requires", []):
                    if r not in nodes:
                        err(path, f"skill_tree node '{n.get('node')}' requires unknown node '{r}'")
                if n.get("kind") == "modifier" and n.get("modifies") not in nodes:
                    err(path, f"modifier node '{n.get('node')}' modifies unknown node")
                check_stats(path, n.get("stat_mods"), f"node '{n.get('node')}'")

    # capturable creatures need a pet family (pets roll from family pools, canon §3)
    for fid, (path, token, d) in defs.items():
        if token == "creature" and d.get("capturable"):
            fams = pet_membership.get(fid, [])
            if len(fams) != 1:
                err(path, f"capturable creature must belong to exactly one pet family, found {fams or 'none'}")

    if errors:
        print(f"CONTENT VALIDATION FAILED — {len(errors)} problem(s):")
        for e in errors:
            print(f"  ✗ {e}")
        return 1
    print(f"content OK: {len(defs)} definitions across {len(TYPE_MAP)} types, "
          f"{len(registries)} registries, 0 problems")
    return 0


if __name__ == "__main__":
    sys.exit(main())
