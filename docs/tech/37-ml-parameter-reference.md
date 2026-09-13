# tech/37 — ML reference: every parameter, artifact and benchmark

> Ricardo, 2026-09-13: *"deeply detail our documentations. Specially for our ML
> files, I want details on every parameter and hyperparameter, as well as
> artifacts produced and how they are later consumed and benchmarked."*
>
> This is the exhaustive reference for `ml/`. Companions: [tech/25](25-creature-ai-and-rl.md)
> (why the design is what it is), [tech/32](32-scaling-rl-training.md) (scaling),
> [design/23](../design/23-arena-and-self-play.md) (the arena loop),
> [design/25](../design/25-arena-training-console.md) (the console),
> [USAGE §4](../USAGE.md) (the commands). Numbers marked *measured* were taken
> on the dev box (20 cores, RTX 4050 6 GB) on 2026-09-13.

---

## 1. The three trainers, and when each is right

| Trainer | Engine in the loop | Hardware | Throughput *(measured)* | Use it when |
|---|---|---|---|---|
| **ES league** — `ml/training/league.py` | Godot headless (real game code) | CPU, N workers | 4-episode match **0.72 s**; 16 matches concurrently **1.4 s** | The default. Fitness is the real game, and the winner deploys straight to the Godot arena |
| **PPO** — `ml/training/ppo.py` | `libdh-env.so` (C++ arena twin), no Godot | GPU (CUDA) + CPU | **32,343 steps/s** end to end at `--envs 32`; raw env alone **527,665 steps/s** | Millions of steps, self-play, exploiters, recurrent nets |
| **Evolve** — `ml/training/evolve.py` | spawns PPO subprocesses, gates in Godot | GPU + CPU | PPO cost × pop × generations | Searching PPO *configs* (arch, lr, entropy, self-play cadence) rather than weights |

All three write the same registry and the same `arena.policy.v1` weights, so a
net from any of them can be gated and deployed by the same path.

---

## 2. Parameters, exhaustively

### 2.1 `league.py` — command-line

