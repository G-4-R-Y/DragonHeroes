# 38 — The reward model: every version, and why each one replaced the last

Ricardo, 2026-09-14: *"How's our final reward function? make sure to document
everything, including the reward function versions as we update it with new
rationale (trace the whole story up to the current one)."*

This is the changelog, not the reference. **The reference is
[25 §5.2](25-creature-ai-and-rl.md) (what the current model computes) and
[37](37-ml-parameter-reference.md) (every constant).** The weights themselves are
data: `ml/training/reward_weights.json`.

The rule for this file: **a version is never deleted, only superseded.** Every
ranking in this repo's history was produced by one of them, and reproducing a
result means being able to run the model that made it — `fitness_v1` is still
selectable for exactly that reason. Each entry below records what it scored, what
went wrong, and the measurement that proved it.

---

## The short answer to "how's our final reward function?"

**v2 is current and it is sound.** Its first independent confirmation arrived on
2026-09-14: given three policies whose real quality was known in advance — a
five-rule heuristic, a trained net, and a statue that never moves — it ranked
them **0.859 > 0.421 > 0.238**, which is the correct order. That test exists
because ranking ground truth is the only check that cannot be satisfied by a
model that merely looks reasonable.

It is **not** finished. Known open items are listed at the bottom.

---

## v0 — two functions that disagreed (until 2026-09-14)

There was no single reward model. There were two, and neither knew about the
other.

**`league.fitness()`** — ranked every ES candidate and every gate verdict:

```python
wins + 0.1 * (hp_self - hp_foe)
```

Two terms. Duration not scored. Damage not scored. `hp` clamps at zero, so
overkill is invisible and a clean kill is indistinguishable from a long grind
that ended at the same health.

**`ppo.py`'s per-tick reward** — what PPO actually optimized:

```
1.0 * (foe_hp_lost - self_hp_lost) - 0.002        every tick
+ 0.02 per kit selected, + 0.05 per chained kit
+1.0 win / -1.0 loss                              at the end
```

So ES ranked candidates on one definition of "good" while PPO trained toward a
different one. Anything PPO learned to value, the gate could not see.

### What was wrong with v0, in the order the defects were found

**1. Time was signed wrong for a loser.** `- R_TIME` applied every tick
regardless of outcome, so a losing agent was paid to die sooner. Ricardo caught
this in the act of asking for the new model — *"If winner, the shorter the
better. If loser, the longest the better."* That is a correction, not a
refinement.

**2. Time was also mis-scaled 7×.** `0.002 × 3600 ticks = 7.2` over a full
episode, against a win bonus of `1.0`. The clock outweighed the result seven to
one. This is precisely the magnitude problem Ricardo named — *"not compare 40
seconds with 0.087 dmg_dealt"* — sitting inside our own trainer.

**3. Dealing and avoiding damage scored identically.** One symmetric hp delta,
weight 1.0 each way. That is the avoidance local optimum written down in code,
and PPO seed 7 duly found it: `mean_loser_hp 0.967`, a timeout "win" the sanity
gate refused.

---

## v1 — `fitness_v1`, kept and still runnable

`league.fitness_v1()` **is** v0's `fitness()`, preserved unchanged and selectable
with `{"model": "v1"}` in `reward_weights.json`. It is unbounded above 1.0, as it
always was; `test_fitness_v1_is_kept_and_still_behaves_as_it_did` pins that.

Not a step forward — a bookmark. Every ES ranking in this repo's history was made
with it.

---

## v2 — one weighted, scale-normalized model (current, 2026-09-14, `f7b8f06`)

Built to Ricardo's specification, which supplied both the directions and the
scaling requirement:

> *"we can get each one of the columns values, weight out which is the most
> importante performance metric, and attribute weights to each variable, sclaing
> values to what is most impactful. Numbers magnitudes must be scaled tho, as to
> not compare 40 seconds with 0.087 dmg_dealt. If winner, the shorter the better.
> If loser, the longest the better. 'dmg_taken' is always 'lower is better',
> 'dmg_dealt' is always 'higher the better', hp_foe lower the better, hp_self
> higher the better, win_rate the higher the better."*

