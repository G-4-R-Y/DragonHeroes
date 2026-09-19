"""genforge.hifi — the Dead Cells / Phantom Tower sprite generator, offline.

Pins: the prompt constants to Ricardo's ``sprites prompt.md``; each pillar
stage on a synthetic model-like candidate (checkerboard backdrop, 4x bilinear
mixels, baked halo, outline gap, dithered patch); the scorecard verdicts
(delivered FAIL, shipped PASS, clean sprite PASS raw); the bundle contract
(bundle_art.gd atlas keys, packed emissive in the normal map's blue channel,
provenance schema); and the CLI. No network, no model, no key.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from genforge.hifi import __main__ as cli
from genforge.hifi import alpha, creatures, emissive, fixture, grid, outline, palette, pipeline, spec
from genforge.hifi.normal import unpack_emissive
from genforge.hifi.scorecard import GateConfig, evaluate

ORUN = creatures.get("orun")


@pytest.fixture(scope="module")
def clean() -> np.ndarray:
    return np.asarray(fixture.clean_sprite())


@pytest.fixture(scope="module")
def candidate() -> Image.Image:
    return fixture.model_like_candidate()


@pytest.fixture(scope="module")
def processed(candidate) -> pipeline.ProcessResult:
    return pipeline.process(candidate, ORUN)


# --------------------------------------------------------------------------
# prompt contract
# --------------------------------------------------------------------------

def test_prompt_constants_match_sprites_prompt_md():
    report = spec.verify_against_source()
    assert report["verified"] is True


def test_master_prompt_fills_the_creature_slot_and_keeps_the_style_verbatim():
    ps = ORUN.prompt()
    assert ps.positive.startswith(ORUN.description)
    assert ps.positive.endswith(spec.MASTER_STYLE)
    assert ps.negative == spec.NEGATIVE_PROMPT
    assert "256x256 pixel grid, profile combat stance." in ps.positive


def test_prompt_renders_for_native_and_folded_negatives():
    ps = ORUN.prompt()
    native = ps.render(True)
    assert native == {"prompt": ps.positive, "negative_prompt": ps.negative}
    folded = ps.render(False)
    assert set(folded) == {"prompt"}
    assert ps.positive in folded["prompt"] and ps.negative in folded["prompt"]


def test_stance_and_grid_swap_only_the_named_words():
    ps = spec.build_prompt("x", stance="collapsed on the ground, core dimmed", grid_px=128)
    assert "128x128 pixel grid, collapsed on the ground, core dimmed." in ps.positive
    assert spec.DEFAULT_STANCE not in ps.positive
    assert ps.positive.count("pixel grid") == 2   # the 128 one + "1:1 pixel grid"


def test_every_key_pose_clip_is_a_required_clip():
    assert set(spec.KEY_POSES) == {"idle", "move", "anticipation", "attack", "hit", "death"}
    assert 12 <= sum(len(v) for v in spec.KEY_POSES.values()) <= 16   # pillar 4


def test_creature_registry_covers_the_arena_roster():
    for key in ("orun", "fen_boar", "gloamfen_stalker", "cinder_drake", "bog_golem",
                "mire_serpent", "grave_shade", "gloam_wisp"):
        assert creatures.get(key).grid_px == 256
    with pytest.raises(KeyError):
        creatures.get("nope")


# --------------------------------------------------------------------------
# stages
# --------------------------------------------------------------------------

def test_alpha_clears_a_painted_checkerboard_and_hardens_the_halo(candidate):
    raw = np.asarray(candidate)
    assert alpha.checkerboard_score(raw)["checkerboard"] > 0.9
    out, rep = alpha.enforce(raw)
    assert rep.background_mode == "checkerboard"
    assert rep.cleared_px > 500_000
    band = alpha.border_band(out.shape[:2])
    assert (out[band][:, 3] == 0).all()           # nothing of the checkerboard survives
    assert set(np.unique(out[..., 3])) <= {0, 255}
    assert rep.fringe_px > 0                       # the anti-aliased matte was eaten


def test_grid_estimate_finds_integer_upscales(clean):
    img = Image.fromarray(clean, "RGBA")
    for factor, resample in ((3, Image.NEAREST), (4, Image.NEAREST), (4, Image.BILINEAR), (5, Image.BICUBIC)):
        big = np.asarray(img.resize((256 * factor, 256 * factor), resample))
        est = grid.estimate(big, 256)
        assert est.pitch == factor, (factor, resample, est)
        assert est.phase_x == 0 and est.phase_y == 0
    nn = grid.estimate(np.asarray(img.resize((1024, 1024), Image.NEAREST)), 256)
    assert nn.conformity == 1.0


def test_grid_estimate_survives_a_padded_offset(clean):
    big = np.asarray(Image.fromarray(clean, "RGBA").resize((768, 768), Image.NEAREST))
    padded = np.pad(big, ((5, 3), (2, 6), (0, 0)))
    est = grid.estimate(padded, 256)
    assert est.pitch == 3 and (est.phase_x, est.phase_y) == (2, 2)
    snapped = grid.snap(padded, est)          # extra transparent cells from the padding are fine

    def content(img):
        ys, xs = np.where(img[..., 3] > 0)
        return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

    assert np.array_equal(content(snapped), content(clean))


def test_snap_of_a_nearest_upscale_is_lossless(clean):
    big = np.asarray(Image.fromarray(clean, "RGBA").resize((1024, 1024), Image.NEAREST))
    est = grid.estimate(big, 256)
    assert np.array_equal(grid.snap(big, est), clean)


def test_painted_image_reports_low_conformity():
    cell = np.asarray(Image.open(Path("genforge/art_sources/bellwether/source-v2.png")).convert("RGBA"))[0:384, 0:256]
    est = grid.estimate(alpha.enforce(cell)[0], 256)
    assert est.conformity < 0.2


def test_palette_builds_eight_shade_ramps_with_directional_hue_shift(clean):
    pal = palette.build(clean, palette.PaletteConfig(ramps=6, emissive_hue_deg=195.0))
    assert pal.colors[0] == pal.ink
    assert all(len(r.shades) == 8 for r in pal.ramps)
    assert len(pal.colors) == 1 + 8 * len(pal.ramps) <= 49
    from genforge.hifi.colour import hue_deg, rgb_to_oklab, rgb_of
    for r in pal.ramps:
        if r.chroma > 0:
            lab = rgb_to_oklab(np.array([rgb_of(r.shades[0]), rgb_of(r.shades[-1])], dtype=np.uint8))
            assert lab[0, 0] < lab[1, 0]                       # dark -> light
            assert abs(hue_deg(lab[0:1])[0] - hue_deg(lab[1:2])[0]) % 360 > 3.0   # hue moved
    q, idx, m = palette.quantize(clean, pal)
    assert (idx[clean[..., 3] > 0] >= 0).all() and (idx[clean[..., 3] == 0] == -1).all()
    assert m["mean_oklab_error"] < 0.05


def test_dither_score_and_dedither():
    idx = np.zeros((16, 16), dtype=np.int16)
    idx[4:12, 4:12] = 1
    ys, xs = np.mgrid[4:12, 4:12]
    idx[4:12, 4:12][(ys + xs) % 2 == 0] = 2
    assert palette.dither_score(idx) == pytest.approx(49 / 225, abs=1e-3)   # 7x7 checker windows of 15x15
    fixed, changed = palette.dedither(idx)
    assert changed > 0 and palette.dither_score(fixed) == 0.0


def test_outline_measure_and_repair(clean):
    rep = outline.measure(clean)
    assert rep.coverage == 1.0 and rep.continuous
    broken = clean.copy()
    ring = outline.perimeter_ring(broken[..., 3] > 0)
    ys, xs = np.where(ring)
    sel = ys > 150
    broken[ys[sel], xs[sel], :3] = (160, 140, 110)          # lineless stretch
    rep_b = outline.measure(broken)
    assert rep_b.coverage < 0.9 and rep_b.gaps > 0
    fixed, painted = outline.repair(broken, (14, 12, 22))
    assert painted == rep_b.gaps
    assert outline.measure(fixed).coverage == 1.0


def test_emissive_mask_isolates_the_cyan_core(clean):
    em, mask, intensity, rep = emissive.extract(clean, 195.0)
    assert rep.pixels > 300 and rep.components == 1
    x0, y0, x1, y1 = rep.bbox
    assert 95 <= x0 and x1 <= 135 and 110 <= y0 and y1 <= 155   # where the fixture drew it
    assert (em[mask, 3] == 255).all() and (em[~mask, 3] == 0).all()
    assert intensity[mask].min() >= 0.5 and intensity[mask].max() <= 1.0
    none, nmask, _, nrep = emissive.extract(clean, None)
    assert not nmask.any() and nrep.expected is False


# --------------------------------------------------------------------------
# the gate, end to end
# --------------------------------------------------------------------------

def test_clean_sprite_passes_the_gate_raw(clean):
    sc = evaluate(clean, ORUN, GateConfig())
    assert sc.verdict == "PASS", sc.failures


def test_model_like_candidate_fails_delivered_and_passes_shipped(processed):
    names = {c.name for c in processed.before.checks if c.hard and not c.passed}
    assert {"transparent_bg", "native_grid", "indexed_palette", "ink_hold_perimeter"} <= names
    assert processed.before.verdict == "FAIL"
    assert processed.after.verdict == "PASS", processed.after.failures
    assert processed.after.score > processed.before.score


def test_processed_sprite_is_the_original_recovered(processed, clean):
    a, b = clean[..., 3] > 0, processed.albedo[..., 3] > 0

    def crop(m):
        ys, xs = np.where(m)
        return m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

    A, B = crop(a), crop(b)
    assert A.shape == B.shape
    iou = (A & B).sum() / (A | B).sum()
    assert iou > 0.99, iou
    assert processed.steps["grid"]["pitch"] == 4
    assert processed.steps["alpha"]["background_mode"] == "checkerboard"
    assert processed.steps["outline"]["after"]["coverage"] == 1.0
    assert processed.steps["dedither"]["dither_after"] <= 0.02


def test_normal_map_packs_the_emissive_mask_in_blue(processed):
    n = processed.normal
    e = unpack_emissive(n)
    mask = processed.emissive[..., 3] > 0
    assert (e[mask] >= 0.5).all() and (e[~mask] == 0).all()
    assert (n[~mask & (n[..., 3] > 0), 2] >= 128).all()     # valid normals elsewhere
    assert np.array_equal(n[..., 3], processed.albedo[..., 3])


def test_bundle_contract_and_provenance(tmp_path, processed):
    rep = pipeline.write_bundle(tmp_path, ORUN, [processed], frame_names=["fx"], prompt=ORUN.prompt())
    assert rep["verdict"] == "PASS"
    for name in ("sheet.png", "sheet_n.png", "sheet_e.png", "atlas.json", "palette.json",
                 "scorecard.json", "provenance.json", "prompt.txt", "negative.txt", "review.html"):
        assert (tmp_path / name).exists(), name
    atlas = json.loads((tmp_path / "atlas.json").read_text())
    assert atlas["frame_size"] == [256, 256] and atlas["combined_sheet"] == "sheet.png"
    assert atlas["animations"]["idle"]["frames"] == 1 and atlas["animations"]["idle"]["row"] == 0
    assert atlas["channels"]["emissive_packed_in_normal_blue"] is True
    prov = json.loads((tmp_path / "provenance.json").read_text())
    assert prov["schema"] == "dragon-heroes.art-source.v1"
    assert prov["prompt"]["negative"] == spec.NEGATIVE_PROMPT
    assert prov["status"] == "PASS" and len(prov["outputs"]) == 3
    assert Image.open(tmp_path / "sheet_n.png").size == (256, 256)
    pal = json.loads((tmp_path / "palette.json").read_text())
    assert pal["schema"] == "dragon-heroes.hifi-palette.v1" and pal["colors"][0] == pal["ink"]


def test_generate_uses_the_backend_seam_and_folds_the_negative(tmp_path, candidate):
    calls = {}

    class FakeBackend:
        name, model = "fake", "fake-image-1"

        def generate(self, prompt, size="1024x1024", n=1, **opts):
            calls.update(prompt=prompt, size=size, n=n, opts=opts)
            return [candidate, fixture.model_like_candidate(seed=3)][:n]

    rep = pipeline.generate(ORUN, tmp_path, backend=FakeBackend(), n=2)
    assert spec.NEGATIVE_PROMPT in calls["prompt"] and "negative_prompt" not in calls["opts"]
    assert calls["opts"]["background"] == "transparent"
    assert rep["verdict"] == "PASS" and len(rep["candidates"]) == 2
    prov = json.loads((tmp_path / "provenance.json").read_text())
    assert prov["provider"]["model"] == "fake-image-1" and prov["record_kind"] == "generation-witnessed"
    assert len(prov["raw_inputs"]) == 2


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def test_cli_prompt_and_creatures(capsys):
    assert cli.main(["prompt", "--creature", "orun", "--folded"]) == 0
    out = capsys.readouterr().out
    assert spec.MASTER_STYLE in out and spec.NEGATIVE_PROMPT in out
    assert cli.main(["creatures"]) == 0
    assert "orun" in capsys.readouterr().out


def test_cli_process_and_score(tmp_path, candidate, capsys):
    raw = tmp_path / "raw.png"; candidate.save(raw)
    assert cli.main(["process", str(raw), "--creature", "orun", "--out", str(tmp_path / "b")]) == 0
    out = capsys.readouterr().out
    assert "HIFI BUNDLE PASS" in out
    assert cli.main(["score", str(tmp_path / "b" / "sheet.png"), "--creature", "orun"]) == 0
    assert "verdict PASS" in capsys.readouterr().out
    assert cli.main(["score", str(raw), "--creature", "orun"]) == 1   # delivered image fails raw
