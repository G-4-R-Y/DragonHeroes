"""Offline narrative graph validation and pinned prior-chapter grounding.

No model calls, world mutations, votes or rewards. Candidate political outcomes
are story branches for review; official outcome evidence belongs to dh-server.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import jsonschema

ROOT = Path(__file__).resolve().parents[2]
GROUPS = {"archetypes": "archetype", "threads": "thread", "factions": "faction", "events": "event"}
CONTENT_GROUPS = ("lore", "effects", "skills", "creatures", "artifacts", "art")


def exported_ids(data):
    result = {r["id"]: r for group in CONTENT_GROUPS for r in data[group]}
    for group in GROUPS:
        for row in data["narrative"][group]:
            result[row["id"]] = row
            for outcome in row.get("outcomes", []):
                result[outcome["id"]] = outcome
    return result


def validate_narrative(data, root, validate_release, source_path, ancestors, remaining):
    narrative = data["narrative"]
    schema = json.loads((ROOT / "content/schemas/narrative.schema.json").read_text())
    errors = [f"narrative/{'/'.join(map(str, e.path))}: {e.message}"
              for e in jsonschema.Draft7Validator(schema).iter_errors(narrative)]
    if errors:
        return errors
    local = {r["id"]: r for group in CONTENT_GROUPS for r in data[group]}
    for group, kind in GROUPS.items():
        for row in narrative[group]:
            for entry, token in [(row, kind)] + [(v, "outcome") for v in row.get("outcomes", [])]:
                fid = entry["id"]
                if not fid.startswith(f"{data['pack']}.{token}."):
                    errors.append(f"{fid}: expected local {token} namespace")
                if fid in local:
                    errors.append(f"duplicate narrative id: {fid}")
                local[fid] = entry

    prior_ids, prior_packs = {}, set()
    paths = set()
    for dep in narrative["dependencies"]:
        try:
            if dep["path"] in paths:
                raise ValueError(f"duplicate narrative dependency: {dep['path']}")
            paths.add(dep["path"])
            remaining[0] -= 1
            if remaining[0] < 0:
                raise ValueError("narrative dependency graph exceeds 32 visits")
            path = source_path(dep["path"], root)
            raw = path.read_bytes()
            if hashlib.sha256(raw).hexdigest() != dep["sha256"]:
                raise ValueError(f"narrative dependency hash mismatch: {dep['path']}")
            prior = json.loads(raw)
            issues = validate_release(prior, root, _ancestors=ancestors + (data["pack"],), _remaining=remaining)
            if issues:
                raise ValueError(f"invalid narrative dependency {dep['path']}: {'; '.join(issues)}")
            if prior["pack"] in prior_packs:
                raise ValueError(f"duplicate dependency namespace: {prior['pack']}")
            prior_packs.add(prior["pack"])
            for fid, row in exported_ids(prior).items():
                if fid in local or fid in prior_ids:
                    raise ValueError(f"narrative dependency shadows id: {fid}")
                prior_ids[fid] = row
        except (OSError, ValueError) as exc:
            errors.append(str(exc))

    def ref(fid, owner, kinds=None):
        if fid not in local or (kinds and fid.split(".")[1] not in kinds):
            errors.append(f"{owner}: unresolved local narrative reference {fid}")

    coverage = []
    for archetype in narrative["archetypes"]:
        ref(archetype["lore"], archetype["id"], {"lore"})
        for fid in archetype["creatures"]:
            ref(fid, archetype["id"], {"creature"})
            coverage.append(fid)
    for creature in data["creatures"]:
        if coverage.count(creature["id"]) != 1:
            errors.append(f"{creature['id']}: needs exactly one narrative archetype")
    membership = set()
    for thread in narrative["threads"]:
        for fid in thread["members"]:
            ref(fid, thread["id"])
            membership.add(fid)
    for row in data["creatures"] + data["artifacts"]:
        if row["id"] not in membership:
            errors.append(f"{row['id']}: missing continuing story thread")
    for row in narrative["factions"] + narrative["events"]:
        ref(row["lore"], row["id"], {"lore"})
        for fid in row.get("factions", []):
            ref(fid, row["id"], {"faction"})
    connected_packs = set()
    for link in narrative["links"]:
        ref(link["from"], "narrative link")
        if link["to"] not in local and link["to"] not in prior_ids:
            errors.append(f"unresolved narrative link: {link['to']}")
        if link["from"] == link["to"]:
            errors.append("narrative link cannot explain itself")
        if link["to"] in prior_ids:
            connected_packs.add(link["to"].split(".")[0])
    if prior_packs - connected_packs:
        errors.append("every narrative dependency needs a meaningful cross-release link")
    # One explicit genesis, grounded in the world bible. New templates cannot
    # silently start another disconnected universe by deleting dependencies.
    if data["pack"] != "fen_bells" and not prior_packs:
        errors.append("new chapters need a pinned prior-release narrative dependency")
    return errors


def grounded_dependencies(data, root=ROOT):
    """Read validated pinned story JSON; text never overrides technical contracts."""
    found = {}
    pending = list(data["narrative"]["dependencies"])
    while pending:
        dep = pending.pop()
        if dep["path"] in found:
            continue
        path = (root / dep["path"]).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError("narrative source escapes repository")
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != dep["sha256"]:
            raise ValueError("narrative dependency changed after validation")
        prior = json.loads(raw)
        found[dep["path"]] = prior
        if len(found) > 32:
            raise ValueError("narrative dependency graph exceeds 32 files")
        pending.extend(prior["narrative"]["dependencies"])
    return found
