"""Outcome gates for weekly authoring, asset ingest and the C++ data boundary."""
import copy
import json
import struct
import subprocess
from pathlib import Path

import pytest
from PIL import Image

from genforge.living.atlas import bake, rgb_hex
from genforge.living.build import build, compile_effects, verify_bundle
from genforge.living.validation import ROOT, load_validated, source_path, validate
from genforge.living.draft import draft
from genforge.living.generate import generate

RELEASE = ROOT / "genforge/releases/bell_beneath_fen.json"
PROBE = ROOT / "sim/build/libs/dh-server/dh-effect-lab"


@pytest.fixture
def release():
    return json.loads(RELEASE.read_text())


def test_authored_release_has_valid_lore_kits_and_rarity(release):
    assert validate(release) == []
    assert {a["rarity"] for a in release["artifacts"]} == {"legendary","relic","mythic","divine"}


def test_next_week_namespace_is_fully_remapped(release):
    new=draft(release,"second_bell","The Second Bell")
    assert validate(new) == []
    assert "fen_bells." not in json.dumps(new)
    assert new["review"]["status"]=="candidate"
    assert release["pack"]=="fen_bells"


def test_provider_step_is_explicit_grounded_and_has_provenance(release,tmp_path):
    class Backend:
        name="fake";model="test"
        def generate(self,prompt,n):
            assert "WORLD BIBLE" in prompt and "SEASON" in prompt and "Orun" in prompt
            assert n==1
            return [Image.new("RGBA",(128,64))]
    out=generate(release,release["art"][0]["id"],Backend(),tmp_path/"candidate")
    assert json.loads((out/"provenance.json").read_text())["provider"]=="fake"
    with pytest.raises(ValueError,match="output exists"):
        generate(release,release["art"][0]["id"],Backend(),out)


@pytest.mark.parametrize("mutate,expected", [
    (lambda d: d["effects"].append(copy.deepcopy(d["effects"][0])), "duplicate id"),
    (lambda d: d["artifacts"][0].update(lore=d["skills"][0]["id"]), "unresolved lore"),
    (lambda d: d["creatures"][0].update(skills=[d["skills"][0]["id"]]), "kit requires"),
    (lambda d: d["artifacts"][0].update(affix_budget=100), "power ceiling"),
    (lambda d: d["artifacts"][0].update(effects=[]), "effect facets"),
    (lambda d: d["effects"][0].update(consumes=["wet"]), "consumed statuses"),
    (lambda d: d["effects"][0].update(budget=1), "throughput floor"),
    (lambda d: d["effects"][0]["vfx"].update(color="#ffffff"), "outside style palette"),
    (lambda d: d["style"].update(max_particles=1), "particles budget"),
    (lambda d: d["art"][0]["clips"][0].update(frames=[99]), "outside source grid"),
    (lambda d: d["art"][0].update(source="../outside.png"), "escapes repository"),
    (lambda d: d["review"].update(status="approved"), "candidate"),
    (lambda d: d["effects"][0].update(script="run.py"), "Additional properties"),
])
def test_invalid_releases_fail_closed(release, mutate, expected):
    mutate(release)
    assert expected in "\n".join(validate(release))


def test_symlink_sources_cannot_escape(tmp_path):
    (tmp_path / "escape").symlink_to(ROOT / "CLAUDE.md")
    with pytest.raises(ValueError, match="escapes"):
        source_path("escape", tmp_path)


def test_atlas_preserves_alpha_palette_and_timeline(release, tmp_path):
    art, style = release["art"][0], release["style"]
    result = bake(ROOT / art["source"], art, style, tmp_path)
    sheet = Image.open(tmp_path / "albedo.png")
    pixels = list(sheet.getdata())
    assert {p[3] for p in pixels} == {0,255}
    assert {p[:3] for p in pixels if p[3]} <= {rgb_hex(c) for c in style["palette"]}
    assert result["metrics"]["unique_frames"] == 8
    assert result["metrics"]["decoded_bytes"] == sheet.width*sheet.height*4*2
    assert "missing clip: attack" in result["blockers"]
    assert result["clips"][0]["frame_ticks"] == [3]*8
    glow = Image.open(tmp_path / "emissive.png")
    assert all(a[3] >= b[3] for a,b in zip(pixels,glow.getdata()))


def test_nontransparent_sheet_and_empty_frames_rejected(release,tmp_path):
    art,style=release["art"][0],release["style"]
    source=tmp_path / "source.png"
    for color,reason in [((0,0,0,255),"transparent margin"),((0,0,0,0),"empty source")]:
        Image.new("RGBA",(128,64),color).save(source)
        with pytest.raises(ValueError,match=reason):
            bake(source,art,style,tmp_path / "out")


def test_decoded_memory_budget_enforced(release,tmp_path):
    release["style"]["max_atlas_bytes"]=65536
    with pytest.raises(ValueError,match="memory budget"):
        bake(ROOT / release["art"][0]["source"],release["art"][0],release["style"],tmp_path)


def test_reproducible_complete_build_and_corruption_detection(tmp_path):
    a=build(RELEASE,tmp_path / "a")
    b=build(RELEASE,tmp_path / "b")
    assert a.name == b.name
    assert (a/"manifest.json").read_bytes() == (b/"manifest.json").read_bytes()
    assert verify_bundle(a)["publishable"] is False
    assert build(RELEASE,tmp_path / "a") == a
    (b/"unexpected.py").write_text("pass")
    with pytest.raises(ValueError,match="unexpected"):
        verify_bundle(b)
    (a/"effects.bin").write_bytes(b"broken")
    with pytest.raises(ValueError,match="hash mismatch"):
        build(RELEASE,tmp_path / "a")


def test_embedded_content_cannot_break_out_of_script(release,tmp_path):
    release["title"]="</script><script>alert('x')</script>"
    src=tmp_path / "release.json";src.write_text(json.dumps(release))
    result=build(src,tmp_path / "out")
    payload=(result/"review-data.js").read_text()
    assert "</script>" not in payload
    assert "\\u003c" in payload


def test_effect_compilation_is_little_endian_and_sorted(release):
    a,ids=compile_effects(release)
    release["effects"].reverse()
    assert compile_effects(release) == (a,ids)
    assert ids == sorted(ids)
    assert struct.unpack("<4sI",a[:8]) == (b"DHE1",4)
    assert len(a) == 8+4*36


@pytest.mark.skipif(not PROBE.exists(),reason="build sim first for the C++ integration gate")
def test_compiled_release_executes_in_cpp(release,tmp_path):
    program,ids=compile_effects(release)
    path=tmp_path/"effects.bin";path.write_bytes(program)
    result=subprocess.run([str(PROBE),str(path)],capture_output=True,text=True,check=True)
    report=json.loads(result.stdout)
    rows=sorted(release["effects"],key=lambda r:r["id"])
    assert len(report["traces"]) == len(ids)
    for trace,row in zip(report["traces"],rows):
        assert trace["magnitude_permille"] == row["magnitude_permille"]
        assert trace["max_targets"] == row["max_targets"]
        assert trace["cooldown_blocked"] and trace["recursion_blocked"]
    # Malformed headers, truncation, trailing data and operand bounds fail closed.
    invalid=bytearray(program);invalid[8+7*4:8+8*4]=struct.pack("<I",999)
    for bad in (b"FAIL"+program[4:],program[:-1],program+b"x",bytes(invalid)):
        path.write_bytes(bad)
        assert subprocess.run([str(PROBE),str(path)],capture_output=True).returncode != 0
