#!/usr/bin/env python3
"""Rebuild the shipping clients, native helpers, icons and offline review together.

This is THE packager (R77, 2026-09-22). It used to be package_codex.py, the
review-build flavor that ran beside tools/package_game.sh — and the flavor won:
it exports to an explicit staged path instead of trusting the preset's
export_path, and it gates the result (icon/manifest verify, headless smoke,
living-preview and lair-journey checks, zip CRC, a /proc check that refuses to
replace a directory a running process is sitting in). package_game.sh trusted
the preset, the preset drifted to builds/codex/, and the zips it built from
builds/<plat>/ shipped a ten-day-old client without anyone noticing. Explicit
paths and gates are why that flavor is the one that survived the merge.

Every export starts in a fresh stage; missing helpers, failed exports or icon
mismatches abort the ZIP.
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
from tools.smoke_package import smoke
from tools.verify_package import verify
from tools.stage_living_preview import stage as stage_preview
from tools.check_living_preview import check as check_preview
from tools.check_lair_journey import check as check_lairs

# builds/<platform>/ holds the extracted package; builds/dragon-heroes-<platform>.zip
# is the distributable. Both are gitignored — builds/README.md says why.
OUT = ROOT / "builds"


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


def processes_using(directory: Path) -> list[tuple[int, str]]:
    """Every live process whose cwd is inside `directory`.

    Replacing a directory out from under a running process unlinks its cwd, and
    on Linux that is not a soft failure: getcwd() starts returning NULL, which
    takes out every relative path the process later resolves. For a running
    Godot that means res:// stops loading and the next load() returns null.
    Linux-only and best-effort by design: /proc may deny us a read, and a miss
    here must never block packaging on a platform that has no /proc.
    """
    found: list[tuple[int, str]] = []
    proc = Path("/proc")
    if not proc.is_dir():
        return found
    target = directory.resolve()
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            cwd = (entry / "cwd").resolve()
            if cwd == target or target in cwd.parents:
                name = (entry / "comm").read_text().strip()
                found.append((int(entry.name), name))
        except (OSError, PermissionError):
            continue
    return found


def helper_candidates(windows: bool, helper_name: str) -> list[Path]:
    """Where dh-server may live, best first.

    A fresh local build always wins. builds/prebuilt/windows/ is the committed
    cross-build cache that lets a clone WITHOUT the llvm-mingw toolchain still
    ship a complete Windows ZIP -- the one capability package_game.sh had that
    this packager did not, carried over in the R77 merge rather than dropped.
    Order is load-bearing: a cached helper must never outrank a rebuilt one.
    """
    if not windows:
        return [ROOT / "sim/build/libs/dh-server" / helper_name]
    return [ROOT / "sim/build-windows/libs/dh-server" / helper_name,
            ROOT / "builds/prebuilt/windows" / helper_name]


def package(platform, review, env):
    windows = platform == "windows"
    preset = "Windows Desktop" if windows else "Linux/X11"
    executable = "dragon-heroes.exe" if windows else "dragon-heroes.x86_64"
    helper_name = "dh-server.exe" if windows else "dh-server"
    helper = next((c for c in helper_candidates(windows, helper_name) if c.is_file()), None)
    if helper is None:
        raise RuntimeError("Missing world-generation helper: " + ", ".join(
            str(c) for c in helper_candidates(windows, helper_name)))
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
        shutil.copyfile(ROOT / "game/branding/dragon-heroes.png", stage / "dragon-heroes.png")
        shutil.copyfile(ROOT / "game/branding/dragon-heroes.ico", stage / "dragon-heroes.ico")
        shutil.copytree(review, stage / "content-review")
        if not windows:
            shutil.copyfile(ROOT / "tools/install_linux_launcher.py", stage / "install-launcher.py")
        readme = (
            "DRAGON HEROES\n"
            "=============\n"
            f"Run {executable}. No Godot installation is required.\n"
            "Keep dh-server(.exe) next to the game; it generates the world.\n"
            "Saves and settings live in their own directory: Dragon Heroes.\n"
            "(Upgrading from a review build? The first launch moves your old\n"
            "'Dragon Heroes Codex' saves across automatically.)\n\n"
            "This is an incremental playable build; the remaining art/biome/\n"
            "enchanted-build work is tracked in the repository at\n"
            "docs/harness/20-roadmap.md.\n\n"
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
            "The saved trial collection is separate from regular Hunt equipment. Full\n"
            "action animations and full production integration await review.\n\n"
            "SOLO: main menu -> hunter name -> class -> ENTER THE HUNT.\n"
            "CO-OP: CO-OP (P2P); one friend hosts, others join by LAN IP (UDP 7377).\n"
            "Controls: WASD move, LMB/Space attack, Shift/RMB dodge, E/Q skills,\n"
            "1-4 skill bar, F capture, Z mount, C character, K keybinds.\n\n"
        )
        if not windows:
            readme += ("LINUX ICON: the first normal launch installs the application icon and\n"
                       "a Dragon Heroes.desktop shortcut. GNOME-compatible file managers\n"
                       "also show the icon on the raw executable. Refresh the folder if needed.\n"
                       "To install without launching, or after moving the folder:\n"
                       "  python3 install-launcher.py\n")
        (stage / "LEIA-ME.txt").write_text(readme, encoding="utf-8")
        manifest = {**source_info(), "flavor": "release", "platform": platform,
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
        archive = stage / f"dragon-heroes-{platform}.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for path in sorted(stage.rglob("*")):
                if path.is_file() and path != archive:
                    bundle.write(path, path.relative_to(stage))
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None:
                raise RuntimeError("Archive CRC check failed")
        destination = OUT / platform
        # This tool owns builds/{linux,windows} and the two zips beside them. The
        # other builds/ subdirectories (trainer/, console/, prebuilt/) belong to
        # other tools and are never touched here.
        in_use = processes_using(destination)
        if in_use:
            raise RuntimeError(
                f"{destination} is the working directory of running process(es) "
                + ", ".join(f"{pid} ({name})" for pid, name in in_use)
                + ". Replacing it would unlink their cwd: getcwd() then returns "
                  "NULL, Godot's DirAccess stops resolving res:// and the game "
                  "dies at the next load() (Ricardo, 2026-09-14 — it crashed at "
                  "a lair doorway). Close the running build and package again.")
        if destination.exists():
            shutil.rmtree(destination)
        archive.replace(OUT / archive.name)
        stage.rename(destination)
    print(f"PACKAGE OK: {OUT / archive.name}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("linux", "windows", "all"), nargs="?", default="all")
    parser.add_argument("--require-clean", action="store_true",
                        help="Abort before building if source or staged generated metadata is uncommitted")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        run([sys.executable, "tools/build_app_icon.py"])
        run([sys.executable, "tools/validate_content.py"])
        review = stage_preview()
        if args.require_clean and source_info()["working_tree_dirty"]:
            raise RuntimeError("Generated staging or source is uncommitted. Review and commit it, then rebuild.")
        env = export_environment()
        run(["cmake", "-S", "sim", "-B", "sim/build", "-DCMAKE_BUILD_TYPE=Release"])
        run(["cmake", "--build", "sim/build", "-j", "4"])
        run(["ctest", "--test-dir", "sim/build", "--output-on-failure"])
        if args.platform in ("windows", "all"):
            # One Windows build tree, sim/build-windows — the merge (R77) dropped
            # sim/build-codex-windows, the second one this packager used to keep.
            try:
                run(["cmake", "-S", "sim", "-B", "sim/build-windows",
                     "-DCMAKE_TOOLCHAIN_FILE=cmake/mingw-w64-x86_64.cmake",
                     "-DCMAKE_BUILD_TYPE=Release"])
                run(["cmake", "--build", "sim/build-windows", "-j", "4"])
            except subprocess.CalledProcessError:
                # No llvm-mingw toolchain on this machine. The committed cache
                # still makes a complete ZIP; only its provenance is older, and
                # BUILD-INFO.json records the hash either way.
                cached = ROOT / "builds/prebuilt/windows/dh-server.exe"
                if not cached.is_file():
                    raise
                print(f"WARNING: mingw cross-build unavailable; using {cached}", flush=True)
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
