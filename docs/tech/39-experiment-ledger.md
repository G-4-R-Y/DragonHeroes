# tech/39 — Experiment ledger: every training run, its hyperparameters, its verdict

**Standing rule (R54, Ricardo, 2026-09-19): every experiment is documented here
with its hyperparameters — a ledger, not prose.** The table below is GENERATED
from what the runs already write (`ml/runs/<run>/config.json`, `summary.txt`,
`logs/*.log`) by `tools/experiment_ledger.py --write`; run it after every
training run and commit the result with the run's other artifacts. Rows are
never typed by hand; if a run is missing a knob, fix `tools/train_run.sh` so the
next `config.json` carries it. Scratch smokes that live outside `ml/runs/` go in
§2 by hand, with the same columns. The parameter meanings are in
[tech/37](37-ml-parameter-reference.md); the reward-model versions in
[tech/38](38-reward-model-history.md); the decisions behind the 2026-09-19
knobs in [`TRAINING_HYPERPARAMETERS.md`](../../TRAINING_HYPERPARAMETERS.md) at
the repo root and [tech/25 §5.1.5](25-creature-ai-and-rl.md).

How to read a verdict: `PASS` = the net cleared the arena gate against both
`scripted` and `native` and was deployed; `FAIL` = registered as a candidate
only, the fleet stayed on the previous pin. `git` is the HEAD the run started
on, `*` = dirty tree (two sessions share this checkout, so nearly always).

## 1. Runs under `ml/runs/` (generated)

<!-- ledger:auto:start -->
| run | started | trainer · keys | hyperparameters | wall · git | verdicts |
|-----|---------|----------------|-----------------|------------|----------|
| `2026-09-13_0630__fen_boar-smoke__g1_p2_e1_j4_s2026` | 2026-09-13T06:30 | es · fen_boar-smoke | gens 1, pop 2, eps 1, jobs 4, seed 2026, speed max | 0h00m06s · `b622aa6*` | fen_boar v7 **FAIL** — wrapper smoke test |
| `2026-09-13_0640__all-creatures__g1000_p10_e13_j20_s2026` | 2026-09-13T06:40 | es · all-creatures | gens 1000, pop 10, eps 13, jobs 20, seed 2026, speed max | — · `0d075a8*` | no verdict recorded |
| `2026-09-13_0653__fen_boar-termsmoke__g2_p2_e1_j4_s2026` | 2026-09-13T06:53 | es · fen_boar-termsmoke | gens 2, pop 2, eps 1, jobs 4, seed 2026, speed max | 0h00m37s · `0d075a8*` | fen_boar v7 **FAIL** — verify themed live output |
| `2026-09-13_1713__fen_boar-ckpt__g4_p2_e1_j4_s2026` | 2026-09-13T17:13 | es · fen_boar-ckpt | gens 4, pop 2, eps 1, jobs 4, seed 2026, speed max | 0h00m53s · `ab14e32*` | fen_boar v7 **FAIL** |
| `2026-09-14_004512-99126562__all-creatures-console__g100_p13_e7_j16` | 2026-09-14T00:45 | es · all-creatures | gens 100, pop 13, eps 7, jobs 16, seed 2026, speed max | — · `f5d96c0*` | bog_golem v4 **FAIL**; cinder_drake v6 **FAIL**; fen_boar_alpha v2 **FAIL**; gloam_wisp v2 **PASS**; gloamfen_stalker v2 **FAIL**; grave_shade v2 **PASS**; mire_serpent v2 **PASS** |
| `2026-09-14_045627-15174226651__cinder_drake-console__steps2000000_envs512` | 2026-09-14T04:56 | ppo · cinder_drake | steps 2,000,000, envs 512, arch mlp, sp 4 | 0h00m59s · `04611a7*` | cinder_drake v6.0 **FAIL** |
| `2026-09-14_075729-31447609__cinder_drake-console__steps2000000_envs512` | 2026-09-14T07:57 | ppo · cinder_drake | steps 2,000,000, envs 512, arch mlp, sp 4 | 0h00m23s · `f7b8f06*` | cinder_drake v6.0 **FAIL** |
| `2026-09-14_1725__fen_boar-fairsmoke__steps1000000_envs512_mlp_sp4` | 2026-09-14T17:25 | ppo · fen_boar-fairsmoke | steps 1,000,000, envs 512, arch mlp, sp 4 | 0h00m12s · `1ba50ef*` | fen_boar v7.0 **FAIL** |
| `2026-09-15_041457-140919896__all-creatures-console__g999_p6_e7_j16` | 2026-09-15T04:14 | es · all-creatures | gens 999, pop 6, eps 7, jobs 16, seed 2026, speed max | — · `1ba50ef*` | no verdict recorded |
| `2026-09-19_1015__all-creatures__steps60000000_envs512_mlp_sp4_ev64_pl80` | 2026-09-19T10:15 | ppo · all-creatures | steps 60,000,000, envs 512, arch mlp, sp 4, promote 0.6, hold 3, probes 64, demote 0.45, reservoir 8, β→ 0.001, std→ 0.1, plateau 80, clone heuristic, mask arena.mask.v1 | 0h31m20s · `545c78a*` | fen_boar_alpha v2.0 **FAIL**; gloamfen_stalker v2.0 **FAIL**; cinder_drake v6.0 **FAIL**; bog_golem v4.0 **FAIL**; mire_serpent v2.0 **FAIL** — R50 converged run (2026-09-19): 60M ceiling per creature, plateau stop on greedy= (80 upd / 0.02 / armed at 20M), arena.mask.v1 + 64 greedy probes + reversible curriculum + reservoir 8 + beta/std anneal; from scratch (CLONE=heuristic only where it qualifies); local GPU |
<!-- ledger:auto:end -->

