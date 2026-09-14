"""tools/genforge.py — the create/check/approve counter.

What matters here is not that the commands run; it is that `check` REFUSES the
things that have already slipped through once. The dungeon boss (`bellwether`)
reached the catalog with no provenance file and one of six required clips, and
every existing gate passed it: the schema validated, the bundle digests matched,
the build succeeded. So these tests are written from that failure backwards.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
_spec = importlib.util.spec_from_file_location("genforge_cli", ROOT / "tools" / "genforge.py")
gf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gf)

OK, WARN, BAD = gf.OK, gf.WARN, gf.BAD


def levels(findings, level):
    return [f for f in findings if f[0] == level]


@pytest.fixture
def art(tmp_path, monkeypatch):
    """An art source on disk, plus the release entry that points at it."""
    monkeypatch.setattr(gf, "ROOT", tmp_path)
    folder = tmp_path / "genforge/art_sources/thing"
    folder.mkdir(parents=True)
    (folder / "source.png").write_bytes(b"\x89PNG pretend")
    (folder / "prompt.txt").write_text("a thing, in the style of the thing")
    return folder, {"id": "pack.art.thing",
                    "source": "genforge/art_sources/thing/source.png",
                    "prompt": "genforge/art_sources/thing/prompt.txt"}


def write_provenance(folder: Path, name="provenance-v1.json", *, source=True, prompt=True):
    rec = {"provider": "builtin-imagegen", "model": "tool-managed"}
    if source:
        rec["sha256"] = hashlib.sha256((folder / "source.png").read_bytes()).hexdigest()
    if prompt:
        rec["prompt_sha256"] = hashlib.sha256((folder / "prompt.txt").read_bytes()).hexdigest()
    (folder / name).write_text(json.dumps(rec))


# ---- provenance --------------------------------------------------------------------


def test_no_provenance_is_a_failure_not_a_warning(art):
    """bellwether's exact situation: prompt and image both present, nothing
    tying them together. It must not be possible to call that ok."""
    _, entry = art
    findings = []
    gf.check_art(entry, findings)
    assert levels(findings, BAD), findings
    assert "NO provenance" in levels(findings, BAD)[0][2]


def test_a_verified_source_passes(art):
    folder, entry = art
    write_provenance(folder)
    findings = []
    gf.check_art(entry, findings)
    assert not levels(findings, BAD)
    assert any("verified" in f[2] for f in levels(findings, OK))


def test_an_edited_image_fails_its_recorded_hash(art):
    folder, entry = art
    write_provenance(folder)
    (folder / "source.png").write_bytes(b"\x89PNG something else entirely")
    findings = []
    gf.check_art(entry, findings)
    assert any("sha256 MISMATCH" in f[2] for f in levels(findings, BAD))


def test_an_edited_prompt_fails_too(art):
    """The image is still the generated one, but it no longer matches the prompt
    on disk — the bundle would claim a provenance it cannot reproduce."""
    folder, entry = art
    write_provenance(folder)
    (folder / "prompt.txt").write_text("a completely different thing")
    findings = []
    gf.check_art(entry, findings)
    assert any("prompt_sha256 MISMATCH" in f[2] for f in levels(findings, BAD))


def test_the_unversioned_format_is_accepted_but_flagged(art):
    folder, entry = art
    write_provenance(folder, "provenance.json")
    findings = []
    gf.check_art(entry, findings)
    assert not levels(findings, BAD)
    assert any("unversioned" in f[2] for f in levels(findings, WARN))


def test_a_missing_prompt_sha_is_a_warning(art):
    folder, entry = art
    write_provenance(folder, prompt=False)
    findings = []
    gf.check_art(entry, findings)
    assert not levels(findings, BAD)
    assert any("prompt_sha256" in f[2] for f in levels(findings, WARN))


def test_a_missing_source_file_fails(art):
    folder, entry = art
    (folder / "source.png").unlink()
    findings = []
    gf.check_art(entry, findings)
    assert any("source missing" in f[2] for f in levels(findings, BAD))


# ---- clip coverage -----------------------------------------------------------------


def _bundle_with_clips(tmp_path: Path, names: list[str]) -> Path:
    bundle = tmp_path / "pack-abc123"
    atlas = bundle / "art" / "thing"
    atlas.mkdir(parents=True)
    (atlas / "atlas.json").write_text(json.dumps({"clips": [{"name": n} for n in names]}))
    return bundle


def test_a_boss_with_one_of_six_clips_fails(tmp_path):
    entry = {"id": "pack.art.thing",
             "required_clips": ["idle", "move", "anticipation", "attack", "hit", "death"]}
    findings = []
    gf.check_clips(entry, _bundle_with_clips(tmp_path, ["idle"]), findings)
    bad = levels(findings, BAD)
    assert bad and "1/6 clips" in bad[0][2]
    for missing in ("move", "anticipation", "attack", "hit", "death"):
        assert missing in bad[0][2]


def test_full_clip_coverage_passes(tmp_path):
    entry = {"id": "pack.art.thing", "required_clips": ["idle", "move"]}
    findings = []
    gf.check_clips(entry, _bundle_with_clips(tmp_path, ["idle", "move", "extra"]), findings)
    assert not levels(findings, BAD)


def test_clips_are_unchecked_without_a_bundle(tmp_path):
    entry = {"id": "pack.art.thing", "required_clips": ["idle", "move"]}
    findings = []
    gf.check_clips(entry, None, findings)
    assert not levels(findings, BAD) and levels(findings, WARN)


def test_no_required_clips_means_nothing_to_say(tmp_path):
    findings = []
    gf.check_clips({"id": "pack.art.thing"}, None, findings)
    assert findings == []


# ---- approval ----------------------------------------------------------------------


def test_an_approval_names_the_exact_bundle_it_approved(tmp_path, monkeypatch, capsys):
    """The bundle is immutable and hash-named, so an approval that did not pin
    the hash would silently carry over to a rebuilt, different bundle."""
    bundles = tmp_path / "bundles"
    bundle = bundles / "pack-deadbeef"
    bundle.mkdir(parents=True)
    manifest = {"content_hash": "deadbeef" * 8, "blockers": ["art review pending"],
                "files": {}}
    (bundle / "manifest.json").write_text(json.dumps(manifest))
    monkeypatch.setattr(gf, "BUNDLES", bundles)
    monkeypatch.setattr(gf, "APPROVALS", tmp_path / "approvals")
    monkeypatch.setattr(gf, "ROOT", tmp_path)

    args = type("A", (), {"pack": "pack", "who": "Ricardo", "note": "looked at it"})()
    assert gf._decide(args, "approved") == 0
    record = json.loads((tmp_path / "approvals" / f"{manifest['content_hash']}.json").read_text())
    assert record["content_hash"] == manifest["content_hash"]
    assert record["manifest_sha256"] == gf.sha256(bundle / "manifest.json")
    assert record["blockers_at_decision"] == ["art review pending"]
    assert gf.approval_for(manifest["content_hash"])["decision"] == "approved"


def test_approving_an_unbuilt_pack_is_refused(tmp_path, monkeypatch):
    monkeypatch.setattr(gf, "BUNDLES", tmp_path / "empty")
    args = type("A", (), {"pack": "nope", "who": "Ricardo", "note": ""})()
    assert gf._decide(args, "approved") == 2


# ---- the real catalog --------------------------------------------------------------


def test_the_live_audit_still_catches_the_dungeon_boss():
    """Not a mock: the repository's own fen_bells pack must still fail, because
    bellwether ships one of six clips. If this ever passes, either the boss was
    fixed (delete this test and celebrate) or the check stopped checking.

    HALF OF IT WAS FIXED, 2026-09-13: this test used to assert the PROVENANCE
    gap, and it went red when the other session backfilled provenance-v1.json —
    which is the test doing its job in the good direction. check_art is satisfied
    now; the animation gap is what is left, so that is what this holds."""
    data = json.loads((ROOT / "genforge/releases/bell_beneath_fen.json").read_text())
    bellwether = next(a for a in data["art"] if a["id"].endswith("bellwether"))

    prov: list = []
    gf.check_art(bellwether, prov)
    assert not levels(prov, BAD), \
        f"bellwether's provenance regressed: {levels(prov, BAD)}"

    clips: list = []
    # The built bundle is what says which clips actually baked — the same one the
    # CLI audits, resolved the same way.
    bundle = gf.bundles().get("fen_bells", [None])[0]
    assert bundle is not None, "fen_bells has no built bundle to audit"
    gf.check_clips(bellwether, bundle, clips)
    assert levels(clips, BAD), "bellwether's missing action clips are no longer detected"
    # The six-row sheet exists (source-v2.png) but was rejected for having a
    # painted checkerboard instead of alpha, and nothing has been wired into the
    # release, so the pack still ships idle only.
    assert "1/6" in levels(clips, BAD)[0][2], levels(clips, BAD)
