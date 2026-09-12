#!/usr/bin/env python3
"""Optional: run from an extracted Linux package to install its application icon."""
import os
from pathlib import Path
import shutil


def main():
    package = Path(__file__).resolve().parent
    executable = package / "dragon-heroes-codex.x86_64"
    if not executable.is_file():
        raise SystemExit("Run this installer from the extracted Dragon Heroes Codex package.")
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
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
        "Terminal=false\nCategories=Game;RolePlaying;\nStartupNotify=true\n",
        encoding="utf-8",
    )
    print(f"Installed app-menu launcher: {desktop}")
    print("Keep this extracted package in place; the launcher points to its executable.")


if __name__ == "__main__":
    main()