**Context the table cannot carry (by run):**

- `2026-09-13_0640 all-creatures g1000` — **LOST**: the machine rebooted at
  g582 of key 1/7; the run predates checkpointing by hours and registered
  nothing (canon §12.49, HANDOFF 2026-09-13).
- `2026-09-13_1713 fen_boar-ckpt g4` — the run that proved `_ckpt_<key>.npz`
  resumes (tech/37 §4.2b); the verdict is irrelevant, the checkpoint was the test.
- `2026-09-14_0045 all-creatures-console g100 p13` — the ES sweep from the
  console: 3 PASS (gloam_wisp, grave_shade, mire_serpent v2 deployed), 4 FAIL.
  ES fitness is computed in the **arena** (`league.run_match`), so these nets
  were never exposed to the dh-env divergences of §12.51 — but they were gated
  on the **unmasked** argmax and now decode through `arena.mask.v1`
  (2026-09-19): re-gate before trusting them.
- `2026-09-14_0456 cinder_drake PPO 2M/512` — the `2048 * envs` rollout bug:
  2 policy updates in 2 M steps, self-play `win_rate 0.81` against an equally
  untrained snapshot, gate 0.00. Produced `MIN_UPDATES = 10` and the fixed
  65 536-step rollout (`ppo.py` header).
- `2026-09-14_0757 cinder_drake PPO 2M/512` — 30 updates; the policy collapsed
  onto a single kit on 100 % of ticks because `R_KIT` was paid on the *intent*
  (selecting a kit) rather than the *effect* (a kit firing). Produced the
  `vec.commit` reward path (tech/25 §5.1.1).
- `2026-09-14_1725 fen_boar-fairsmoke PPO 1M/512` — first run after the
  fairness layer moved into dh-env. Its `v7.0` net is the one measured for the
  train/deploy divergence: **sampled 0.96 vs greedy 0.04** win rate against
  native, head entropy 1.940/1.946 nats (ln 7 = 1.946) — the argmax was one
  action forever. This measurement is what produced the 2026-09-19 changes.
- `2026-09-15_0414 all-creatures-console g999 p6` — ES sweep interrupted at
  `fen_boar_alpha` g438 (best 0.531, mean 0.516); checkpoint in `weights/`;
  no gate ran. Not resumed — every net trained before the 2026-09-19 decode
  contract would need re-gating anyway.
