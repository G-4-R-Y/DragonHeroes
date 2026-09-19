# Training hyperparameters — what changed on 2026-09-19, and why

Short version for Ricardo. The full parameter reference is
[docs/tech/37-ml-parameter-reference.md](docs/tech/37-ml-parameter-reference.md);
every experiment with its knobs and verdict is in
[docs/tech/39-experiment-ledger.md](docs/tech/39-experiment-ledger.md); the
reasoning trail is [docs/tech/25 §5.1.5](docs/tech/25-creature-ai-and-rl.md).

## The problem, in one line

The PPO trainer **samples** πθ (Categorical over the 7 action logits, Bernoulli
dodge, Gaussian move); every serving runtime — numpy `policy_net.act`, GDScript
`neural_policy.gd`, C++ `Arena::mlp_act`, `env_parity` — **executes argmax πθ**.
Same weights, different policy. Measured on `fen_boar v7.0` (1 M steps, after
the fairness layer): sampled won **0.96** of episodes vs native, greedy won
**0.04**; head entropy ≈ 1.94 nats out of ln 7 = 1.95, so the argmax was
"act 3 forever". The promotion gate read the sampled number, i.e. it could
promote a policy that never ships.

Two execution rules for the same πθ were on the table: **(A)** keep shipping
argmax and train so that argmax *is* the policy (anneal, evaluate greedy,
promote on greedy); **(B)** make the runtimes sample (seeded). Decision: A,
plus action masking; B is built only if a post-hoc sampled-vs-greedy measurement
on the converged nets still shows a gap.

## What changed

