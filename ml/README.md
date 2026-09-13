# ml/ — creature AI training (docs/tech/25, docs/design/23)

> **Every parameter, hyperparameter, artifact and benchmark is documented in
> [docs/tech/37-ml-parameter-reference.md](../docs/tech/37-ml-parameter-reference.md).**
> Commands: [docs/USAGE.md §4](../docs/USAGE.md). Isolated, cumulative runs:
> `tools/train_run.sh` (writes `ml/runs/<date>__<keys>__<config>/`, leaves the
> deployed `ml/serving/` alone until you promote a winner).
>
> The GUI for all of it is the **training console**
> (`godot --path game res://arena/console.tscn`): it starts isolated ES *and*
> GPU/PPO runs through `tools/train_run.sh`, browses `ml/runs/`, manages the
> registry (which version is the deployed pin), and runs **best-of-N** head to
> head between any two nets — see [design/25](../docs/design/25-arena-training-console.md).
> Watch a long run from a terminal with `tools/train_watch.py`.


RL is scoped to elite bosses, Champion Ghosts, and Gloomfall fill (canon §9) —
normal creatures use data-driven BT/utility profiles in `content/*/ai-profiles/`.

**Live today (design/23):** the arena self-play loop runs on the prototype
combat code — `training/policy_net.py` (numpy twin of the Godot neural
runtime), `training/league.py` (headless-match league + ES trainer: per-species
fine-tunes AND one global net with an embedding row per content id),
`eval/gate.py` (scripted suite + past-policy ladder + degeneracy checks; a
failed gate keeps the previous pin), `serving/registry.json` (versioned
policies + lineage + eval reports), `data/episodes/` (R0 obs+action JSONL —
the behavioral-cloning dataset; gitignored). ES is the bootstrap: registry,
gate, obs schema and datasets port unchanged to PufferLib once dh-env lands.

- `training/` — policy nets, self-play league runs, ES trainer now; PufferLib
  3.x configs over `sim/libs/dh-env` (C API + nanobind) when it lands.
- `eval/` — the automated gate before ANY bot redeploys: scripted suite + past
  policies + behavior regression.
- `serving/` — policy registry; ONNX (INT8) export at dh-env time. Weights are
  served on game servers only and NEVER ship to clients (canon §9).

Phase R0 (replay logging) runs TODAY in the arena recorder (`--record-dir`) and
moves server-side into `dh-server` at the first playtest — it is this
directory's most important dependency.

## Layout today

| Path | What it holds |
|---|---|
| `training/policy_net.py` | numpy MLP + embedding table — the twin of the Godot runtime |
| `training/league.py` | ES trainer, match runner, registry, progress feed |
| `training/ppo.py` | GPU PPO over dh-env (self-play, exploiters, squads, GRU) |
| `training/torch_policy.py` | torch twins of the policy net (MLP + GRU) |
| `training/gpu_guard.py` | VRAM cap and rollout clamp (`DH_VRAM_FRACTION`) |
| `training/evolve.py` | ES over PPO *configs* (arch, lr, entropy, self-play cadence) |
| `env/dh_env.py`, `env/bench.py` | ctypes binding for `libdh-env.so`, throughput bench |
| `env/specs.json` | generated fighter stats (from the real Godot bodies) |
| `eval/gate.py` | the deploy gate: scripted + native suites, ladder, sanity |
| `serving_paths.py` | resolves artifact paths through `DH_SERVING_DIR` |
| `serving/` | deployed registry + weights (weights gitignored) |
| `runs/` | isolated run folders from `tools/train_run.sh` (gitignored) |
| `data/` | episodes, progress feeds, logs (gitignored) |
| `tests/` | league, policy-net and progress-feed suites |