- `2026-09-19_1015 all-creatures PPO 60M/512 ev64 pl80` — **the R50 converged
  run** (`arena.mask.v1`, 64 greedy probes, reversible curriculum, reservoir 8,
  β/std anneal, plateau stop 80 upd / 0.02 armed at 20 M; from scratch, clone
  of the heuristic where it qualified). Wall 31 min for 7 creatures; every
  creature plateau-stopped between 25.3 M and 38.1 M steps. Training-time
  **`greedy=` vs scripts at stop / best**: fen_boar_alpha 0.40 / 0.55 (never
  promoted), gloamfen_stalker 0.57 / 0.83 (promoted ×2, demoted ×1),
  cinder_drake 0.94, bog_golem 0.86, mire_serpent 0.96, grave_shade 0.83,
  gloam_wisp 0.91 (all promoted; cinder_drake and mire_serpent demoted once
  and re-promoted). **Gate (4 episodes in the Godot arena, mirror build,
  `scripted` then `native` policy):** PASS grave_shade (0.75 / 1.0) and
  gloam_wisp (1.0 / 1.0), both deployed; FAIL the other five — cinder_drake
  suite_scripted **0.25** against a training greedy of **0.94**, bog_golem
  0.25 vs 0.86, mire_serpent 0.75 scripted but native 0.25, gloamfen_stalker
  0.25 / 0.0, fen_boar_alpha 0.0 / 1.0. TWO FINDINGS: (1) with p = 0.94,
  1 win in 4 has probability 0.004 — this is not sampling noise but a
  **dh-env → arena outcome gap** on the greedy decode that the R50 parity
  work (identical decode, PARITY OK on one fen_boar net) did not close for
  these creatures; measure it per creature with ≥ 32 episodes before touching
  the trainer again (roadmap R55). (2) The gate's 4 episodes are too few to
  separate 0.6 from 0.9 either way. Also noted: the plateau stop counts a
  regression as flat and exports the final weights, not the best-greedy
  checkpoint (gloamfen_stalker best 0.83, exported at 0.57) — best-greedy
  export is the queued trainer change.

## 2. Scratch experiments (outside `ml/runs/`, by hand)

Same columns. These ran with `DH_SERVING_DIR` pointed at a scratch folder so
they never touched `ml/serving/`; the numbers are kept, the weights were not.

