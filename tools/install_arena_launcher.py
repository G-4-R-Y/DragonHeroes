#!/usr/bin/env python3
"""Put the Arena Console in the desktop menu, with the Dragon Heroes icon.

Ricardo, 2026-09-13: "create an execution icon binary as the rest ... we even
have custom icons". The codex flavour already ships one (tools/package_codex.py
stages a PNG and tools/install_linux_launcher.py registers the .desktop entry);
the training cockpit did not — it was a godot command line you had to remember.
This is the same treatment for it.

    tools/build_console.sh          # exports the binary, then calls this
    python3 tools/install_arena_launcher.py              # dev tree, no export
    python3 tools/install_arena_launcher.py --uninstall

WHAT IT REGISTERS
    ~/.local/share/applications/dragon-heroes-arena.desktop
    ~/.local/share/icons/hicolor/512x512/apps/dragon-heroes-arena.png
(or $XDG_DATA_HOME). The icon is game/branding/dragon-heroes.png, the 512x512
PNG tools/build_app_icon.py renders from the curated source — the same art the
game and the Windows .ico use, so the menu entry matches the client.

It prefers builds/console/dh-arena-console.x86_64 when that export exists and
falls back to running the console out of the source tree through `godot`. It
NEVER launches anything: this writes files and stops. (Opening the console spawns
a Vulkan window, and that is Ricardo's to do — tools/run_vulkan.sh, canon §12.)
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ICON_SOURCE = ROOT / "game" / "branding" / "dragon-heroes.png"
EXPORTED = ROOT / "builds" / "console" / "dh-arena-console.x86_64"
NAME = "dragon-heroes-arena"


def desktop_environment() -> dict:
    """A Snap-confined IDE redirects XDG at its own sandbox; a desktop entry has
    to land in the user's real home or it never reaches their menu. Same reason
    tools/install_linux_launcher.py does this for the codex build."""
    env = dict(os.environ)
    if env.get("SNAP"):
        for key in ("GIO_MODULE_DIR", "GIO_EXTRA_MODULES", "LD_LIBRARY_PATH"):
            if "/snap/" in env.get(key, ""):
                env.pop(key, None)
    return env


def data_dir(env: dict) -> Path:
    data = Path(env.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    if env.get("SNAP") and "/snap/" in str(data):
        data = Path(env.get("SNAP_REAL_HOME", Path.home())) / ".local/share"
    return data


def exec_line() -> tuple[str, str]:
    """(Exec=, a human note). Desktop Exec quoting is not shell quoting: inside a
    quoted argument only \\ " ` $ are escaped with a backslash, and a literal
    percent is %%."""
    def q(s: str) -> str:
        for ch in ("\\", '"', "`", "$"):
            s = s.replace(ch, "\\" + ch)
        return '"' + s.replace("%", "%%") + '"'

    if EXPORTED.is_file() and os.access(EXPORTED, os.X_OK):
        return q(str(EXPORTED)), f"exported binary {EXPORTED.relative_to(ROOT)}"
    godot = shutil.which("godot")
    if godot is None:
        raise SystemExit("no builds/console export and no `godot` on PATH — run "
                         "tools/build_console.sh first")
    return (f"{q(godot)} --path {q(str(ROOT / 'game'))} {q('res://arena/console.tscn')}",
            "source tree via godot (run tools/build_console.sh for a standalone binary)")


def install(uninstall: bool = False) -> int:
    env = desktop_environment()
    data = data_dir(env)
    entry = data / "applications" / f"{NAME}.desktop"
    icon = data / "icons/hicolor/512x512/apps" / f"{NAME}.png"

    if uninstall:
        for path in (entry, icon):
            if path.exists():
                path.unlink()
                print(f"removed {path}")
        _refresh(entry.parent, env)
        return 0

    if not ICON_SOURCE.is_file():
        raise SystemExit(f"missing {ICON_SOURCE} — run tools/build_app_icon.py first")
    command, note = exec_line()
    entry.parent.mkdir(parents=True, exist_ok=True)
    icon.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ICON_SOURCE, icon)
    entry.write_text(
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Version=1.0\n"
        "Name=Dragon Heroes — Arena Console\n"
        "GenericName=Creature AI training cockpit\n"
        "Comment=Train, gate, benchmark and deploy creature AI\n"
        f"Exec={command}\n"
        f"Icon={NAME}\n"
        "Terminal=false\n"
        "Categories=Development;Game;\n"
        "StartupNotify=true\n"
        "Keywords=dragon;heroes;arena;training;ai;\n",
        encoding="utf-8")
    entry.chmod(0o755)
    _refresh(entry.parent, env)
    print(f"installed {entry}\n          {icon}\n  target: {note}")
    print("  open it from the application menu (searching \"Arena\" finds it).")
    return 0


def _refresh(applications: Path, env: dict) -> None:
    """Best effort: most desktops pick the entry up on their own, and a missing
    update-desktop-database must not fail the install."""
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", str(applications)],
                       env=env, check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--uninstall", action="store_true", help="remove the entry and icon")
    return install(ap.parse_args().uninstall)


if __name__ == "__main__":
    sys.exit(main())
