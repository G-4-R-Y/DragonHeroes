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
#   tools/train_run.sh --tournament --all                      # the METHOD BRACKET per creature
#   tools/train_run.sh --tournament --key fen_boar --build core.arena.fen_boar_alpha
#   GENERATIONS=200 POP=10 EPISODES=6 tools/train_run.sh --all # the real budget
#   tools/train_all.sh --ppo --steps 8000000                  # PPO over EVERY creature
#   CLONE=heuristic tools/train_all.sh --ppo                  # clone the heuristic first
#   tools/train_run.sh --ppo --key cinder_drake --build core.arena.cinder_drake \
#       --opp-build core.arena.fen_boar_alpha                  # GPU PPO instead of ES
#   tools/train_run.sh --run-dir ml/runs/<name> --key ... --build ...   # caller names it
#   tools/train_run.sh --resume ml/runs/<run>                  # continue a killed run
#   tools/train_run.sh --list                                  # every past run, oldest first
#   tools/train_run.sh --promote ml/runs/<run>                 # copy PASSING nets into ml/serving
#
# Env knobs (ES): GENERATIONS (20) POP (8) EPISODES (4) JOBS (desktop: min(nproc-4, 16); throughput: nproc) SEED (2026)
#                 SPEED (max) OPPONENTS ("") CHECKPOINT_EVERY (25)
# Env knobs (both): NET ("" = the deployed 64x64 tanh). An architecture preset
#                 from ml/training/architectures.json — `python3 -m ml.training.arch`
#                 lists them with their per-tick cost. It lands in config.json, so a
#                 run folder always says which architecture produced its nets.
#                   NET=relu-wide tools/train_run.sh --ppo --key ...   # a teacher
#
# CHECKPOINT_EVERY exists because the trainer registers its net only when the
# WHOLE generation loop finishes: without it, killing a 1000-generation run
# throws away every hour of it. With it, --resume continues from the last saved
# generation, reusing the same run folder (and therefore the same registry,
# weights and progress feed).
# Env knobs (PPO): STEPS (2000000) ENVS (512) ARCH (mlp) SELFPLAY_EVERY (4)
#                  CLONE ('' | heuristic) PROMOTE_WR (0.60) PROMOTE_HOLD (3)
#                  EVAL_ENVS (64) DEMOTE_WR (0.45) RESERVOIR (8)           # R50, 2026-09-19
#                  ENTROPY_FINAL (0.001) MOVE_STD_FINAL (0.1)             # annealing
#                  PLATEAU_UPDATES (0=off) PLATEAU_DELTA (0.02) PLATEAU_MIN_STEPS (0)
#
# --tournament is TRAIN ALL's other gear. The plain sweep trains every creature
# ONE way (ES, or PPO with --ppo) and assumes that was the right way; the
# tournament sweep makes the methods compete per creature: each trains the same
# key in its own subprocess, each is gated against the same pre-tournament pin,
# then the candidates FIGHT best-of-N and only the winner takes the pin
# (ml/training/tournament.py). Same run folder, same $DH_SERVING_DIR isolation,
# same per-key progress feed — the console's chart follows it unchanged.
# Env knobs (tournament): METHODS (es,ppo) BEST_OF (5) BRACKET_EPISODES (1)
#                 GATE_EPISODES (= EPISODES; 0 skips the gate) METHOD_TIMEOUT (0 = none)
#                 TEACHER ("" — a wide net's key for the `distill` method)
# The ES knobs above feed the bracket's es entrant and the PPO knobs its ppo
# entrant, so one set of dials drives the whole bracket:
#   METHODS=es,ppo,distill TEACHER=cinder_drake BEST_OF=9 tools/train_run.sh --tournament --all
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
# shellcheck source=tools/dh_term.sh
source "$REPO/tools/dh_term.sh"      # palette, dragon banner, rules, bars