### The four design rules

1. **Normalize first.** Every term becomes a goodness in `[0, 1]` against its
   *own* reference scale — one health bar (`DMG_REF = 1.0`), the episode cap
   (`EPISODE_CAP_S = 60.0`) — before any weight applies. Seconds and health bars
   are never compared as raw magnitudes again.
2. **Directions are declared**, in the `TERMS` table, not implied by a sign
   buried in an expression. Anything "lower is better" is normalized as `1 - x`.
3. **Duration is conditional on the outcome.** Shorter when winning, longer when
   losing, **neutral on a draw** — giving a draw the loser's rule would pay an
   agent to stall to the time limit, which is the degenerate policy the gate's
   sanity check already refuses.
4. **The outcome outweighs everything else combined.**

### Weights (`ml/training/reward_weights.json`)

| term | weight | why this number |
|---|---|---|
| `win` | 0.55 | the product is winning, so it dominates by construction |
| `dmg_dealt` | 0.15 | offence has been the hardest thing to teach — weight it above defence so avoidance stops being a tie |
| `dmg_taken` | 0.11 | defence matters **less** than offence, deliberately; symmetric was the local optimum |
| `hp_foe` | 0.08 | same story as `dmg_dealt`, clamped and end-of-episode — a coarse confirmation, not a second vote |
| `hp_self` | 0.06 | likewise for `dmg_taken` |
| `duration` | 0.05 | a tiebreaker: win faster, lose slower |

### Two invariants, enforced on load rather than intended

`assert_sane_weights` refuses any weight set where:

* the weights do not sum to 1.0 — otherwise a score is not on one scale and no
  threshold reads the same twice;
* `win` does not **exceed** the sum of all others — otherwise a sufficiently
  pretty loss outranks an ugly win, and the agent learns to lose beautifully.

The second invariant earned its keep the same day it was written: it is what made
the mirror-matchup bug visible (below).

### Worked ordering (`python3 -m ml.training.reward --explain`)

```
fast clean kill 0.965 > slow bloody win 0.801 > timeout stall 0.472
                      > long brave loss 0.246 > instant death 0.003
```

The stall sits above the losses because a draw genuinely is half an outcome. What
stops stalling is the gate's hard sanity check, not a weight, and the tool says
so rather than pretending otherwise.

### One model, both consumers

`league.fitness()` ranks ES candidates with it and `ppo.py` pays
`R_TERMINAL * (score - 0.5)` at the episode boundary. ES and PPO can no longer
optimize different things. PPO's per-tick shaping became `R_DEAL 1.0` /
`R_ABSORB 0.73` (asymmetric on purpose) with `R_TIME 0.0` — the old constants are
commented above, not deleted.

---

## v2 patch history — four bugs, all found by measurement

Each of these produced a *plausible number*, not an error. That is the pattern
worth remembering.

### v2.0.1 — the mirror matchup had no winner (`2871a8f`)

**Symptom:** Ricardo's training console showed `fitness 0.607` beside
`win_rate 0.00`. Both cannot be true — invariant 2 caps a zero-win policy at
0.45.

**Cause:** in self-play both fighters carry the same `build_id`, so
`winner == e["a"]` was true no matter who won. Every mirror episode scored as a
win for whichever side was being read. A net that lost 4 of 4 scored **0.672**.

**Fix:** at the source rather than in the reader — `game/arena/arena.gd` now
writes `winner_side` (`"a"`/`"b"`/`"draw"`), because a side letter cannot be
ambiguous the way a build id can. `_winner_is_self()` resolves in a declared
order: `winner_side`, then an explicit draw, then build ids **only when they
differ**, then health (the side at zero lost), then draw. Old rows still parse.

