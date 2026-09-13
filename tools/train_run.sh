#!/usr/bin/env bash
# Isolated, cumulative training runs (Ricardo, 2026-09-13: "can't we have a test
# backup so i can test freely and cumulatively without overwriting stuff?
# perhaps if theres an active one we put the new registry inside a folder with
# the configs used and date as name (with date first…)").
#
# Every run gets its own folder under ml/runs/, named DATE FIRST then the
# config, so the folder sorts chronologically:
#
#   ml/runs/2026-09-13_1930__fen_boar__g20_p8_e4_j20_s2026/
#       config.json     every knob, git HEAD, host, godot/torch versions
#       registry.json   this run's registry (seeded from the deployed one)
#       weights/        this run's nets
#       progress/       per-key JSONL feeds (the console's format)
#       logs/           per-key trainer + gate output
#       summary.txt     wall time, gate verdicts, what to promote
#
# ml/serving/ is left ALONE — it stays the deployed registry the game and the
# training console read — until you promote a winner on purpose.
#
# Usage:
#   tools/train_run.sh --all                                  # every creature build
#   tools/train_run.sh --key fen_boar --build core.arena.fen_boar_alpha
#   tools/train_run.sh --all --label sweep-highpop             # name it
#   GENERATIONS=200 POP=10 EPISODES=6 tools/train_run.sh --all # the real budget
#   tools/train_run.sh --ppo --key cinder_drake --build core.arena.cinder_drake \
#       --opp-build core.arena.fen_boar_alpha                  # GPU PPO instead of ES
#   tools/train_run.sh --list                                  # every past run, oldest first
#   tools/train_run.sh --promote ml/runs/<run>                 # copy PASSING nets into ml/serving
#
# Env knobs (ES): GENERATIONS (20) POP (8) EPISODES (4) JOBS (nproc) SEED (2026)
#                 SPEED (max) OPPONENTS ("")
# Env knobs (PPO): STEPS (2000000) ENVS (32) ARCH (mlp) SELFPLAY_EVERY (4)
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"

GENERATIONS="${GENERATIONS:-20}"; POP="${POP:-8}"; EPISODES="${EPISODES:-4}"
JOBS="${JOBS:-$(nproc)}"; SEED="${SEED:-2026}"; SPEED="${SPEED:-max}"
OPPONENTS="${OPPONENTS:-}"
STEPS="${STEPS:-2000000}"; ENVS="${ENVS:-32}"; ARCH="${ARCH:-mlp}"
SELFPLAY_EVERY="${SELFPLAY_EVERY:-4}"
PYVENV="$REPO/ml/.venv/bin/python"

MODE="es"; ALL=0; KEY=""; BUILD=""; OPP_BUILD=""; LABEL=""; FRESH=0; NOTE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all) ALL=1; shift;;
    --key) KEY="$2"; shift 2;;
    --build) BUILD="$2"; shift 2;;
    --opp-build) OPP_BUILD="$2"; shift 2;;
    --label) LABEL="$2"; shift 2;;
    --note) NOTE="$2"; shift 2;;
    --fresh) FRESH=1; shift;;
    --ppo) MODE="ppo"; shift;;
    --list) MODE="list"; shift;;
    --promote) MODE="promote"; RUN_IN="${2:-}"; shift 2 || shift;;
    -h|--help) sed -n '2,40p' "$0"; exit 0;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done

# ---------- list -------------------------------------------------------------
if [ "$MODE" = "list" ]; then
  python3 - "$REPO" <<'PY'
import json, sys
from pathlib import Path
runs = sorted((Path(sys.argv[1]) / "ml" / "runs").glob("*/config.json"))
if not runs:
    print("no runs yet — tools/train_run.sh --all"); raise SystemExit(0)
for cfg_path in runs:                       # date-first names sort chronologically
    cfg = json.loads(cfg_path.read_text())
    run = cfg_path.parent
    reg = run / "registry.json"
    pol = json.loads(reg.read_text()).get("policies", []) if reg.exists() else []
    mine = [p for p in pol if p.get("created", "") >= cfg["started"]]
    passed = sum(1 for p in mine if p.get("deployed"))
    summary = (run / "summary.txt")
    wall = ""
    if summary.exists():
        for line in summary.read_text().splitlines():
            if line.startswith("wall:"): wall = line.split(":", 1)[1].strip()
    print(f"{run.name}")
    print(f"    {cfg['mode']} · {cfg.get('keys_label','')} · {cfg['knobs']}"
          f" · {len(mine)} nets, {passed} passed gate{' · ' + wall if wall else ''}")
    if cfg.get("note"): print(f"    note: {cfg['note']}")
PY
  exit 0
fi

# ---------- promote ----------------------------------------------------------
if [ "$MODE" = "promote" ]; then
  [ -n "${RUN_IN:-}" ] || { echo "usage: tools/train_run.sh --promote ml/runs/<run>" >&2; exit 2; }
  python3 - "$REPO" "$RUN_IN" <<'PY'
