#!/usr/bin/env python3
"""Publish builds/dragon-heroes-*.zip as GitHub release assets (R78).

The zips ARE the game to anyone downloading, so they were committed on purpose
-- and that is what pushed the repository past GitHub's 50 MB warning and
towards its 100 MB per-file hard block: every package run committed another
~110 MB of binaries that git can never compress and never forgets. Release
assets cost nothing, are not cloned, and report download counts; Git LFS would
have been a recurring bill for the same bytes.

What stays in-tree is builds/BUILD-INFO.json -- the index: which release holds
the current build, from which commit, and the sha256 of each asset, so a clone
can prove a downloaded zip is the one this repository published. (The per-
package BUILD-INFO.json inside each zip is a different, older file: it hashes
that package's own contents. This one hashes the packages.)

    python3 tools/publish_release.py                 # publish the local zips
    python3 tools/publish_release.py --dry-run       # everything but the upload
    python3 tools/publish_release.py --check         # is the index current?

Requires the gh CLI, authenticated with write access to the repository.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds"
INDEX = OUT / "BUILD-INFO.json"
PLATFORMS = ("linux", "windows")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def package_info(archive: Path) -> dict:
    """Provenance, read back out of the zip's own BUILD-INFO.json.

    Reading it rather than asking git is deliberate: it reports the commit the
    package was BUILT from, which is not necessarily HEAD by the time anyone
    publishes it.
    """
    with zipfile.ZipFile(archive) as bundle:
        manifest = json.loads(bundle.read("BUILD-INFO.json"))
    stat = archive.stat()
    return {
        "file": archive.name,
        "bytes": stat.st_size,
        "sha256": sha256(archive),
        "built": datetime.datetime.fromtimestamp(
            stat.st_mtime, datetime.timezone.utc).isoformat(timespec="seconds"),
        "base_commit": manifest["base_commit"],
        "working_tree_dirty": manifest["working_tree_dirty"],
        "executable": manifest["executable"],
    }


def collect(allow_dirty: bool) -> dict[str, dict]:
    packages = {}
    for platform in PLATFORMS:
        archive = OUT / f"dragon-heroes-{platform}.zip"
        if not archive.is_file():
            raise SystemExit(
                f"missing {archive.relative_to(ROOT)} -- run "
                f"`python3 tools/package_build.py {platform}` first. Publishing "
                "one platform without the other would leave the release half a game.")
        info = package_info(archive)
        if info["working_tree_dirty"] and not allow_dirty:
            raise SystemExit(
                f"{archive.name} was built from a dirty tree ({info['base_commit'][:7]}). "
                "A published asset nobody can rebuild is worse than no asset: commit, "
                "repackage, then publish -- or pass --allow-dirty and say so in the notes.")
        packages[platform] = info
    return packages


def gh(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(["gh", *args], cwd=ROOT, text=True, capture_output=True, check=check)


def default_tag(packages: dict[str, dict]) -> str:
    """build-<date>-<commit>: sortable, and it names the source it came from."""
    newest = max(p["built"] for p in packages.values())
    commit = packages["linux"]["base_commit"][:7]
    return f"build-{newest[:10].replace('-', '')}-{commit}"


def notes(tag: str, packages: dict[str, dict]) -> str:
    subject = subprocess.check_output(
        ["git", "log", "-1", "--format=%s", packages["linux"]["base_commit"]],
        cwd=ROOT, text=True).strip()
    lines = [
        f"Playable build from `{packages['linux']['base_commit'][:7]}` — {subject}",
        "",
        "Download the zip for your platform, extract it anywhere, and run the",
        "executable inside. Controls and what to try first are in `LEIA-ME.txt`.",
        "",
        "| Platform | File | Size | sha256 |",
        "|---|---|---|---|",
    ]
    for platform in PLATFORMS:
        info = packages[platform]
        lines.append(f"| {platform} | `{info['file']}` | {info['bytes'] / 1048576:.1f} MiB "
                     f"| `{info['sha256'][:16]}…` |")
    lines += [
        "",
        "Verify a download with `sha256sum` against `builds/BUILD-INFO.json` in",
        "the repository at this tag.",
        "",
        "The source builds without these assets: see `docs/USAGE.md`.",
    ]
    return "\n".join(lines) + "\n"


def write_index(tag: str, url: str, packages: dict[str, dict]) -> None:
    INDEX.write_text(json.dumps({
        "_comment": "Index of the published distributables (R78). The zips live in "
                    "GitHub release assets, not in this repository -- git cannot "
                    "compress them and never forgets them. Regenerate with "
                    "tools/publish_release.py.",
        "release_tag": tag,
        "release_url": url,
        "packages": {platform: {**info, "download_url":
                                f"{url.rsplit('/tag/', 1)[0]}/download/{tag}/{info['file']}"
                                if "/tag/" in url else None}
                     for platform, info in packages.items()},
    }, indent=2) + "\n", encoding="utf-8")


def check() -> int:
    """Does the in-tree index still describe the zips sitting in builds/?"""
    if not INDEX.is_file():
        print(f"RELEASE INDEX MISSING: {INDEX.relative_to(ROOT)}", file=sys.stderr)
        return 1
    index = json.loads(INDEX.read_text())
    stale = []
    for platform in PLATFORMS:
        archive = OUT / f"dragon-heroes-{platform}.zip"
        if not archive.is_file():
            continue  # A clean clone has no zips at all. That is the point of R78.
        recorded = index["packages"].get(platform, {}).get("sha256")
        if sha256(archive) != recorded:
            stale.append(platform)
    if stale:
        print("RELEASE INDEX STALE for " + ", ".join(stale)
              + " -- builds/ holds a package the index does not describe. "
                "Run tools/publish_release.py.", file=sys.stderr)
        return 1
    print(f"RELEASE INDEX OK: {index['release_tag']} ({index['release_url']})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tag", help="Release tag (default: build-<date>-<commit>)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be published; upload nothing")
    parser.add_argument("--check", action="store_true",
                        help="Verify builds/BUILD-INFO.json describes the local zips")
    parser.add_argument("--allow-dirty", action="store_true",
                        help="Publish packages built from an uncommitted tree")
    parser.add_argument("--draft", action="store_true", help="Create the release as a draft")
    args = parser.parse_args()

    if args.check:
        return check()

    packages = collect(args.allow_dirty)
    tag = args.tag or default_tag(packages)
    total = sum(p["bytes"] for p in packages.values())
    print(f"publishing {tag}: " + ", ".join(
        f"{p['file']} ({p['bytes'] / 1048576:.1f} MiB)" for p in packages.values())
        + f" — {total / 1048576:.1f} MiB total", flush=True)

    if args.dry_run:
        print(notes(tag, packages))
        print("DRY RUN — nothing uploaded")
        return 0

    existing = gh("release", "view", tag, "--json", "url", check=False)
    if existing.returncode == 0:
        url = json.loads(existing.stdout)["url"]
        print(f"release {tag} exists; replacing its assets", flush=True)
        gh("release", "upload", tag, *[str(OUT / p["file"]) for p in packages.values()],
           "--clobber")
    else:
        notes_file = OUT / ".release-notes.md"
        notes_file.write_text(notes(tag, packages), encoding="utf-8")
        try:
            create = ["release", "create", tag, "--title", f"Dragon Heroes — {tag}",
                      "--notes-file", str(notes_file)]
            if args.draft:
                create.append("--draft")
            create += [str(OUT / p["file"]) for p in packages.values()]
            gh(*create)
        finally:
            notes_file.unlink(missing_ok=True)
        url = json.loads(gh("release", "view", tag, "--json", "url").stdout)["url"]

    # Trust the server's byte counts over the local ones: a truncated upload is
    # exactly the failure an index full of local hashes would hide.
    assets = json.loads(gh("release", "view", tag, "--json", "assets").stdout)["assets"]
    by_name = {a["name"]: a["size"] for a in assets}
    for info in packages.values():
        if by_name.get(info["file"]) != info["bytes"]:
            raise SystemExit(f"upload mismatch for {info['file']}: "
                             f"{by_name.get(info['file'])} bytes on the release, "
                             f"{info['bytes']} locally")

    write_index(tag, url, packages)
    print(f"RELEASE OK: {url}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
