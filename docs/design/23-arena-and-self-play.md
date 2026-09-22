# 23 — The Arena: observable self-play, per-species & global policies, bounty-hunter builds

> **Status:** v1 landed (2026-09-02). Conforms to [canon §9](../00-canon.md) and
> [tech/25](../tech/25-creature-ai-and-rl.md) — this is the observable front end of
> the RL program (R0 logging + R1 self-play league) running on the *prototype*
> combat code while dh-env (the C++ vectorized sim) is still being built.
> Everything here — obs schema, policy registry, eval gate, recorded datasets —
> is designed to port unchanged to PufferLib/dh-env when it lands.

## What it is

`game/arena/` is an isolated match runner where creatures, bosses and geared
player builds face off in a bounded ring — windowed for watching, headless for
training. It exists so we can **watch our creature AI learn**: scripted baselines
today, per-species fine-tuned nets and one global net as training produces them.
The same roster ([content/core/arena/builds.json](../../content/core/arena/builds.json))
defines **bounty-hunter builds** — player-shaped NPCs with real class, attributes,
rolled gear, rune sockets, class-tree loadouts, pets, and cosmetic loadouts —
which later walk the world as huntable NPCs (equipment, runes, skills, pets,
enchantments and cosmetics included; cosmetics stay presentation-only, canon §2).

## Architecture

```
arena.tscn ─ arena.gd        the "main" contract holder: fx/telegraphs/post/
                             damage services, fields (fire/earth/mire/LAVA
                             fusion), death routing, episodes, HUD, CLI
  ├─ world_stub.gd           flat ring world ("world" group: is_walkable)
  ├─ fighter.gd              one combatant: body + proxy + policy + pet + cosmetics
  ├─ proxy.gd                ArenaProxy — the uniform target surface (below)
  ├─ policy.gd               base + fairness layer (obs delay, aim noise, burst cap)
  ├─ scripted_policy.gd      utility baseline (eval suite, fallback mind)
  ├─ neural_policy.gd        MLP runtime — loads ml/-exported weights JSON
  ├─ recorder.gd             R0 obs+action JSONL per episode (30 Hz)
  ├─ builds.gd               ProtoBuild — Session-compatible build object
  └─ cosmetics.gd            ProtoCosmetics — auras / necklaces / weapon glows
```

**The two seams that make self-play possible** (small additive ARENA HOOK patches
to the prototype, marked in-code; zero behavioral change to the hunt):

1. **Target override** — creatures/bosses/projectiles/pets accepted only the
   global `"player"` group as a target. They now honor an optional override
   node, which is what enables creature-vs-creature and build-vs-build at all.
2. **Bot drive** — `bot_drive` on players and creatures hands movement/attacks
   to an external policy through the same code paths the built-in AI uses
   (same windups, cooldowns, telegraphs). Player aim is injected (`bot_aim`)
   instead of the mouse; `build_source` is a Session-compatible `ProtoBuild`
   so **two differently-geared builds share one scene** — the autoload stays
   untouched.

**The proxy.** Every fighter gets one `ArenaProxy` child — its *only* member of
the `"creatures"` group (bodies are de-grouped). Creature strikes use
player-style hit signatures, player skills use creature-style ones; the proxy
adapts both directions (including player-body DoT fallbacks and status
degradation), so all three match shapes — creature/creature, build/creature,
build/build — run through one code path. Skip-guards (`owner_fighter`) keep a
fighter from ever hitting its own proxy.

## Policies and the two neural lineages

- **native** — the built-in prototype AI (baseline; bosses keep their kits).
- **scripted** — utility heuristics through the shared command API (range
  bands, strafes, skill bar off cooldown, windup-dodge, low-HP disengage).
- **neural:\<weights.json\>** — the MLP runtime. One loader serves both:
  - **per-species nets** — fine-tuned per creature type/build (embedding row `*`).
  - **the global net** — one weight set + one embedding row per content id;
    it trains on episodes from *every* creature and *every* build (canon §9 §5:
    new content = new embedding rows initialized from the table mean, never new
    tensor shapes).

**Fairness is baked in** (canon §9 §6): all policies observe through a sampled
150–250 ms delay buffer, aim through gaussian noise, and commit actions under a
burst-binding cap (6 commits/s). **In `dh::sim::Arena` too, since 2026-09-14** —
it had none of this until then (canon §12.51, tech/25 §5.1.4), which is why a
policy could win 1.00 in training and lose 0–12 here. The sim's twin pieces are
`Arena::obs` (the ring), `Arena::percept` (what a built-in mind may act on) and
`Arena::budget_ok` (the cap); `Arena::obs_now` is the undelayed truth and exists
for probes and replay traces only. **Observation schema `arena.obs.v1`** (31
floats, fixed and versioned — header of `policy.gd`) + 16-dim embedding slot;
`ml/training/policy_net.py` is the byte-exact numpy twin.

The decode is part of the policy contract too (`arena.mask.v1`, 2026-09-19): a
policy may only pick an action its body can take right now — attack/special/kit
off cooldown, dodge with a charge — decided from the same delayed observation it
reads, so the trainer, the numpy twin, this arena, the C++ frozen opponent and the
parity probe all turn one head into one action. `neural_policy.gd::decode` is the
arena's copy; `tests/mask_parity_test.tscn` pins it to the Python fixture. The
number that promotes a net to self-play and gates it is the GREEDY (argmax) win
rate against the scripts — what the arena actually runs — never the sampled one.

## Training loop (ml/)

