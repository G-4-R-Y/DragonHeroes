"""Provider-agnostic image backend + model provider — all network-free (mocked).

Proves the OpenAI wiring works end-to-end without a key or an API call:
the HTTP layer is monkeypatched, so these run in CI and never spend budget.
"""
from __future__ import annotations

import base64
import io
import json

import pytest
from PIL import Image

from genforge.pipeline import image_backend as ib
from genforge.pipeline.model_provider import ModelPartsProvider, build_prompt
from genforge.pipeline.providers import get_parts_provider
from genforge.pipeline.stub_provider import GenerationRequest, StubPartsProvider


def _fake_png_b64(size=(12, 16)) -> str:
    buf = io.BytesIO()
    Image.new("RGBA", size, (120, 80, 200, 255)).save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


class _FakeResp:
    def __init__(self, payload: dict):
        self._body = json.dumps(payload).encode("utf-8")

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


# --------------------------------------------------------------------------
# OpenAI backend
# --------------------------------------------------------------------------


def test_openai_backend_decodes_b64(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test-not-real")
    captured = {}

    def fake_urlopen(req, timeout=0):
        captured["url"] = req.full_url
        captured["auth"] = req.get_header("Authorization")
        captured["body"] = json.loads(req.data.decode("utf-8"))
        return _FakeResp({"data": [{"b64_json": _fake_png_b64((12, 16))}]})

    monkeypatch.setattr(ib.urllib.request, "urlopen", fake_urlopen)
    imgs = ib.OpenAIImageBackend(model="gpt-image-1").generate("a dragon", size="1024x1024")

    assert len(imgs) == 1 and imgs[0].size == (12, 16)
    assert captured["url"] == ib._OPENAI_URL
    assert captured["auth"] == "Bearer sk-test-not-real"
    assert captured["body"]["model"] == "gpt-image-1"
    assert captured["body"]["background"] == "transparent"   # sprite-friendly
    assert "response_format" not in captured["body"]          # gpt-image-1 quirk


def test_dalle_model_requests_b64_format(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    captured = {}

    def fake_urlopen(req, timeout=0):
        captured["body"] = json.loads(req.data.decode("utf-8"))
        return _FakeResp({"data": [{"b64_json": _fake_png_b64()}]})

    monkeypatch.setattr(ib.urllib.request, "urlopen", fake_urlopen)
    ib.OpenAIImageBackend(model="dall-e-3").generate("x")
    assert captured["body"]["response_format"] == "b64_json"


def test_missing_key_raises(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    with pytest.raises(ib.ImageGenError, match="OPENAI_API_KEY"):
        ib.OpenAIImageBackend().generate("x")


def test_http_error_surfaces(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")

    def boom(req, timeout=0):
        raise ib.urllib.error.HTTPError(ib._OPENAI_URL, 429, "Too Many Requests",
                                        {}, io.BytesIO(b'{"error":"rate"}'))

    monkeypatch.setattr(ib.urllib.request, "urlopen", boom)
    with pytest.raises(ib.ImageGenError, match="HTTP 429"):
        ib.OpenAIImageBackend().generate("x")


# --------------------------------------------------------------------------
# factory selection
# --------------------------------------------------------------------------


def test_backend_factory(monkeypatch):
    assert isinstance(ib.get_image_backend("openai"), ib.OpenAIImageBackend)
    monkeypatch.setenv("GENFORGE_IMAGE_BACKEND", "openai")
    assert isinstance(ib.get_image_backend(), ib.OpenAIImageBackend)
    with pytest.raises(ib.ImageGenError, match="unknown image backend"):
        ib.get_image_backend("stability-xl")


def test_provider_factory(monkeypatch):
    monkeypatch.delenv("GENFORGE_PROVIDER", raising=False)
    assert isinstance(get_parts_provider(), StubPartsProvider)        # safe default
    assert type(get_parts_provider("model")).__name__ == "ModelPartsProvider"
    with pytest.raises(ValueError, match="unknown GENFORGE_PROVIDER"):
        get_parts_provider("nope")


# --------------------------------------------------------------------------
# model provider end-to-end (fake backend — no network)
# --------------------------------------------------------------------------


class _FakeBackend:
    name = "fake"
    model = "fake-1"

    def generate(self, prompt, size="1024x1024", n=1, **opts):
        return [Image.new("RGBA", (32, 48), (10, 20, 30, 255))]


def test_model_provider_writes_bundle(tmp_path):
    req = GenerationRequest(archetype="dragon", family="Emberwing", tier="legendary",
                            theme_tags=["fire", "gloom"], palette_hints=["ember"])
    bundle = ModelPartsProvider(backend=_FakeBackend()).generate_parts(req, tmp_path)

    assert bundle.sheet_path.exists()
    manifest = json.loads(bundle.manifest_path.read_text())
    assert manifest["sheet_size"] == [32, 48]
    assert list(manifest["parts"]) == ["body"]
    assert manifest["parts"]["body"]["pivot"] == [16.0, 48.0]   # feet
    prov = json.loads((tmp_path / "gen_provenance.json").read_text())
    assert prov["backend"] == "fake" and prov["kind"] == "concept"


def test_prompt_is_style_locked():
    p = build_prompt(GenerationRequest(archetype="humanoid", family="Gloam Mage",
                                       tier="elite", theme_tags=["umbral"]))
    assert "pixel-art" in p and "transparent background" in p
    assert "Gloam Mage" in p and "umbral" in p
