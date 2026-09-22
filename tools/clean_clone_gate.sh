#!/usr/bin/env bash
# R78 gate: a clean clone must still build and run without the zips.
#
# Since R78 the distributables are GitHub release assets, not tracked files. That
# is only safe if a fresh clone -- which gets no zips at all -- can still produce
# a running game from source, and can still find the published packages. This
# script proves both, from a real clone rather than from the working tree, so a
# file that only exists because it was never committed cannot fool it.
#
# Usage: bash tools/clean_clone_gate.sh [clone-dir]
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLONE="${1:-${TMPDIR:-/tmp}/dh-clean-clone-gate}"
rm -rf "$CLONE"

echo "=== 1. clone (no working tree carried over)"
git clone --quiet --no-hardlinks "file://$SRC" "$CLONE"
cd "$CLONE"
echo "HEAD: $(git log -1 --format='%h %s')"

echo "=== 2. the zips must NOT be there"
if ls builds/dragon-heroes-*.zip >/dev/null 2>&1; then
  echo "GATE FAIL: a zip came along in the clone"; exit 1
fi
echo "builds/ contents:"; ls -la builds/
test -f builds/BUILD-INFO.json || { echo "GATE FAIL: no builds/BUILD-INFO.json"; exit 1; }
python3 -c "import json;d=json.load(open('builds/BUILD-INFO.json'));print('index tag:   ',d['release_tag']);print('index commit:',d['release_commit']);print('index url:  ',d['release_url'])"

echo "=== 3. build the simulation workspace from source"
cmake -S sim -B sim/build -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build sim/build -j"$(nproc)" 2>&1 | tail -3

echo "=== 4. ctest"
ctest --test-dir sim/build --output-on-failure 2>&1 | tail -6

echo "=== 5. run it headless (the M0 harness)"
./sim/build/libs/dh-server/dh-server --entities 2000 --ticks 3000 2>&1 | tail -8

echo "=== 6. validate the content pack"
python3 tools/validate_content.py 2>&1 | tail -3

echo "=== 7. the index describes downloadable assets"
python3 - <<'PY'
import json, urllib.request
d = json.load(open("builds/BUILD-INFO.json"))
for plat, info in d["packages"].items():
    req = urllib.request.Request(info["download_url"], method="HEAD")
    with urllib.request.urlopen(req) as r:
        size = int(r.headers.get("Content-Length", -1))
    ok = "OK" if size == info["bytes"] else "MISMATCH"
    print(f"{plat}: HTTP {r.status} {size} B vs index {info['bytes']} B -> {ok}")
    assert size == info["bytes"], plat
PY

echo "CLEAN CLONE GATE OK: builds, tests, runs, and can fetch its own distributables"