| # | Change | Knob (default) | Why |
|---|--------|----------------|-----|
| 1 | **Action masking `arena.mask.v1`** in all five runtimes. Logits of actions the body cannot take right now go to `MASK_NEG = −1e9` before the softmax (trainer) / are skipped by the argmax (serving). Rule, from the obs the net sees + two body constants: noop always; attack `o[5]≤0`; special `o[6]≤0` (player) or `o[5]≤0` (creature — its "special" is a swing); kit k `k<kit_count ∧ o[7+k]≤0`; dodge flag `o[12]>0`. | none — it is the decode contract. Pinned by `ml/tests/test_action_mask.py`, `game/arena/tests/mask_parity_test.gd` (18 shared fixture cases) and `sim-tests` | A kit on an 8 s cooldown is a no-op on ~299 of every 300 ticks it is selectable, so the credit for "cast a kit" was spread over 300 refused picks and one real cast — the gradient towards *using* kits was 1/300 of what it should be. With the mask, probability mass only ever sits on executable actions, and log πθ(a\|s), the entropy and the argmax all refer to the same masked distribution. |
| 2 | **Greedy probes.** The last `--eval-envs` envs decode argmax (the serving decode), ride in the same `step_many`, and are **excluded from the PPO update** (their actions are not samples, so their log-probs mean nothing to the ratio). Their win rate vs the scripts prints as `greedy=`; the sampled one as `scripts=`. | `--eval-envs 64` (12.5 % of 512) | J(πθ^greedy) is the number that ships; it is now measured every update instead of once at the gate. 32 probes needed ~56 updates to fill the 40-episode window; 64 need ~28. |
| 3 | **Promotion reads the greedy number, and is reversible.** Promote at `greedy ≥ --promote-wr` held `--promote-hold` updates; **demote** the self-play slots back to scripts at `greedy < --demote-wr` held the same number of updates. Scripts are never dropped: after promotion the train envs are ⅓ scripted, ⅓ native, ⅓ self-play, and the probes always stay on scripts. | `--promote-wr 0.60`, `--promote-hold 3`, `--demote-wr 0.45` (hysteresis; 0 disables) | Ricardo: "interchange scripted vs self-play until we are constantly winning scripted, as to not exploit some strategy". Self-play that drifts away from what the gate measures is not progress. |
| 4 | **Snapshot reservoir.** Self-play opponents are drawn round-robin from the last `--reservoir` frozen snapshots, not only the latest self. The newest is also written to `ml/data/ppo_snapshots/` for post-mortems and `env_parity`. | `--reservoir 8` | A single moving opponent is something the learner can overfit to, and what it learned to beat last refresh is gone next refresh. A spread of its own history is the cheap stochasticity Ricardo asked for — in the *opponents*, not in the policy (the policy's stochasticity is the gap itself). |
| 5 | **Annealing.** Entropy bonus β and the move-head std decay linearly in steps over the nominal budget. | `ENTROPY 0.01 → --entropy-final 0.001`; `MOVE_STD 0.3 → --move-std-final 0.1` | As πθ sharpens, sample and argmax converge by construction. A plateau stop leaves them part-way; the log line records where. |
| 6 | **Plateau stop.** Stop when `greedy=` has not improved by `--plateau-delta` for `--plateau-updates` updates, once past `--plateau-min-steps`. The step budget is a ceiling, not a target. | `--plateau-updates 0` (off) in `ppo.py`; the converged run uses `80 / 0.02 / 20 M` | 60 M steps per creature is ~915 updates ≈ 6 min at the measured 165–175 k steps/s, so the cost of the ceiling is small; the stop is there so a run that converged at 25 M does not spend 35 M sharpening noise. |

Everything else is unchanged: `GAMMA 0.99`, `LAM 0.95`, `CLIP 0.2`, `LR 3e-4`,
`EPOCHS 4`, `MINIBATCHES 8`, rollout `65 536` steps (512 envs × 128 ticks),
`MIN_UPDATES 10`, reward model v2 (`win 0.55 / dmg_dealt 0.15 / dmg_taken 0.11 /
hp_foe 0.08 / hp_self 0.06 / duration 0.05`, terminal ×2.0), `R_KIT 0.02`,
`R_CHAIN 0.05` paid on the tick a kit actually fires.

## What the smokes showed (fen_boar mirror, seed 7, 512 envs, 2026-09-19)

| run | steps / updates | mask | sampled `scripts=` | `greedy=` | notes |
|-----|-----------------|------|--------------------|-----------|-------|
| step-1 smoke | 1.31 M / 20 | off | 0.93 | n/a (window not full) | curriculum + probes + annealing mechanically correct |
| step-2 smoke | 3.28 M / 50 | **on** | 0.59 (swung 0.25 → 0.94 → 0.28 → 0.94) | **0.32** (0.19 → 0.34) | promoted at it=40 on greedy ≥ 0.30 (smoke threshold), reservoir of 3, plateau stop fired at it=50; `env_parity` on the exported net: **PARITY OK**, win 1.00 in dh-env *and* the arena vs native (12 eps) |

The sampled-vs-greedy gap is still wide at 3 M steps — expected, the anneal
only reaches β = 0.001 / std = 0.1 at the end of the nominal budget. That is
what the 60 M converged run is for; its `greedy=` trace is the experiment.

## How to run it

```sh
# the converged run (Ricardo's build order, step 4): 60 M ceiling, plateau stop, clone where it qualifies
STEPS=60000000 PLATEAU_UPDATES=80 PLATEAU_DELTA=0.02 PLATEAU_MIN_STEPS=20000000 \
CLONE=heuristic tools/train_all.sh --ppo
# one creature
tools/train_run.sh --ppo --key fen_boar --build core.arena.fen_boar_alpha --opp-build core.arena.fen_boar_alpha
```

Env knobs: `EVAL_ENVS DEMOTE_WR RESERVOIR ENTROPY_FINAL MOVE_STD_FINAL
PLATEAU_UPDATES PLATEAU_DELTA PLATEAU_MIN_STEPS` (+ the older `STEPS ENVS
PROMOTE_WR PROMOTE_HOLD SELFPLAY_EVERY CLONE NET`). Every run writes
`config.json` with all of them; `tools/experiment_ledger.py --write` turns the
run folders into the table in tech/39.

## Consequence for nets that already exist

Every runtime now decodes through the mask, so a net gated *before* 2026-09-19
plays a (slightly) different policy today: it no longer wastes ticks re-picking
refused actions. The exported JSON records `"action_mask": "arena.mask.v1"`
when a net was *trained* under the mask. Nothing deployed is trusted until it
is re-gated — the converged run replaces them all anyway.
