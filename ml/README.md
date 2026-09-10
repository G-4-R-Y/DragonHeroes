# ml/ — creature AI training (docs/tech/25, docs/design/23)

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
