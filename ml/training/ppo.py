"""PPO over dh-env (docs/tech/25 §R1): the GPU trainer Ricardo asked for.

  learner (torch, CUDA, VRAM-capped via gpu_guard)
    × N in-process libdh-env arenas (216-256k steps/s/core, no Godot)
    × opponents: native | scripted | mlp SELF-PLAY (frozen snapshots of the
      learner — the past-self league inside the env; exploiters join via
      ml/training/league.py's opponent lists)

Reward mirrors the league's fitness (win rate + hp-margin shaping), so ES and
PPO optimize the same objective and every PPO checkpoint exports schema
"arena.policy.v1" JSON the Godot arena gates verbatim.

    ml/.venv/bin/python -m ml.training.ppo \
        --key cinder_drake --build core.arena.cinder_drake \
        --opp-build core.arena.fen_boar_alpha \
        --steps 2000000 --envs 32 --selfplay-every 4
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
from ml.env.dh_env import DhEnv, OBS_DIM                     # noqa: E402
from ml.training.gpu_guard import apply as gpu_apply, clamp_batch  # noqa: E402
from ml.training.torch_policy import TorchPolicyNet, TorchGRUPolicyNet  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
WEIGHTS_DIR = REPO / "ml" / "serving" / "weights"
REGISTRY = REPO / "ml" / "serving" / "registry.json"

# reward shaping == league fitness terms (win rate + hp margin)
R_WIN, R_LOSE, R_HP_DELTA, R_TIME = 1.0, -1.0, 1.0, 0.002
# combo incentives (Ricardo: "no dull simple attacks — mobs rely on skill
# combos"): small per-cast bonus so kits beat LMB spam, plus a chaining bonus
# for firing a DIFFERENT kit within the combo window (1.5 s = 90 ticks)
R_KIT, R_CHAIN, CHAIN_WINDOW = 0.02, 0.05, 90
GAMMA, LAM, CLIP, ENTROPY, LR, EPOCHS, MINIBATCHES = 0.99, 0.95, 0.2, 0.01, 3e-4, 4, 8
SNAPSHOTS = REPO / "ml" / "data" / "ppo_snapshots"


def pack_for_cpp(net: TorchPolicyNet) -> tuple[np.ndarray, np.ndarray,
                                                np.ndarray, np.ndarray]:
    """Torch net -> the C++ packing: per layer [W out×in][b]; emb16 row "*"."""
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
    return (np.concatenate(params).astype(np.float32),
            np.array(layer_in, dtype=np.int32),
            np.array(layer_out, dtype=np.int32), emb.astype(np.float32))


def pack_from_policy_json(path: str) -> tuple[np.ndarray, np.ndarray,
                                              np.ndarray, np.ndarray]:
    """arena.policy.v1 JSON -> the C++ packing (fixed exploiter opponents)."""
    data = json.load(open(path))
    params, layer_in, layer_out = [], [], []
    for l in data["layers"]:
        w = np.asarray(l["w"], dtype=np.float32)
        params += [w.ravel(), np.asarray(l["b"], dtype=np.float32)]
        layer_in.append(w.shape[1])
        layer_out.append(w.shape[0])
    emb = np.asarray(data.get("embeddings", {}).get("*", [0.0] * 16),
                     dtype=np.float32)
    return (np.concatenate(params).astype(np.float32),
            np.array(layer_in, dtype=np.int32),
            np.array(layer_out, dtype=np.int32), emb)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True)
    ap.add_argument("--build", required=True)
    ap.add_argument("--opp-build", required=True)
    ap.add_argument("--steps", type=int, default=2_000_000)
    ap.add_argument("--envs", type=int, default=32)
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
    net = (TorchGRUPolicyNet(["*"], obs_dim=obs_dim) if args.arch == "gru"
           else TorchPolicyNet(["*"], obs_dim=obs_dim)).to(device)
    if args.warm_start:
        from ml.training import policy_net
        es = policy_net.PolicyNet()
        data = json.load(open(args.warm_start))
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
    obs = np.stack([e.reset(seed=args.seed * 977 + i) for i, e in enumerate(envs)])
    prev_self = np.ones(args.envs, dtype=np.float32)
    prev_foe = np.ones(args.envs, dtype=np.float32)

    def refresh_selfplay() -> None:
        params, li, lo, emb = pack_for_cpp(net)
        import ctypes
        for e in mlp_envs:   # only the self-play third gets the fresh snapshot
            lib = __import__("ml.env.dh_env", fromlist=["lib"]).lib()
            lib.dh_env_set_opp_weights(
                ctypes.c_void_p(e._handle),
                params.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
                li.ctypes.data_as(ctypes.POINTER(ctypes.c_int32)),
                lo.ctypes.data_as(ctypes.POINTER(ctypes.c_int32)),
                len(li), emb.ctypes.data_as(ctypes.POINTER(ctypes.c_float)))
        refresh_selfplay.keepalive = (params, li, lo, emb)   # borrowed pointers!

    iteration = 0
    done_steps = 0
    results: list[int] = []
    t0 = time.time()
    if args.exploit:
        # EXPLOITER MODE (AlphaStar league shape): the opponent is a FIXED
        # target net — this run's only job is finding its weaknesses
        packed = pack_from_policy_json(args.exploit)
        import ctypes
        lib = __import__("ml.env.dh_env", fromlist=["lib"]).lib()
        for e in envs:
            lib.dh_env_set_opp_weights(
                ctypes.c_void_p(e._handle),
                packed[0].ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
                packed[1].ctypes.data_as(ctypes.POINTER(ctypes.c_int32)),
                packed[2].ctypes.data_as(ctypes.POINTER(ctypes.c_int32)),
                len(packed[1]), packed[3].ctypes.data_as(ctypes.POINTER(ctypes.c_float)))
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
                for i, e in enumerate(envs):
                    done, nobs = e.step((float(m_np[i, 0]), float(m_np[i, 1])),
                                        int(acts[i]))
                    r = R_HP_DELTA * ((prev_foe[i] - e.hp_frac(1))
                                      - (prev_self[i] - e.hp_frac(0))) - R_TIME
                    tick_count[i] += 1
                    if 3 <= int(acts[i]) <= 6:   # a kit was cast
                        r += R_KIT
                        if last_kit[i] >= 0 and last_kit[i] != int(acts[i]) \
                                and tick_count[i] - last_kit_tick[i] <= CHAIN_WINDOW:
                            r += R_CHAIN   # chained a DIFFERENT kit in the window
                        last_kit[i] = int(acts[i])
                        last_kit_tick[i] = tick_count[i]
                    if done:
                        w = e.winner
                        r += R_WIN if w == 0 else (R_LOSE if w == 1 else 0.0)
                        results.append(w)
                        nobs = e.reset(seed=int(rng.integers(2**31)))
                        prev_self[i] = prev_foe[i] = 1.0
                        last_kit[i] = -1
                        tick_count[i] = 0
                        if h is not None:
                            h[i] = 0.0   # episode boundary wipes temporal state
                    else:
                        prev_self[i] = e.hp_frac(0)
                        prev_foe[i] = e.hp_frac(1)
                    b_rew[t, i] = r
                    b_done[t, i] = float(done)
                    obs[i] = nobs
        done_steps += T * N
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
        if iteration % 5 == 0:
            recent = results[-200:]
            wr = sum(1 for w in recent if w == 0) / max(1, len(recent))
            sps = done_steps / (time.time() - t0)
            print(f"[ppo:{args.key}] it={iteration} steps={done_steps:,} "
                  f"sps={sps:,.0f} win_rate(last {len(recent)})={wr:.2f}")
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
