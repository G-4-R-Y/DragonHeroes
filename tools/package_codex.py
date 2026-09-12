#!/usr/bin/env python3
"""Rebuild Codex clients, native helpers, icons and the offline review together.

Normal packaging stays in package_game.sh. Every Codex export starts in a
fresh stage; missing helpers, failed exports or icon mismatches abort the ZIP.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.smoke_codex import smoke
from tools.verify_package import verify
from tools.stage_living_preview import stage as stage_preview
from tools.check_living_preview import check as check_preview
from tools.check_lair_journey import check as check_lairs

OUT = ROOT / "builds/codex"


def run(command, env=None):
    subprocess.run([str(a) for a in command], cwd=ROOT, env=env, check=True)


def export_environment():
    roots = [Path.home() / ".local/share/godot/export_templates"]
    if os.environ.get("XDG_DATA_HOME"):
        roots.insert(0, Path(os.environ["XDG_DATA_HOME"]) / "godot/export_templates")
    templates = next((p for p in roots if (p / "4.6.stable").is_dir()), None)
    if templates is None:
        raise RuntimeError("Install Godot 4.6 export templates using Manage Export Templates first.")
    env = dict(os.environ)
    for key, name in (("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                      ("XDG_CACHE_HOME", "cache")):
        path = ROOT / "genforge/candidates/packaging" / name
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    local_templates = Path(env["XDG_DATA_HOME"]) / "godot/export_templates"
    local_templates.parent.mkdir(parents=True, exist_ok=True)
    if local_templates.is_symlink():
        if local_templates.resolve() != templates.resolve():
            local_templates.unlink()
            local_templates.symlink_to(templates, target_is_directory=True)
    elif not local_templates.exists():
        local_templates.symlink_to(templates, target_is_directory=True)
    return env


def source_info():
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
    return {"base_commit": commit, "working_tree_dirty": dirty,
            "branch": subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()}


def package(platform, review, env):
    windows = platform == "windows"
    preset = "Windows Desktop" if windows else "Linux/X11"
    executable = "dragon-heroes-codex.exe" if windows else "dragon-heroes-codex.x86_64"
    helper_name = "dh-server.exe" if windows else "dh-server"
    helper = ROOT / ("sim/build-codex-windows" if windows else "sim/build") / "libs/dh-server" / helper_name
    if not helper.is_file():
        raise RuntimeError(f"Missing rebuilt world-generation helper: {helper}")
    with tempfile.TemporaryDirectory(prefix=f".{platform}-", dir=OUT) as temporary:
        stage = Path(temporary)
        log = ROOT / f"genforge/candidates/packaging/export-{platform}.log"
        with log.open("w") as handle:
            result = subprocess.run(["godot", "--headless", "--path", "game", "--export-release",
                                     preset, str(stage / executable)], cwd=ROOT, env=env,
                                    stdout=handle, stderr=subprocess.STDOUT)
        if result.returncode != 0 or not (stage / executable).is_file():
            raise RuntimeError(f"Export failed; see {log}\n{log.read_text()[-3000:]}")
        shutil.copy2(helper, stage / helper_name)
        shutil.copyfile(ROOT / "game/branding/dragon-heroes.png", stage / "dragon-heroes-codex.png")
        shutil.copyfile(ROOT / "game/branding/dragon-heroes.ico", stage / "dragon-heroes-codex.ico")
        shutil.copytree(review, stage / "content-review")
        if not windows:
            shutil.copyfile(ROOT / "tools/install_linux_launcher.py", stage / "install-launcher.py")
        readme = (
            "DRAGON HEROES — CODEX REVIEW BUILD\n"
            "================================\n"
            f"Run {executable}. No Godot installation is required.\n"
            "Keep dh-server(.exe) next to the game; it generates the world.\n"
            "Codex uses its own save/settings directory: Dragon Heroes Codex.\n\n"
            "CONTENT REVIEW: open content-review/index.html in your browser.\n"
            "PLAYABLE PREVIEW: choose PLAY NEW CONTENT: LAIRS & LEGENDS.\n"
            "EXPLORE SHRINE ENTRANCES starts beside the first doorway; G enters.\n"
            "Defeat its guardian to unlock BOSS RUSH and earn a saved artifact.\n"
            "Rush clears earn more artifacts; ENTER continues to the next round.\n"
            "Practice lets you compare every artifact without changing your collection.\n"
            "Fight Orun, compare four artifacts and read their stories with L.\n"
            "Trial: WASD move, mouse aim, LMB/Space cut, Shift/RMB dodge,\n"
            "Q Wet field, E Storm, R companion; 1-4 switch artifact tiers.\n"
            "Q then E triggers Mythic chains; R triggers the Divine ward.\n"
            "ENTER retries/continues; F bonds the guardian; ESC returns to Hunt/collection.\n"
            "The saved Codex collection is separate from regular Hunt equipment. Full\n"
            "action animations and full production integration await review.\n\n"
            "SOLO: main menu -> hunter name -> class -> ENTER THE HUNT.\n"
            "CO-OP: CO-OP (P2P); one friend hosts, others join by LAN IP (UDP 7377).\n"
            "Controls: WASD move, LMB/Space attack, Shift/RMB dodge, E/Q skills,\n"
            "1-4 skill bar, F capture, Z mount, C character, K keybinds.\n\n"
        )
        if not windows:
            readme += "LINUX APP-MENU ICON: optionally run python3 install-launcher.py.\n"
        (stage / "LEIA-ME.txt").write_text(readme, encoding="utf-8")
        manifest = {**source_info(), "flavor": "codex", "platform": platform,
                    "executable": executable, "world_helper": helper_name,
                    "files": {str(p.relative_to(stage)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted(stage.rglob("*")) if p.is_file()}}
        (stage / "BUILD-INFO.json").write_text(json.dumps(manifest, indent=2) + "\n")
        try:
            verify(stage, ROOT / "game/branding/dragon-heroes.ico")
        except ValueError:
            # Preserve the actual failed export for diagnosis, outside distributables.
            shutil.copy2(stage / executable, log.parent / f"failed-{executable}")
            raise
        if not windows:
            smoke(stage, log.parent)
            check_preview(stage)
            check_lairs(stage)
        archive = stage / f"dragon-heroes-codex-{platform}.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for path in sorted(stage.rglob("*")):
                if path.is_file() and path != archive:
                    bundle.write(path, path.relative_to(stage))
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None:
                raise RuntimeError("Archive CRC check failed")
        destination = OUT / platform
        # This tool owns only builds/codex/{linux,windows}; normal builds are separate.
        if destination.exists():
            shutil.rmtree(destination)
        archive.replace(OUT / archive.name)
        stage.rename(destination)
    print(f"PACKAGE OK: {OUT / archive.name}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("linux", "windows", "all"), nargs="?", default="all")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        run([sys.executable, "tools/build_app_icon.py"])
        run([sys.executable, "tools/validate_content.py"])
        review = stage_preview()
        env = export_environment()
        run(["cmake", "-S", "sim", "-B", "sim/build", "-DCMAKE_BUILD_TYPE=Release"])
        run(["cmake", "--build", "sim/build", "-j", "4"])
        run(["ctest", "--test-dir", "sim/build", "--output-on-failure"])
        if args.platform in ("windows", "all"):
            run(["cmake", "-S", "sim", "-B", "sim/build-codex-windows",
                 "-DCMAKE_TOOLCHAIN_FILE=cmake/mingw-w64-x86_64.cmake", "-DCMAKE_BUILD_TYPE=Release"])
            run(["cmake", "--build", "sim/build-codex-windows", "-j", "4"])
        log = ROOT / "genforge/candidates/packaging/import.log"
        with log.open("w") as handle:
            subprocess.run(["godot", "--headless", "--path", "game", "--import", "--quit"],
                           cwd=ROOT, env=env, stdout=handle, stderr=subprocess.STDOUT, check=True)
        for platform in ("linux", "windows") if args.platform == "all" else (args.platform,):
            package(platform, review, env)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"PACKAGE FAILED: {error}\n")


if __name__ == "__main__":
    main()