```
ml/training/policy_net.py   MLP + embedding table; .npz <-> game-JSON export
ml/training/league.py       match runner (headless godot subprocess), ES trainer
                            (OpenAI-ES: sigma perturbations, centered-rank update),
                            species + global modes, registry writer
ml/eval/gate.py             scripted suite + past-policy ladder + degeneracy
                            checks; FAIL = fleet stays on previous pin (boring)
ml/serving/registry.json    versioned policies: weights hash, lineage, eval report
ml/data/episodes/           recorded obs+action JSONL (gitignored; the BC dataset)
```

ES is the bootstrap, not the endgame (canon §9 compute budget assumes the C++
env — Godot-in-the-loop is ~100× too slow for PPO at scale). It exists to prove
the loop end-to-end *today*: **train → registry → gate → deploy**, with every
episode recorded for behavioral cloning. When `dh-env` lands, the same registry,
gate, obs schema and datasets carry over to PufferLib PPO (tech/25 §4.2).

## Running it

```bash
# Watch (windowed): roster rotation, [N]ext [R]ematch [1/2/3] speed [Q]uit
godot --path game res://arena/arena.tscn

# Headless match set (what the league runs)
godot --headless --path game res://arena/arena.tscn -- \
    --a core.arena.dusk_revenant --b core.arena.fen_boar_alpha \
    --policy-a scripted --policy-b native --episodes 4 --seed 7 --fast \
    --record-dir "$PWD/ml/data/episodes" --out /tmp/result.json

# The gate (CI): 3 matchups, damage must flow both ways, no orphan proxies
godot --headless --path game res://arena/arena.tscn -- --selftest   # ARENA SELFTEST OK

# Train + gate a species net
python3 -m ml.training.league train --key fen_boar --build core.arena.fen_boar_alpha \
    --generations 3 --pop 6 --episodes 4
python3 -m ml.training.league gate --key fen_boar --build core.arena.fen_boar_alpha
```

## Watching a dh-env match (the trace)

The arena has a window; **dh-env does not** — it is a headless C++ library, and
that is the half of the stack the trainer actually lives in. So "watch a dh-env
match" can only mean: record what it did, tick by tick, then have the arena act
the recording out.

```bash
# Record one dh-env episode (policy: a net's game.json, or `heuristic`)
python3 -m ml.eval.trace_match --build core.arena.cinder_drake \
    --policy heuristic --opp scripted --seed 3 --out ml/runs/traces/drake.json

# Watch it: real bodies driven by the recorded commands, recorded positions
# drawn as ghosts on top
godot --path game res://arena/arena.tscn -- --replay ml/runs/traces/drake.json --spectate
```

From the console, **REPLAY ENV** does both in one press (the seed advances every
time, so every press is a different match and every one of them is reproducible).

The trace is `arena.trace.v1`: 23 floats per tick — the tick, then 11 per side
(position, aim, hp fraction, windup and dodge timers, the last committed action,
and the move/act command that side's mind actually issued). Both sides carry
their commands, so the replay drives BOTH fighters from the recording; nothing
in the arena is left to decide anything.

That makes it a **parity instrument**, not just a viewer. Identical commands fed
into two runtimes should produce identical motion, so the distance between a body
and its ghost is the environment error — localised to a tick and a body, which is
something win rates and hp totals can never do. The verdict line prints the mean
and peak drift per side, `break_tick_{a,b}` (the first tick a body crossed 20 px
from its ghost, `-1` = never), and `gap_rec`/`gap_now` — the mean distance
*between the two bodies*, recorded versus replayed, which says whether the two
runtimes were even fighting the same fight.

Gate: `bash tools/trace_replay_test.sh` (`TRACE REPLAY OK`).

## Cosmetics (GenForge pack, landed with the arena)

The arena is where cosmetics are *worn* first: `ProtoCosmetics` attaches
element auras (fire/frost/storm/venom/umbral/blood — shader media, umbral
occludes), **Grand-Chase-style necklaces** (3 elemental beads orbiting the
body on a tilted ellipse, depth-sorted behind/in-front), and weapon glows
(`pulse()` on every attack). Labs: `genforge/vfx_lab/auras/`,
`genforge/vfx_lab/necklace_orbit/`; shaders: `game/prototype/shaders/
aura_body.gdshader`, `necklace_bead.gdshader`, `weapon_aura.gdshader`. Gate:
`game/arena/tests/cosmetics_test.tscn` (COSMETICS OK). Cosmetic elements are
schema-validated (`content/schemas/arena_build.schema.json`); they are
presentation-only and never enter combat math (canon §2).

## Known limits / next steps

- Fields damage fighters only (not summons); duo bosses enter as single
  fighters (duo pairing table is future content); RL boss *phase augmentation*
  stays R3 (tech/25 §4.4).
- Neural policies drive the shared command API; native boss kits are not yet
  policy-addressable (boss self-play uses native vs neural mirror matches).
- Bounty hunters in the world: the roster is arena content today; spawning
  them as hunt NPCs with their drops is a hunt-side feature on top of this data.
- Balance is uncalibrated (numbers are the prototype's); fitness bands in the
  gate are proposals to tune once the league has real history.
- Trace replay is faithful at RANGE and breaks at CONTACT: with identical
  commands the arena's melee pair never closes (mean body gap 21.6 px recorded →
  90.4 px replayed), so no strike lands. The recorded contact equilibrium comes
  out of dh-sim's own windup/recover/separation state, which a command-only
  replay cannot reproduce. Open as R55 (tech/25 §5.3.2).