**Verified:** the losing side now scores 0.102.

### v2.0.2 — the kit bonus paid 72× winning the fight (`2871a8f`)

**Symptom:** the retrained policy picked kit slot 1 on **100.000%** of ticks,
`|move| mean 0.059`.

**Cause:** `R_KIT = 0.02` paid for *selecting* a kit — the intent — and
`field_cast` has an 8 s cooldown, so 480 of every 481 ticks that selected it did
nothing. `3600 × 0.02 = 72` per episode against a terminal worth at most 1. The
degenerate policy was optimal for the reward it was given.

**Fix:** pay for effect. `dh::sim::Arena::last_commit(who)` records the action the
sim **accepted** (`-1` when refused); `dh_env_step_many_commit()` carries it
through the C ABI as a *new* symbol so a stale `.so` raises `AttributeError`
rather than reading an unset register. `ppo.py` masks the dodge bit off first,
because bit 3 is not part of the pick:

```python
pick = vec.commit & (ACT_DODGE - 1)
kit  = (vec.commit >= 0) & (pick >= 3) & (pick <= 6)
```

**Verified:** 600 kit selections produce **1** actual cast. The golden
`state_hash` matrix is unchanged — commit tracking is observation only.

**The general rule this established:** any per-tick shaping term must read sim
state (what changed), never agent output (what was requested). See
[25 §5.1.1](25-creature-ai-and-rl.md).

### v2.0.3 — the arena's vocabulary is not the model's (`dfcb75e`)

**Symptom:** a statue that lost every episode outranked a net that won a third of
its fights.

**Cause:** `episode_terms()` reads `winner_is_self`/`seconds`; an arena row says
`winner_side`/`duration_s`. Handed a raw arena row, the two **heaviest** terms —
`win` and `duration` — both silently defaulted to 0.5. A loss scored **0.528
instead of 0.238**: above real wins, and above the 0.45 ceiling invariant 2
guarantees. Its own docstring claimed it took the arena's vocabulary, which was
exactly false and is what misled the author.

**Fix:** a row carrying outcome evidence in the arena's vocabulary is now
**refused**, with a message naming `from_arena_row`. A row with no outcome
evidence at all is still an honest draw, not an error.

**Worth keeping:** the bug was found because a result contradicted an invariant
written hours earlier. The invariant was right.

### v2.0.4 — validated against ground truth (`dfcb75e`)

Not a bug — the first check that the model ranks *known* quality correctly.
Three policies of known relative strength, `core.arena.cinder_drake` mirror,
12 episodes each:

| policy | vs native | v2 score |
|---|---|---|
| heuristic (five rules) | win 1.00 | **0.859** |
| trained net v5.0 | win 0.33 | 0.421 |
| statue (never moves) | win 0.00 | 0.238 |

Correct order, and the gaps are proportionate. Re-run these controls whenever a
term or weight changes — a reward model that cannot rank a statue below a
fighter cannot rank anything.

---

## Open, and honest about it

* **Avoidance shaping (`R_TIME`) has not been re-judged.** It is 0.0 with the old
  constants commented above it. Every run that motivated it was made by a policy
  that could not attack while dodging, so it needs re-measuring on the fixed
  decode, not reasoning about.
* **`dps_taken` parity is unresolved** — opponents deal damage 1.70–2.28× faster
  in `dh-env` than in the Godot arena ([25 §5.3](25-creature-ai-and-rl.md)). Until
  that closes, a score measured in one environment is not directly comparable to
  the same score measured in the other.
* **The weights have never been tuned against outcomes**, only reasoned about and
  checked for sanity. They are a defensible starting point, not a result.
* **`hp_foe`/`hp_self` partly duplicate `dmg_dealt`/`dmg_taken`.** Deliberate
  (coarse confirmation of a finer term), but it means 0.14 of the total weight is
  a second vote on damage. Worth revisiting once the model has been tuned.
