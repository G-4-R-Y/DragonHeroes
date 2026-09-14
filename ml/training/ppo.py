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
from ml.env.dh_env import DhEnv, VecDhEnv, OBS_DIM, set_opp_weights  # noqa: E402
from ml.training import arch as arch_mod                     # noqa: E402
from ml.training.arch import ACT_CODE, normalize_act         # noqa: E402
from ml.training.gpu_guard import apply as gpu_apply, clamp_batch  # noqa: E402
from ml.training.torch_policy import TorchPolicyNet, TorchGRUPolicyNet  # noqa: E402


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

# reward shaping == league fitness terms (win rate + hp margin)
R_WIN, R_LOSE, R_HP_DELTA, R_TIME = 1.0, -1.0, 1.0, 0.002
# combo incentives (Ricardo: "no dull simple attacks — mobs rely on skill
# combos"): small per-cast bonus so kits beat LMB spam, plus a chaining bonus
# for firing a DIFFERENT kit within the combo window (1.5 s = 90 ticks)
R_KIT, R_CHAIN, CHAIN_WINDOW = 0.02, 0.05, 90
GAMMA, LAM, CLIP, ENTROPY, LR, EPOCHS, MINIBATCHES = 0.99, 0.95, 0.2, 0.01, 3e-4, 4, 8
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
    ap.add_argument("--selfplay-every", type=int, default=4,
                    help="refresh the frozen self-play opponent every K iterations")
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

    steps_per_rollout = clamp_batch(2048 * args.envs, budget)
    t_horizon = max(256, steps_per_rollout // args.envs)
    if args.arch == "gru":
        t_horizon = min(t_horizon, 256)   # sequential BPTT: keep T tractable
    print(f"[ppo:{args.key}] device={device} envs={args.envs} "
          f"horizon={t_horizon} (VRAM-capped at {steps_per_rollout})")

    if args.exploit or args.arch == "gru":
        # fixed target / no snapshots: gru runs fight native+scripted halves
        opps = (["mlp"] * args.envs if args.exploit
                else ["native" if i % 2 == 0 else "scripted"
                      for i in range(args.envs)])
        envs = [DhEnv(args.build, args.opp_build, opp=opps[i],
                      seed=args.seed + i, squad=squad)
                for i in range(args.envs)]
    else:
        thirds = [("native",), ("scripted",), ("mlp",)]
        envs = [DhEnv(args.build, args.opp_build, opp=thirds[i % 3][0],
                      seed=args.seed + i, squad=squad)
                for i in range(args.envs)]
    mlp_envs = envs if args.exploit else \
        ([] if (args.arch == "gru" or squad) else envs[2::3])
    # ONE ctypes crossing per tick instead of four per env per tick
    # (Ricardo, 2026-09-13: "do it!"). Measured on the dev box while it was
    # fully loaded: 32 envs 56.6k -> 352.6k steps/s (6.2x), 128 envs 55.0k ->
    # 638.8k (11.6x), bit-identical trajectories to the per-env path.
    vec = VecDhEnv(envs, threads=max(1, args.env_threads))
    obs = vec.reset(np.array([args.seed * 977 + i for i in range(args.envs)],
                             dtype=np.uint64)).copy()
    prev_self = np.ones(args.envs, dtype=np.float32)
    prev_foe = np.ones(args.envs, dtype=np.float32)

    def refresh_selfplay() -> None:
        params, li, lo, emb, acts = pack_for_cpp(net)
        exact = True
        for e in mlp_envs:   # only the self-play third gets the fresh snapshot
            exact = set_opp_weights(e._handle, params, li, lo, emb, acts)
        if not exact and not refresh_selfplay.warned:
            refresh_selfplay.warned = True
            print(f"[ppo:{args.key}] WARNING libdh-env.so predates per-layer "
                  f"activations — the self-play opponent will run "
                  f"tanh/linear, not {net.arch.activation}. Rebuild: "
                  f"cmake --build sim/build -j", flush=True)
        refresh_selfplay.keepalive = (params, li, lo, emb, acts)  # borrowed pointers!
    refresh_selfplay.warned = False

    iteration = 0
    done_steps = 0
    results: list[int] = []
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
    elif args.arch != "gru" and not squad:
        refresh_selfplay()   # the opponent is the learner's own frozen snapshot
    # combo tracking per env: last kit act + tick (chain bonus window)
    last_kit = np.full(args.envs, -1, dtype=np.int64)
    last_kit_tick = np.full(args.envs, -1000, dtype=np.int64)
    tick_count = np.zeros(args.envs, dtype=np.int64)
    while done_steps < args.steps:
        iteration += 1
        if not args.exploit and args.arch != "gru" and not squad \
                and iteration % args.selfplay_every == 0:
            refresh_selfplay()   # past-self becomes the opponent
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
                act_dist = torch.distributions.Categorical(logits=logits)
                dodge_dist = torch.distributions.Bernoulli(logits=dodge)
                a = act_dist.sample()
                d = dodge_dist.sample()
                noise = 0.3 * torch.randn_like(move)
                m = (move + noise).clamp(-1.0, 1.0)
                logp = act_dist.log_prob(a) + dodge_dist.log_prob(d)
                acts = torch.where(d > 0.5, torch.full_like(a, 7), a).cpu().numpy()
                b_obs[t] = t_obs.cpu()
                b_move[t] = m.cpu()
                b_act[t] = torch.where(d > 0.5, torch.full_like(a, 7), a)
                b_logp[t] = logp.cpu()
                b_val[t] = value.cpu()
                m_np = m.cpu().numpy()
                # the whole tick in one call; hp, done and winner come back
                # with the observations, so nothing else crosses into C here
                nobs, done_n, hp, win = vec.step(m_np, acts)
                self_hp, foe_hp = hp[:, 0], hp[:, 1]
                r = (R_HP_DELTA * ((prev_foe - foe_hp) - (prev_self - self_hp))
                     - R_TIME).astype(np.float32)
                tick_count += 1
                kit = (acts >= 3) & (acts <= 6)          # a kit was cast
                if kit.any():
                    r[kit] += R_KIT
                    # chained a DIFFERENT kit inside the combo window
                    chain = kit & (last_kit >= 0) & (last_kit != acts) \
                        & ((tick_count - last_kit_tick) <= CHAIN_WINDOW)
                    r[chain] += R_CHAIN
                    last_kit[kit] = acts[kit]
                    last_kit_tick[kit] = tick_count[kit]
                live = done_n == 0
                prev_self[live] = self_hp[live]
                prev_foe[live] = foe_hp[live]
                fin = np.flatnonzero(done_n)
                if fin.size:
                    w = win[fin]
                    r[fin] += np.where(w == 0, R_WIN,
                                       np.where(w == 1, R_LOSE, 0.0)).astype(np.float32)
                    results.extend(int(x) for x in w)
                    vec.reset_done(fin, rng.integers(1, 2**31, size=fin.size)
                                   .astype(np.uint64))
                    prev_self[fin] = 1.0
                    prev_foe[fin] = 1.0
                    last_kit[fin] = -1
                    tick_count[fin] = 0
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
                        _, logits, dodge, value, h_up = net(
                            b_obs[t, mb].to(device), "*", h_up)
                        is_dodge = b_act[t, mb].to(device) == 7
                        a = torch.where(is_dodge,
                                        torch.zeros_like(b_act[t, mb]).to(device),
                                        b_act[t, mb].to(device))
                        cat = torch.distributions.Categorical(logits=logits)
                        logps.append(cat.log_prob(a)
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
            f_obs = b_obs.reshape(T * N, -1).to(device)
            f_act = b_act.reshape(T * N).to(device)
            f_logp = b_logp.reshape(T * N).to(device)
            f_adv = adv.reshape(T * N).to(device)
            f_ret = ret.reshape(T * N).to(device)
            f_adv = (f_adv - f_adv.mean()) / (f_adv.std() + 1e-8)
            for _ in range(EPOCHS):
                idx = torch.randperm(T * N, device=device)
                for mb in idx.split((T * N) // MINIBATCHES):
                    _, logits, dodge, value = net(f_obs[mb])
                    is_dodge = f_act[mb] == 7
                    a = torch.where(is_dodge, torch.zeros_like(f_act[mb]), f_act[mb])
                    logp = (torch.distributions.Categorical(logits=logits).log_prob(a)
                            + torch.distributions.Bernoulli(logits=dodge).log_prob(
                                is_dodge.float()))
                    ratio = (logp - f_logp[mb]).exp()
                    s1 = ratio * f_adv[mb]
                    s2 = ratio.clamp(1 - CLIP, 1 + CLIP) * f_adv[mb]
                    loss = (-torch.min(s1, s2).mean()
                            + 0.5 * (value - f_ret[mb]).pow(2).mean()
                            - ENTROPY * torch.distributions.Categorical(
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
        sps = done_steps / (time.time() - t0)
        shown = min(done_steps, args.steps)
        eta = max(0.0, (args.steps - done_steps)) / max(sps, 1.0)
        # roll/upd split: after the batched dh_env_step_many landed, the
        # rollout is no longer the expensive half — the PPO update is.
        print(f"[ppo:{args.key}] it={iteration} steps={shown:,}/{args.steps:,} "
              f"sps={sps:,.0f} roll={roll_s:.1f}s({T * N / max(roll_s, 1e-6):,.0f}/s) "
              f"upd={upd_s:.1f}s win_rate(last {len(recent)})={wr:.2f} "
              f"eta={int(eta) // 60:d}m{int(eta) % 60:02d}s", flush=True)
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
                 and args.arch != "gru"},
    })
    json.dump(reg, open(REGISTRY, "w"), indent=1)
    print(f"[ppo:{args.key}] registered v{version} (candidate) — gate it: "
          f"ml/.venv/bin/python -m ml.training.league gate --key {args.key} "
          f"--build {args.build}")


if __name__ == "__main__":
    main()
