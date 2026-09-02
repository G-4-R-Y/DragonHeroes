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