GENERATIONS="${GENERATIONS:-20}"; POP="${POP:-8}"; EPISODES="${EPISODES:-4}"
# Leave room for the game/desktop. Explicit JOBS keeps its requested value;
# TRAIN_PROFILE=throughput opts into the old all-CPU default for an idle machine.
TRAIN_PROFILE="${TRAIN_PROFILE:-desktop}"
case "$TRAIN_PROFILE" in desktop|throughput) ;; *) echo "TRAIN_PROFILE must be desktop or throughput" >&2; exit 2;; esac
TRAIN_CPUS="$(nproc)"
TRAIN_DEFAULT_JOBS="$TRAIN_CPUS"
if [ "$TRAIN_PROFILE" = desktop ]; then
  # Measured 2026-09-13, idle 20-thread box, pop 10 / 13 episodes / 2 opponents,
  # resident arena workers: jobs 4 -> 9.6 s/gen, 8 -> 7.4, 10 -> 7.1, 12 -> 7.0,
  # 16 -> 6.4, 20 -> 6.4. 16 and 20 TIE, so capping at 16 costs nothing and still
  # hands 4 threads back to the desktop. Ricardo, 2026-09-13: "perhaps we should
  # cap at 16? ... we are compute bound, not parallel worker bound" — he is right.
  # PREVIOUS DEFAULT (kept for reference, min(nproc/2, 4) = 4 jobs here = 1.5x slower):
  #   TRAIN_DEFAULT_JOBS=$((TRAIN_CPUS / 2))
  #   [ "$TRAIN_DEFAULT_JOBS" -ge 1 ] || TRAIN_DEFAULT_JOBS=1
  #   [ "$TRAIN_DEFAULT_JOBS" -le 4 ] || TRAIN_DEFAULT_JOBS=4
  TRAIN_DEFAULT_JOBS=$((TRAIN_CPUS - 4))
  [ "$TRAIN_DEFAULT_JOBS" -ge 1 ] || TRAIN_DEFAULT_JOBS=1
  [ "$TRAIN_DEFAULT_JOBS" -le 16 ] || TRAIN_DEFAULT_JOBS=16
fi
JOBS="${JOBS:-$TRAIN_DEFAULT_JOBS}"; SEED="${SEED:-2026}"; SPEED="${SPEED:-max}"
OPPONENTS="${OPPONENTS:-}"; CHECKPOINT_EVERY="${CHECKPOINT_EVERY:-25}"
STEPS="${STEPS:-2000000}"; ENVS="${ENVS:-512}"; ARCH="${ARCH:-mlp}"  # ENVS was 32 pre-batching
# The opponent curriculum (tech/25 5.1.2). CLONE=heuristic prepends the
# behaviour-cloning stage; PROMOTE_* decide when scripts give way to self-play.
PROMOTE_WR="${PROMOTE_WR:-0.60}"; PROMOTE_HOLD="${PROMOTE_HOLD:-3}"
# R50 (2026-09-19): greedy probes (the number that SHIPS), reversible promotion,
# snapshot reservoir, entropy/move-std annealing and the plateau stop. Each is
# explained in ml/training/ppo.py --help and TRAINING_HYPERPARAMETERS.md (root).
EVAL_ENVS="${EVAL_ENVS:-64}"; DEMOTE_WR="${DEMOTE_WR:-0.45}"; RESERVOIR="${RESERVOIR:-8}"
ENTROPY_FINAL="${ENTROPY_FINAL:-0.001}"; MOVE_STD_FINAL="${MOVE_STD_FINAL:-0.1}"
PLATEAU_UPDATES="${PLATEAU_UPDATES:-0}"; PLATEAU_DELTA="${PLATEAU_DELTA:-0.02}"
PLATEAU_MIN_STEPS="${PLATEAU_MIN_STEPS:-0}"
CLONE="${CLONE:-}"
# NET is the SHAPE (architectures.json); ARCH above is the older mlp-vs-gru axis.
NET="${NET:-}"; NET_ARG=(); [ -z "$NET" ] || NET_ARG=(--net "$NET")
SELFPLAY_EVERY="${SELFPLAY_EVERY:-4}"
# --tournament: the bracket's own dials. GATE_EPISODES defaults to EPISODES so
# the tournament gate is exactly as strict as the sweep gate it replaces.
METHODS="${METHODS:-es,ppo}"; BEST_OF="${BEST_OF:-5}"
BRACKET_EPISODES="${BRACKET_EPISODES:-1}"; GATE_EPISODES="${GATE_EPISODES:-$EPISODES}"
METHOD_TIMEOUT="${METHOD_TIMEOUT:-0}"; TEACHER="${TEACHER:-}"
PYVENV="$REPO/ml/.venv/bin/python"