| when | what | hyperparameters | result | verdict / consequence |
|------|------|-----------------|--------|-----------------------|
| 2026-09-19 | **greedy vs sampled, same weights** (`fen_boar v7.0` of the fairsmoke run; `gvs_all.py`, 48 eps) | decode = the only variable | vs native: sampled **0.96**, greedy **0.04**; vs scripted similar order; `logit_dist.py`: entropy 1.940/1.946 nats, argmax = act 3 on ~100 % of ticks | the trainer's policy is not the shipped policy → R50 decision (Option A + masking) |
| 2026-09-19 | **kit credit assignment** (`v6.0` cinder_drake, argmax vs sampled kit fires) | — | argmax fired kits 13/8315 ticks vs 643 sampled | masking is orthogonal to A/B and needed by both |
| 2026-09-19 | **step-1 smoke** (curriculum + probes + annealing, no mask) `fen_boar` mirror | steps 1 310 720 (20 upd), envs 512, probes 32, promote 0.30 hold 2, demote 0.20, sp 2, reservoir 3, β 0.01→0.001, std 0.3→0.1, seed 7 | sampled `scripts=` 0.93; `greedy=` window never filled (32 probes too few for 20 updates) | mechanics correct; probes default raised to 64 |
| 2026-09-19 | **step-2 smoke** (everything above **+ `arena.mask.v1`**) `fen_boar` mirror | steps 3 276 800 (50 upd), envs 512, probes 64, promote 0.30 hold 2, demote 0.20, sp 2, reservoir 3, β→0.001, std→0.1, plateau 8 / 0.02 / 2 M, seed 7; `kit_count=2` | sampled `scripts=` 0.25→0.83→0.28→0.94→0.59; **`greedy=` 0.19→0.34→0.32**; PROMOTED at it=40 (149/448 train envs to self-play, 64 probes stay on scripts); pooled `win_rate` fell to 0.40 once self-play entered; PLATEAU STOP at it=50 (greedy flat within 0.02 of best 0.34 for 8 updates); 165–175 k steps/s | `env_parity` on the exported net vs native, 12 eps seed 7777: **PARITY OK**, every term inside tolerance, **win 1.00 in dh-env and 1.00 in the arena** — the first net whose greedy decode wins in both runtimes |
| 2026-09-19 | **R55 — dh-env vs arena OUTCOME gap on the converged nets** (`ml.eval.env_parity`, the run's `weights/*.json`, greedy decode, 32 eps each side, seed 4242) | decode identical; only the runtime differs | win rate dh-env → arena: cinder_drake v6.0 vs scripted **0.72 → 0.56**, vs native **0.875 → 0.03**; bog_golem v4.0 vs scripted **0.91 → 0.375**; mire_serpent v2.0 vs native **1.00 → 0.28**; gloam_wisp v2.0 vs scripted 0.75 → 1.00. The common term: **damage TAKEN per second is 1.7–2.3× higher in the arena** (cinder_drake vs native 0.044 → 0.101 bars/s; mire_serpent 0.050 → 0.103; bog_golem 0.012 → 0.022), while damage DEALT per second mostly agrees; cinder_drake vs scripted is 2.12× longer in dh-env with both rates halved | the trainer's world under-models what the opponent does to the policy; the nets learn a "safe" that is not safe in the game. Not a sampling artefact (32 eps), not the decode (parity OK), not the sample size of the gate (which is still too small). Next: net-free baselines per build (scripted vs native both runtimes) to localize the bodies/kits whose EFFECTS dh-env does not simulate |
| 2026-09-19 | **R55 full matrix** — every converged net × {scripted, native} opponent, dh-env vs arena, 32 eps, greedy, seed 4242 (`env_parity`) | only the runtime differs | win dh→arena / taken-per-second dh→arena: **native** — bog_golem 1.00→1.00 / 0.016→0.013, fen_boar_alpha 0.75→1.00 / 0.024→0.022, gloam_wisp 1.00→1.00 / 0.018→0.019 (melee and wisp natives AT PARITY); cinder_drake 0.88→0.03 / 0.044→**0.101**, mire_serpent 1.00→0.28 / 0.050→**0.103**, grave_shade 1.00→1.00 / 0.022→**0.069**, gloamfen_stalker 0.41→0.28 / 0.043→0.057 (ground natives WITH ranged kits hit 2–3× harder in the arena while the policy's own dealt/s agrees); **scripted** — every body: dealt/s AND taken/s ≈ 2× in the arena, episodes 1.4–2.3× longer in dh-env (bog_golem 60→42 s, cinder_drake 23.8→11.2, stalker 33.8→15.8, serpent 20.3→8.8): the sim's scripted opponent engages far less | the physics is at parity (melee natives agree, the policy's bolts agree); the OPPONENT DRIVERS in `arena.cpp` are not: `native_tick` under-uses ranged kits for ground bodies, `scripted_tick` paces the fight at half the arena's exchange rate. Fix those two ports, re-run this matrix, then retrain |
| 2026-09-19 | **runtime parity of the mask** | 18 fixture cases (`game/arena/tests/fixtures/action_mask_v1.json`) | Python (numpy = torch = env_parity), GDScript `MASK PARITY OK 18/18`, C++ `sim-tests` (rule + frozen-opponent integration) | the decode contract is pinned in every runtime |
| 2026-09-21 | **R55-b — the four divergences behind the matrix**, found by DAMAGE BY SOURCE (contact / bolt / field, booked in both runtimes and in `env_parity`) restricted to the first 10 s of each episode, so the endgame tail could not hide the exchange (`$S/r55/first10.py`, cinder_drake v6.0, 24 eps, seed 4242) | one channel at a time; same greedy decode | **(1) the Fiery elite affix was not in the sim at all.** `creature.gd::_strike` follows a landed bite with `take_damage(damage*0.5, dir, "fire")`; a String arg3 routes through `proxy.gd`'s element branch — raw damage on a creature body — and is booked as BOLT. cinder_drake wears it. Measured vs native, bolt taken per 10 s: dh **30.9** vs arena **58.2**, and 25 of the 27 missing points were this one packet. Brutal/Swift/Bulwark are stat edits `dump_specs.gd` already read off the finished body; only this one is behaviour. **(2) the native kit driver was competing with the swing.** `fighter.gd::pre_tick` fires kits on a channel of its own, every frame, whatever the body is doing; the sim wrote the kit into the single `act` slot, so it was silenced for every frozen frame — windup 0.22 s + recover 0.4 s of a 1.12 s cycle, 55% of them. **(3) the kit bolt fan carried aim noise** (`gauss()*kAimNoise`) that `fighter.gd::cmd_aim` (`if body is ProtoPlayer`) never applies to a creature: `_kit_exec` fires down `(foe_pos-from).normalized()` rotated by ±12° and nothing else. **(4) storm bolts were 3.0 px**; `projectile.gd` declares `radius := 4.0` and only `set_steel()` (the Veilblade knife, which no creature kit throws) narrows it — `set_arcane/violet/frost` are tints. After all four, vs native: contact taken dh 50.6 / ar 54.4, bolt taken dh **54.9** / ar 58.2, bolt dealt dh 61.7 / ar 68.6 | the sim was missing a whole damage packet and gating a whole channel. `specs.json` gained `fiery`; it crosses to dh-env by its own optional symbol (`dh_env_set_body_affix`), never by resizing `DhFighterSpec` |
| 2026-09-21 | **R55-b — the parity harness was measuring two different clocks** | — | `run_arena` left `league.run_match` at its default `time_limit=45.0` while `run_dh_env` ran to `--max-ticks 4096` = **68.3 s**. Every term in the verdict is per SECOND, so any build whose fights reach the cap had its dh-env mean stretched by episodes the arena had already truncated: fen_boar_alpha vs scripted read dh **65.2 s** against the arena's 38.9 s, and reported an environment divergence that was the harness's own asymmetry. `--time-limit` (45.0) now drives BOTH runtimes and `--max-ticks` is an override for a deliberately asymmetric probe | a measurement bug, not an environment one. Anything read off the seconds/dps ratios before 2026-09-21 is suspect for the long-fight builds |
| 2026-09-21 | **R55-b full matrix re-run** — every converged net × {scripted, native}, both runtimes, 32 eps, greedy, seed 4242, one 45 s clock | the four fixes + the clock | **worst ratio across all 14 cells 3.17 → 1.93**; `agree` 1/14 → 3/14. Damage taken/s, dh→arena ratio, **native** column: cinder_drake **2.31 → 1.01**, mire_serpent **2.06 → 1.02**, grave_shade **3.17 → 1.48**, bog_golem 1.18 → 1.19, fen_boar_alpha 1.06 → 1.16, gloamfen_stalker 1.32 → 1.47, gloam_wisp 1.05 → 1.23. Episode length, **scripted** column: gloamfen_stalker **2.14 → 1.05**, bog_golem 1.42 → 1.00, gloam_wisp 1.26 → 1.04, fen_boar_alpha 1.32 → 1.13, cinder_drake 2.12 → 1.76, mire_serpent 2.31 → 1.87, grave_shade 1.53 → 1.61 | the ranged-kit natives that drove the original finding are closed. Four native cells moved up 0.1–0.15 — noise-sized on 32 mirror episodes, and worth re-reading at 64. `worst` (the absolute terms) is dominated by **win_rate in a MIRROR matchup with a greedy decode**: the outcome is near-deterministic, so a hair of divergence flips every episode at once (bog_golem native reads 0.00 vs 0.44). Judge this probe on the rate ratios, not on win_rate |
| 2026-09-21 | **R55-b residual, localized** (cinder_drake v6.0 vs scripted, 32 eps) | — | totals now agree and only the CLOCK does not: damage taken dh **0.813** bars vs arena **0.892**, dealt dh **0.962** vs **0.897**, per channel within ~10% — but the episodes run dh **19.9 s** vs arena **11.3 s**. It is not a tail: the whole distribution is shifted (dh median **22.1 s**, min 8.2; arena median **9.8 s**, max 20.8, zero episodes at the cap). Restricted to the first 10 s the RATES already agree (taken dh 94.5 vs ar 106.3, dealt 101.6 vs 104.3 raw hp). So dh lands **96%** of its eventual damage inside 10 s and then spends another ten seconds on the last 4%, where the arena lands 98.8% and ends | the residual is the ENDGAME, not the exchange: below 0.25 hp `scripted_policy.gd` re-arms `_retreat_t = 2.5` forever and both bodies run at the same speed, so the chase only converges when something breaks the symmetry. The arena has `creature.gd::_separate(delta)` body separation and the sim has none — the first thing to port next |

## 3. Adding a run

1. Train through `tools/train_run.sh` / `tools/train_all.sh` — they write
   `config.json` with every knob (`STEPS ENVS ARCH SELFPLAY_EVERY PROMOTE_WR
   PROMOTE_HOLD EVAL_ENVS DEMOTE_WR RESERVOIR ENTROPY_FINAL MOVE_STD_FINAL
   PLATEAU_* CLONE NET`, plus git head, torch, host).
2. `python3 tools/experiment_ledger.py --write`, then add the context bullet
   in §1 if the row cannot explain itself (a lost run, a bug it exposed, what
   it changed).
3. Anything run by hand with `DH_SERVING_DIR` elsewhere: a row in §2, same
   columns, before the scratch folder is deleted.
