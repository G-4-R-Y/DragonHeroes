#!/usr/bin/env python3
"""Put a Dragon Heroes console in the desktop menu, with the Dragon Heroes icon.

Ricardo, 2026-09-13: "create an execution icon binary as the rest ... we even
have custom icons". The shipping client already ships one (tools/package_build.py
stages a PNG and tools/install_linux_launcher.py registers the .desktop entry);
the training cockpit did not — it was a godot command line you had to remember.
This is the same treatment for it.

    tools/build_console.sh                     # exports the binaries, calls this
    python3 tools/install_console_launcher.py arena
    python3 tools/install_console_launcher.py genforge
    python3 tools/install_console_launcher.py all --uninstall

WHAT IT REGISTERS (per target)
    ~/.local/share/applications/dragon-heroes-<target>.desktop
    ~/.local/share/icons/hicolor/512x512/apps/dragon-heroes-<target>.png
(or $XDG_DATA_HOME). The icon is game/branding/dragon-heroes.png, the 512x512
PNG tools/build_app_icon.py renders from the curated source — the same art the
game and the Windows .ico use, so the menu entry matches the client.

It prefers the exported binary under builds/console/ when one exists and falls
back to running the scene out of the source tree through `godot`. It
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

# One row per console: the exported binary, the scene to fall back to, and how
# the menu entry reads. Adding a third console is adding a row here.
TARGETS = {
    "arena": {
        "binary": ROOT / "builds" / "console" / "dh-arena-console.x86_64",
        "scene": "res://arena/console.tscn",
        "name": "Dragon Heroes — Arena Console",
        "generic": "Creature AI training cockpit",
        "comment": "Train, gate, benchmark and deploy creature AI",
        "keywords": "dragon;heroes;arena;training;ai;",
    },
    "genforge": {
        "binary": ROOT / "builds" / "console" / "dh-genforge-console.x86_64",
        "scene": "res://genforge/console.tscn",
        "name": "Dragon Heroes — GenForge Console",
        "generic": "Content pipeline cockpit",
        "comment": "Create, audit and approve generated content",
        "keywords": "dragon;heroes;genforge;content;art;approve;",
    },
}


def desktop_environment() -> dict:
    """A Snap-confined IDE redirects XDG at its own sandbox; a desktop entry has
    to land in the user's real home or it never reaches their menu. Same reason
    tools/install_linux_launcher.py does this for the game build."""
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


def exec_line(target: str) -> tuple[str, str]:
    """(Exec=, a human note). Desktop Exec quoting is not shell quoting: inside a
    quoted argument only \\ " ` $ are escaped with a backslash, and a literal
    percent is %%."""
    def q(s: str) -> str:
        for ch in ("\\", '"', "`", "$"):
            s = s.replace(ch, "\\" + ch)
        return '"' + s.replace("%", "%%") + '"'

    spec = TARGETS[target]
    binary = spec["binary"]
    if binary.is_file() and os.access(binary, os.X_OK):
        return q(str(binary)), f"exported binary {binary.relative_to(ROOT)}"
    godot = shutil.which("godot")
    if godot is None:
        raise SystemExit(f"no {binary.relative_to(ROOT)} and no `godot` on PATH — run "
                         "tools/build_console.sh first")
    return (f"{q(godot)} --path {q(str(ROOT / 'game'))} {q(spec['scene'])}",
            "source tree via godot (run tools/build_console.sh for a standalone binary)")


def install(target: str, uninstall: bool = False) -> int:
    spec = TARGETS[target]
    name = f"dragon-heroes-{target}"
    env = desktop_environment()
    data = data_dir(env)
    entry = data / "applications" / f"{name}.desktop"
    icon = data / "icons/hicolor/512x512/apps" / f"{name}.png"

    if uninstall:
        for path in (entry, icon):
            if path.exists():
                path.unlink()
                print(f"removed {path}")
        _refresh(entry.parent, env)
        return 0

    if not ICON_SOURCE.is_file():
        raise SystemExit(f"missing {ICON_SOURCE} — run tools/build_app_icon.py first")
    command, note = exec_line(target)
    entry.parent.mkdir(parents=True, exist_ok=True)
    icon.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ICON_SOURCE, icon)
    entry.write_text(
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Version=1.0\n"
        f"Name={spec['name']}\n"
        f"GenericName={spec['generic']}\n"
        f"Comment={spec['comment']}\n"
        f"Exec={command}\n"
        f"Icon={name}\n"
        "Terminal=false\n"
        "Categories=Development;Game;\n"
        "StartupNotify=true\n"
        f"Keywords={spec['keywords']}\n",
        encoding="utf-8")
    entry.chmod(0o755)
    _refresh(entry.parent, env)
    print(f"installed {entry}\n          {icon}\n  target: {note}")
    print(f"  open it from the application menu (searching "
          f"\"{spec['name'].split('— ')[-1].split()[0]}\" finds it).")
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
    ap.add_argument("target", nargs="?", default="all",
                    choices=[*TARGETS, "all"], help="which console (default: all)")
    ap.add_argument("--uninstall", action="store_true", help="remove the entry and icon")
    args = ap.parse_args()
    targets = list(TARGETS) if args.target == "all" else [args.target]
    return max(install(t, args.uninstall) for t in targets)


if __name__ == "__main__":
    sys.exit(main())