MODE="es"; ALL=0; KEY=""; BUILD=""; OPP_BUILD=""; LABEL=""; FRESH=0; NOTE=""
RUN_DIR=""            # --run-dir: the caller names the folder (the console does)
RESUME_RUN=""         # --resume: continue that run folder from its checkpoints
while [ $# -gt 0 ]; do
  case "$1" in
    --all) ALL=1; shift;;
    --key) KEY="$2"; shift 2;;
    --build) BUILD="$2"; shift 2;;
    --opp-build) OPP_BUILD="$2"; shift 2;;
    --label) LABEL="$2"; shift 2;;
    --note) NOTE="$2"; shift 2;;
    --fresh) FRESH=1; shift;;
    --run-dir) RUN_DIR="$2"; shift 2;;
    --resume) RESUME_RUN="$2"; shift 2;;
    --ppo) MODE="ppo"; shift;;
    --tournament) MODE="tournament"; shift;;
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
if [ -z "$RESUME_RUN" ]; then      # a resume reads all of this back from config.json
  [ $ALL -eq 1 ] || [ -n "$KEY" ] || { echo "need --all or --key KEY --build BUILD" >&2; exit 2; }
  [ $ALL -eq 1 ] || [ -n "$BUILD" ] || { echo "--key needs --build" >&2; exit 2; }
fi
# --all trains every creature as a MIRROR (opp_build = build, below), so the
# opponent flag is only required for a single --key run. This guard used to fire
# on --all too, which made the documented `train_all.sh --ppo` exit 2 (R50, 2026-09-19).
[ "$MODE" != "ppo" ] || [ $ALL -eq 1 ] || [ -n "$OPP_BUILD" ] || { echo "--ppo needs --opp-build (or --all)" >&2; exit 2; }
[ "$MODE" != "ppo" ] || [ -x "$PYVENV" ] || { echo "PPO needs ml/.venv (torch)" >&2; exit 2; }
# A bracket has no checkpoint to resume from: a method is a whole subprocess and
# the fight only means anything once every entrant finished. Say so instead of
# silently retraining hours of work under the same folder.
[ "$MODE" != "tournament" ] || [ -z "$RESUME_RUN" ] || {
  echo "--resume cannot continue a tournament run (a bracket has no per-generation checkpoint)." >&2
  echo "Start a new one, or resume the ES sweep with --resume and no --tournament." >&2; exit 2; }

if [ $ALL -eq 1 ]; then KEYS_LABEL="all-creatures"; else KEYS_LABEL="$KEY"; fi
if [ -n "$LABEL" ]; then KEYS_LABEL="${KEYS_LABEL}-${LABEL}"; fi
if [ "$MODE" = "ppo" ]; then
  KNOBS="steps${STEPS}_envs${ENVS}_${ARCH}_sp${SELFPLAY_EVERY}_ev${EVAL_ENVS}"
  [ "$PLATEAU_UPDATES" = 0 ] || KNOBS="${KNOBS}_pl${PLATEAU_UPDATES}"
elif [ "$MODE" = "tournament" ]; then
  KNOBS="bracket-$(echo "$METHODS" | tr ',' '-')_bo${BEST_OF}_g${GENERATIONS}_p${POP}_e${EPISODES}"
else
  KNOBS="g${GENERATIONS}_p${POP}_e${EPISODES}_j${JOBS}_s${SEED}"
fi
# Decide the key/build pairs up front and RECORD them: that is what makes
# `--resume <run>` need no other flags — the folder knows what it was training.
if [ $ALL -eq 1 ]; then
  KEYS=$(python3 - <<'PY'
import json
for b in json.load(open("game/arena/data/builds.json"))["builds"]:
    if b.get("kind") == "creature":
        print(f"{b['id'].split('.')[-1]} {b['id']}")
PY
)
elif [ -n "$KEY" ]; then
  KEYS="$KEY $BUILD"
else
  KEYS=""
fi

