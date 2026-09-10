#!/usr/bin/env bash
# MP co-op gate (docs/tech/33): boots a host + a client on loopback and greps
# both verdicts. Exit 0 only if BOTH print their OK line.
set -u
cd "$(dirname "$0")/.."
LOG_A=$(mktemp)
LOG_B=$(mktemp)
timeout 90 godot --headless --path game res://mp/tests/mp_test.tscn -- --host >"$LOG_A" 2>&1 &
HOST_PID=$!
sleep 2   # let the host bind before the client dials
timeout 90 godot --headless --path game res://mp/tests/mp_test.tscn -- --join >"$LOG_B" 2>&1 &
JOIN_PID=$!
wait $HOST_PID; HOST_RC=$?
wait $JOIN_PID; JOIN_RC=$?
grep -h "MP HOST OK\|MP CLIENT OK\|MP TEST FAIL" "$LOG_A" "$LOG_B"
if [ $HOST_RC -eq 0 ] && [ $JOIN_RC -eq 0 ]; then
  echo "MP TEST OK"
  rm -f "$LOG_A" "$LOG_B"
  exit 0
fi
echo "MP TEST FAILED (host=$HOST_RC join=$JOIN_RC) — logs:"
tail -n 5 "$LOG_A"
tail -n 5 "$LOG_B"
rm -f "$LOG_A" "$LOG_B"
exit 1
