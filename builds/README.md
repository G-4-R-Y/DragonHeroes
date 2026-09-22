# builds/ — distributables

What players receive, plus the one binary that cannot be rebuilt everywhere.

| Path | Tracked? | What it is |
|---|---|---|
| `BUILD-INFO.json` | yes | The index: which GitHub release holds the current build, the commit it came from, and each asset's size and sha256. Written by `tools/publish_release.py`. |
| `dragon-heroes-linux.zip` | **no** | The shipped Linux build (`tools/package_build.py linux`) — published as a release asset, not committed. |
| `dragon-heroes-windows.zip` | **no** | The shipped Windows build (`tools/package_build.py windows`) — same. |
| `prebuilt/windows/dh-server.exe` | yes | Cross-build cache of the worldgen binary, so a clone without the mingw toolchain can still produce a complete Windows zip. See its README. |
| `linux/`, `windows/` | no | Raw Godot export dirs the zips are made from — regenerated every package run, and over GitHub's 100 MB limit. |
| `trainer/`, `console/` | no | The ~96 MB arena trainer export and the Arena Console app. |

Everything untracked here is listed in `.gitignore`: the export directories are
scratch, and since **R78** (2026-09-22) the zips are too, as far as git is
concerned.

## Why the zips left the repository (R78)

They were tracked on purpose — the zip *is* the game to anyone who downloads
it. But a ZIP is already compressed, so git stores each new one whole, and git
never forgets: by 2026-09-22 the history held 25 versions of them, the clone
was 697 MB, and the Windows zip had grown to 57 MB against GitHub's 100 MB
**hard** per-file block. Git LFS would have moved the same bytes onto a
recurring bill. Release assets are free, are not cloned, and report download
counts.

    python3 tools/publish_release.py            # package → release → index
    python3 tools/publish_release.py --dry-run  # everything except the upload
    python3 tools/publish_release.py --check    # is the index current?

It refuses to publish a package built from a dirty tree, and it trusts the
server's byte counts over the local ones — a truncated upload is exactly the
failure an index full of local hashes would hide.

**Removing them from the index does not shrink the history.** The old blobs are
still in every clone; only a history rewrite removes them, and that invalidates
every existing clone, so it is a decision for Ricardo, not a cleanup step.

A clone has no zips at all, and is not supposed to need them: `docs/USAGE.md`
builds and runs the game from source.

One packager writes all of this: **`tools/package_build.py`** (R77,
2026-09-22 — it is the former `package_codex.py`, promoted). It exports to an
explicit path instead of trusting the preset's `export_path`, then gates the
result before it will write a ZIP. `tools/package_game.sh` still works and is
now a wrapper around it; the separate `builds/codex/` flavour is gone.
