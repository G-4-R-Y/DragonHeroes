# builds/ — distributables

What players receive, plus the one binary that cannot be rebuilt everywhere.

| Path | Tracked? | What it is |
|---|---|---|
| `dragon-heroes-linux.zip` | yes | The shipped Linux build (`tools/package_build.py linux`). |
| `dragon-heroes-windows.zip` | yes | The shipped Windows build (`tools/package_build.py windows`). |
| `prebuilt/windows/dh-server.exe` | yes | Cross-build cache of the worldgen binary, so a clone without the mingw toolchain can still produce a complete Windows zip. See its README. |
| `linux/`, `windows/` | no | Raw Godot export dirs the zips are made from — regenerated every package run, and over GitHub's 100 MB limit. |
| `trainer/`, `console/` | no | The ~96 MB arena trainer export and the Arena Console app. |

Everything untracked here is listed in `.gitignore` — the zips are the
distributable, the export directories are scratch.

One packager writes all of this: **`tools/package_build.py`** (R77,
2026-09-22 — it is the former `package_codex.py`, promoted). It exports to an
explicit path instead of trusting the preset's `export_path`, then gates the
result before it will write a ZIP. `tools/package_game.sh` still works and is
now a wrapper around it; the separate `builds/codex/` flavour is gone.
