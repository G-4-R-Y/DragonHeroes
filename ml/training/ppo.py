"""PPO over dh-env (docs/tech/25 §R1): the GPU trainer Ricardo asked for.

  learner (torch, CUDA, VRAM-capped via gpu_guard)
    × N in-process libdh-env arenas, ALL stepped in one call per tick
      (dh_env_step_many: 352k env-steps/s at 32 envs, 639k at 128)
    × opponents: native | scripted | mlp SELF-PLAY (frozen snapshots of the
      learner — the past-self league inside the env; exploiters join via
      ml/training/league.py's opponent lists)

Reward mirrors the league's fitness (win rate + hp-margin shaping), so ES and
PPO optimize the same objective and every PPO checkpoint exports schema
"arena.policy.v1" JSON the Godot arena gates verbatim.

    ml/.venv/bin/python -m ml.training.ppo \
        --key cinder_drake --build core.arena.cinder_drake \
        --opp-build core.arena.fen_boar_alpha \
        --steps 2000000 --envs 512 --selfplay-every 4

Throughput (Ricardo, 2026-09-13: "A batched step across all environments... is
roughly sixteen times of headroom sitting there. --> do it!"). Two things were
in the way, and the second only became visible once the first was fixed:

  1. the rollout crossed into C four times PER ENV PER TICK (step, hp_frac x2,
     winner). dh_env_step_many does the whole tick in one crossing:
     32 envs 56.6k -> 352.6k env-steps/s (6.2x), 128 envs 55.0k -> 638.8k
     (11.6x), trajectories bit-identical to the per-env path.
  2. with the envs cheap, each tick is one SMALL GPU forward, so the rollout
     became kernel-launch bound. A wider batch fixes it: end-to-end PPO went
     5,834 -> 56,288 steps/s going from 32 to 512 envs (9.6x), and is flat
     past 512. Hence the new --envs default.

Both were measured while a 20-job ES sweep had the box at load 20, so an idle
machine does better. `roll=`/`upd=` in each iteration line shows the split.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from ml.env.dh_env import (ACT_DODGE, DhEnv, VecDhEnv, OBS_DIM,   # noqa: E402
                          set_opp_weights, supports_dodge_flag,
                          supports_opp_switch, tick_hz)
from ml.training import arch as arch_mod                     # noqa: E402
from ml.training import reward as reward_model               # noqa: E402
from ml.training.arch import ACT_CODE, normalize_act         # noqa: E402
from ml.training.gpu_guard import apply as gpu_apply, clamp_batch  # noqa: E402
from ml.training.torch_policy import TorchPolicyNet, TorchGRUPolicyNet, mask_heads  # noqa: E402


def policy_hidden_default() -> tuple[int, ...]:
    from ml.training.policy_net import HIDDEN
    return HIDDEN
from ml.serving_paths import registry_path as ml_registry_path  # noqa: E402
from ml.serving_paths import weights_dir as ml_weights_dir  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
# $DH_SERVING_DIR redirects every artifact to an isolated run folder
# (tools/train_run.sh); unset = the deployed ml/serving (ml/serving_paths.py).
WEIGHTS_DIR = ml_weights_dir()
REGISTRY = ml_registry_path()

# ---- reward shaping ---------------------------------------------------------
# The TERMINAL reward is now ml/training/reward.py — the same weighted,
# scale-normalized model league.fitness() ranks ES candidates with, so the two
# optimisers stop pulling in different directions. What stays here is the DENSE
# per-tick signal, which exists only for credit assignment: it tells the agent
# which tick the outcome came from, it does not define the outcome.
#
# R_TERMINAL scales the [0,1] episode score into reward units. 2.0 reproduces
# the old +1/-1 spread between a perfect win and a total loss.
R_TERMINAL = 2.0
# Dense damage shaping, and it is ASYMMETRIC on purpose. It used to be one term,
# R_HP_DELTA * ((foe lost) - (self lost)), weight 1.0 each way — so avoiding a
# hit paid exactly as well as landing one, and standing still is much easier
# than fighting. That is the avoidance local optimum, and PPO seed 7 found it
# (mean_loser_hp 0.967, a timeout "win" the sanity gate correctly refused).
# Dealing damage is now worth more per health point than taking it is worth
# avoiding, in the same ratio as the terminal model's two weights.
R_DEAL, R_ABSORB = 1.0, 0.73
# PREVIOUS SETTINGS, kept per Ricardo's standing rule (comment out, never
# delete) — the shaping every PPO run before 2026-09-14 used:
#     R_WIN, R_LOSE, R_HP_DELTA, R_TIME = 1.0, -1.0, 1.0, 0.002
# R_TIME was wrong twice over. It applied every tick REGARDLESS of outcome, so a
# losing agent was paid to die sooner (Ricardo: "If loser, the longest the
# better"), and at 0.002 x 3600 ticks it totalled 7.2 against a win bonus of
# 1.0, so the clock outweighed the result by 7x. There is no per-tick clock term
# now: GAMMA already discounts later reward, which IS "sooner is better", and
# the outcome-conditioned duration term lives in the terminal score where it can
# carry the right sign.
R_TIME = 0.0
# combo incentives (Ricardo: "no dull simple attacks — mobs rely on skill
# combos"): small per-cast bonus so kits beat LMB spam, plus a chaining bonus
# for firing a DIFFERENT kit within the combo window (1.5 s = 90 ticks)
# Paid on the tick a kit actually FIRES (vec.commit), never on selecting one.
# CHAIN_WINDOW is in TICKS and the sim runs at 60 Hz, so 90 ticks = 1.5 s.
R_KIT, R_CHAIN, CHAIN_WINDOW = 0.02, 0.05, 90
GAMMA, LAM, CLIP, ENTROPY, LR, EPOCHS, MINIBATCHES = 0.99, 0.95, 0.2, 0.01, 3e-4, 4, 8
# Std of the Gaussian the move head is sampled from. It was already the 0.3 of
# the old `0.3 * randn_like(move)` exploration noise — what was missing is that
# a policy-gradient method only trains the heads whose log-probability is in the
# ratio. move was not, so head_move never received a gradient and every PPO net
# ever exported moved with its INITIAL weights (measured on the 2026-09-14
# cinder_drake export: |move| mean 0.027 on a +-1 scale — a creature that
# stands still). That is why PPO gated at win_rate 0.00 against scripted at
# every budget while ES, which perturbs the whole parameter vector, passed.
MOVE_STD = 0.3
# ANNEALING (R50 decision, 2026-09-19). The trainer SAMPLES pi_theta; every
# serving runtime (policy_net.act, neural_policy.gd, Arena::mlp_act,
# env_parity) executes argmax pi_theta — a different policy from the same
# weights. Measured on fen_boar v7.0: the sampled policy won 0.96 of episodes
# against native, the greedy one 0.04, because at entropy ~1.94 nats the
# argmax is "act 3 forever". Annealing the entropy bonus and the move std
# towards zero over the run shrinks that gap by construction: as pi_theta
# sharpens, sample and argmax converge. The FINAL values are what the run
# ends on; the schedule is linear in done_steps. The greedy-eval envs below
# report the number that actually ships, at every update.
ENTROPY_FINAL = 0.001
MOVE_STD_FINAL = 0.1
SNAPSHOTS = REPO / "ml" / "data" / "ppo_snapshots"


def pack_for_cpp(net: TorchPolicyNet) -> tuple[np.ndarray, np.ndarray, np.ndarray,
                                                np.ndarray, np.ndarray]:
    """Torch net -> the C++ packing: per layer [W out×in][b]; emb16 row "*"; and
    the per-layer activation codes (ml.training.arch.ACT_CODE) — without those
    the frozen self-play opponent would run a relu net as tanh, which is a
    different opponent than the one being trained."""
    params, layer_in, layer_out = [], [], []
    with torch.no_grad():
        for lin in net.layers:
            w = lin.weight.cpu().numpy()
            params += [w.ravel(), lin.bias.cpu().numpy()]
            layer_in.append(w.shape[1])
            layer_out.append(w.shape[0])
        w = torch.cat([net.head_move.weight, net.head_act.weight,
                       net.head_dodge.weight], dim=0).cpu().numpy()
        b = torch.cat([net.head_move.bias, net.head_act.bias,
                       net.head_dodge.bias], dim=0).cpu().numpy()
        params += [w.ravel(), b]
        layer_in.append(w.shape[1])
        layer_out.append(w.shape[0])
        emb = net.embeddings.weight[net.key_to_idx.get("*", 0)].cpu().numpy()
    acts = [ACT_CODE[a] for a in net.arch.layer_acts(len(layer_in))]
    return (np.concatenate(params).astype(np.float32),
            np.array(layer_in, dtype=np.int32),
            np.array(layer_out, dtype=np.int32), emb.astype(np.float32),
            np.array(acts, dtype=np.int32))


def pack_from_policy_json(path: str) -> tuple[np.ndarray, np.ndarray, np.ndarray,
                                              np.ndarray, np.ndarray]:
    """arena.policy.v1 JSON -> the C++ packing (fixed exploiter opponents)."""
    data = json.load(open(path))
    params, layer_in, layer_out, acts = [], [], [], []
    for l in data["layers"]:
        w = np.asarray(l["w"], dtype=np.float32)
        params += [w.ravel(), np.asarray(l["b"], dtype=np.float32)]
        layer_in.append(w.shape[1])
        layer_out.append(w.shape[0])
        # normalize_act also accepts "logits", the name the old exporter used
        acts.append(ACT_CODE[normalize_act(l.get("act", "tanh"))])
    emb = np.asarray(data.get("embeddings", {}).get("*", [0.0] * 16),
                     dtype=np.float32)
    return (np.concatenate(params).astype(np.float32),
            np.array(layer_in, dtype=np.int32),
            np.array(layer_out, dtype=np.int32), emb,
            np.array(acts, dtype=np.int32))


# Fewer updates than this is not a short run, it is a broken one: the trainer
# refuses rather than registering a net the gate will reject at win_rate 0.00.
MIN_UPDATES = 10


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True)
    ap.add_argument("--build", required=True)
    ap.add_argument("--opp-build", required=True)
    ap.add_argument("--steps", type=int, default=2_000_000)
    # was 32 until 2026-09-13. With the per-env Python loop gone
    # (dh_env_step_many), the cost per TICK is one small GPU forward, so the
    # way to go faster is a WIDER batch per launch, not a longer horizon.
    # Measured on the dev box while a 20-job ES sweep was running:
    #   envs=32   5,834 steps/s     envs=256  31,582 steps/s
    #   envs=64   9,747 steps/s     envs=512  56,288 steps/s  <- the knee
    #   envs=1024 57,757 steps/s    envs=2048 56,414 steps/s  (flat past 512)
    ap.add_argument("--envs", type=int, default=512)
    # RICARDO'S CURRICULUM, 2026-09-14: "after tuning the arena training as to
    # learn from scripts first and, once reliably wiining against it, self
    # playing". Before this, a third of the envs were self-play from step 0 —
    # two policies that both stand still, teaching each other nothing. The
    # script phase gives the learner an opponent that actually fights, so there
    # is a gradient to climb before it is allowed to play itself.
    ap.add_argument("--curriculum", dest="curriculum", action="store_true",
                    default=True, help="scripts first, self-play on promotion "
                                       "(default; --no-curriculum for the old "
                                       "fixed native/scripted/mlp thirds)")
    ap.add_argument("--no-curriculum", dest="curriculum", action="store_false")
    ap.add_argument("--promote-wr", type=float, default=0.60,
                    help="win rate vs the scripts that promotes to self-play")
    ap.add_argument("--promote-hold", type=int, default=3,
                    help="consecutive updates the win rate must HOLD — "
                         "'reliably winning', not 'won once'")
    ap.add_argument("--selfplay-every", type=int, default=4,
                    help="refresh the frozen self-play opponent every K iterations")
    # R50 (2026-09-19): the promotion gate used to read the SAMPLED win rate,
    # which is a policy that never ships. These envs decode argmax exactly as
    # policy_net.act / neural_policy.gd / Arena::mlp_act do, ride in the same
    # step_many, and are EXCLUDED from the PPO update (their actions are not
    # samples from pi_theta, so their log-probabilities mean nothing to the
    # ratio). Their win rate is J(pi_theta^greedy) — the shipped number.
    # 64 of 512 (12.5%): measured in the 2026-09-19 smoke, 32 probes needed
    # ~56 updates (3.7M steps) to finish the 40 episodes the window requires;
    # 64 needed ~28. The update loses 12.5% of its samples for a number that
    # arrives twice as fast.
    ap.add_argument("--eval-envs", type=int, default=64,
                    help="envs that execute argmax (the serving decode); "
                         "reported as greedy=, drive promotion, never trained on")
    # Ricardo's curriculum fixes (2026-09-19): "interchange scripted vs
    # self-play until we are constantly winning scripted, as to not exploit
    # some strategy". Promotion is REVERSIBLE — fall below the floor and the
    # self-play third goes back to scripts — and scripts are never dropped.
    ap.add_argument("--demote-wr", type=float, default=0.45,
                    help="greedy win rate vs scripts BELOW which a promoted "
                         "run demotes back to scripts-only (hysteresis with "
                         "--promote-wr; 0 disables)")
    ap.add_argument("--reservoir", type=int, default=8,
                    help="past snapshots kept for self-play; the opponent is "
                         "drawn from this pool, not only the latest self, so "
                         "the learner cannot overfit to one reflection")
    ap.add_argument("--entropy-final", type=float, default=ENTROPY_FINAL,
                    help=f"entropy bonus at the END of the run (linear from "
                         f"{ENTROPY}; pass {ENTROPY} for constant)")
    ap.add_argument("--move-std-final", type=float, default=MOVE_STD_FINAL,
                    help=f"move-head Gaussian std at the END of the run "
                         f"(linear from {MOVE_STD}; pass {MOVE_STD} for constant)")
    # PLATEAU STOP: the 60M budget is a ceiling, not a target. Stop when the
    # greedy win rate vs the scripts has not improved by --plateau-delta over
    # the last --plateau-updates updates (0 disables). Only armed after
    # --plateau-min-steps so a cold start is not mistaken for convergence.
    ap.add_argument("--plateau-updates", type=int, default=0,
                    help="stop early when greedy= has not improved for this "
                         "many updates (0 = run the full --steps)")
    ap.add_argument("--plateau-delta", type=float, default=0.02,
                    help="the improvement that resets the plateau counter")
    ap.add_argument("--plateau-min-steps", type=int, default=0,
                    help="never plateau-stop before this many steps")
    ap.add_argument("--warm-start", default="", help="registry JSON/npz to init from")
    ap.add_argument("--exploit", default="",
                    help="policy_v1 JSON of a MAIN agent: train a dedicated "
                         "exploiter that only fights this fixed target")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--squad-a-buddy", default="",
                    help="2v2: build id of the learner-side buddy body")
    ap.add_argument("--squad-b-buddy", default="",
                    help="2v2: build id of the enemy-side buddy body")
    ap.add_argument("--env-threads", type=int, default=1,
                    help="worker threads inside dh_env_step_many. 1 (the "
                         "default) is fastest on a busy box: a 32-env tick is "
                         "only tens of microseconds, so sync costs more than "
                         "it saves. Raise it only with >=128 envs on idle cores.")
    # --net/--hidden/--activation/--init/--init-scale, identical on every trainer
    # (ml/training/arch.py). NOTE --arch below is the older mlp-vs-gru switch and
    # is a different axis entirely; --net picks the SHAPE of the mlp.
    arch_mod.add_arguments(ap)
    ap.add_argument("--arch", choices=["mlp", "gru"], default="mlp",
                    help="gru = recurrent net (temporal combos/kiting); "
                         "self-play snapshots disabled (C++ opponent is "
                         "stateless MLP) — opponents are native+scripted")
    args = ap.parse_args()
    if args.eval_envs < 0 or args.eval_envs >= args.envs // 2:
        raise SystemExit(f"--eval-envs {args.eval_envs} must be in "
                         f"[0, {args.envs // 2}) for --envs {args.envs}")

    budget = gpu_apply()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.manual_seed(args.seed)
    rng = np.random.default_rng(args.seed)

    squad = (args.squad_a_buddy, args.squad_b_buddy) \
        if args.squad_a_buddy and args.squad_b_buddy else None
    obs_dim = 36 if squad else OBS_DIM
    from ml.training.policy_net import macs
    net_arch = arch_mod.from_args(args)
    hidden = net_arch.hidden
    if args.arch == "gru" and net_arch != arch_mod.Arch():
        raise SystemExit("--net/--hidden are mlp only (the GRU stack has its own shape)")
    net = (TorchGRUPolicyNet(["*"], obs_dim=obs_dim) if args.arch == "gru"
           else TorchPolicyNet(["*"], obs_dim=obs_dim, arch=net_arch)).to(device)
    if args.arch != "gru":
        print(f"[ppo:{args.key}] net '{net_arch.name}': {list(hidden)} "
              f"{net_arch.activation}, init {net_arch.init} — {macs(hidden):,} MACs/tick",
              flush=True)
    if hidden != policy_hidden_default():
        # The C++ frozen-opponent MLP (dh-sim Arena::set_opp_mlp) refuses layers
        # wider than kMlpMaxUnits and falls back to scripted, so say up front
        # whether self-play will actually see this net.
        cap = 512
        fits = all(n <= cap for n in hidden)
        print(f"[ppo:{args.key}] WIDE net {hidden}: {macs(hidden):,} MACs/tick vs "
              f"{macs():,} — a teacher, not something to ship. self-play opponent: "
              f"{'on' if fits else f'OFF (layers > {cap} are refused by dh-sim)'}",
              flush=True)
    if args.warm_start:
        from ml.training import policy_net
        es = policy_net.PolicyNet(arch=net_arch)
        data = json.load(open(args.warm_start))
        # A warm start only means anything if the donor has THIS shape. Copying a
        # 64x64 tanh trunk into a 256x256 relu one used to half-work (zip() just
        # stopped at the shorter list) and produced a net that was neither.
        src_h = [len(l["b"]) for l in data["layers"][:-1]]
        src_a = normalize_act(data["layers"][0].get("act", "tanh"))
        if tuple(src_h) != tuple(hidden) or src_a != net_arch.activation:
            raise SystemExit(
                f"--warm-start {Path(args.warm_start).name} is {src_h} {src_a}; "
                f"this run is {list(hidden)} {net_arch.activation}. Warm-starting "
                f"across architectures is not a thing — drop --warm-start, or "
                f"distill (ml/training/distill.py).")
        for i, l in enumerate(data["layers"]):
            es.weights[i] = np.asarray(l["w"], dtype=np.float32)
            es.biases[i] = np.asarray(l["b"], dtype=np.float32)
        es.embeddings = {k: np.asarray(v, dtype=np.float32)
                         for k, v in data.get("embeddings", {}).items()}
        net.from_policy_net(es)
        print(f"[ppo:{args.key}] warm-started from {args.warm_start}")
    opt = torch.optim.Adam(net.parameters(), lr=LR)

    # Steps per policy update — a FIXED step budget, deliberately NOT `2048 *
    # envs`. Tying the rollout to --envs is what broke Ricardo's 2026-09-14
    # cinder_drake run: when --envs went 32 -> 512 with the batched rollout
    # (ab14e32), `2048 * envs` took a rollout from 65,536 steps to 1,048,576, so
    # the unchanged 2,000,000-step budget bought 2 policy updates instead of 30.
    # PPO learns nothing in 2 updates — that run printed win_rate 0.81 (against
    # its own frozen self-play snapshot, which is equally untrained) and then
    # gated at 0.00 against scripted. --envs is a THROUGHPUT knob: 512 is the
    # measured knee, and it must not change how often the policy is updated.
    ROLLOUT_STEPS = 65_536
    steps_per_rollout = clamp_batch(ROLLOUT_STEPS, budget)
    t_horizon = max(64, steps_per_rollout // args.envs)
    if args.arch == "gru":
        t_horizon = min(t_horizon, 256)   # sequential BPTT: keep T tractable
    rollout = t_horizon * args.envs
    updates = max(1, args.steps // rollout)
    print(f"[ppo:{args.key}] device={device} envs={args.envs} "
          f"horizon={t_horizon} rollout={rollout:,} steps -> {updates} policy "
          f"updates (VRAM cap {steps_per_rollout:,})")
    if updates < MIN_UPDATES:
        raise SystemExit(
            f"[ppo:{args.key}] REFUSING to start: {args.steps:,} steps over a "
            f"{rollout:,}-step rollout is {updates} policy update(s), and PPO "
            f"cannot learn in fewer than {MIN_UPDATES}. This is the failure mode "
            f"that produced a net with win_rate 0.00 against scripted while its "
            f"self-play number read 0.81. Raise the budget to at least "
            f"--steps {MIN_UPDATES * rollout:,}, or lower --envs.")
    # Loaded once: the weights are validated on load (they must sum to 1.0 and
    # `win` must outweigh every other term combined), so a bad edit to
    # reward_weights.json stops the run here rather than quietly retraining
    # against a different objective.
    reward_weights = reward_model.load_weights()
    TICK_HZ = tick_hz()
    print(f"[ppo:{args.key}] reward model {reward_model.active_model()} "
          f"weights={reward_weights} terminal x{R_TERMINAL}")
    # arena.mask.v1 (ml/env/dh_env.py): the body constants the mask needs.
    # The rollout samples from the MASKED heads and the update recomputes the
    # MASKED heads, so pi_theta is the policy the serving runtimes execute.
    from ml.env.dh_env import mask_args
    kit_count, is_player = mask_args(args.build)
    print(f"[ppo:{args.key}] action mask arena.mask.v1: kit_count={kit_count} "
          f"is_player={is_player} (unavailable actions -> -1e9 before softmax)",
          flush=True)
    if not supports_dodge_flag():
        raise SystemExit(
            f"[ppo:{args.key}] REFUSING to start: libdh-env.so predates the "
            f"dodge flag (ml/env/dh_env.py::ACT_DODGE), so every dodge this "
            f"policy chooses is silently dropped while the update still pays "
            f"its log-probability — training against an env that ignores a "
            f"third of the head. Rebuild: cmake --build sim/build -j")

    if args.exploit or args.arch == "gru":
        # fixed target / no snapshots: gru runs fight native+scripted halves
        opps = (["mlp"] * args.envs if args.exploit
                else ["native" if i % 2 == 0 else "scripted"
                      for i in range(args.envs)])
        envs = [DhEnv(args.build, args.opp_build, opp=opps[i],
                      seed=args.seed + i, squad=squad)
                for i in range(args.envs)]
    elif args.curriculum:
        # PHASE 1 — scripts only. Both of them: the gate requires beating
        # `scripted` AND `native`, so training against one and gating on two is
        # how a net passes half a gate. Slot i%3==2 is the one that will flip
        # to self-play on promotion; it starts as a script too.
        envs = [DhEnv(args.build, args.opp_build,
                      opp=("scripted" if i % 2 == 0 else "native"),
                      seed=args.seed + i, squad=squad)
                for i in range(args.envs)]
    else:
        thirds = [("native",), ("scripted",), ("mlp",)]
        envs = [DhEnv(args.build, args.opp_build, opp=thirds[i % 3][0],
                      seed=args.seed + i, squad=squad)
                for i in range(args.envs)]
    curriculum = bool(args.curriculum) and not args.exploit \
        and args.arch != "gru" and not squad
    if curriculum and not supports_opp_switch():
        raise SystemExit(
            f"[ppo:{args.key}] libdh-env.so predates dh_env_set_opp_policy, so "
            f"the curriculum could never leave its script phase and would look "
            f"exactly like a run that simply never self-played. Rebuild: "
            f"cmake --build sim/build -j   (or pass --no-curriculum)")
    # The LAST eval_envs envs are the greedy probes. They are never handed to
    # self-play (they measure the shipped policy against the SCRIPTS, the same
    # opponents the gate uses) and never enter the update. The learner slots
    # are the first N_train envs.
    N_eval = args.eval_envs if (args.arch != "gru" and not squad) else 0
    N_train = args.envs - N_eval
    is_eval = np.zeros(args.envs, dtype=bool)
    is_eval[N_train:] = True
    if N_eval:
        # the greedy probes alternate scripted/native regardless of mode, so
        # greedy= is always "vs the gate's opponents"
        for j, i in enumerate(range(N_train, args.envs)):
            if envs[i].opp != ("scripted" if j % 2 == 0 else "native"):
                envs[i].set_opp("scripted" if j % 2 == 0 else "native")
    selfplay_slots = [i for i in range(2, N_train, 3)]
    mlp_envs = envs if args.exploit else \
        ([] if (args.arch == "gru" or squad or curriculum)
         else [envs[i] for i in selfplay_slots])
    # ONE ctypes crossing per tick instead of four per env per tick
    # (Ricardo, 2026-09-13: "do it!"). Measured on the dev box while it was
    # fully loaded: 32 envs 56.6k -> 352.6k steps/s (6.2x), 128 envs 55.0k ->
    # 638.8k (11.6x), bit-identical trajectories to the per-env path.
    vec = VecDhEnv(envs, threads=max(1, args.env_threads))
    obs = vec.reset(np.array([args.seed * 977 + i for i in range(args.envs)],
                             dtype=np.uint64)).copy()
    prev_self = np.ones(args.envs, dtype=np.float32)
    prev_foe = np.ones(args.envs, dtype=np.float32)

    # RESERVOIR (Ricardo, 2026-09-19). Self-play used to mean "the latest
    # frozen self, on every self-play env" — a single opponent the learner can
    # overfit to, and one that moves every K updates, so what it learned to
    # beat last time is gone. The reservoir keeps the last --reservoir
    # snapshots and hands each self-play env one of them, round-robin, so at
    # any moment the learner faces a SPREAD of its own history. Every packed
    # tuple stays referenced here: the C side borrows the pointers.
    reservoir: list[tuple] = []

    def refresh_selfplay() -> None:
        packed = pack_for_cpp(net)
        reservoir.append(packed)
        del reservoir[:-max(1, args.reservoir)]
        if args.reservoir > 1 and (args.exploit or not curriculum or promoted):
            # keep the newest one on disk too, for post-mortems and env_parity
            try:
                SNAPSHOTS.mkdir(parents=True, exist_ok=True)
                net.export_policy_v1(str(SNAPSHOTS / f"{args.key}_it{iteration:05d}.json"))
                olds = sorted(SNAPSHOTS.glob(f"{args.key}_it*.json"))
                for f in olds[:-args.reservoir]:
                    f.unlink()
            except OSError as exc:   # a full disk must not kill the run
                print(f"[ppo:{args.key}] snapshot not written: {exc}", flush=True)
        exact = True
        for k, e in enumerate(mlp_envs):   # only the self-play slots
            params, li, lo, emb, acts = reservoir[k % len(reservoir)]
            exact = set_opp_weights(e._handle, params, li, lo, emb, acts) and exact
        if not exact and not refresh_selfplay.warned:
            refresh_selfplay.warned = True
            print(f"[ppo:{args.key}] WARNING libdh-env.so predates per-layer "
                  f"activations — the self-play opponent will run "
                  f"tanh/linear, not {net.arch.activation}. Rebuild: "
                  f"cmake --build sim/build -j", flush=True)
    refresh_selfplay.warned = False

    iteration = 0
    done_steps = 0
    results: list[int] = []
    # The promotion gate must read the SCRIPT envs only. A pooled win rate rises
    # on its own as self-play gets easier against a frozen snapshot of itself,
    # so pooling would let a policy promote on its own reflection.
    env_is_script = [True] * args.envs if curriculum else [False] * args.envs
    script_results: list[int] = []
    # J(pi_theta^greedy) vs the scripts: outcomes of the eval envs only. This
    # is the number promotion reads and the number the gate will see.
    eval_results: list[int] = []
    promoted = not curriculum
    holding = 0
    sinking = 0
    promotions = 0
    demotions = 0

    def promote() -> None:
        """Phase 2: a third of the TRAIN envs start fighting the learner's own
        frozen snapshots. Weights FIRST — set_opp_policy refuses kMlp on an env
        that has never been handed a net, which is the whole point of that
        refusal. The eval envs never move: greedy= stays "vs scripts"."""
        nonlocal promoted, mlp_envs, promotions, sinking
        mlp_envs = [envs[i] for i in selfplay_slots]
        promoted = True     # refresh_selfplay writes snapshots once promoted
        refresh_selfplay()
        switched = 0
        for i in selfplay_slots:
            if envs[i].set_opp("mlp"):
                env_is_script[i] = False
                switched += 1
        promotions += 1
        sinking = 0
        print(f"[ppo:{args.key}] CURRICULUM phase 2/2 — PROMOTED at "
              f"iteration {iteration}, {done_steps:,} steps: {switched} of "
              f"{N_train} train envs now fight past selves, the rest stay on "
              f"scripts; {N_eval} greedy probes stay on scripts.", flush=True)

    def demote(greedy_wr: float) -> None:
        """Ricardo (2026-09-19): "interchange scripted vs self-play until we
        are constantly winning scripted". The self-play slots go back to the
        scripts when the SHIPPED policy stops beating them — self-play that
        drifts away from what the gate measures is not progress."""
        nonlocal promoted, mlp_envs, demotions, holding
        for i in selfplay_slots:
            envs[i].set_opp("scripted" if (i // 3) % 2 == 0 else "native")
            env_is_script[i] = True
        mlp_envs = []
        promoted = False
        holding = 0
        demotions += 1
        print(f"[ppo:{args.key}] CURRICULUM DEMOTED at iteration {iteration}, "
              f"{done_steps:,} steps: greedy vs scripts {greedy_wr:.2f} < "
              f"--demote-wr {args.demote_wr:.2f}; self-play slots are scripts "
              f"again until it holds {args.promote_wr:.2f} for "
              f"{args.promote_hold} updates.", flush=True)
    t0 = time.time()
    if args.exploit:
        # EXPLOITER MODE (AlphaStar league shape): the opponent is a FIXED
        # target net — this run's only job is finding its weaknesses
        packed = pack_from_policy_json(args.exploit)
        for e in envs:
            set_opp_weights(e._handle, packed[0], packed[1], packed[2],
                            packed[3], packed[4])
        exploiter_keepalive = packed          # borrowed pointers!
        print(f"[ppo:{args.key}] EXPLOITER vs {Path(args.exploit).name}")
    elif args.arch != "gru" and not squad and not curriculum:
        refresh_selfplay()   # the opponent is the learner's own frozen snapshot
    elif curriculum:
        print(f"[ppo:{args.key}] CURRICULUM phase 1/2 — scripts only "
              f"(scripted + native). Self-play unlocks at win rate "
              f">= {args.promote_wr:.2f} held for {args.promote_hold} updates.",
              flush=True)
    # combo tracking per env: last kit act + tick (chain bonus window)
    last_kit = np.full(args.envs, -1, dtype=np.int64)
    last_kit_tick = np.full(args.envs, -1000, dtype=np.int64)
    tick_count = np.zeros(args.envs, dtype=np.int64)
    # Per-episode damage in HEALTH BARS, for the terminal score. Accumulated
    # from the hp deltas already computed each tick rather than read back from
    # Arena::damage_taken: same unit, one fewer crossing into C. The difference
    # is that overkill does not count here (hp clamps at zero) — which for a
    # reward is the behaviour you want anyway, since a corpse is a corpse.
    ep_dealt = np.zeros(args.envs, dtype=np.float64)
    ep_absorbed = np.zeros(args.envs, dtype=np.float64)
    # plateau tracking on greedy= (the shipped number)
    best_greedy = -1.0
    flat_updates = 0
    stopped_early = ""
    t_is_eval = torch.from_numpy(is_eval)
    while done_steps < args.steps:
        iteration += 1
        if not args.exploit and args.arch != "gru" and not squad \
                and promoted and iteration % args.selfplay_every == 0:
            refresh_selfplay()   # a past self becomes the opponent
        # linear schedules in done_steps (R50): both reach their FINAL value on
        # the last update of the nominal budget; a plateau stop leaves them
        # part-way, which is what the run's log line records
        frac = min(1.0, done_steps / max(1, args.steps))
        move_std = MOVE_STD + (args.move_std_final - MOVE_STD) * frac
        entropy_coef = ENTROPY + (args.entropy_final - ENTROPY) * frac
        # ---- rollout --------------------------------------------------------
        t_roll = time.time()
        T, N = t_horizon, args.envs
        b_obs = torch.zeros(T, N, obs_dim)
        b_move = torch.zeros(T, N, 2)
        b_act = torch.zeros(T, N, dtype=torch.long)
        b_logp = torch.zeros(T, N)
        b_val = torch.zeros(T, N)
        b_rew = np.zeros((T, N), dtype=np.float32)
        b_done = np.zeros((T, N), dtype=np.float32)
        h = net.initial_state(N, device) if args.arch == "gru" else None
        b_h0 = h.detach().cpu() if h is not None else None
        with torch.no_grad():
            for t in range(T):
                t_obs = torch.from_numpy(obs).to(device)
                if h is not None:
                    move, logits, dodge, value, h = net(t_obs, "*", h)
                else:
                    move, logits, dodge, value = net(t_obs)
                logits, dodge = mask_heads(logits, dodge, t_obs, kit_count, is_player)
                act_dist = torch.distributions.Categorical(logits=logits)
                dodge_dist = torch.distributions.Bernoulli(logits=dodge)
                move_dist = torch.distributions.Normal(move, move_std)
                a = act_dist.sample()
                d = dodge_dist.sample()
                # the RAW sample is what the log-probability refers to; the env
                # gets the clamped one. Storing the clamped sample instead would
                # make the ratio disagree with the action that was actually taken.
                m_raw = move_dist.sample()
                if N_eval:
                    # the greedy probes execute the SERVING decode: argmax
                    # pick, dodge = logit > 0, move = the mean. Same weights,
                    # the policy the four runtimes actually run.
                    ev = t_is_eval.to(a.device)
                    a = torch.where(ev, logits.argmax(-1), a)
                    d = torch.where(ev, (dodge > 0).to(d.dtype), d)
                    m_raw = torch.where(ev.unsqueeze(-1), move, m_raw)
                m = m_raw.clamp(-1.0, 1.0)
                logp = (move_dist.log_prob(m_raw).sum(-1)
                        + act_dist.log_prob(a) + dodge_dist.log_prob(d))
                # dodge is a FLAG on the pick, not a replacement for it
                # (ml/env/dh_env.py::ACT_DODGE). It used to overwrite `a` with
                # 7, which cost two things at once: in the env the agent lost
                # its attack on every dodging tick, and in the update below the
                # true `a` was unrecoverable, so the categorical log-probability
                # was recomputed for action 0 and the PPO ratio did not even
                # equal 1 at the unchanged policy. Keeping both in one int fixes
                # both, because `act & 7` and `act >= 8` invert it exactly.
                env_act = a + ACT_DODGE * d.long()
                acts = env_act.cpu().numpy()
                b_obs[t] = t_obs.cpu()
                b_move[t] = m_raw.cpu()
                b_act[t] = env_act
                b_logp[t] = logp.cpu()
                b_val[t] = value.cpu()
                m_np = m.cpu().numpy()
                # the whole tick in one call; hp, done and winner come back
                # with the observations, so nothing else crosses into C here
                nobs, done_n, hp, win = vec.step(m_np, acts)
                self_hp, foe_hp = hp[:, 0], hp[:, 1]
                # asymmetric: landing a hit is worth more than dodging one
                d_dealt = np.maximum(prev_foe - foe_hp, 0.0)
                d_absorbed = np.maximum(prev_self - self_hp, 0.0)
                r = (R_DEAL * (prev_foe - foe_hp)
                     - R_ABSORB * (prev_self - self_hp)).astype(np.float32)
                ep_dealt += d_dealt
                ep_absorbed += d_absorbed
                tick_count += 1
                # PAY FOR EFFECT, NOT INTENT. This used to read `acts` — what
                # the policy WANTED — so selecting a kit paid R_KIT whether or
                # not the kit fired. A kit on an 8 s cooldown stays selectable
                # for 480 ticks per cast, so spamming one earned 3600 x 0.02 =
                # 72 per episode against a terminal worth 1, and the policy
                # duly collapsed onto that single action on 100.000% of ticks
                # (cinder_drake v6.0, measured 2026-09-14). vec.commit is the
                # action the sim actually EXECUTED, or -1 when it was refused.
                pick = vec.commit & (ACT_DODGE - 1)
                kit = (vec.commit >= 0) & (pick >= 3) & (pick <= 6)
                if kit.any():
                    r[kit] += R_KIT
                    # chained a DIFFERENT kit inside the combo window
                    chain = kit & (last_kit >= 0) & (last_kit != pick) \
                        & ((tick_count - last_kit_tick) <= CHAIN_WINDOW)
                    r[chain] += R_CHAIN
                    last_kit[kit] = pick[kit]
                    last_kit_tick[kit] = tick_count[kit]
                live = done_n == 0
                prev_self[live] = self_hp[live]
                prev_foe[live] = foe_hp[live]
                fin = np.flatnonzero(done_n)
                if fin.size:
                    w = win[fin]
                    # The terminal is the full weighted episode score, so every
                    # term Ricardo specified — outcome, damage both ways, both
                    # healths, and the outcome-CONDITIONED duration — is paid
                    # exactly once, on one [0,1] scale, at the only moment the
                    # outcome is known. Centred on 0.5 so a mediocre episode is
                    # neutral rather than a bonus.
                    for j, e in enumerate(fin):
                        ep_score = reward_model.episode_score({
                            "winner_is_self": None if w[j] < 0 else (w[j] == 0),
                            "hp_self": float(self_hp[e]),
                            "hp_foe": float(foe_hp[e]),
                            "dmg_dealt": float(ep_dealt[e]),
                            "dmg_taken": float(ep_absorbed[e]),
                            "seconds": float(tick_count[e]) / TICK_HZ,
                        }, reward_weights)
                        r[e] += R_TERMINAL * (ep_score - 0.5)
                    # results: the TRAIN envs' sampled outcomes; eval_results:
                    # the greedy probes'; script_results: sampled outcomes on
                    # script envs — collected in EVERY phase now, so the
                    # script number never goes dark after promotion
                    for j, e in enumerate(fin):
                        e = int(e)
                        if is_eval[e]:
                            eval_results.append(int(w[j]))
                        else:
                            results.append(int(w[j]))
                            if env_is_script[e]:
                                script_results.append(int(w[j]))
                    vec.reset_done(fin, rng.integers(1, 2**31, size=fin.size)
                                   .astype(np.uint64))
                    prev_self[fin] = 1.0
                    prev_foe[fin] = 1.0
                    last_kit[fin] = -1
                    tick_count[fin] = 0
                    ep_dealt[fin] = 0.0
                    ep_absorbed[fin] = 0.0
                    if h is not None:
                        h[fin] = 0.0   # episode boundary wipes temporal state
                b_rew[t] = r
                b_done[t] = done_n.astype(np.float32)
                obs = nobs
        done_steps += T * N
        roll_s = time.time() - t_roll
        t_upd = time.time()
        # ---- GAE ------------------------------------------------------------
        with torch.no_grad():
            if h is not None:
                next_val = net(torch.from_numpy(obs).to(device), "*", h)[3].cpu()
            else:
                next_val = net(torch.from_numpy(obs).to(device))[3].cpu()
        adv = torch.zeros(T, N)
        lastgae = torch.zeros(N)
        for t in reversed(range(T)):
            nonterminal = 1.0 - torch.from_numpy(b_done[t])
            nv = next_val if t == T - 1 else b_val[t + 1]
            delta = torch.from_numpy(b_rew[t]) + GAMMA * nv * nonterminal - b_val[t]
            lastgae = delta + GAMMA * LAM * nonterminal * lastgae
            adv[t] = lastgae
        ret = adv + b_val
        # ---- PPO update -----------------------------------------------------
        if args.arch == "gru":
            # recurrent path: minibatch over ENVS, replay full T sequences from
            # the stored h0 (truncated BPTT per horizon)
            f_adv = adv.to(device)
            f_ret = ret.to(device)
            f_adv = (f_adv - f_adv.mean()) / (f_adv.std() + 1e-8)
            for _ in range(EPOCHS):
                env_perm = torch.randperm(N)
                for mb in env_perm.split(max(1, N // MINIBATCHES)):
                    h_up = b_h0[mb].to(device)
                    logps, vals, ents = [], [], []
                    for t in range(T):
                        o_t = b_obs[t, mb].to(device)
                        move, logits, dodge, value, h_up = net(o_t, "*", h_up)
                        logits, dodge = mask_heads(logits, dodge, o_t,
                                                   kit_count, is_player)
                        stored = b_act[t, mb].to(device)
                        is_dodge = stored >= ACT_DODGE
                        a = stored % ACT_DODGE      # exact inverse of the encode
                        cat = torch.distributions.Categorical(logits=logits)
                        logps.append(torch.distributions.Normal(move, MOVE_STD)
                                     .log_prob(b_move[t, mb].to(device)).sum(-1)
                                     + cat.log_prob(a)
                                     + torch.distributions.Bernoulli(
                                         logits=dodge).log_prob(is_dodge.float()))
                        vals.append(value)
                        ents.append(cat.entropy())
                    logp = torch.stack(logps)
                    ratio = (logp - b_logp[:, mb].to(device)).exp()
                    s1 = ratio * f_adv[:, mb]
                    s2 = ratio.clamp(1 - CLIP, 1 + CLIP) * f_adv[:, mb]
                    loss = (-torch.min(s1, s2).mean()
                            + 0.5 * (torch.stack(vals) - f_ret[:, mb]).pow(2).mean()
                            - ENTROPY * torch.stack(ents).mean())
                    opt.zero_grad()
                    loss.backward()
                    torch.nn.utils.clip_grad_norm_(net.parameters(), 0.5)
                    opt.step()
        else:
            # the greedy probes are dropped here: their actions are argmax, not
            # samples, so their stored log-probabilities are not log pi_theta(a|s)
            # and the ratio would be meaningless for them
            NT = N_train
            f_obs = b_obs[:, :NT].reshape(T * NT, -1).to(device)
            f_act = b_act[:, :NT].reshape(T * NT).to(device)
            f_logp = b_logp[:, :NT].reshape(T * NT).to(device)
            f_move = b_move[:, :NT].reshape(T * NT, 2).to(device)
            f_adv = adv[:, :NT].reshape(T * NT).to(device)
            f_ret = ret[:, :NT].reshape(T * NT).to(device)
            f_adv = (f_adv - f_adv.mean()) / (f_adv.std() + 1e-8)
            for _ in range(EPOCHS):
                idx = torch.randperm(T * NT, device=device)
                for mb in idx.split((T * NT) // MINIBATCHES):
                    move, logits, dodge, value = net(f_obs[mb])
                    logits, dodge = mask_heads(logits, dodge, f_obs[mb],
                                               kit_count, is_player)
                    is_dodge = f_act[mb] >= ACT_DODGE
                    a = f_act[mb] % ACT_DODGE       # exact inverse of the encode
                    logp = (torch.distributions.Normal(move, move_std)
                            .log_prob(f_move[mb]).sum(-1)
                            + torch.distributions.Categorical(logits=logits).log_prob(a)
                            + torch.distributions.Bernoulli(logits=dodge).log_prob(
                                is_dodge.float()))
                    ratio = (logp - f_logp[mb]).exp()
                    s1 = ratio * f_adv[mb]
                    s2 = ratio.clamp(1 - CLIP, 1 + CLIP) * f_adv[mb]
                    loss = (-torch.min(s1, s2).mean()
                            + 0.5 * (value - f_ret[mb]).pow(2).mean()
                            - entropy_coef * torch.distributions.Categorical(
                                logits=logits).entropy().mean())
                    opt.zero_grad()
                    loss.backward()
                    torch.nn.utils.clip_grad_norm_(net.parameters(), 0.5)
                    opt.step()
        # every iteration, not every fifth: a rollout is ~30 s and a silent
        # trainer is an unreadable trainer (Ricardo, 2026-09-13: "make sure to
        # make logs constant and pretty in those files")
        upd_s = time.time() - t_upd
        recent = results[-200:]
        wr = sum(1 for w in recent if w == 0) / max(1, len(recent))
        # J(pi_theta) on the script envs — sampled, i.e. what the update sees
        window = script_results[-200:]
        script_wr = (sum(1 for w in window if w == 0) / len(window)
                     if len(window) >= 40 else float("nan"))
        # J(pi_theta^greedy) — the probes, argmax, vs scripts: what SHIPS
        gwindow = eval_results[-200:]
        greedy_wr = (sum(1 for w in gwindow if w == 0) / len(gwindow)
                     if len(gwindow) >= 40 else float("nan"))
        # "once reliably wiining against it" — HELD, not touched. A win rate
        # that crosses the line for one update and falls back has not learned
        # to beat the scripts, it has had a good batch. The gate number is the
        # GREEDY one (R50); with --eval-envs 0 it falls back to the sampled
        # script rate, which is the pre-2026-09-19 behaviour.
        gate_wr = greedy_wr if N_eval else script_wr
        if curriculum and gate_wr == gate_wr:      # not nan
            if not promoted:
                holding = holding + 1 if gate_wr >= args.promote_wr else 0
                if holding >= args.promote_hold:
                    promote()
            elif args.demote_wr > 0:
                sinking = sinking + 1 if gate_wr < args.demote_wr else 0
                if sinking >= args.promote_hold:
                    demote(gate_wr)
        # plateau on the shipped number, only once it exists and the floor is past
        if args.plateau_updates and gate_wr == gate_wr \
                and done_steps >= args.plateau_min_steps:
            if gate_wr >= best_greedy + args.plateau_delta:
                best_greedy = gate_wr
                flat_updates = 0
            else:
                flat_updates += 1
        sps = done_steps / (time.time() - t0)
        shown = min(done_steps, args.steps)
        eta = max(0.0, (args.steps - done_steps)) / max(sps, 1.0)
        phase_tag = ("" if not curriculum else
                     (f"sp={len(mlp_envs)}({sinking}/{args.promote_hold}) "
                      if promoted else f"hold={holding}/{args.promote_hold} "))
        # roll/upd split: after the batched dh_env_step_many landed, the
        # rollout is no longer the expensive half — the PPO update is.
        print(f"[ppo:{args.key}] it={iteration} steps={shown:,}/{args.steps:,} "
              f"sps={sps:,.0f} roll={roll_s:.1f}s({T * N / max(roll_s, 1e-6):,.0f}/s) "
              f"upd={upd_s:.1f}s win_rate(last {len(recent)})={wr:.2f} "
              + (f"scripts={script_wr:.2f} " if script_wr == script_wr
                 else f"scripts=n/a({len(window)}) ")
              + ("" if not N_eval else
                 (f"greedy={greedy_wr:.2f} " if greedy_wr == greedy_wr
                  else f"greedy=n/a({len(gwindow)}/40) "))
              + phase_tag
              + f"ent={entropy_coef:.4f} std={move_std:.3f} "
              + (f"flat={flat_updates}/{args.plateau_updates} "
                 if args.plateau_updates else "")
              + f"eta={int(eta) // 60:d}m{int(eta) % 60:02d}s", flush=True)
        if args.plateau_updates and flat_updates >= args.plateau_updates \
                and iteration >= MIN_UPDATES:
            stopped_early = (f"greedy {gate_wr:.2f} flat within "
                             f"{args.plateau_delta:.2f} of best {best_greedy:.2f} "
                             f"for {flat_updates} updates")
            print(f"[ppo:{args.key}] PLATEAU STOP at it={iteration}, "
                  f"{done_steps:,}/{args.steps:,} steps: {stopped_early}",
                  flush=True)
            break
    print(f"[ppo:{args.key}] final: win_rate={wr:.2f} scripts={script_wr:.2f} "
          + (f"greedy={greedy_wr:.2f} " if N_eval else "")
          + f"promotions={promotions} demotions={demotions} "
          f"ent={entropy_coef:.4f} std={move_std:.3f} steps={done_steps:,}",
          flush=True)
    # ---- export: the same JSON the Godot arena gates ------------------------
    WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)
    reg = json.load(open(REGISTRY)) if REGISTRY.exists() else \
        {"schema": "arena.registry.v1", "policies": []}
    version = 1 + max((p["version"] for p in reg["policies"]
                       if p["key"] == args.key), default=0)
    if args.arch == "gru" or squad:
        # no policy_v1 export (the Godot runtime is stateless 31-obs MLP
        # today); these candidates gate via dh-env eval until Godot catches up
        tag = "squad" if squad else "gru"
        out = WEIGHTS_DIR / f"{args.key}_{tag}_v{version}.pt"
        torch.save(net.state_dict(), out)
        game_json = None
    else:
        out = WEIGHTS_DIR / f"{args.key}_ppo_v{version}.json"
        net.export_policy_v1(str(out))
        game_json = str(out.resolve())
    reg["policies"].append({
        "key": args.key, "kind": "exploiter" if args.exploit else "species",
        "version": version,
        "parent": args.exploit or args.warm_start or None,
        "created": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "npz": None, "game_json": game_json, "deployed": False,
        "eval": {"build": args.build, "trainer": "ppo", "arch": args.arch,
                 "steps": done_steps, "selfplay": not args.exploit
                 and args.arch != "gru",
                 # R50/R54: what the trainer measured, so the experiment ledger
                 # can be rebuilt from the registry alone
                 "greedy_wr": None if not N_eval or greedy_wr != greedy_wr
                 else round(greedy_wr, 3),
                 "sampled_script_wr": None if script_wr != script_wr
                 else round(script_wr, 3),
                 "promotions": promotions, "demotions": demotions,
                 "eval_envs": N_eval, "reservoir": args.reservoir,
                 "entropy_final": args.entropy_final,
                 "move_std_final": args.move_std_final,
                 "plateau_stop": stopped_early or None},
    })
    json.dump(reg, open(REGISTRY, "w"), indent=1)
    print(f"[ppo:{args.key}] registered v{version} (candidate) — gate it: "
          f"ml/.venv/bin/python -m ml.training.league gate --key {args.key} "
          f"--build {args.build}")


if __name__ == "__main__":
    main()