import json, shutil, sys
from pathlib import Path
repo, run = Path(sys.argv[1]), Path(sys.argv[2]).resolve()
src = run / "registry.json"
if not src.exists(): raise SystemExit(f"no registry in {run}")
cfg = json.loads((run / "config.json").read_text())
dst = repo / "ml" / "serving" / "registry.json"
dst_w = repo / "ml" / "serving" / "weights"; dst_w.mkdir(parents=True, exist_ok=True)
deployed = json.loads(dst.read_text()) if dst.exists() else \
    {"schema": "arena.registry.v1", "policies": []}
run_reg = json.loads(src.read_text())
promoted = []
for p in run_reg["policies"]:
    if not p.get("deployed") or p.get("created", "") < cfg["started"]:
        continue                              # only THIS run's gate-passing nets
    for field in ("game_json", "npz"):
        old = p.get(field)
        if not old: continue
        old_p = Path(old)
        if not old_p.exists() or dst_w in old_p.parents: continue
        new_p = dst_w / old_p.name
        shutil.copy2(old_p, new_p)
        p[field] = str(new_p)
    p["promoted_from"] = run.name
    versions = [q["version"] for q in deployed["policies"] if q["key"] == p["key"]]
    p["version"] = (max(versions) + 1) if versions else 1
    for q in deployed["policies"]:             # one deployed pin per key
        if q["key"] == p["key"]: q["deployed"] = False
    deployed["policies"].append(p)
    promoted.append(f"{p['key']} v{p['version']}")
if not promoted:
    raise SystemExit(f"nothing to promote from {run.name} (no net passed its gate)")
dst.write_text(json.dumps(deployed, indent=1))
print(f"[promote] {run.name} -> ml/serving: " + ", ".join(promoted))
print("[promote] re-gate from the deployed registry before shipping:")
for name in promoted:
    print(f"    python3 -m ml.training.league gate --key {name.split()[0]} --build <build>")
PY
  exit 0
fi

# ---------- start a run ------------------------------------------------------
[ $ALL -eq 1 ] || [ -n "$KEY" ] || { echo "need --all or --key KEY --build BUILD" >&2; exit 2; }
[ $ALL -eq 1 ] || [ -n "$BUILD" ] || { echo "--key needs --build" >&2; exit 2; }
[ "$MODE" != "ppo" ] || [ -n "$OPP_BUILD" ] || { echo "--ppo needs --opp-build" >&2; exit 2; }
[ "$MODE" != "ppo" ] || [ -x "$PYVENV" ] || { echo "PPO needs ml/.venv (torch)" >&2; exit 2; }

if [ $ALL -eq 1 ]; then KEYS_LABEL="all-creatures"; else KEYS_LABEL="$KEY"; fi
if [ -n "$LABEL" ]; then KEYS_LABEL="${KEYS_LABEL}-${LABEL}"; fi
if [ "$MODE" = "ppo" ]; then
  KNOBS="steps${STEPS}_envs${ENVS}_${ARCH}_sp${SELFPLAY_EVERY}"
else
  KNOBS="g${GENERATIONS}_p${POP}_e${EPISODES}_j${JOBS}_s${SEED}"
fi
STAMP="$(date +%Y-%m-%d_%H%M)"                     # DATE FIRST: the folder sorts by time
RUN="$REPO/ml/runs/${STAMP}__${KEYS_LABEL}__${KNOBS}"
[ ! -e "$RUN" ] || RUN="${RUN}_$(date +%S)"
mkdir -p "$RUN/weights" "$RUN/progress" "$RUN/logs"

ACTIVE="$(pgrep -fa 'ml\.training\.(league|ppo|evolve)' | grep -v train_run | head -3 || true)"
DEPLOYED="$REPO/ml/serving/registry.json"
if [ $FRESH -eq 0 ] && [ -f "$DEPLOYED" ]; then
  cp "$DEPLOYED" "$RUN/registry.json"              # cumulative: start from what is deployed
  SEEDED="deployed registry ($(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['policies']))" "$DEPLOYED") policies)"
else
  echo '{"schema": "arena.registry.v1", "policies": []}' > "$RUN/registry.json"
  SEEDED="empty (--fresh)"
fi

python3 - "$RUN" <<PY
import json, os, platform, subprocess, sys, time
from pathlib import Path
run = Path(sys.argv[1])
def sh(*c):
    try: return subprocess.run(c, capture_output=True, text=True, timeout=30).stdout.strip().splitlines()[0]
    except Exception: return "?"