| Sub-command | Parameter | Default | What it does |
|---|---|---|---|
| all | `--progress-file` | `ml/data/progress/<key>.jsonl` | JSONL feed the console tails (§4.4) |
| all | `--speed` | `max` | `max` = CPU-bound, engine run with `--fixed-fps 60`; a number = wall-clock multiplier (legacy `4`). Results are **bit-identical** between them |
| `init` | `--key` | required | Registry key for the species/build family |
| `init` | `--global` | off | Create the global net (one embedding row per content id) instead of a species net |
| `train` | `--key` / `--build` | required | Registry key and the roster build ID it fights as |
| `train` | `--generations` | 3 | ES outer iterations. Wall cost ≈ generations × (pop × opponents ÷ jobs) × match time |
| `train` | `--pop` | 6 | Candidates per generation (mirrored perturbations). **Set `pop × opponents = cores`**; on 20 cores that is `--pop 10` |
| `train` | `--episodes` | 4 | Episodes per match. More = less fitness noise, linearly more time |
| `train` | `--sigma` | 0.02 | ES perturbation scale on every weight. Too small = no signal; too large = the population stops resembling the parent |
| `train` | `--lr` | 0.02 | ES step size applied to the fitness-weighted average perturbation |
| `train` | `--seed` | 2026 | Seeds candidate noise and match RNG (gear rolls, spawn jitter) |
| `train` | `--opponents` | `native`, `scripted` (both = the trainee's own build) | `policy@build` list, e.g. `native@core.arena.gloamfen_stalker,scripted@core.arena.dusk_revenant` |
| `train` | `--jobs` | 1 | Concurrent headless workers. **Useless past `pop × opponents`** — that is how many matches exist per generation |
| `train-global` | `--builds` | required | Comma-separated builds the one global net trains across |
| `train-global` | same knobs | gens 3, pop 6, episodes 2 | Every episode of every matchup updates the same weights |
| `gate` | `--key` / `--build` / `--episodes` | required, required, 4 | Runs §5's checks on the newest candidate |
| `round-robin` | `--episodes` | 2 | Deployed policies fight each other; prints the table |

### 2.2 `league.py` — internal constants

| Constant | Value | Meaning |
|---|---|---|
| `DEFAULT_OPPONENTS` | `native`, `scripted` | The two baselines every candidate must beat |
| `DEFAULT_SPEED` | `max` | See `--speed` |
| `fitness()` | `win_rate + 0.1 × (own_hp − foe_hp)` | HP-margin shaping gives gradient before wins appear; anneal it away as leagues mature (tech/25 §4.2) |
| `time_limit` (per episode) | 45 s sim time | Draw if neither side dies |
| timeout guard | `episodes × 45 s × wall + 120 s` | Hang guard, not an estimate |

### 2.3 `ppo.py` — command-line

| Parameter | Default | What it does |
|---|---|---|
| `--key` / `--build` | required | Registry key; the learner's build |
| `--opp-build` | required | The opponent's build |
| `--steps` | 2,000,000 | Total environment steps. At 32k steps/s ≈ 62 s per million *(measured)* |
| `--envs` | 32 | Parallel in-process arenas. Rollout batch = `envs × horizon` |
| `--selfplay-every` | 4 | Refresh the frozen self-play snapshot every N iterations. Only the self-play third of envs gets it |
| `--warm-start` | — | Registry JSON/npz to initialise from (ES → PPO continuity) |
| `--exploit` | — | Path to a fixed target net: every env plays it, the run's only job is finding its weaknesses (AlphaStar-style exploiter) |
| `--seed` | 0 | Torch, numpy and per-env seeds |
| `--arch` | `mlp` | `mlp` (exports to Godot) or `gru` (recurrent; **no Godot export**, gates via dh-env only) |
| `--squad-a-buddy` / `--squad-b-buddy` | — | Turn on 2v2; switches the observation to `arena.obs.v2` (36 floats). Squad nets also skip the Godot export |

Opponent mix without `--exploit`: envs are split in **thirds** — native AI,
scripted baseline, and `mlp` (the learner's own frozen snapshot). With `--arch gru`
the mix is half native, half scripted and self-play is off, because the C++
opponent slot is a stateless MLP.

### 2.4 `ppo.py` — hyperparameters (module constants)

| Constant | Value | Meaning |
|---|---|---|
| `GAMMA` | 0.99 | Discount |
| `LAM` | 0.95 | GAE λ |
| `CLIP` | 0.2 | PPO ratio clip |
| `ENTROPY` | 0.01 | Entropy bonus — the exploration knob `evolve.py` searches |
| `LR` | 3e-4 | Adam learning rate |
| `EPOCHS` | 4 | Passes per rollout |
| `MINIBATCHES` | 8 | Minibatches per epoch |
| `R_WIN` / `R_LOSE` | +1.0 / −1.0 | Terminal reward |
| `R_HP_DELTA` | 1.0 | Per-tick shaping on (damage dealt − damage taken), mirrors league fitness |
| `R_TIME` | 0.002 | Per-tick penalty: stalling costs |
| `R_KIT` | 0.02 | Per kit cast — beats LMB spam (canon: "no dull simple attacks") |
| `R_CHAIN` | 0.05 | Casting a **different** kit inside the window |
| `CHAIN_WINDOW` | 90 ticks (1.5 s) | The combo window that bonus applies in |
| rollout | `clamp_batch(2048 × envs)` | VRAM-capped (§2.5); horizon = `max(256, batch ÷ envs)`, and ≤ 256 for GRU (sequential BPTT) |
| grad clip | 0.5 | Global norm |
| action noise | 0.3 σ gaussian on the move head | Exploration on the continuous head |

### 2.5 `gpu_guard.py`

| Knob | Default | Meaning |
|---|---|---|
| `DH_VRAM_FRACTION` (env) | 0.5 | Fraction of the 6 GB card this process may allocate — set *before* the first CUDA allocation, so an over-budget run fails fast instead of OOM-ing mid-epoch |
| `FLOATS_PER_STEP` | 256 | Rollout-buffer accounting: obs + actions + logp + rewards + values + advantages per step |
| activation reserve | 25 % of the cap | The rest is the rollout ceiling: `max_steps = usable ÷ (FLOATS_PER_STEP × 4 B)` |
| `cudnn.benchmark` | on | Shapes are fixed, so autotuning pays |

### 2.6 Networks

| | `policy_net.PolicyNet` (numpy, ES) | `torch_policy.TorchPolicyNet` (PPO) | `TorchGRUPolicyNet` |
|---|---|---|---|
| Input | `obs[31] ++ embedding[16]` | same | same |
| Body | 64, 64 tanh | 64, 64 tanh | GRUCell(64) |
| Heads | `move[2]`, `act logits[7]`, `dodge logit[1]` | same + a **value head** (not exported) | same + value |
| Export | `arena.policy.v1` JSON + `.npz` | `arena.policy.v1` JSON | `.pt` only |
| `INIT_SCALE` | 0.1 | torch default | torch default |
| `explore` (exported) | 0.05 | 0.05 | — |

New content never changes tensor shapes: it gets a new **embedding row**,
initialised from the table mean plus small noise (canon §9 §5).

### 2.7 Observation schema `arena.obs.v1` — 31 floats

Defined once in `game/arena/policy.gd`, mirrored by `ml/training/policy_net.py`
and `sim/libs/dh-sim` (the C++ twin):

| Index | Content |
|---|---|
| 0 | own HP fraction |
| 1–2 | own position relative to ring centre ÷ 512 |
| 3–4 | own velocity ÷ 100 |
| 5 | attack cooldown fraction |
| 6 | special (E) cooldown fraction |
| 7–10 | skill slots 1–4 cooldown fractions |
| 11 | charge fraction (Combo / Attunement) |
| 12 | dodge charges fraction |
| 13 | slowed flag |
| 14 | damage-over-time flag |
| 15 | enemy HP fraction |
| 16–17 | enemy relative position ÷ 512 |
| 18 | distance ÷ 512 |
| 19–20 | bearing to enemy (sin, cos) |
| 21 | enemy body radius ÷ 16 |
| 22 | enemy winding-up flag |
| 23–30 | two nearest hostile projectiles: relative x, y ÷ 512 and velocity x, y ÷ 256 |

`arena.obs.v2` (36 floats, squads only) appends an ally block at 31–35: buddy
HP, relative position, distance, windup. 1v1 keeps v1 unchanged, so the Godot
runtime and every existing net stay valid.

**Fairness is trained, not patched** (canon §9 §6): every policy observes
through a sampled 150–250 ms delay buffer, aims through gaussian noise
(`AIM_NOISE_RAD` 0.06 rad ≈ 3.4°) and commits under a 6 actions/second burst cap.

### 2.8 `evolve.py` — the outer loop

| Parameter | Default | Meaning |
|---|---|---|
| `--pop` | 4 | PPO configs per generation |
| `--generations` | 3 | Outer iterations; top half survives and mutates |
| `--steps` | 500,000 | PPO steps per candidate — deliberately short |
| `--seed` | 0 | Config mutation and per-candidate PPO seeds |
| `CONFIG_SPACE` | arch, lr, entropy, selfplay_every | Mutation ranges, halved or doubled per child |

Candidate fitness: MLP candidates are gated in the **real Godot arena** (wins vs
native + scripted, draws count half); GRU candidates fall back to the dh-env
win rate parsed from their log, because they have no Godot export.

### 2.9 `dh-env` — the C++ environment

`DhEnv(build_a, build_b, opp="native"|"scripted"|"mlp", seed, balance=True, squad=None)`.
Fighter stats come from `ml/env/specs.json`, **generated** from the real Godot
bodies (`game/arena/tools/dump_specs.tscn`) — never hand-edited, so balance
changes reach training by re-dumping. `balance=True` scales both fighters to the
geometric-mean EHP × DPS budget (canon §12.42a) so kits, not raw stats, decide
training fights; the Godot eval gate stays unbalanced on purpose. C API:
`dh_env_create`, `dh_env_create_squad`, `dh_env_reset`, `dh_env_step`,
`dh_env_set_opp_weights`, `dh_env_hp_frac`, `dh_env_winner`, `dh_env_tick`,
`dh_env_obs_dim`, `dh_env_destroy`.

---

## 3. Where runs write: `DH_SERVING_DIR`

Every path below is resolved through `ml/serving_paths.py`. Unset, artifacts go
to `ml/serving/` — the **deployed** registry the game and console read. Set, the
whole run is isolated:

```bash
tools/train_run.sh --all --label sweep-highpop     # creates the folder, seeds it, runs, summarises
tools/train_run.sh --list                          # every run, oldest first, with config + gate results
tools/train_run.sh --promote ml/runs/<run>         # copy only gate-PASSING nets into ml/serving
```

```
ml/runs/2026-09-13_1930__all-creatures__g20_p8_e4_j20_s2026/
    config.json    every knob, git HEAD + dirty flag, godot/torch versions, cores, other trainers seen running
    registry.json  seeded from the deployed registry (cumulative) unless --fresh
    weights/       this run's nets
    progress/      per-key JSONL (console format)
    logs/          per-key trainer + gate output
    summary.txt    wall time, per-key gate verdicts, the promote command
```

Date first, so the folder sorts chronologically; the config is in the name so a
run is identifiable without opening it.

---

## 4. Artifacts: what is produced, and who consumes it

### 4.1 Weights JSON — `arena.policy.v1`

`{schema, obs_dim: 31, emb_dim: 16, explore: 0.05, embeddings: {key: [16 floats]}, layers: [{w, b, act}]}`
with `act` = tanh for hidden layers, linear for the head.

- **Produced by** `league train` (`<key>_v<N>.json`), `ppo` (`<key>_ppo_v<N>.json`),
  `evolve` (via PPO).
- **Consumed by** `game/arena/neural_policy.gd` verbatim — pass the path as
  `--policy-a` / `--policy-b`, or copy into `game/arena/data/` and use a
  `res://` path to *watch* it; by `league gate`; by `ppo --warm-start` and
  `--exploit`; by the console's Watch button.

### 4.2 `.npz` (ES) and `.pt` (GRU / squad)

`.npz` is the ES training format (weights + embeddings). `.pt` is a torch
`state_dict` for architectures with no Godot runtime yet — they gate through
dh-env evaluation only, and are the reason the registry entry records `arch`.

### 4.3 `registry.json` — `arena.registry.v1`

One entry per trained net:

| Field | Meaning |
|---|---|
| `key`, `version` | Family and monotonically increasing version |
| `kind` | `species`, `global`, `exploiter` |
| `parent` | Warm-start or exploit target lineage |
| `created` | Timestamp — also how `train_run.sh` tells this run's nets from seeded ones |
| `npz`, `game_json` | Absolute artifact paths (`game_json` is null for GRU/squad) |
| `deployed` | The pin. A failed gate leaves the previous pin alone, by design |
| `eval` | The gate report (§5) or, for PPO, `{trainer, arch, steps, selfplay}` |
| `promoted_from` | Set by `train_run.sh --promote` — which run folder it came from |

Weights are served on game servers only and never ship to clients (canon §9).

### 4.4 Progress feed — `progress/<key>.jsonl`

One JSON object per line, appended live: `start` (key, build, generations, pop),
`match` (generation, candidate, opponent build, policy, score), `candidate`
(fitness), `generation` (best, mean), `registered` (version, npz), `gate`
(version, pass, per-check metrics), `error` (message — an uncaught exception
becomes a line before it propagates). The training console
(`game/arena/console.tscn`) tails exactly this: chart, score strip, ETA.

### 4.5 Episode records — `ml/data/episodes/`

Written when a match runs with `--record-dir` (the gate always records). JSONL
of observations and actions: the behavioural-cloning dataset and the replay
source for later imitation work. Gitignored.

### 4.6 Logs — `ml/data/logs/<key>.log`, or `<run>/logs/`

Raw trainer plus gate output per key. `evolve.py` also parses its PPO logs for
`win_rate(last N)=` when a GRU candidate has no Godot-gradeable export.

### 4.7 `ml/env/specs.json`

Generated fighter table for dh-env: per build, `max_hp`, `damage`, `move_speed`,
`attack_reach`, `attack_cd`, `body_radius`, `special_cd`, `dodge_max`,
`is_player`, `is_ranged`, `kind`, `kits`; plus `field_kind_ids`. Regenerate
after any balance change:

```bash
godot --headless --path game -s res://arena/tools/dump_specs.gd -- --out "$PWD/ml/env/specs.json"
```

---

## 5. How a net is benchmarked

`ml/eval/gate.py` — nothing deploys without passing it:

| Check | Band | Meaning |
|---|---|---|
| `suite_scripted` | win rate 0.30–1.00 | Beat the utility baseline |
| `suite_native` | win rate 0.30–1.00 | Beat the built-in creature AI |
| `suite_*_sanity` | mean loser HP deficit ≥ 0.05 | Damage must actually flow — catches stalls and degenerate policies |
| `ladder_vs_deployed` | win rate 0.25–0.90 | Improvement over the current pin without a tier jump; skipped when nothing is deployed yet |

Every check runs `--episodes` matches in the real Godot arena (unbalanced, on
purpose — deployment reality). Pass sets `deployed: true`; fail leaves the fleet
on the previous pin and says so.

Other measurements:

```bash
ml/.venv/bin/python -m ml.env.bench --seconds 5 --opp scripted   # env throughput, asserts ≥ 100k steps/s
python3 -m ml.training.league round-robin --episodes 2           # deployed policies vs each other
python3 -m pytest ml/tests/ -q                                   # league, policy-net and progress-feed tests
```

*Measured 2026-09-13:* bench 527,665 steps/s; one 4-episode Godot match 0.72 s;
16 concurrent 1.4 s; 20 concurrent 1.7 s; a gate (3 sequential match sets) 3.1 s;
PPO end to end 32,343 steps/s at `--envs 32`, win rate against the native third
visibly moving inside the first two million steps.

---

## 6. Known gaps (2026-09-13)

- **The learning signal against native `fen_boar`**: candidates take 0 wins in
  every match, so fitness moves on HP margin alone. Next levers: an opponent
  curriculum (scripted → past self → native) and reward shaping (tech/25 §4.2).
- **GRU and squad nets cannot deploy**: the Godot runtime is a stateless
  31-observation MLP. They gate via dh-env until it grows a recurrent path and
  observation v2.
- **PPO leaves ~16× on the table**: the environment alone runs 527k steps/s but
  the trainer reaches 32k, because Python steps each env individually through
  ctypes every tick. A batched `dh_env_step_many` over all envs (or several
  worker processes) is the obvious next optimisation.
- **ONNX / INT8 serving** is still future work; the runtime reads JSON today.
