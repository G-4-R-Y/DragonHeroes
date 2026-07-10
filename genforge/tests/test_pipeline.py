"""End-to-end proof of the GenForge v0 pipeline.

Generates the mage and dragon parts sheets with the stub provider, bakes their
animations through the skeleton/pose pipeline, and asserts the output contract
(files, frame counts, frame sizes, atlas metadata, actual pixel motion).

The baked demo bundles land in ``genforge/candidates/demo/`` on purpose —
open ``strips/*.png`` and ``sheet.png`` there to see the results.

Run from the repo root:
    python3 -m pytest genforge/tests/test_pipeline.py -v
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from genforge.pipeline.assemble import Assembler  # noqa: E402
from genforge.pipeline.manifest import PartsManifest  # noqa: E402
from genforge.pipeline.poses import PoseLibrary  # noqa: E402
from genforge.pipeline.skeletons import Skeleton  # noqa: E402
from genforge.pipeline.stub_provider import (  # noqa: E402
    GenerationRequest,
    StubPartsProvider,
)

DEMO_DIR = REPO_ROOT / "genforge" / "candidates" / "demo"

# animation -> (frame_count, fps, loop), straight from the pose libraries
MAGE_ANIMS = {
    "idle": (2, 2.0, True),
    "walk": (4, 6.0, True),
    "attack": (3, 8.0, False),
    "cast": (3, 6.0, False),
}
DRAGON_ANIMS = {
    "fly": (3, 8.0, True),
    "breath": (3, 6.0, False),
    "walk": (4, 6.0, True),
}
MAGE_CANVAS = (128, 128)
DRAGON_CANVAS = (208, 152)


def _bake(archetype: str, entity: str, family: str, hints, out_name: str):
    out = DEMO_DIR / out_name
    provider = StubPartsProvider()
    bundle = provider.generate_parts(
        GenerationRequest(
            archetype=archetype, family=family, entity=entity,
            palette_hints=list(hints),
        ),
        out / "parts",
    )
    skeleton = Skeleton.load(archetype)
    poses = PoseLibrary.load(archetype)
    atlas = Assembler(bundle.manifest, skeleton, poses).bake(out / "baked")
    return bundle, skeleton, atlas, out


@pytest.fixture(scope="module")
def mage():
    return _bake("humanoid", "gloam_mage", "umbral", ["violet", "gold"], "gloam_mage")


@pytest.fixture(scope="module")
def dragon():
    return _bake("dragon", "ember_drake", "emberkin", ["red"], "ember_drake")


# ---------------------------------------------------------------------------
# parts-sheet contract
# ---------------------------------------------------------------------------

def _assert_parts_contract(bundle, skeleton):
    assert bundle.sheet_path.exists(), "parts.png missing"
    assert bundle.manifest_path.exists(), "parts.json missing"
    # loading re-runs JSON-Schema validation + bounds checks
    manifest = PartsManifest.load(bundle.manifest_path)
    sheet = manifest.open_sheet()  # also asserts sheet_size matches the PNG
    assert sheet.mode == "RGBA"
    # every part a skeleton bone draws by default must exist on the sheet
    for bone in skeleton.bones:
        if bone.part is not None:
            assert bone.part in manifest.parts, f"sheet lacks part '{bone.part}'"
    # pivots must sit inside their rects
    for name, region in manifest.parts.items():
        _, _, w, h = region.rect
        px, py = region.pivot
        assert 0 <= px <= w and 0 <= py <= h, f"pivot outside rect for '{name}'"


def test_mage_parts_sheet_contract(mage):
    bundle, skeleton, _, _ = mage
    _assert_parts_contract(bundle, skeleton)
    assert bundle.manifest.entity == "gloam_mage"
    assert bundle.manifest.archetype == "humanoid"


def test_dragon_parts_sheet_contract(dragon):
    bundle, skeleton, _, _ = dragon
    _assert_parts_contract(bundle, skeleton)
    # VFX strip cells exist for the pose-library part overrides
    for cell in ("vfx_breath_0", "vfx_breath_1", "vfx_breath_2"):
        assert cell in bundle.manifest.parts


# ---------------------------------------------------------------------------
# baked strips + atlas
# ---------------------------------------------------------------------------

def _assert_baked(out_dir: Path, atlas: dict, anims: dict, canvas):
    cw, ch = canvas
    assert atlas["frame_size"] == [cw, ch]
    atlas_on_disk = json.loads((out_dir / "baked" / "atlas.json").read_text())
    assert atlas_on_disk["animations"].keys() == atlas["animations"].keys()

    for name, (frames, fps, loop) in anims.items():
        entry = atlas["animations"][name]
        assert entry["frames"] == frames, f"{name}: wrong frame count"
        assert entry["fps"] == fps and entry["loop"] == loop
        strip_path = out_dir / "baked" / entry["strip"]
        assert strip_path.exists(), f"{name}: strip missing"
        strip = Image.open(strip_path)
        assert strip.size == (cw * frames, ch), f"{name}: wrong strip size"

    combined = Image.open(out_dir / "baked" / "sheet.png")
    max_frames = max(f for f, _, _ in anims.values())
    assert combined.size == (cw * max_frames, ch * len(anims))


def test_mage_bakes_idle_walk_attack(mage):
    _, _, atlas, out = mage
    _assert_baked(out, atlas, MAGE_ANIMS, MAGE_CANVAS)


def test_dragon_bakes_fly_breath(dragon):
    _, _, atlas, out = dragon
    _assert_baked(out, atlas, DRAGON_ANIMS, DRAGON_CANVAS)


# ---------------------------------------------------------------------------
# the frames actually contain a posed creature (not empty, not static)
# ---------------------------------------------------------------------------

def _frames_of(strip_path: Path, frame_w: int):
    strip = Image.open(strip_path).convert("RGBA")
    return [
        strip.crop((i * frame_w, 0, (i + 1) * frame_w, strip.height))
        for i in range(strip.width // frame_w)
    ]


def _assert_moving(out_dir: Path, anim: str, frame_w: int, min_pixels: int = 400):
    frames = _frames_of(out_dir / "baked" / "strips" / f"{anim}.png", frame_w)
    for i, frame in enumerate(frames):
        opaque = sum(1 for a in frame.getchannel("A").getdata() if a > 0)
        assert opaque >= min_pixels, f"{anim} frame {i} nearly empty ({opaque}px)"
    stills = {f.tobytes() for f in frames}
    assert len(stills) == len(frames), f"{anim}: found identical frames"


def test_mage_frames_move(mage):
    _, _, _, out = mage
    for anim in ("idle", "walk", "attack", "cast"):
        _assert_moving(out, anim, MAGE_CANVAS[0])


def test_dragon_frames_move(dragon):
    _, _, _, out = dragon
    for anim in ("fly", "breath", "walk"):
        _assert_moving(out, anim, DRAGON_CANVAS[0])


def test_cast_vfx_appears_only_on_keyed_frames(mage):
    """The VFX bone starts hidden; the cast pose unhides it on frames 1–2."""
    bundle, skeleton, _, out = mage
    frames = _frames_of(out / "baked" / "strips" / "cast.png", MAGE_CANVAS[0])
    # frame 0 (windup, vfx hidden) must have fewer opaque pixels than frame 2
    # (release, vfx burst + rays visible)
    def opaque(f):
        return sum(1 for a in f.getchannel("A").getdata() if a > 0)

    assert opaque(frames[2]) > opaque(frames[0])


# ---------------------------------------------------------------------------
# supersample flag
# ---------------------------------------------------------------------------

def test_supersample_bakes_same_geometry(mage, tmp_path):
    bundle, skeleton, _, _ = mage
    poses = PoseLibrary.load("humanoid")
    atlas = Assembler(bundle.manifest, skeleton, poses, supersample=True).bake(
        tmp_path / "ss", ["idle"]
    )
    strip = Image.open(tmp_path / "ss" / "strips" / "idle.png")
    assert strip.size == (MAGE_CANVAS[0] * 2, MAGE_CANVAS[1])


# ---------------------------------------------------------------------------
# pose-library validation
# ---------------------------------------------------------------------------

def test_pose_library_rejects_unknown_bones():
    skeleton = Skeleton.load("humanoid")
    bad = PoseLibrary.from_dict(
        {
            "skeleton": "humanoid",
            "animations": {
                "oops": {"fps": 6, "frames": [{"not_a_bone": {"rotation_deg": 10}}]}
            },
        }
    )
    with pytest.raises(ValueError, match="unknown bone"):
        bad.validate_against(skeleton)


# ---------------------------------------------------------------------------
# service — POST /generate/creature writes a full bundle under candidates/
# ---------------------------------------------------------------------------

def test_service_generate_creature():
    from fastapi.testclient import TestClient

    from genforge.service.app import CANDIDATES_ROOT, GENFORGE_ROOT, app

    client = TestClient(app)

    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["status"] == "ok"

    resp = client.post(
        "/generate/creature",
        json={
            "archetype": "dragon",
            "family": "emberkin",
            "tier": "elite",
            "palette_hints": ["red"],
            "theme_tags": ["cinder"],
        },
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()

    bundle_dir = GENFORGE_ROOT / body["bundle_dir"]
    # the candidate contract: bundles live under genforge/candidates/, only
    assert CANDIDATES_ROOT.resolve() in bundle_dir.resolve().parents

    for key in ("parts_sheet", "parts_manifest", "atlas", "combined_sheet"):
        assert (GENFORGE_ROOT / body["outputs"][key]).exists(), key
    for strip in body["outputs"]["strips"].values():
        assert (GENFORGE_ROOT / strip).exists()

    provenance = json.loads((GENFORGE_ROOT / body["provenance"]).read_text())
    assert provenance["candidate_id"] == body["candidate_id"]
    assert provenance["request"]["archetype"] == "dragon"
    assert provenance["provider"]["name"] == "stub_procedural"
    assert provenance["animations"].keys() == DRAGON_ANIMS.keys()

    assert body["animations"]["fly"]["frames"] == 3
    assert body["animations"]["breath"]["frames"] == 3


def test_service_rejects_unknown_animation_and_leaves_no_partial_bundle():
    from fastapi.testclient import TestClient

    from genforge.service.app import CANDIDATES_ROOT, app

    before = {p.name for p in CANDIDATES_ROOT.iterdir()}
    client = TestClient(app)
    resp = client.post(
        "/generate/creature",
        json={"archetype": "humanoid", "animations": ["moonwalk"]},
    )
    assert resp.status_code == 400
    assert "moonwalk" in resp.json()["detail"]
    after = {p.name for p in CANDIDATES_ROOT.iterdir()}
    assert after == before, "failed request left a partial candidate bundle"
