"""Provider-agnostic image-generation backend for GenForge.

GenForge's ``PartsProvider`` seam (stub_provider.py) turns a request into a
parts sheet. A *model* provider needs to actually call an image model — this
module is the provider-agnostic seam for THAT call, so OpenAI, Stability, a
local diffusion server, etc. all sit behind one tiny interface and swap by
config with zero pipeline changes (canon directive 4: weekly content, and now
the art that backs it, never requires engine work).

Design rules:
  * ONE interface — ``ImageBackend.generate(prompt, ...) -> [PIL.Image]``.
  * Selection + config is ENV-driven; a key is NEVER hardcoded, logged, or
    committed. ``OPENAI_API_KEY`` is read from the environment at call time.
  * stdlib HTTP only (urllib) — no SDK coupling, so a new backend is one class
    hitting its own REST endpoint. (The `openai` SDK may be installed, but we
    do not depend on it, keeping the seam truly provider-agnostic.)
  * Importing this module NEVER needs a key or network — construction is lazy
    and the key is only required when ``generate`` is actually called.

Add a provider: implement ``ImageBackend`` and register it in ``_BACKENDS``.
"""
from __future__ import annotations

import base64
import io
import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Protocol

from PIL import Image


class ImageGenError(RuntimeError):
    """Any backend failure (missing key, HTTP error, malformed response)."""


class ImageBackend(Protocol):
    """The seam a real image model implements."""

    name: str
    model: str

    def generate(
        self, prompt: str, size: str = "1024x1024", n: int = 1, **opts
    ) -> List[Image.Image]:
        ...


# --------------------------------------------------------------------------
# OpenAI
# --------------------------------------------------------------------------

_OPENAI_URL = "https://api.openai.com/v1/images/generations"
# gpt-image-1 is the current image model (successor to DALL-E 3); it always
# returns base64 and supports a transparent background — ideal for sprites.
_DEFAULT_OPENAI_MODEL = "gpt-image-1"


@dataclass
class OpenAIImageBackend:
    """OpenAI Images API via stdlib HTTP. Key from ``OPENAI_API_KEY`` at call time."""

    model: str = field(default_factory=lambda: os.environ.get(
        "GENFORGE_OPENAI_MODEL", _DEFAULT_OPENAI_MODEL))
    timeout: float = 120.0
    name: str = "openai"

    def _key(self) -> str:
        key = os.environ.get("OPENAI_API_KEY", "").strip()
        if not key:
            raise ImageGenError(
                "OPENAI_API_KEY is not set. Export it in the environment "
                "(never commit it). The provider-agnostic seam is wired; it "
                "only needs the key present at generation time."
            )
        return key

    def _payload(self, prompt: str, size: str, n: int, opts: dict) -> dict:
        body: Dict[str, object] = {"model": self.model, "prompt": prompt,
                                   "size": size, "n": n}
        if self.model.startswith("dall-e"):
            # DALL-E returns a URL unless asked for b64; n must be 1 for dall-e-3
            body["response_format"] = "b64_json"
        else:
            # gpt-image-1: transparent PNG sprites, tunable quality
            body["background"] = opts.get("background", "transparent")
            body["output_format"] = opts.get("output_format", "png")
            if "quality" in opts:
                body["quality"] = opts["quality"]
        return body

    def generate(
        self, prompt: str, size: str = "1024x1024", n: int = 1, **opts
    ) -> List[Image.Image]:
        req = urllib.request.Request(
            _OPENAI_URL,
            data=json.dumps(self._payload(prompt, size, n, opts)).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self._key()}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:500]
            raise ImageGenError(f"OpenAI HTTP {e.code}: {detail}") from e
        except urllib.error.URLError as e:
            raise ImageGenError(f"OpenAI request failed: {e.reason}") from e
        return self._decode(data)

    @staticmethod
    def _decode(data: dict) -> List[Image.Image]:
        items = data.get("data") or []
        if not items:
            raise ImageGenError(f"no image data in response: {str(data)[:300]}")
        images: List[Image.Image] = []
        for item in items:
            b64 = item.get("b64_json")
            if not b64:
                raise ImageGenError("response item has no b64_json payload")
            images.append(Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA"))
        return images


# --------------------------------------------------------------------------
# registry + factory
# --------------------------------------------------------------------------

# Provider-agnostic: register a class here and it is selectable by name/env.
_BACKENDS: Dict[str, type] = {
    "openai": OpenAIImageBackend,
}


def available_backends() -> List[str]:
    return sorted(_BACKENDS)


def get_image_backend(name: Optional[str] = None, **cfg) -> ImageBackend:
    """Construct the configured backend.

    Precedence: explicit ``name`` arg > ``GENFORGE_IMAGE_BACKEND`` env >
    the default ('openai'). Construction is lazy — no key or network here.
    """
    resolved = (name or os.environ.get("GENFORGE_IMAGE_BACKEND", "openai")).lower()
    cls = _BACKENDS.get(resolved)
    if cls is None:
        raise ImageGenError(
            f"unknown image backend '{resolved}'; available: {available_backends()}"
        )
    return cls(**cfg)