STAMP="$(date +%Y-%m-%d_%H%M)"                     # DATE FIRST: the folder sorts by time
if [ -n "$RESUME_RUN" ]; then
  case "$RESUME_RUN" in /*) RUN="$RESUME_RUN";; *) RUN="$REPO/$RESUME_RUN";; esac
  [ -f "$RUN/config.json" ] || { echo "not a run folder: $RESUME_RUN" >&2; exit 2; }
elif [ -n "$RUN_DIR" ]; then
  case "$RUN_DIR" in /*) RUN="$RUN_DIR";; *) RUN="$REPO/$RUN_DIR";; esac
else
  RUN="$REPO/ml/runs/${STAMP}__${KEYS_LABEL}__${KNOBS}"
  [ ! -e "$RUN" ] || RUN="${RUN}_$(date +%S)"
fi
mkdir -p "$RUN/weights" "$RUN/progress" "$RUN/logs"

ACTIVE="$(pgrep -fa 'ml\.training\.(league|ppo|evolve)' | grep -v train_run | head -3 || true)"
DEPLOYED="$REPO/ml/serving/registry.json"
if [ -n "$RESUME_RUN" ]; then
  SEEDED="resumed — this run's own registry, untouched"
  KEYS_FROM_CONFIG=1
  # the knobs must match the killed run or the checkpoint will not apply;
  # read them back instead of trusting the environment
  eval "$(python3 - "$RUN" <<'PY'
import json, sys
from pathlib import Path
cfg = json.loads((Path(sys.argv[1]) / "config.json").read_text())
es = cfg.get("es", {})
for k, v in (("GENERATIONS", es.get("generations")), ("POP", es.get("pop")),
             ("EPISODES", es.get("episodes")), ("SEED", es.get("seed")),
             ("SPEED", es.get("speed")), ("KEYS_LABEL", cfg.get("keys_label")),
             ("OPPONENTS", es.get("opponents")), ("MODE", cfg.get("mode"))):
    if v is not None:
        print(f"{k}={json.dumps(str(v))}")
pairs = cfg.get("keys") or []
if pairs:
    print("KEYS=" + json.dumps("\n".join(f"{k} {b}" for k, b in pairs)))
else:      # runs created before config.json recorded the pairs
    print("KEYS_FROM_CONFIG=0")
PY
)"
  if [ "${KEYS_FROM_CONFIG:-1}" = "0" ]; then
    # an older run folder: fall back to the label, or make the caller say
    [ "${KEYS_LABEL#all}" != "$KEYS_LABEL" ] && KEYS=$(python3 - <<'PY'
import json
for b in json.load(open("game/arena/data/builds.json"))["builds"]:
    if b.get("kind") == "creature":
        print(f"{b['id'].split('.')[-1]} {b['id']}")
PY
)
    [ -n "$KEYS" ] || { echo "this run folder predates recorded keys — add --key KEY --build BUILD" >&2; exit 2; }
  fi
elif [ $FRESH -eq 0 ] && [ -f "$DEPLOYED" ]; then
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
  "keys": [tuple(l.split(None, 1)) for l in """$KEYS""".strip().splitlines() if l.strip()],
  "knobs": "$KNOBS",
  "note": """$NOTE""",
  "seeded_from": """$SEEDED""",
  "es": {"generations": $GENERATIONS, "pop": $POP, "episodes": $EPISODES,
         "jobs": $JOBS, "seed": $SEED, "speed": "$SPEED", "opponents": "$OPPONENTS"},
  "ppo": {"steps": $STEPS, "envs": $ENVS, "arch": "$ARCH",
          "selfplay_every": $SELFPLAY_EVERY, "build": "$BUILD", "opp_build": "$OPP_BUILD",
          "promote_wr": $PROMOTE_WR, "promote_hold": $PROMOTE_HOLD, "clone": "$CLONE",
          "eval_envs": $EVAL_ENVS, "demote_wr": $DEMOTE_WR, "reservoir": $RESERVOIR,
          "entropy_final": $ENTROPY_FINAL, "move_std_final": $MOVE_STD_FINAL,
          "plateau_updates": $PLATEAU_UPDATES, "plateau_delta": $PLATEAU_DELTA,
          "plateau_min_steps": $PLATEAU_MIN_STEPS, "action_mask": "arena.mask.v1"},
  "tournament": {"methods": "$METHODS", "best_of": $BEST_OF,
                 "bracket_episodes": $BRACKET_EPISODES, "gate_episodes": $GATE_EPISODES,
                 "method_timeout": $METHOD_TIMEOUT, "teacher": "$TEACHER"},
  "net": "$NET" or "default",
  "env": {"git_head": sh("git", "rev-parse", "--short", "HEAD"),
          "git_dirty": bool(sh("git", "status", "--porcelain")),
          "godot": sh("godot", "--version"), "torch": torch_v,
          "host": platform.node(), "cores": os.cpu_count()},
  "other_trainers_running": """$ACTIVE""" or None,
}, open(run / "config.json", "w"), indent=2)
PY

dh_banner "DRAGON HEROES" "TRAINING FORGE · isolated, cumulative runs"
dh_kv run "${RUN#"$REPO"/}"
dh_kv mode "$MODE · $KEYS_LABEL · $KNOBS"
[ -z "$NET" ] || dh_kv net "$NET (ml/training/architectures.json)"
dh_kv resources "$TRAIN_PROFILE profile · $JOBS jobs (explicit JOBS overrides defaults)"
dh_kv seeded "$SEEDED"
if [ "$MODE" = "tournament" ]; then
  dh_kv bracket "$METHODS · best-of $BEST_OF · gate $GATE_EPISODES episodes — the methods compete, the winner takes the pin"
  dh_kv checkpoint "none — a bracket restarts from the top (each method is a whole subprocess)"
else
  dh_kv checkpoint "every $CHECKPOINT_EVERY generations — kill it and resume with: tools/train_run.sh --resume ${RUN#"$REPO"/}"
fi
dh_kv isolated "DH_SERVING_DIR=$RUN — ml/serving is untouched"
dh_kv watch "tools/train_watch.py ${RUN#"$REPO"/}"
[ -z "$NOTE" ] || dh_kv note "$NOTE"
[ -z "$ACTIVE" ] || { dh_warn "another trainer is already running:"; echo "$ACTIVE" | sed 's/^/      /'; }
echo
export DH_SERVING_DIR="$RUN"
godot --headless --path game --import >/dev/null 2>&1 || true
T0=$(date +%s)

if [ "$MODE" = "ppo" ]; then
  # PPO over EVERY creature, not just one. `--ppo` read $KEY alone, so
  # `train_all.sh --ppo` silently trained a single key — Ricardo, 2026-09-14:
  # "run a train_all experiment (even with PPO only)". With --all it loops the
  # same key list the ES and tournament branches use; each creature trains as a
  # mirror, which is what the gate measures.
  if [ $ALL -eq 1 ]; then PPO_KEYS="$KEYS"; else PPO_KEYS="$KEY $BUILD"; fi
  N_KEYS=$(echo "$PPO_KEYS" | grep -c . || true); I_KEY=0
  echo "$PPO_KEYS" | while read -r key build; do
    [ -n "$key" ] || continue
    I_KEY=$((I_KEY + 1))
    if [ $ALL -eq 1 ]; then opp_build="$build"; else opp_build="${OPP_BUILD:-$build}"; fi
    dh_rule "$I_KEY/$N_KEYS  ppo $key"
    dh_kv build "$build  vs  $opp_build"
    dh_kv budget "$STEPS steps · $ENVS envs · $ARCH · self-play every $SELFPLAY_EVERY"
    dh_kv curriculum "scripts first, self-play at GREEDY win rate $PROMOTE_WR held $PROMOTE_HOLD updates; demote below $DEMOTE_WR; reservoir $RESERVOIR"
    dh_kv greedy "$EVAL_ENVS argmax probes ride the batch (never trained on) — greedy= is the number that ships"
    dh_kv anneal "entropy 0.01 -> $ENTROPY_FINAL, move std 0.3 -> $MOVE_STD_FINAL over the budget"
    [ "$PLATEAU_UPDATES" = 0 ] || dh_kv plateau "stop when greedy= gains < $PLATEAU_DELTA for $PLATEAU_UPDATES updates (armed after $PLATEAU_MIN_STEPS steps)"
    # STAGE 0 - clone the heuristic first (tech/25 5.1.2). OFF by default,
    # because it changes where the policy starts: CLONE=heuristic warm-starts
    # PPO from a net that already walks at the enemy instead of one whose move
    # head emits 0.110 +- 0.006 no matter where the enemy is.
    WARM_ARG=()
    if [ "${CLONE:-}" = "heuristic" ]; then
      dh_kv clone "behaviour-cloning the five-rule heuristic before PPO"
      # SOFT on purpose. distill refuses a teacher that does not beat BOTH
      # baselines (Ricardo's condition, "once they surpass the default
      # script/engine behaviour"), and MEASURED 2026-09-14 the five-rule
      # heuristic clears `scripted` on some builds and not others — drake and
      # golem yes, fen_boar and gloamfen_stalker no. A build with no qualifying
      # teacher should train from scratch through the curriculum, not abort the
      # sweep for the builds that follow it.
      "$PYVENV" -u -m ml.training.distill --key "${key}_clone" --build "$build" \
          --teacher heuristic --opp scripted 2>&1 \
          | tee "$RUN/logs/${key}_clone.log" \
          || dh_warn "clone $key did not qualify - PPO starts cold for this build"
      CLONE_JSON=$(python3 "$REPO/tools/dh_latest_net.py" "$RUN/registry.json" "${key}_clone")
      if [ -n "$CLONE_JSON" ]; then
        WARM_ARG=(--warm-start "$CLONE_JSON")
      else
        dh_warn "clone produced no net for $key - PPO starts cold"
      fi
    fi
    "$PYVENV" -u -m ml.training.ppo --key "$key" --build "$build" \
        --opp-build "$opp_build" --steps "$STEPS" --envs "$ENVS" --arch "$ARCH" \
        --selfplay-every "$SELFPLAY_EVERY" --seed "$SEED" \
        --promote-wr "$PROMOTE_WR" --promote-hold "$PROMOTE_HOLD" \
        --eval-envs "$EVAL_ENVS" --demote-wr "$DEMOTE_WR" --reservoir "$RESERVOIR" \
        --entropy-final "$ENTROPY_FINAL" --move-std-final "$MOVE_STD_FINAL" \
        --plateau-updates "$PLATEAU_UPDATES" --plateau-delta "$PLATEAU_DELTA" \
        --plateau-min-steps "$PLATEAU_MIN_STEPS" \
        "${WARM_ARG[@]}" "${NET_ARG[@]}" 2>&1 \
        | tee "$RUN/logs/$key.log" \
        | python3 -u "$REPO/tools/dh_trainfmt.py" --key "$key" || dh_err "ppo $key failed - see logs/$key.log"
    "$PYVENV" -u -m ml.training.league gate --key "$key" --build "$build" \
        --episodes "$EPISODES" 2>&1 | tee -a "$RUN/logs/$key.log" \
        | python3 -u "$REPO/tools/dh_trainfmt.py" --key "$key" || true
  done
elif [ "$MODE" = "tournament" ]; then
  # TRAIN ALL, but each creature's methods fight for the pin instead of one
  # method being assumed right. tournament.py does the gating and the bracket;
  # this loop only supplies the keys so the run folder, the per-key logs and the
  # console's per-key progress feed look exactly like the ES sweep's.
  OPP_ARG=(); [ -z "$OPPONENTS" ] || OPP_ARG=(--opponents "$OPPONENTS")
  OPPB_ARG=(); [ -z "$OPP_BUILD" ] || OPPB_ARG=(--opp-build "$OPP_BUILD")
  TEACHER_ARG=(); [ -z "$TEACHER" ] || TEACHER_ARG=(--teacher "$TEACHER")
  TIMEOUT_ARG=(); [ "$METHOD_TIMEOUT" = "0" ] || TIMEOUT_ARG=(--method-timeout "$METHOD_TIMEOUT")
  GATE_ARG=(--gate-episodes "$GATE_EPISODES"); [ "$GATE_EPISODES" -gt 0 ] || GATE_ARG=(--no-gate)
  N_KEYS=$(echo "$KEYS" | grep -c . || true); I_KEY=0
  echo "$KEYS" | while read -r key build; do
    [ -n "$key" ] || continue
    I_KEY=$((I_KEY + 1))
    dh_rule "$I_KEY/$N_KEYS  $key  ·  bracket $METHODS"
    dh_kv build "$build"
    dh_kv budget "best-of $BEST_OF · es: $GENERATIONS gens × pop $POP · ppo: $STEPS steps · $JOBS jobs"
    python3 -u -m ml.training.tournament --key "$key" --build "$build" \
        --methods "$METHODS" --best-of "$BEST_OF" \
        --bracket-episodes "$BRACKET_EPISODES" "${GATE_ARG[@]}" \
        --generations "$GENERATIONS" --pop "$POP" --episodes "$EPISODES" \
        --jobs "$JOBS" --seed "$SEED" --speed "$SPEED" \
        --checkpoint-every "$CHECKPOINT_EVERY" \
        --steps "$STEPS" --envs "$ENVS" --arch "$ARCH" \
        --selfplay-every "$SELFPLAY_EVERY" \
        "${OPP_ARG[@]}" "${OPPB_ARG[@]}" "${NET_ARG[@]}" "${TEACHER_ARG[@]}" \
        "${TIMEOUT_ARG[@]}" 2>&1 \
        | tee "$RUN/logs/$key.log" \
        | python3 -u "$REPO/tools/dh_trainfmt.py" --key "$key" \
            --generations "$GENERATIONS" --pop "$POP" \
        || dh_err "$key tournament failed — see logs/$key.log"
  done
else
  OPP_ARG=(); [ -z "$OPPONENTS" ] || OPP_ARG=(--opponents "$OPPONENTS")
  RESUME_ARG=(); [ -z "$RESUME_RUN" ] || RESUME_ARG=(--resume)
  N_KEYS=$(echo "$KEYS" | grep -c . || true); I_KEY=0
  echo "$KEYS" | while read -r key build; do
    [ -n "$key" ] || continue
    I_KEY=$((I_KEY + 1))
    dh_rule "$I_KEY/$N_KEYS  $key"
    dh_kv build "$build"
    dh_kv budget "$GENERATIONS gens · pop $POP · $EPISODES episodes · $JOBS jobs · speed $SPEED"
    # -u: without it Python block-buffers into the pipe and a 200-generation
    # run prints nothing for ten minutes. dh_trainfmt paints it live; the
    # untouched trainer text still lands in logs/<key>.log through tee.
    python3 -u -m ml.training.league train --key "$key" --build "$build" \
        --generations "$GENERATIONS" --pop "$POP" --episodes "$EPISODES" \
        --jobs "$JOBS" --seed "$SEED" --speed "$SPEED" \
        --checkpoint-every "$CHECKPOINT_EVERY" "${RESUME_ARG[@]}" "${OPP_ARG[@]}" \
        "${NET_ARG[@]}" 2>&1 \
        | tee "$RUN/logs/$key.log" \
        | python3 -u "$REPO/tools/dh_trainfmt.py" --key "$key" \
            --generations "$GENERATIONS" --pop "$POP" \
        || dh_err "$key training failed — see logs/$key.log"
    python3 -u -m ml.training.league gate --key "$key" --build "$build" \
        --episodes "$EPISODES" 2>&1 | tee -a "$RUN/logs/$key.log" \
        | python3 -u "$REPO/tools/dh_trainfmt.py" --key "$key" || true
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
PY

dh_rule "summary"
while IFS= read -r line; do
  case "$line" in
    *" PASS "*|*" PASS") printf '%s  ✓%s %s\n' "$C_GREEN" "$C_0" "$line";;
    *" fail "*|*" fail") printf '%s  ✗%s %s\n' "$C_RED" "$C_0" "$line";;
    "") echo;;
    *) printf '  %s%s%s\n' "$C_PALE" "$line" "$C_0";;
  esac
done < "$RUN/summary.txt"
echo
dh_say "watch any run live:   ${C_CYAN}tools/train_watch.py ${RUN#"$REPO"/}${C_0}"
dh_say "every run, oldest first:   ${C_CYAN}tools/train_run.sh --list${C_0}"
