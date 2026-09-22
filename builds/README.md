# builds/ — distributables

What players receive, plus the one binary that cannot be rebuilt everywhere.

| Path | Tracked? | What it is |
|---|---|---|
| `dragon-heroes-linux.zip` | yes | The shipped Linux build (`tools/package_game.sh linux`). |
| `dragon-heroes-windows.zip` | yes | The shipped Windows build (`tools/package_game.sh windows`). |
| `prebuilt/windows/dh-server.exe` | yes | Cross-build cache of the worldgen binary, so a clone without the mingw toolchain can still produce a complete Windows zip. See its README. |
| `linux/`, `windows/` | no | Raw Godot export dirs the zips are made from — regenerated every package run, and over GitHub's 100 MB limit. |
| `trainer/`, `console/`, `codex/` | no | The ~96 MB arena trainer export, the Arena Console app, and Codex cross-build output. |

Everything untracked here is listed in `.gitignore` — the zips are the
distributable, the export directories are scratch.
