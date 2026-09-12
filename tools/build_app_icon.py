#!/usr/bin/env python3
"""Convert the curated source to application PNG and all Windows ICO sizes."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZES = (16, 32, 48, 64, 128, 256)


def main():
    source = ROOT / "genforge/art_sources/app_icon/source.png"
    out = ROOT / "game/branding"
    out.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image = image.convert("RGBA")
    if image.width != image.height or image.getchannel("A").getextrema() != (0, 255):
        raise ValueError("icon source must be square RGBA with transparent and opaque pixels")
    # Format/size conversion only: the original generated design is retained.
    image.resize((512, 512), Image.LANCZOS).save(out / "dragon-heroes.png")
    image.save(out / "dragon-heroes.ico", sizes=[(s, s) for s in SIZES])
    with Image.open(out / "dragon-heroes.ico") as icon:
        assert icon.ico.sizes() == {(s, s) for s in SIZES}
    (ROOT / "genforge/art_sources/app_icon/provenance.json").write_text(json.dumps({
        "provider": "built-in image_gen", "model": "not exposed by tool",
        "prompt": "prompt.txt", "source": "source.png",
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "outputs": ["game/branding/dragon-heroes.png", "game/branding/dragon-heroes.ico"],
        "ico_sizes": list(SIZES),
    }, indent=2) + "\n")
    print("APP ICON OK: 512px PNG + ICO sizes 16, 32, 48, 64, 128, 256")


if __name__ == "__main__":
    main()
