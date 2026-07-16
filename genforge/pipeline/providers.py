"""PartsProvider selection — one factory, env-driven, provider-agnostic.

``GENFORGE_PROVIDER`` picks the parts provider:
  * 'stub' (DEFAULT) — procedural Pillow art, zero API calls, zero cost.
  * 'model' / 'genai' — the real image-model provider (model_provider.py),
    which uses the image backend chosen by ``GENFORGE_IMAGE_BACKEND`` (default
    'openai'). Never the default, so nothing spends API budget by accident.

Adding a provider is one entry here — the pipeline, service, and bakers all
call ``get_parts_provider()`` and stay unchanged (canon directive 4).
"""
from __future__ import annotations

import os
from typing import Optional

from .stub_provider import StubPartsProvider


def get_parts_provider(name: Optional[str] = None):
    resolved = (name or os.environ.get("GENFORGE_PROVIDER", "stub")).lower()
    if resolved in ("stub", "procedural"):
        return StubPartsProvider()
    if resolved in ("model", "genai", "openai", "ai"):
        # Imported lazily so the stub path never imports the model machinery.
        from .model_provider import ModelPartsProvider
        return ModelPartsProvider()
    raise ValueError(
        f"unknown GENFORGE_PROVIDER '{resolved}'; use 'stub' or 'model'"
    )
