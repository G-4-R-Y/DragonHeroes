#!/usr/bin/env python3
"""Compile the reviewed authoring data into C++ tables and a Godot display pack."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import jsonschema
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from genforge.living.build import build, canonical, mask
from genforge.living.validation import load_validated, TAGS, STATUSES


def load_config(path=None):
    def invalid_constant(value):
        raise ValueError(f"Non-finite preview number: {value}")
    config = json.loads((path or ROOT / "genforge/playable/fen_bells.json").read_text(), parse_constant=invalid_constant)
    try:
        jsonschema.validate(config, json.loads((ROOT / "content/schemas/living-preview.schema.json").read_text()))
    except jsonschema.ValidationError as error:
        raise ValueError(f"Playable configuration: {error.message}") from error
    release = load_validated(ROOT / config["release"])
    seen = set()
    for lair in config["lairs"]:
        if lair["id"] in seen:
            raise ValueError("Duplicate lair ID")
        seen.add(lair["id"])
        creature = next((c for c in release["creatures"] if c["id"] == lair["creature"]), None)
        if creature is None:
            raise ValueError("Playable creature reference does not exist")
        if [p["skill"] for p in lair["phases"]] != creature["skills"]:
            raise ValueError("Playable phase order must implement the complete authored creature kit")
        if not set(lair["reward_cycle"]) <= {a["id"] for a in release["artifacts"]}:
            raise ValueError("Lair reward must reference a playable artifact")
    creature = next(c for c in release["creatures"] if c["id"] == config["lairs"][0]["creature"])
    effects = sorted(release["effects"], key=lambda r: r["id"])
    if len(effects) > 8 or len(release["artifacts"]) != 4:
        raise ValueError("Preview v1 supports up to eight effects and four artifact presets")
    if any(e["action"] not in ("echo", "chain", "resource", "ward") for e in effects):
        raise ValueError("Preview host does not implement one of the authored effect actions")
    root_tags = {"hit": ({"melee"}, {"storm"}), "dodge": ({"dodge"},), "pet_hit": ({"pet"},)}
    for effect in effects:
        if not any(set(effect["tags"]) <= tags for tags in root_tags.get(effect["trigger"], ())):
            raise ValueError("Preview host cannot supply an authored effect trigger/tag combination")
        if not set(effect["requires"]) <= {"wet"} or (effect["trigger"] == "dodge" and effect["requires"]):
            raise ValueError("Preview host cannot supply an authored effect status condition")
        if effect["action"] in ("echo", "chain") and effect["trigger"] == "dodge":
            raise ValueError("Preview dodge event has no enemy target for this effect")
        if effect["action"] != "chain" and effect["max_targets"] != 1:
            raise ValueError("Preview non-chain effects require exactly one target")
    return config, release, creature, effects


def stage():
    config, release, creature, effects = load_config()
    review = build(ROOT / config["release"], ROOT / "genforge/candidates/living")
    output = ROOT / "game/living/generated"
    output.mkdir(parents=True, exist_ok=True)
    # One bounded atlas set per authored lair; distinct guardians need no code.
    for index, lair in enumerate(config["lairs"]):
        boss = next(c for c in release["creatures"] if c["id"] == lair["creature"])
        art = boss["art"].split(".")[-1]
        dest = output if index == 0 else output / f"lair_{index}"
        dest.mkdir(parents=True, exist_ok=True)
        for name in ("albedo.png", "emissive.png", "atlas.json"):
            shutil.copyfile(review / "art" / art / name, dest / name)
    texture_bytes = 0
    # Check the largest encounter's working set, with the shared scene textures.
    shared = 0
    for texture in (ROOT/"game/living/shrine.png", ROOT/"game/prototype/art/hero/sheet.png", ROOT/"game/prototype/art/gloamfen_wisp/sheet.png"):
        with Image.open(texture) as image: shared += image.width*image.height*4
    for index in range(len(config["lairs"])):
        dest = output if index == 0 else output / f"lair_{index}"
        size = shared
        for name in ("albedo.png", "emissive.png"):
            with Image.open(dest/name) as image: size += image.width*image.height*4
        texture_bytes = max(texture_bytes, size)
    if texture_bytes > 8*1024*1024:
        raise ValueError("Playable trial exceeds the 8 MiB decoded texture budget")
    content_hash = json.loads((review / "manifest.json").read_text())["content_hash"]
    # Simulation parity is independent of PNG encoder/Pillow versions.
    stamp = int(hashlib.sha256(canonical({"config": config, "release": release})).hexdigest()[:8],16)
    (output / "chapter.json").write_bytes(canonical({"release": release, "playable": config,
        "content_hash": content_hash, "simulation_stamp": stamp, "decoded_texture_bytes": texture_bytes}))
    lines = ["// Generated by tools/stage_living_preview.py; edit the authoring JSON.",
             "#pragma once", "#include <array>", "#include <dh/sim/effects.hpp>", "#include <dh/content/lairs.generated.hpp>",
             "namespace dh::sim::living_data {",
             f"inline constexpr unsigned simulation_stamp = {stamp}u;",
             "using Phase = dh::content::lairs::Phase;",
             f"inline constexpr std::array<EffectDef,{len(effects)}> effects = {{{{"]
    for e in effects:
        lines.append("{EffectTrigger::%s,%d,%d,%d,EffectAction::%s,%d,%d,%d,%d}," % (
            e["trigger"], mask(e["tags"], TAGS), mask(e["requires"], STATUSES),
            mask(e["consumes"], STATUSES), e["action"], e["magnitude_permille"],
            e["cooldown_ticks"], e["max_targets"], e["budget"]))
    lines.append("}};")
    lines.append("inline constexpr std::array<unsigned,%d> visual_ticks = {%s};" % (len(effects), ",".join(
        str(max(1,round(sum(e["vfx"][key] for key in ("anticipation_ms","impact_ms","dissipate_ms"))*30/1000))) for e in effects)))
    ids = [e["id"] for e in effects]
    artifacts = sorted(release["artifacts"], key=lambda a: ["legendary", "relic", "mythic", "divine"].index(a["rarity"]))
    lines.append("inline constexpr std::array<unsigned,4> artifact_masks = {" + ",".join(
        str(sum(1 << ids.index(e) for e in a["effects"])) for a in artifacts) + "};")
    lines.append("inline constexpr std::array<float,4> affixes = {" + ",".join(
        f"{a['affix_budget']}.0f" for a in artifacts) + "};")
    lines.append("inline constexpr auto phases = dh::content::lairs::definitions[0].phases;")
    lines.append("inline constexpr float boss_hp = dh::content::lairs::definitions[0].boss_hp;")
    catalog = ["// Generated by tools/stage_living_preview.py; edit authoring JSON.",
        "#pragma once", "#include <array>", "#include <string_view>",
        "namespace dh::content::lairs {",
        "struct Phase { unsigned verb, windup, recovery; float damage, radius; };",
        "struct Definition { std::string_view id, creature; unsigned salt, region_chunks; float boss_hp; unsigned phase_count; std::array<Phase,8> phases; unsigned reward_count; std::array<unsigned,16> rewards; };",
        "inline constexpr unsigned placement_version=1;",
        f"inline constexpr std::array<Definition,{len(config['lairs'])}> definitions = {{{{"]
    for lair in config["lairs"]:
        catalog.append('{"%s","%s",%d,%d,%.6ff,%d,{{' % (lair["id"], lair["creature"], lair["placement_salt"], lair["region_chunks"], lair["boss_hp"], len(lair["phases"])))
        for p in lair["phases"]:
            verb = ["pools", "storm", "leap", "sweep", "ward"].index(p["verb"])
            catalog.append("{%d,%d,%d,%.6ff,%.6ff}," % (verb,p["windup"],p["recovery"],p["damage"],p["radius"]))
        rewards = [str(next(i for i,a in enumerate(artifacts) if a["id"] == item)) for item in lair["reward_cycle"]]
        catalog.append("}},%d,{%s}}," % (len(rewards), ",".join(rewards)))
    catalog.append("}};")
    catalog.append("inline constexpr std::array<std::string_view,4> artifact_ids = {" + ",".join(json.dumps(a["id"]) for a in artifacts) + "};")
    for key,value in config["rush"].items():
        catalog.append(f"inline constexpr float rush_{key} = {float(value):.6f}f;")
    catalog.append("} // namespace dh::content::lairs\n")
    (ROOT / "sim/libs/dh-content/include/dh/content/lairs.generated.hpp").write_text("\n".join(catalog))
    for key in ("hunter_hp", "move_speed", "base_damage", "affix_damage_per_point"):
        lines.append(f"inline constexpr float {key} = {float(config[key]):.6f}f;")
    lines.append("} // namespace dh::sim::living_data\n")
    (ROOT / "sim/libs/dh-sim/include/dh/sim/living_content.generated.hpp").write_text("\n".join(lines))
    print(f"PLAYABLE CONTENT OK: {creature['name']}, {len(config['lairs'])} lairs, 4 artifacts; {review}")
    return review


if __name__ == "__main__":
    stage()