torch_v = sh("$PYVENV", "-c", "import torch;print(torch.__version__, torch.cuda.is_available())")
json.dump({
  "started": time.strftime("%Y-%m-%dT%H:%M:%S"),
  "mode": "$MODE",
  "keys_label": "$KEYS_LABEL",
  "knobs": "$KNOBS",
  "note": """$NOTE""",
  "seeded_from": """$SEEDED""",
  "es": {"generations": $GENERATIONS, "pop": $POP, "episodes": $EPISODES,
         "jobs": $JOBS, "seed": $SEED, "speed": "$SPEED", "opponents": "$OPPONENTS"},
  "ppo": {"steps": $STEPS, "envs": $ENVS, "arch": "$ARCH",
          "selfplay_every": $SELFPLAY_EVERY, "build": "$BUILD", "opp_build": "$OPP_BUILD"},
  "env": {"git_head": sh("git", "rev-parse", "--short", "HEAD"),
          "git_dirty": bool(sh("git", "status", "--porcelain")),
          "godot": sh("godot", "--version"), "torch": torch_v,
          "host": platform.node(), "cores": os.cpu_count()},
  "other_trainers_running": """$ACTIVE""" or None,
}, open(run / "config.json", "w"), indent=2)
PY

echo "[train-run] $RUN"
echo "[train-run] isolated: DH_SERVING_DIR — ml/serving is untouched. Seeded from: $SEEDED"
[ -z "$ACTIVE" ] || echo "[train-run] NOTE: another trainer is running:"$'\n'"$ACTIVE"
export DH_SERVING_DIR="$RUN"
godot --headless --path game --import >/dev/null 2>&1 || true
T0=$(date +%s)

if [ "$MODE" = "ppo" ]; then
  echo "=== ppo $KEY ($BUILD vs $OPP_BUILD, $ARCH, $STEPS steps, $ENVS envs) ==="
  "$PYVENV" -u -m ml.training.ppo --key "$KEY" --build "$BUILD" \
      --opp-build "$OPP_BUILD" --steps "$STEPS" --envs "$ENVS" --arch "$ARCH" \
      --selfplay-every "$SELFPLAY_EVERY" --seed "$SEED" 2>&1 | tee "$RUN/logs/$KEY.log" | tail -3
  "$PYVENV" -u -m ml.training.league gate --key "$KEY" --build "$BUILD" \
      --episodes "$EPISODES" 2>&1 | tee -a "$RUN/logs/$KEY.log" | tail -3 || true
else
  if [ $ALL -eq 1 ]; then
    KEYS=$(python3 - <<'PY'
import json
for b in json.load(open("game/arena/data/builds.json"))["builds"]:
    if b.get("kind") == "creature":
        print(f"{b['id'].split('.')[-1]} {b['id']}")
PY
)
  else
    KEYS="$KEY $BUILD"
  fi
  OPP_ARG=(); [ -z "$OPPONENTS" ] || OPP_ARG=(--opponents "$OPPONENTS")
  echo "$KEYS" | while read -r key build; do
    [ -n "$key" ] || continue
    echo "=== $key ($build) ==="
    python3 -m ml.training.league train --key "$key" --build "$build" \
        --generations "$GENERATIONS" --pop "$POP" --episodes "$EPISODES" \
        --jobs "$JOBS" --seed "$SEED" --speed "$SPEED" "${OPP_ARG[@]}" \
        2>&1 | tee "$RUN/logs/$key.log" | tail -2
    python3 -m ml.training.league gate --key "$key" --build "$build" \
        --episodes "$EPISODES" 2>&1 | tee -a "$RUN/logs/$key.log" | tail -3 || true
  done
fi

WALL=$(( $(date +%s) - T0 ))
python3 - "$RUN" "$WALL" <<'PY'
import json, sys, time
from pathlib import Path
run, wall = Path(sys.argv[1]), int(sys.argv[2])
cfg = json.loads((run / "config.json").read_text())
reg = json.loads((run / "registry.json").read_text())
mine = [p for p in reg["policies"] if p.get("created", "") >= cfg["started"]]
lines = [f"run: {run.name}", f"started: {cfg['started']}",
         f"wall: {wall // 3600}h{(wall % 3600) // 60:02d}m{wall % 60:02d}s",
         f"mode: {cfg['mode']}  knobs: {cfg['knobs']}",
         f"seeded from: {cfg['seeded_from']}", ""]
for p in mine:
    ev = p.get("eval") or {}
    checks = ev.get("checks") or {}
    detail = " ".join(f"{k}={v.get('win_rate', v.get('pass'))}" for k, v in checks.items())
    lines.append(f"{p['key']} v{p['version']} "
                 f"{'PASS' if p.get('deployed') else 'fail'}  {detail}".rstrip())
if not mine:
    lines.append("no nets registered (did the trainer fail? check logs/)")
lines += ["", "promote the passing nets into ml/serving with:",
          f"    tools/train_run.sh --promote ml/runs/{run.name}"]
(run / "summary.txt").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY
