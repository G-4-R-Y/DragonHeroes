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
| `train` | `--checkpoint-every` | 25 | Save the search state (theta + the RNG stream) every N generations; 0 disables. Without it a killed run loses everything — the net registers only after the FULL loop completes |
| `train` | `--resume` | off | Continue this key's checkpoint instead of restarting the search. **Exact, not approximate:** match seeds are derived from the generation index, and the perturbation RNG is restored from its saved bit-generator state, so a resumed run is the run that would have happened (asserted bit-for-bit in `ml/tests/test_league.py`) |
| `train-global` | `--builds` | required | Comma-separated builds the one global net trains across |
| `train-global` | same knobs | gens 3, pop 6, episodes 2 | Every episode of every matchup updates the same weights |
| `gate` | `--key` / `--build` / `--episodes` | required, required, 4 | Runs §5's checks on the newest candidate |
| `round-robin` | `--episodes` | 2 | Deployed policies fight each other; prints the table |

### 2.2 `league.py` — internal constants

| Constant | Value | Meaning |
|---|---|---|
| `DEFAULT_OPPONENTS` | `native`, `scripted` | The two baselines every candidate must beat |
| `DEFAULT_SPEED` | `max` | See `--speed` |
| `fitness()` | the weighted model, `ml/training/reward.py` | One scale-normalized definition of "good fight", shared with PPO's terminal reward so ES and PPO stop optimising different things (tech/25 §4.3). Weights are data: `ml/training/reward_weights.json` |
| `fitness_v1()` | `win_rate + 0.1 × (own_hp − foe_hp)` | The original, KEPT and selectable (`"model": "v1"`). Scores neither damage nor duration, and hp clamps at zero, so a kill and a long grind ending at the same health are one number to it. Every ES ranking before 2026-09-14 used it |
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
| `R_TERMINAL` | 2.0 | Scales the `[0,1]` weighted episode score (`ml/training/reward.py`) into reward units, centred on 0.5. Reproduces the old ±1 spread between a perfect win and a total loss, but now every term — outcome, damage both ways, both healths, outcome-conditioned duration — is paid once on one scale |
| `R_DEAL` / `R_ABSORB` | 1.0 / 0.73 | Dense per-tick damage shaping, **asymmetric on purpose**. It was one symmetric term (`R_HP_DELTA` 1.0 each way), so avoiding a hit paid exactly as well as landing one — the avoidance local optimum, which PPO seed 7 duly found (`mean_loser_hp 0.967`, a timeout "win" the sanity gate refused) |
| ~~`R_WIN` / `R_LOSE`~~ | ~~+1.0 / −1.0~~ | Superseded by `R_TERMINAL` × the weighted score |
| ~~`R_HP_DELTA`~~ | ~~1.0~~ | Superseded by `R_DEAL` / `R_ABSORB` |
| `R_TIME` | **0.0** (was 0.002) | Removed, wrong twice over. It applied every tick REGARDLESS of outcome, so a losing agent was paid to die sooner (Ricardo: *"If loser, the longest the better"*); and at `0.002 × 3600` ticks it totalled **7.2 against a win bonus of 1.0**, so the clock outweighed the result 7×. `GAMMA` already discounts later reward — that IS "sooner is better" — and duration now lives in the terminal score where its sign can depend on the outcome |
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
| Body | `arch.hidden`, `arch.activation` (default 64, 64 tanh) | same | GRUCell(64), fixed |
| Heads | `move[2]`, `act logits[7]`, `dodge logit[1]` | same + a **value head** (not exported) | same + value |
| Export | `arena.policy.v1` JSON + `.npz` | `arena.policy.v1` JSON | `.pt` only |
| Init | `arch.init` (`normal` ×`init_scale`, `he`, `xavier`) | same rule | torch default |
| `explore` (exported) | 0.05 | 0.05 | — |

New content never changes tensor shapes: it gets a new **embedding row**,
initialised from the table mean plus small noise (canon §9 §5).

### 2.6b The architecture — `--net` (`ml/training/arch.py`)

Ricardo, 2026-09-13: *"net hyperparams should be configurable, as to test new
architectures."* One `Arch` — width, activation, init — named in
`ml/training/architectures.json`, selected the same way on **every** trainer:

```bash
python3 -m ml.training.arch                       # the presets and what they cost
python3 -m ml.training.league train --net relu    --key k --build b
ml/.venv/bin/python -m ml.training.ppo --net relu-wide --key k --build b --opp-build ob
python3 -m ml.training.distill --net tiny --teacher k@candidate --key k --build b
python3 -m ml.training.tournament --net relu --all     # every entrant, one shape
NET=relu-wide tools/train_run.sh --ppo --key k --build b --opp-build ob
```

| Flag | Default | What it does |
|---|---|---|
| `--net` | `default` | A preset from `architectures.json`. Adding one there needs no code |
| `--hidden` | from the preset | `256,256`. Any depth |
| `--activation` | from the preset | `tanh`, `relu`, `leaky_relu` (slope 0.01), `linear`. Hidden layers only — the head is always linear |
| `--init` | from the preset | `normal` (×`--init-scale`), `he` (relu), `xavier` (tanh) |
| `--init-scale` | 0.1 | Only used by `normal` |

| Preset | Shape | MACs/tick | Note |
|---|---|---|---|
| `default` | 64, 64 tanh | 7,744 | **What ships.** Every net in `ml/serving` is this |
| `tiny` | 32, 32 tanh | 2,848 | Half the cost, for crowded scenes |
| `relu` | 64, 64 relu, he | 7,744 | Shipping size, different nonlinearity |
| `wide` | 256, 256 tanh, xavier | 80,128 | **Teacher only** — 10.3× the budget |
| `relu-wide` | 256, 256 relu, he | 80,128 | Teacher only |
| `deep` | 128×3 relu, he | 40,064 | Teacher only — depth instead of width |

**Why the activation list is short.** The same forward pass runs in four places,
and two of them have to be **bit-identical** (`game/arena/neural_policy.gd` and
`sim/libs/dh-godot` `DhPolicyNet` — a last-bit disagreement invalidates every
trained weight). `max(0, x)` and a hard-coded 0.01 slope are exactly reproducible
in GDScript and C++; `gelu`/`silu` would need an `erf`/`exp` equivalence proof
nobody has written. The gate is
`godot --headless --path game res://arena/tests/policy_parity_test.tscn --quit-after 20`.

**Activation codes** cross into C++ and are part of the contract:
`0 linear · 1 tanh · 2 relu · 3 leaky_relu`. The exported JSON carries the NAME;
`dh_env_set_opp_weights_acts` and `DhPolicyNet.add_layer` carry the code. The
numbering is chosen so an old `bool use_tanh` still means what it meant.

**Architectures do not warm-start into each other.** `league train` and
`ppo --warm-start` both refuse a donor of a different shape or activation and say
so — copying a 64×64 tanh trunk into a 256×256 relu one produces a net that is
neither. The way across is distillation (`ml/training/distill.py`), which is
exactly what it is for.

**A wide net cannot ship.** 80,128 MACs is ~1.09 ms/agent/tick against a 16,670 µs
frame: fifteen agents eat it. Train a teacher wide, distil a `default` student,
deploy the student.

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

`{schema, obs_dim: 31, emb_dim: 16, explore: 0.05, hidden: [...], arch: {...},
embeddings: {key: [16 floats]}, layers: [{w, b, act}]}`
where each layer's `act` is one of `tanh`, `relu`, `leaky_relu`, `linear` (§2.6b).
The runtime reads the layer shapes and each `act`; `hidden`/`arch`/`macs` are
metadata so a file on disk can say what it is.

> `act: "logits"` appears in four nets exported before activations were an enum
> (`cinder_drake_ppo_v2..v5`). It always meant linear and is still accepted as an
> alias everywhere; nothing writes it any more.

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

### 4.2b `_ckpt_<key>.npz` — the interruptible search

A long ES run used to be all-or-nothing: `train_es` registers its net only when
the whole generation loop finishes, so a 1000-generation sweep killed at
generation 488 left nothing behind. The checkpoint fixes that.

| Array in the `.npz` | Holds |
|---|---|
| `theta` | the current search centre |
| `meta` | a JSON blob: `next_g`, `theta_size`, `rng_state` (the bit-generator state), the knobs the run was using, and when it was saved |

- **One file, deliberately.** The first cut wrote theta and the metadata as two
  files. Each rename was atomic but the *pair* was not, so a kill landing
  between them left weights from generation N beside metadata claiming N-k, and
  the resume would silently replay generations it had already done. Both now
  ride in one `.npz`, so the single rename commits the whole checkpoint —
  it either exists completely or does not exist. `test_checkpoint_commits_in_a_single_rename`
  holds that line.
- **Produced by** `league train` every `--checkpoint-every` generations, written
  to a temp name and renamed. It lands in `$DH_SERVING_DIR/weights/`, meaning an
  isolated run checkpoints inside its own folder.
- **Consumed by** `league train --resume` and `tools/train_run.sh --resume <run>`.
- **Deleted** the moment the run completes and registers, so a later `--resume`
  cannot pick up a finished search.
- **Refused** when the checkpoint is for a different parameter count (the
  warm-start moved) or is already at or past the requested generation count —
  the run says so and starts fresh rather than half-applying it.

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

### Head to head: `league versus` (best-of-N)

The gate says *is this net good enough to ship*. `versus` says *which of these
two is better* (Ricardo, 2026-09-13: "even put one against the other for
benchmarking (best of N)").

```bash
python3 -m ml.training.league versus --best-of 9 --episodes 3 --jobs 9 \
    --a fen_boar@v6 --b fen_boar@deployed --a-build core.arena.fen_boar_alpha
```

| Flag | Default | Meaning |
|---|---|---|
| `--a` / `--b` | required | `native`, `scripted`, a path to an `arena.policy.v1` JSON, or a registry reference: `<key>`, `<key>@v3`, `<key>@deployed`, `<key>@candidate` |
| `--a-build` / `--b-build` | required / = `--a-build` | the builds the two sides play |
| `--best-of` | 9 | rounds. All of them are played even after the outcome is decided |
| `--episodes` | 1 | episodes per round; a round goes to whoever wins more |
| `--jobs` | 1 | rounds run concurrently |
| `--seed` | 2026 | round *i* uses `seed + i*7919`, so a verdict replays |
| `--out` | `ml/data/benchmarks/<date>__<a>_vs_<b>.json` | where the verdict lands |

Verdict schema `arena.versus.v1`: both sides' spec/label/build, `best_of`,
`episodes_per_round`, seed, speed, every round (`wins_a`, `wins_b`, `draws`,
`hp_a`, `hp_b`, `score_a`, `duration_s`), then `rounds_a`/`rounds_b`/
`rounds_drawn`, `winner`, `clinched_round` and `episode_win_rate_a`. It streams
`versus_start` / `versus_round` / `versus_done` on the progress feed under the
key `versus`, which is how the console's VERSUS tab paints it live.

> **Determinism caveat (measured 2026-09-13).** A *neural* side makes rounds
> differ: aim noise and the observation delay consume the per-episode seed, so
> one net vs native gave 0-2, 0-0 and 0-1 on seeds 3 / 777 / 424242. Two
> *baseline* sides do not: scripted vs native returned an identical 1-0 for
> every seed tried. A best-of-N between native and scripted is therefore N
> copies of one match — a reference point, not a distribution.

Other measurements:

```bash
ml/.venv/bin/python -m ml.env.bench --seconds 5 --opp scripted   # env throughput, asserts ≥ 100k steps/s
python3 -m ml.training.league round-robin --episodes 2           # deployed policies vs each other
python3 -m pytest ml/tests/ -q                                   # league, policy-net and progress-feed tests
```

*Measured 2026-09-13 (idle box):* bench 527,665 steps/s; one 4-episode Godot
match 0.72 s; 16 concurrent 1.4 s; 20 concurrent 1.7 s; a gate (3 sequential
match sets) 3.1 s; PPO end to end 32,343 steps/s at `--envs 32`.

### Why a Godot episode costs what it costs

Ricardo, 2026-09-13: *"what is it about episodes that take them so long? won't
they be only calculated computationally? we don't need to render images"*.

Rendering is already off — `--headless` draws nothing. The cost is that the
match is a **real fight simulated frame by frame by the Godot engine**: an
episode covers ~28.5 simulated seconds at 60 physics ticks per second, so
~1,700 frames, each running GDScript `_physics_process` across every node in
the arena, plus a fresh engine process per match.

*Measured 2026-09-13, one process at a time, on a box already running a 20-job
sweep:*

| Episodes in the match | Wall |
|---|---|
| 1 | 4.07 s |
| 4 | 7.74 s |
| 13 | 16.58 s |

That is a straight line: **~3.0 s fixed per match** (engine boot, project and
scene load) plus **~1.04 s per episode**. So episodes are not what is
expensive per unit — the engine is. Two consequences:

- More episodes per match is *cheaper per episode*, because the 3 s startup
  amortises. Thirteen episodes cost 1.28 s each; one episode costs 4.07 s.
- A live sweep sees far worse than 16.58 s per 13-episode match — the run of
  2026-09-13 averages 86 s — because `--jobs 20` puts 20 of these engines on 20
  cores at once and they contend.

The comparison that matters, both measured on the same loaded box:

| Simulator | Simulated seconds per wall second |
|---|---|
| Godot arena, headless | 27.5× |
| `libdh-env` (the C++ twin), 64 envs | 6,076× |

**~220× apart.** That is the whole argument for dh-env: the PPO tier already
trains there, and the ES league still pays the Godot price because its fitness
is deliberately the *deployment* environment. The gate must stay in Godot; the
search does not have to.

#### Where the tick actually goes (measured 2026-09-13, later)

Ricardo followed up: *"1) can't we load the engine just once and run all
episodes? 2) can't we accelerate the 60 physics tick/s to just process all the
ticks capped by our processing power? 3) how can we optimize the godot arena? i
noticed my gpu is VERY subutilised"*. The table above answers (1) — the engine
already loads once per MATCH, not per episode. The rest needed a profile.

Method: run the same matchup at two different `--time-limit` values and take
the slope. Startup cancels out, so the number is honest even on a loaded box.
**A first attempt at this was wrong** and is worth recording: it passed the
weights as a path relative to the repo, but the arena runs with `--path game`,
so `FileAccess` resolved it against `res://`, the load failed, and the fighter
silently fell back to its native AI. The "neural" rows measured native. Always
pass an absolute policy path, and check stderr for `NeuralPolicy:` errors.

| Matchup | µs per tick |
|---|---|
| native vs native | ~250–380 |
| scripted vs scripted | ~340–630 |
| neural vs native | ~2,540 |
| neural vs neural | ~4,740–4,950 |

**One neural side costs ~2,200 µs per tick — 93% of the whole arena tick.**
Physics, projectiles, fields and every other node together are the remaining
7%. The forward pass is 47→64→64→10, just 7,744 multiply-adds, and GDScript was
spending ~400 ns on each one because `_forward` held the weights as an `Array`
of `Array` and did `float(row[j]) * float(out[j])` — every element through a
Variant. Flattening to a `PackedFloat64Array` indexed `o * n_in + j` made it
**1.74× faster with bit-identical fights** (the exported weights are
float32-exact and the accumulator was always a GDScript float, so no number
moves). Even flattened it is ~3,100 µs/tick, still ~1000× off what C does:
moving the forward pass into `dh-godot` is the single biggest remaining win,
and it is blocked on that GDExtension not existing yet.

Answering (2): the tick rate is **already uncapped**. `--speed max` sets
`--fixed-fps 60`, `Engine.max_fps = 0` and
`low_processor_usage_mode_sleep_usec = 0`, so the engine advances one 1/60 s
tick per frame as fast as one core allows and never sleeps. 60 Hz is the
simulation *resolution*, not a wall-clock rate. Note that canon specifies a
**30 Hz** sim; the arena runs at 60, so matching canon would halve the work —
but it changes dodge windows and projectile stepping, so every trained net and
gate band would need revisiting. That is a product decision, not a tuning knob.

Answering (3): **the GPU cannot help this path at all.** A `--headless` Godot
draws nothing, so the arena never touches the GPU — an idle card during
training means there is no rendering to do, not that throughput is being left
unused. The GPU tier is PPO over `libdh-env`. Nor does running more keys in
parallel help — though my first reason for saying so was wrong. I read load
average 23–24 on 10 physical cores as oversubscription. Measured afterwards on
an idle box, `--jobs` does not plateau until 16:

| `--jobs` | 4 | 8 | 10 | 12 | 16 | 20 |
|---|---|---|---|---|---|---|
| steady s/generation | 9.6 | 7.4 | 7.1 | 7.0 | 6.4 | 6.4 |

`JOBS=$(nproc)` is correct; hyperthreading earns its keep. The real reason
parallel keys buy nothing is **throughput, not contention**: a generation is 20
matches, and one key at `jobs=20` already saturates the box at ~3.1 matches per
second. Two keys at `jobs=10` each push the same 40 matches through the same
pipe in the same total time.

#### The arena was not reproducible (fixed 2026-09-13)

Godot **randomises the global random stream at startup** — three consecutive
headless runs printed `randf()` = 0.394, 0.927, 0.505. `arena.gd` seeded its
own `_rng` but never that one, and gameplay draws from it: `creature.gd`'s
wander target, `hag.gd`'s retreat destination, `projectile.gd`'s volley desync.
So the same `--seed` produced a different fight every run:

| dusk_revenant vs gloam_wisp, seed 77 | `dmg_taken_b` per episode |
|---|---|
| run 1 | [0, 0, 0] |
| run 2 | [0, 88.6, 0] |
| run 3 | [0, 112.0, 0] |

Winners were stable, which is why every win-rate check missed it — but fitness
is `win_rate + 0.1 × (own_hp − foe_hp)`, so the hp term was partly luck.
Measured fitness over 4 identical runs of the live sweep's own matchup:
**sd 0.0037 before, 0.0000 after**, against a within-generation candidate sd of
0.0350. So roughly **11% of what ES was ranking on was noise** — real, now
gone, and not the order-of-magnitude effect a first glance suggests.

The fix is one line in `_start_episode`: seed the global stream from the match
seed, the rotation index and the episode index, so episodes still differ from
each other while reproducing exactly across runs.

#### Resident arena workers (`--serve`)

The engine boot is pure overhead repeated 20 times a generation. `--serve`
keeps one engine alive and takes matchups as JSON on stdin:

```
in   {"a":..,"b":..,"policy_a":..,"policy_b":..,"episodes":N,"time_limit":..,
      "seed":N,"speed":"max","out":"/abs/path.json"}
     {"quit":true}
out  ARENA SERVE READY            (boot finished, send work)
     ARENA SERVE DONE <out path>  (that matchup is written and closed)
```

The result still goes to a **file**, not stdout, so the reader is unchanged and
Godot's own prints cannot corrupt a result. `league.py` keeps a pool of these,
one per job, booted once per run. `DH_ARENA_POOL=0` turns it off.

Steady-state cost of one generation (idle box; pop 10, 13 episodes, 2
opponents, jobs 10; every row includes the flat-MLP fix):

| configuration | s/generation | speedup |
|---|---|---|
| editor binary, one engine per match | 13.0 | 1.00× |
| editor binary + resident workers | 9.3 | 1.39× |
| release export, one engine per match | 9.5 | 1.36× |
| release export + resident workers | 7.1 | **1.83×** |

All four produce identical scores. A 1000-generation key goes 3.6 h → 2.0 h.

**The correctness gate is state leaking between matches.** A reused engine
could carry a cache, a static or a surviving node into the next fight. The test
sends the same matchup **first and last** in a batch with others between, and
demands the one-shot result for both — order dependence is how leakage shows.
A worker that hangs or dies is dropped and the match is retried one-shot, so a
flaky engine can never fail a generation, and every worker is killed at exit
(a leaked one is a headless Godot holding a core until reboot).

Two traps, both found by running it rather than reasoning about it:

- `OS.read_string_from_stdin()` is **line-oriented and strips the newline**, so
  code that waits for a `"\n"` hangs on the very first request.
- Godot flushes stdout per print in **debug** builds but not in **release**, so
  a release trainer's `ARENA SERVE READY` sits in the C buffer and every worker
  times out. Fixed with `run/flush_stdout_on_print=true`. A build check that
  reads stdout from a file after exit will NOT catch this — it has to probe
  over a live pipe, which is what `tools/build_arena.sh` now does.

#### The forward pass in C++ — and the bottleneck moving

`sim/libs/dh-godot` is now built (`tools/build_dh_godot.sh`) and exposes
`DhPolicyNet`. Per tick, neural vs neural, idle box:

| forward pass | µs/tick |
|---|---|
| nested `Array` of `Array` (original) | ~986 |
| flat `PackedFloat64Array` (GDScript) | 566 |
| `DhPolicyNet` (C++) | **105** |

Bit-identical fights at every step — verified, because the registry's nets were
trained against the GDScript runtime.

**But 5.4× per tick did not become 5.4× per generation.** Measured end to end on
the best configuration (release export + resident workers, pop 10, 13 episodes,
2 opponents, candidates perturbed from a *trained* net so the fights run long),
interleaved A/B/A/B: C++ 12.4 s/gen vs GDScript 13.2 s/gen — **~1.06×, inside
the noise**.

That is the honest result, and it is worth understanding rather than hiding: the
forward pass *was* 93% of the tick, and now the tick is no longer where a
generation's time goes. What is left is per-episode scene teardown and rebuild
(`_start_episode` frees both fighters, clears summons, projectiles and fields,
then respawns from the build defs — 13 times per match) and per-match process
overhead. **That is the next thing to profile**, not the tick.

A warning for anyone benchmarking this: an earlier version of the end-to-end
test used *random* candidate nets. They lose in seconds, so the generation was
engine-startup bound and showed nothing at all. Perturb a trained net, or the
measurement answers a question nobody asked.

#### Can the GPU do the physics? (asked 2026-09-13)

No, and the premise is worth correcting. Godot's 2D physics is CPU-only — there
is no CUDA backend to enable, and writing one is an engine project rather than a
setting. But the deeper answer is that **physics is not the cost**: the forward
pass is ~93% of the tick and everything else — physics, projectiles, fields,
node processing — is the remaining ~7%. Taking physics to zero buys 7%.

The shape is also wrong for a GPU. A GPU wins on *throughput*: thousands of
independent items in one launch. One arena match has two fighters and a handful
of projectiles, and a kernel launch costs ~5–10 µs against a ~250–380 µs step of
branchy, data-dependent scalar logic — the transfers would cost more than the
math. The same applies to the MLP: 7,744 multiply-adds is far too small a call
to be worth a round trip on its own.

The GPU-shaped version of this problem is *"simulate ten thousand fights at
once"*, and that already exists: `libdh-env` + PPO, batched, on the GPU, at
56k steps/s. For the **Godot** arena the next step is C++ (`dh-godot`), not CUDA.

#### The release trainer export

Training runs matches through the Godot **editor** binary, which is a debug
build (`OS.is_debug_build()` is true). `tools/build_arena.sh` exports a release
build instead. A release template refuses a scene path on the command line
(`disable_path_overrides`), so the export carries the custom feature `trainer`
and `game/project.godot` sets `run/main_scene.trainer="res://arena/arena.tscn"`
— the binary boots the arena itself. Point training at it with `DH_ARENA_BIN`.

Verified **bit-identical** to the editor binary on scripted, native and neural
matchups. Honest payoff: startup **4.01 s → 2.53 s**, and near nothing per tick
while the GDScript MLP dominates — but 1.5 s × 20 matches × 1000 generations is
about 8 hours per key, so it pays for itself. It becomes a large win once the
forward pass moves to C++.

### The batched environment (`dh_env_step_many`)

The PPO rollout used to cross into C four times **per env per tick** (step, two
`hp_frac`, `winner`) and pay a Python loop on top. `dh_env_step_many` does the
whole tick in one crossing, writing observations, done flags, HP fractions and
winners into caller-owned buffers; `VecDhEnv` (`ml/env/dh_env.py`) is the Python
side. Envs share nothing, so an optional C++ worker pool can drain them —
`--env-threads`, default 1, because a 32-env tick is only tens of microseconds
and synchronising costs more than it saves below ~128 envs.

*Measured while a 20-job ES sweep held the box at load 20:*

| Envs | Per-env loop | `step_many` | Gain |
|---|---|---|---|
| 32 | 56,564 steps/s | 352,559 | 6.2× |
| 64 | 62,380 | 399,433 | 6.4× |
| 128 | 54,974 | 638,807 | 11.6× |

Trajectories are bit-identical to the per-env path (asserted over 200 ticks ×
32 envs with a fixed action stream), and episode counts match.

With the envs cheap, the rollout became bound by one **small GPU forward per
tick**, so the throughput knob is now batch width, not horizon:

| `--envs` | End-to-end PPO |
|---|---|
| 32 | 5,834 steps/s |
| 64 | 9,747 |
| 256 | 31,582 |
| 512 | **56,288** ← the knee, and the new default |
| 1024 | 57,757 |
| 2048 | 56,414 |

Each iteration prints `roll=`/`upd=` so the split is visible: after the change
the PPO update is a second or two while the rollout is still the larger half.

---

## 6. Known gaps (2026-09-13)

- **The learning signal against native `fen_boar`**: candidates take 0 wins in
  every match, so fitness moves on HP margin alone. Next levers: an opponent
  curriculum (scripted → past self → native) and reward shaping (tech/25 §4.2).
- **GRU and squad nets cannot deploy**: the Godot runtime is a stateless
  31-observation MLP. They gate via dh-env until it grows a recurrent path and
  observation v2.
- ~~**PPO leaves ~16× on the table**~~ — **done 2026-09-13** (Ricardo: "do
  it!"). `dh_env_step_many` removed the per-env ctypes loop (6.2× at 32 envs,
  11.6× at 128) and raising `--envs` to 512 amortised the per-tick GPU launch
  (9.6× end to end). What is left: the rollout is still the larger half of an
  iteration, so the next lever is either a CUDA graph / larger net per launch or
  several worker processes. The C++ worker pool exists (`--env-threads`) but
  loses on a contended box below ~128 envs.
- **ONNX / INT8 serving** is still future work; the runtime reads JSON today.
