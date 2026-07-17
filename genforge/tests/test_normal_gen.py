"""normal_gen: bevel+Sobel normal maps — neutral background, outward edge
normals, byte-for-byte determinism, and batch skip logic. All offline."""
from __future__ import annotations

import io

import numpy as np
from PIL import Image

from genforge.pipeline.normal_gen import (
    generate_normal_map,
    normal_path_for,
    process_file,
    run_batch,
)


def _square_sprite(size=24, inset=6, color=(180, 120, 60, 255)) -> Image.Image:
    """Opaque square centered on a transparent canvas."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(inset, size - inset):
        for x in range(inset, size - inset):
            px[x, y] = color
    return img


def _png_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


# --------------------------------------------------------------------------
# core generation
# --------------------------------------------------------------------------


def test_transparent_background_is_neutral():
    out = np.asarray(generate_normal_map(_square_sprite()))
    corners = [(0, 0), (0, -1), (-1, 0), (-1, -1)]
    for y, x in corners:
        assert tuple(out[y, x]) == (128, 128, 255, 0)


def test_alpha_follows_source():
    src = _square_sprite()
    out = np.asarray(generate_normal_map(src))
    assert np.array_equal(out[..., 3], np.asarray(src)[..., 3])


def test_edge_normals_point_outward():
    inset = 6
    out = np.asarray(generate_normal_map(_square_sprite(size=24, inset=inset)))
    mid = 12
    # left edge tilts left (R < 128), right edge tilts right (R > 128)
    assert out[mid, inset, 0] < 128
    assert out[mid, 24 - inset - 1, 0] > 128
    # top edge tilts up (green-up convention: G > 128), bottom tilts down
    assert out[inset, mid, 1] > 128
    assert out[24 - inset - 1, mid, 1] < 128
    # square center is flat: neutral normal, opaque alpha
    assert tuple(out[mid, mid]) == (128, 128, 255, 255)


def test_blue_channel_is_up_everywhere():
    out = np.asarray(generate_normal_map(_square_sprite()))
    assert out[..., 2].min() > 128  # z > 0: never a backfacing normal


def test_determinism():
    src = _square_sprite()
    assert _png_bytes(generate_normal_map(src)) == _png_bytes(generate_normal_map(src))


# --------------------------------------------------------------------------
# batch skip logic
# --------------------------------------------------------------------------


def test_batch_generates_missing_and_skips_existing(tmp_path):
    strips = tmp_path / "strips"
    strips.mkdir()
    _square_sprite().save(tmp_path / "a.png")
    _square_sprite().save(strips / "b.png")     # recursion: nested source
    _square_sprite().save(tmp_path / "c.png")
    sentinel = b"do-not-touch"
    (tmp_path / "c_n.png").write_bytes(sentinel)  # existing sibling -> skip

    written = run_batch(tmp_path)

    assert sorted(p.name for p in written) == ["a_n.png", "b_n.png"]
    assert (tmp_path / "a_n.png").exists()
    assert (strips / "b_n.png").exists()
    assert (tmp_path / "c_n.png").read_bytes() == sentinel  # never overwritten


def test_batch_never_processes_normal_maps(tmp_path):
    _square_sprite().save(tmp_path / "a.png")
    run_batch(tmp_path)
    run_batch(tmp_path)  # second pass: a_n.png present, must be a no-op
    assert list(run_batch(tmp_path)) == []
    assert not (tmp_path / "a_n_n.png").exists()


def test_process_file_default_output_name(tmp_path):
    src = tmp_path / "sheet.png"
    _square_sprite().save(src)
    dst = process_file(src)
    assert dst == normal_path_for(src) == tmp_path / "sheet_n.png"
    assert dst.exists()
