#!/usr/bin/env python3
"""Install the Codex launcher and associate its PNG with the Linux executable.

Linux file managers do not infer this association from a PNG beside an ELF.
The standard desktop entry works across desktops; GIO custom-icon metadata
also decorates the raw executable in GNOME-compatible file managers.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess


def install(package: Path, data: Path | None = None, metadata=True):
    package = package.resolve()
    executable = package / "dragon-heroes-codex.x86_64"
    if not executable.is_file():
        raise SystemExit("Run this installer from the extracted Dragon Heroes Codex package.")
    data = data or Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    applications = data / "applications"
    icons = data / "icons/hicolor/512x512/apps"
    applications.mkdir(parents=True, exist_ok=True)
    icons.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(package / "dragon-heroes-codex.png", icons / "dragon-heroes-codex.png")
    # Desktop Exec quoting is not shell quoting; %% is a literal percent.
    path = str(executable).replace("\\", "\\\\").replace('"', '\\"')
    path = path.replace("$", "\\$").replace("`", "\\`").replace("%", "%%")
    if "\n" in path or "\r" in path:
        raise SystemExit("Package paths containing line breaks are unsupported.")
    # Desktop string-value unescaping happens before Exec argument unescaping.
    path = path.replace("\\", "\\\\")
    desktop = applications / "dragon-heroes-codex.desktop"
    desktop.write_text(
        "[Desktop Entry]\nType=Application\nVersion=1.0\n"
        "Name=Dragon Heroes — Codex\nComment=Dragon Heroes review build\n"
        f'Exec="{path}"\nIcon=dragon-heroes-codex\n'
        "Terminal=false\nCategories=Game;RolePlaying;\nStartupNotify=false\n",
        encoding="utf-8",
    )
    desktop.chmod(0o755)
    shortcut = package / "Dragon Heroes Codex.desktop"
    shutil.copy2(desktop, shortcut)
    associated = False
    gio = shutil.which("gio")
    if metadata and gio:
        associated = subprocess.run([gio, "set", "-t", "string", str(executable),
            "metadata::custom-icon", (icons / "dragon-heroes-codex.png").resolve().as_uri()],
            capture_output=True, timeout=10).returncode == 0
        subprocess.run([gio, "set", "-t", "string", str(shortcut),
            "metadata::trusted", "true"], capture_output=True, timeout=10)
    refresh = shutil.which("update-desktop-database")
    if refresh:
        subprocess.run([refresh, str(applications)], capture_output=True, timeout=10)
    return desktop, associated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    desktop, associated = install(args.package)
    if not args.quiet:
        print(f"Installed app-menu launcher: {desktop}")
        print("File-manager icon associated." if associated else
              "This file manager does not expose custom icons; use Dragon Heroes Codex.desktop.")
        print("Run this installer again if you move the extracted package.")


if __name__ == "__main__":
    main()
