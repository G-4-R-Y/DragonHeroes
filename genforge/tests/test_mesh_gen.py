"""mesh_gen stage contract tests — stub provider only (no weights in CI)."""

import json
from pathlib import Path

import pytest

from genforge.pipeline.mesh_gen import (MeshRequest, generate,
                                        get_mesh_provider)


@pytest.fixture()
def concept(tmp_path: Path) -> Path:
    img = tmp_path / "concept.png"
    img.write_bytes(b"\x89PNG\r\n\x1a\nfake-for-hashing")
    return img


def test_stub_roundtrip(tmp_path: Path, concept: Path) -> None:
    out = generate(MeshRequest("fen_boar", concept, seed=7), "stub_procedural",
                   candidates_root=tmp_path / "candidates")
    prov = json.loads((out / "provenance.json").read_text())
    assert prov["kind"] == "mesh"
    assert prov["provider"]["name"] == "stub_procedural"
    assert prov["request"]["actor"] == "fen_boar"
    assert prov["request"]["image_sha256"]
    mesh = out / prov["mesh"]
    assert mesh.exists() and mesh.stat().st_size > 500
    head = mesh.read_text().splitlines()
    assert head[0].startswith("# genforge mesh_gen stub")
    assert any(l.startswith("f ") for l in head)


def test_deterministic_candidate_id(tmp_path: Path, concept: Path) -> None:
    req_a = MeshRequest("fen_boar", concept, seed=7)
    req_b = MeshRequest("fen_boar", concept, seed=7)
    assert req_a.digest() == req_b.digest()
    assert req_a.digest() != MeshRequest("fen_boar", concept, seed=8).digest()


def test_unknown_provider_rejected() -> None:
    with pytest.raises(KeyError):
        get_mesh_provider("does-not-exist")


def test_auto_requires_install(monkeypatch: pytest.MonkeyPatch) -> None:
    for var in ("DH_TRIPOSR_DIR", "DH_HUNYUAN3D_DIR", "DH_TRELLIS_DIR"):
        monkeypatch.delenv(var, raising=False)
    with pytest.raises(RuntimeError, match="docs/tech/31"):
        get_mesh_provider("auto")


def test_auto_picks_best_local(monkeypatch: pytest.MonkeyPatch,
                               tmp_path: Path) -> None:
    for var in ("DH_HUNYUAN3D_DIR", "DH_TRELLIS_DIR"):
        monkeypatch.delenv(var, raising=False)
    (tmp_path / "tsr").mkdir()
    monkeypatch.setenv("DH_TRIPOSR_DIR", str(tmp_path / "tsr"))
    assert get_mesh_provider("auto").name == "triposr"
    (tmp_path / "hy").mkdir()
    monkeypatch.setenv("DH_HUNYUAN3D_DIR", str(tmp_path / "hy"))
    assert get_mesh_provider("auto").name == "hunyuan3d"


def test_no_cloud_providers_exist() -> None:
    # Ricardo 2026-09-10: no cloud GPU tiers — the registry must stay local-only
    with pytest.raises(KeyError):
        get_mesh_provider("cloudrun")


# --- PARKED 2026-09-10 (Cloud Run tier, kept not deleted — see mesh_gen.py) --
# def test_auto_prefers_cloudrun(monkeypatch, tmp_path):
#     (tmp_path / "tsr").mkdir()
#     monkeypatch.setenv("DH_TRIPOSR_DIR", str(tmp_path / "tsr"))
#     monkeypatch.setenv("DH_MESH_CLOUDRUN_URL", "https://mesh-x.a.run.app")
#     assert get_mesh_provider("auto").name == "cloudrun"
#
# def test_cloudrun_requires_url(monkeypatch):
#     monkeypatch.delenv("DH_MESH_CLOUDRUN_URL", raising=False)
#     prov = get_mesh_provider("cloudrun")
#     with pytest.raises(RuntimeError, match="DH_MESH_CLOUDRUN_URL"):
#         prov._url()
#
# def test_cloudrun_roundtrip_mocked(monkeypatch, tmp_path, concept):
#     import genforge.pipeline.mesh_gen as mg
#     class FakeResp:
#         headers = {"X-DH-Model": "hunyuan3d-2.1"}
#         def read(self): return b"glTF" + b"\x00" * 2000
#         def __enter__(self): return self
#         def __exit__(self, *a): return False
#     monkeypatch.setenv("DH_MESH_CLOUDRUN_URL", "https://mesh-x.a.run.app")
#     monkeypatch.setattr(mg.CloudRunMeshProvider, "_id_token", lambda self: "tok")
#     monkeypatch.setattr("urllib.request.urlopen", lambda req, timeout: FakeResp())
#     out = generate(MeshRequest("fen_boar", concept, seed=3), "cloudrun",
#                    candidates_root=tmp_path / "candidates")
#     prov = json.loads((out / "provenance.json").read_text())
#     assert prov["provider"]["name"] == "cloudrun"
#     assert (out / "mesh.glb").stat().st_size > 2000
# --- end PARKED ---------------------------------------------------------------


def test_offload_lowers_floor(monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
                              concept: Path) -> None:
    import genforge.pipeline.mesh_gen as mg
    root = tmp_path / "hy"
    (root / ".venv" / "bin").mkdir(parents=True)
    monkeypatch.setenv("DH_HUNYUAN3D_DIR", str(root))
    monkeypatch.setattr(mg, "free_vram_mb", lambda: 5716)
    prov = get_mesh_provider("hunyuan3d")
    # 6 GB card, no offload: refused with the offload/cloud hint
    monkeypatch.delenv("DH_MESH_OFFLOAD", raising=False)
    with pytest.raises(RuntimeError, match="DH_MESH_OFFLOAD"):
        prov.generate_mesh(MeshRequest("fen_boar", concept), tmp_path)
    # offload on: floor drops below 5716 -> passes preflight, fails later on
    # the missing venv python (proves preflight is what moved)
    monkeypatch.setenv("DH_MESH_OFFLOAD", "1")
    with pytest.raises(RuntimeError, match="no venv"):
        prov.generate_mesh(MeshRequest("fen_boar", concept), tmp_path)


def test_vram_gate_message(monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
                           concept: Path) -> None:
    # a fake TRELLIS checkout with a venv, on a 6 GB machine -> refused with
    # a pointer at the rented-GPU tier, BEFORE any subprocess runs
    root = tmp_path / "trellis"
    (root / ".venv" / "bin").mkdir(parents=True)
    (root / ".venv" / "bin" / "python").touch()
    monkeypatch.setenv("DH_TRELLIS_DIR", str(root))
    monkeypatch.setattr("genforge.pipeline.mesh_gen.free_vram_mb", lambda: 5716)
    prov = get_mesh_provider("trellis")
    with pytest.raises(RuntimeError, match="rented-GPU"):
        prov.generate_mesh(MeshRequest("fen_boar", concept), tmp_path)
