"""Offline action atlas and relocatable Linux desktop integration outcomes."""
from pathlib import Path
import shutil
import subprocess

from PIL import Image

from genforge.pipeline.bake_game_art import bake_actor
from tools.install_linux_launcher import desktop_environment, install


def test_action_bake_has_distinct_motion_and_matching_lighting(tmp_path):
    atlas = bake_actor("hero", tmp_path)
    signatures = set()
    for name in ("attack", "cast", "heavy", "spin", "dodge"):
        clip = atlas["animations"][name]
        assert not clip["loop"]
        with Image.open(tmp_path / "hero" / clip["strip"]) as strip:
            fw, fh = atlas["frame_size"]
            frames = [strip.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(clip["frames"])]
            assert all(frame.getbbox() for frame in frames)
            assert len({frame.tobytes() for frame in frames}) >= 4
            signatures.add(strip.tobytes())
            normal = Path(clip["strip"]).with_stem(name + "_n")
            with Image.open(tmp_path / "hero" / normal) as lighting:
                assert strip.size == lighting.size
                assert strip.getchannel("A").tobytes() == lighting.getchannel("A").tobytes()
    assert len(signatures) == 5


def test_linux_icon_installs_a_valid_relocatable_launcher(tmp_path):
    package = tmp_path / 'Dragon Heroes $test % "quoted"'
    package.mkdir()
    executable = package / "dragon-heroes.x86_64"
    executable.write_bytes(b"test")
    icon = package / "dragon-heroes.png"
    icon.write_bytes(b"icon test fixture")
    data = tmp_path / "xdg"
    desktop, associated = install(package, data=data, metadata=False)
    assert not associated
    assert (data / "icons/hicolor/512x512/apps" / icon.name).read_bytes() == icon.read_bytes()
    assert (package / "Dragon Heroes.desktop").read_bytes() == desktop.read_bytes()
    assert "Icon=dragon-heroes\n" in desktop.read_text()
    if shutil.which("desktop-file-validate"):
        subprocess.run(["desktop-file-validate", str(desktop)], check=True)
    moved = tmp_path / "Moved Game"
    package.rename(moved)
    desktop, _ = install(moved, data=data, metadata=False)
    assert str(moved) in desktop.read_text()
    assert str(package) not in desktop.read_text()


def test_snap_ide_installs_for_host_desktop(monkeypatch, tmp_path):
    monkeypatch.setenv("SNAP", "/snap/code/262")
    monkeypatch.setenv("SNAP_REAL_HOME", str(tmp_path / "real_home"))
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / "real_home/snap/code/262/.local/share"))
    monkeypatch.setenv("GIO_MODULE_DIR", str(tmp_path / "real_home/snap/code/common/.cache/gio-modules"))
    package = tmp_path / "package"
    package.mkdir()
    (package / "dragon-heroes.x86_64").write_bytes(b"fixture")
    (package / "dragon-heroes.png").write_bytes(b"icon")
    desktop, _ = install(package, metadata=False)
    assert desktop == tmp_path / "real_home/.local/share/applications/dragon-heroes.desktop"
    assert "GIO_MODULE_DIR" not in desktop_environment()
