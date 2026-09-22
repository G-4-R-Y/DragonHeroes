#!/usr/bin/env bash
# R56 gate — TRAINER STOP OK.
#
# Guards the stop path in `game/arena/console.gd` (`_spawn_league` / `_stop` /
# `_reap_group`). Ricardo, 2026-09-21: "GPU processes are not ended properly
# after training in the console."
#
# The old path was `kill -STOP pid; pkill -KILL -P pid; kill -KILL pid`.
# `pkill -P` reaches exactly ONE generation, so anything the trainer spawned one
# level deeper outlived Stop and kept holding the card. The fix launches the
# trainer under `setsid`, giving it a session of its own, and kills the whole
# PROCESS GROUP.
#
# The group kill is only safe BECAUSE of setsid: Godot's children inherit
# Godot's process group, so signalling a group we did not create would kill the
# editor running the console. console.gd proves ownership by requiring
# pgid == pid before it ever uses the `-PGID` form; this gate asserts that
# invariant holds for the exact command string the console builds.
#
#   bash tools/trainer_stop_test.sh     # -> TRAINER STOP OK
set -u

fail() { echo "TRAINER STOP FAIL: $*"; exit 1; }

# A stand-in trainer with a real GRANDCHILD: python -> bash -> sleep. The
# `& wait` defeats bash's exec-the-last-command optimization, which would
# otherwise collapse the grandchild into a direct child and hide the bug.
TRAINER='python3 -c "
import subprocess,time
subprocess.Popen([\"bash\",\"-c\",\"sleep 120 & wait\"])
time.sleep(120)"'

# Sets PID / PGID. Deliberately NOT a command substitution: `$(...)` reads until
# the write end of its pipe closes, and the spawned trainer inherits that pipe —
# the fixture would be held hostage by its own plumbing. It also redirects the
# trainer's stdout, exactly as console.gd appends it to a log file.
spawn() {   # mirrors console.gd::_spawn_league
  bash -lc "exec setsid $TRAINER" >/dev/null 2>&1 &
  PID=$!
  disown "$PID" 2>/dev/null   # kills are expected; keep job-control notices out of the gate output
  PGID=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.3
    PGID=$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ')
    [ -n "$PGID" ] && [ "$(pgrep -g "$PGID" 2>/dev/null | wc -l)" -ge 3 ] && break
  done
}

alive() { pgrep -g "$1" 2>/dev/null | wc -l; }
cleanup() { [ -n "${1:-}" ] && kill -KILL -- "-$1" 2>/dev/null; }

# ---- 1. the old one-generation reap must LEAK (this is the bug) -----------------
spawn
pid=$PID; pgid=$PGID
[ -n "$pgid" ] || fail "could not read the trainer's pgid"
[ "$pgid" = "$pid" ] || fail "setsid did not make the trainer a group leader (pgid=$pgid pid=$pid)"
before=$(alive "$pgid")
[ "$before" -ge 3 ] || fail "fixture did not start: only $before processes in the group"
kill -STOP "$pid" 2>/dev/null; pkill -KILL -P "$pid"; kill -KILL "$pid" 2>/dev/null
sleep 1
leaked=$(alive "$pgid")
cleanup "$pgid"
[ "$leaked" -gt 0 ] || fail "the old path reaped everything — the fixture no longer has a grandchild, so this gate proves nothing"

# ---- 2. the group reap must leave NOTHING ---------------------------------------
spawn
pid=$PID; pgid=$PGID
[ "$pgid" = "$pid" ] || fail "setsid did not make the trainer a group leader (pgid=$pgid pid=$pid)"
before=$(alive "$pgid")
[ "$before" -ge 3 ] || fail "fixture did not start: only $before processes in the group"
kill -STOP -- "-$pgid" 2>/dev/null; kill -KILL -- "-$pgid" 2>/dev/null
sleep 1
left=$(alive "$pgid")
cleanup "$pgid"
[ "$left" -eq 0 ] || fail "group kill left $left process(es) alive"

echo "TRAINER STOP OK — group of $before reaped whole; the old one-generation path leaked $leaked"
