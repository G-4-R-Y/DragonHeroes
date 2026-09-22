# Prebuilt Windows worldgen binary

`dh-server.exe` — the C++ worldgen/server binary, cross-compiled for Windows.
`tools/package_game.sh windows` copies it next to the game executable inside
`builds/dragon-heroes-windows.zip`; without it the packaged Windows build has no
infinite world and no co-op world parity.

| | |
|---|---|
| sha256 | `246445fa35cf3de24ed80edd265730eaf48c8377fbb072a7bfd158fb0d8b4349` |
| size | 97,792 bytes |
| target | PE32+ x86-64, MS Windows console |
| toolchain | portable llvm-mingw, `sim/cmake/mingw-w64-x86_64.cmake` |
| first committed | `674d57b` (as `sim/build-windows/dh-server.exe`) |

## Why a binary is in the tree

It is a **cache, not a source of truth** — `sim/` builds it from scratch. It
lives here so a fresh clone on a machine without the mingw toolchain can still
produce a complete Windows zip, which is the one thing most contributors cannot
reproduce locally.

It used to ride along inside a fully committed 137-file CMake build tree
(`sim/build-windows/`: `CMakeCache.txt`, object files, generated Makefiles,
compiler logs) that `.gitignore` had *already* been told to ignore. That tree is
untracked now; the 97 KB artifact that was actually load-bearing moved here,
where the path says what it is and nobody will delete it while clearing build
directories.

## Rebuilding it

```sh
cmake -S sim -B sim/build-windows \
  -DCMAKE_TOOLCHAIN_FILE=$PWD/sim/cmake/mingw-w64-x86_64.cmake \
  -DCMAKE_BUILD_TYPE=Release && cmake --build sim/build-windows -j
cp sim/build-windows/libs/dh-server/dh-server.exe builds/prebuilt/windows/
```

`tools/package_game.sh` prefers a fresh local cross-build
(`sim/build-windows/dh-server.exe`) over this copy, so a rebuild wins
automatically and this file only matters when no local build exists. Refresh it
whenever `sim/` changes in a way that affects worldgen.
