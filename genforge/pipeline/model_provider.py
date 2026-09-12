"""Real gen-AI parts provider — the model-backed ``PartsProvider``.

Sits behind the SAME seam as ``StubPartsProvider`` (stub_provider.py): given a
``GenerationRequest`` it produces a parts sheet PNG + a ``parts.json`` manifest.
The pixels come from a provider-agnostic image backend (image_backend.py, e.g.
OpenAI gpt-image-1); swapping model vendors is one env var, no pipeline change.

SCOPE (v1, honest): a single image model call yields ONE full-figure concept
sprite, so this emits a single ``body`` region (a static/concept bundle usable
as a sprite immediately). Turning a generated figure into a fully SKELETAL,
multi-part animated bundle needs one more step — either (a) prompt the model
onto a FIXED TEMPLATE LAYOUT so parts land in known regions, or (b) a
segmentation pass to carve parts.json — plus a matching skeleton/pose. That is
the documented next step (docs/tech/28 §9), and it connects to the 3D->render
route for animation. The image backend itself is fully general and already
powers any GenForge art call (creatures, props, VFX frames).
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import List, Optional

from PIL import Image

try:
    from .image_backend import ImageBackend, get_image_backend
    from .manifest import PartRegion, PartsManifest
    from .stub_provider import GenerationRequest, PartsBundle
except ImportError:  # invoked as a plain script path, not as a module
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from genforge.pipeline.image_backend import ImageBackend, get_image_backend
    from genforge.pipeline.manifest import PartRegion, PartsManifest
    from genforge.pipeline.stub_provider import GenerationRequest, PartsBundle


# The style lock: every prompt is wrapped so output stays on-brand (docs/design
# /17). The Veilands = dark-fantasy Lumen/Gloom world.
_STYLE_LOCK = (
    "modern dark-fantasy pixel-art game sprite, deliberate crisp pixel clusters, "
    "selective outlines, readable anatomy, distinct metal, cloth and organic materials, "
    "deep indigo shadows and restrained luminous accents without baked bloom; "
    "single centered full-body character, fixed three-quarter angled top-down view, "
    "transparent background, no text, no logos, no border, no ground shadow"
)

_TIER_WORDS = {
    "normal": "a common creature",
    "elite": "an elite, more ornate and threatening variant",
    "legendary": "a legendary named boss, awe-inspiring and intricate",
}


def build_prompt(request: GenerationRequest, extra: str = "") -> str:
    """Compose the style-locked prompt from the request's lore fields."""
    bits: List[str] = [_STYLE_LOCK]
    subject = request.family if request.family and request.family != "unnamed" \
        else request.archetype
    bits.append(f"subject: {subject} ({request.archetype}), "
                f"{_TIER_WORDS.get(request.tier, request.tier)}")
    if request.theme_tags:
        bits.append("themes: " + ", ".join(request.theme_tags))
    if request.palette_hints:
        bits.append("palette: " + ", ".join(request.palette_hints))
    if extra:
        bits.append(extra)
    return ". ".join(bits)


class ModelPartsProvider:
    """PartsProvider backed by a real image model (provider-agnostic backend)."""

    name = "genai_model"
    version = "0.1.0"

    def __init__(self, backend: Optional[ImageBackend] = None,
                 size: str = "1024x1024", prompt_extra: str = "") -> None:
        # Lazy: no key/network at construction; only when generate_parts runs.
        self._backend = backend
        self.size = os.environ.get("GENFORGE_IMAGE_SIZE", size)
        self.prompt_extra = prompt_extra
        self.last_prompt = ""

    @property
    def backend(self) -> ImageBackend:
        if self._backend is None:
            self._backend = get_image_backend()
        return self._backend

    def generate_parts(self, request: GenerationRequest, out_dir: Path) -> PartsBundle:
        prompt = build_prompt(request, self.prompt_extra)
        self.last_prompt = prompt
        images = self.backend.generate(prompt, size=self.size, n=1)
        sheet = images[0]

        # Optional on-style pixel pass: nearest-downscale to a target height.
        px_h = os.environ.get("GENFORGE_MODEL_PIXEL_HEIGHT")
        if px_h:
            h = max(16, int(px_h))
            w = max(1, round(sheet.width * h / sheet.height))
            sheet = sheet.resize((w, h), Image.NEAREST)

        out_dir = Path(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        sheet_path = out_dir / "parts.png"
        sheet.save(sheet_path)

        # v1: one full-figure "body" region, pivot at feet (bottom-centre).
        regions = {"body": PartRegion(
            rect=(0, 0, sheet.width, sheet.height),
            pivot=(sheet.width / 2.0, float(sheet.height)),
            angle_hint=0.0,
        )}
        manifest = PartsManifest(
            entity=request.entity_slug(),
            archetype=request.archetype,
            sheet="parts.png",
            sheet_size=(sheet.width, sheet.height),
            parts=regions,
        )
        manifest_path = manifest.save(out_dir / "parts.json")

        # provenance sidecar (the prompt + model that produced these pixels)
        (out_dir / "gen_provenance.json").write_text(json.dumps({
            "provider": self.name, "version": self.version,
            "backend": getattr(self.backend, "name", "?"),
            "model": getattr(self.backend, "model", "?"),
            "size": self.size, "prompt": prompt, "kind": "concept",
        }, indent=2))
        return PartsBundle(
            sheet_path=sheet_path, manifest_path=manifest_path, manifest=manifest
        )


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python -m genforge.pipeline.model_provider",
        description="Generate a concept parts sheet from a real image model "
                    "(needs OPENAI_API_KEY; provider set by GENFORGE_IMAGE_BACKEND).",
    )
    ap.add_argument("--archetype", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--family", default="unnamed")
    ap.add_argument("--tier", default="normal")
    ap.add_argument("--entity", default=None)
    ap.add_argument("--palette-hints", default="")
    ap.add_argument("--theme-tags", default="")
    ap.add_argument("--prompt-extra", default="")
    ap.add_argument("--size", default="1024x1024")
    args = ap.parse_args(argv)

    req = GenerationRequest(
        archetype=args.archetype, family=args.family, tier=args.tier,
        entity=args.entity,
        palette_hints=[h for h in args.palette_hints.split(",") if h],
        theme_tags=[t for t in args.theme_tags.split(",") if t],
    )
    provider = ModelPartsProvider(size=args.size, prompt_extra=args.prompt_extra)
    bundle = provider.generate_parts(req, Path(args.out))
    print(f"  prompt:   {provider.last_prompt}")
    print(f"  sheet:    {bundle.sheet_path}")
    print(f"  manifest: {bundle.manifest_path} ({len(bundle.manifest.parts)} parts)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
