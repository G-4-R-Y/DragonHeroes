#!/usr/bin/env bash
# R51 gate — TRACE REPLAY OK.
#
# Guards the whole dh-env -> arena replay chain: the C trace buffer
# (sim/libs/dh-env), the recorder (ml/eval/trace_match.py), the replay mind
# (game/arena/trace_policy.gd) and the ghost overlay (game/arena/trace_ghosts.gd).
#
# WHAT IS ACTUALLY ASSERTED. A duel fought at RANGE replays almost exactly: the
# same commands, fed into the arena's real bodies, reproduce the recorded motion
# to within a body's width. That single number is a surprisingly broad guard —
# break the frame layout, the side stride, the dodge FLAG bit, the tick clock or
# the ghost's cursor and it blows up immediately.
#
# A duel fought at CONTACT does not replay today (docs/harness/21-work-journal.md,
# R51): the pair never closes, so nothing is asserted about it here. Gating on a
# known-bad number only cements it — the contact case runs for its numbers,
# printed as INFO, so the day it converges someone notices.
#
# The reference pairing is deliberate, not arbitrary. cinder_drake vs the
# SCRIPTED mind is a standoff (mean body gap 28.5 px); the same creature vs the
# NATIVE mind closes to 17 px and diverges like the boar does. The gate wants
# the chain under test, not the open bug.
#
#   bash tools/trace_replay_test.sh     # -> TRACE REPLAY OK
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RANGED="core.arena.cinder_drake"         # vs scripted: a standoff — the reference
CONTACT="core.arena.fen_boar_alpha"      # vs native: close quarters — informational
OUT="$REPO/ml/runs/traces/gate-ranged.json"
CONTACT_OUT="$REPO/ml/runs/traces/gate-contact.json"

# Generous enough never to flake on float order, tight enough that any real
# break in the chain lands far outside. Measured 2026-09-22: mean 0.43/0.81,
# peak 5.63, gap 28.5 vs 28.5.
MAX_MEAN=3.0
MAX_PEAK=15.0
MAX_GAP_RATIO=1.15

fail() { echo "TRACE REPLAY FAIL: $*"; exit 1; }

[ -f "$REPO/sim/build/libs/dh-env/libdh-env.so" ] || \
  fail "libdh-env.so missing — build it: cmake --build sim/build -j"

cd "$REPO" || fail "cannot enter $REPO"
mkdir -p ml/runs/traces

record() {   # build, opp, seed, out
  python3 -m ml.eval.trace_match --build "$1" --policy heuristic --opp "$2" \
      --seed "$3" --out "$4" >/dev/null 2>&1 \
    || fail "recorder failed for $1 vs $2 (run it by hand for the traceback)"
  [ -s "$4" ] || fail "recorder wrote no trace for $1"
}

replay() {   # trace path -> the ARENA REPLAY line
  timeout 300 godot --headless --path game res://arena/arena.tscn -- \
      --replay "$1" --fast 2>&1 | grep -E "^ARENA REPLAY drift" | tail -1
}

record "$RANGED" scripted 3 "$OUT"

# The trace is a contract before it is a measurement: a replay that silently
# read the wrong stride would still produce numbers, just meaningless ones.
python3 - "$OUT" <<'PY' || fail "trace document is malformed"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["schema"] == "arena.trace.v1", d["schema"]
sf, st, F = d["side_fields"], d["stride"], d["frames"]
assert st == 1 + 2 * sf, (st, sf)
assert F and all(len(r) == st for r in F), "ragged frames"
assert F[0][0] == 0 and F[-1][0] == len(F) - 1, "ticks are not 0..n-1"
PY

LINE="$(replay "$OUT")"
[ -n "$LINE" ] || fail "no ARENA REPLAY line — the arena did not replay $OUT"
echo "$LINE"

python3 - "$LINE" "$MAX_MEAN" "$MAX_PEAK" "$MAX_GAP_RATIO" <<'PY' || exit 1
import sys
kv = dict(p.split("=", 1) for p in sys.argv[1].split() if "=" in p)
mean, peak, ratio = (float(x) for x in sys.argv[2:5])
bad = []
for side in ("a", "b"):
    if float(kv["drift_mean_" + side]) > mean:
        bad.append("drift_mean_%s=%s > %.1f" % (side, kv["drift_mean_" + side], mean))
    if float(kv["drift_peak_" + side]) > peak:
        bad.append("drift_peak_%s=%s > %.1f" % (side, kv["drift_peak_" + side], peak))
    if kv["break_tick_" + side] != "-1":
        bad.append("break_tick_%s=%s (the pair came apart)" % (side, kv["break_tick_" + side]))
if kv["recorded_winner"] != kv["replayed_winner"]:
    bad.append("winner %s -> %s" % (kv["recorded_winner"], kv["replayed_winner"]))
# The fight must stay the same fight: two bodies the same distance apart, on
# average, or the strikes that land are not the strikes that were recorded.
rec, now = float(kv["gap_rec"]), float(kv["gap_now"])
if rec > 0.0 and not (1.0 / ratio <= now / rec <= ratio):
    bad.append("gap %.1f -> %.1f" % (rec, now))
if bad:
    print("TRACE REPLAY FAIL: " + "; ".join(bad))
    sys.exit(1)
PY

record "$CONTACT" native 7 "$CONTACT_OUT"
CONTACT_LINE="$(replay "$CONTACT_OUT")"
[ -n "$CONTACT_LINE" ] || fail "no ARENA REPLAY line for the contact trace"
echo "INFO (not gated — the known contact-range divergence): $CONTACT_LINE"

echo "TRACE REPLAY OK"
