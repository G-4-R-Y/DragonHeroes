# ml/ — creature AI training (docs/tech/25)

RL is scoped to elite bosses, Champion Ghosts, and Gloomfall fill (canon §9) —
normal creatures use data-driven BT/utility profiles in `content/*/ai-profiles/`.

- `training/` — PufferLib 3.x configs, self-play league runs, behavioral-cloning
  pipelines over `sim/libs/dh-env` (C API + nanobind).
- `eval/` — the automated gate before ANY bot redeploys: scripted suite + past
  policies + behavior regression.
- `serving/` — ONNX (INT8) export + policy registry. Weights are served on game
  servers only and NEVER ship to clients (canon §9).

Phase R0 (replay logging, server-side obs+action pairs) starts at the first playtest
and lives in `dh-server` — it is this directory's most important dependency.
