# 24 — Order-of-magnitude levers (review of 2026-09-02)

> **Status:** analysis, not decisions — candidates for Ricardo's call. Grounded in
> a full read of `game/prototype/` (the playable slice), the arena self-play runs,
> and the canon/docs. Ordered by expected quality gain per effort. §1 = landed in
> the same pass; §2 = the levers that multiply the game; §3 = the polish backlog.

## 1. What this pass already shipped (polish pack)

Gameplay-correctness + feel fixes, all gated (CLICKTEST 16/16, FXSTRESS OK,
ARENA SELFTEST OK, hunt boot clean, validate 0):

- **Input buffering** (dodge/E/Q/slots 1-4, 150 ms) + empty-dodge-charge
  feedback — the single largest feel gap vs the Hades/Phantom Tower bar.
- **Dodge honesty**: the dash grants brief i-frames AND displacement
  (genre-standard); comments now match behavior, bots identical.
- Point-blank strikes no longer whiff (zero-vector arc test), Ignite no longer
  overwrites a stronger burn, hostile bolts and fields hit pets, armor's
  phys-reduction is clamped (no heal-on-hit singularity via blood_price),
  overlapping hitstops are last-writer-wins, respawn clears transient combat
  state, chain whiffs refund half cooldown + always play cast feedback,
  Matriarch's Talon Dive is wall-gated, low-HP gets a breathing red bar + post
  pulse, the camera leads toward the cursor, and leveling heals to full
  (the sustain floor the hunt lacked).

### Hunt level-up refresh (Ricardo, 2026-09-12)

A newly earned Hunt level refreshes derived stats, then fills current HP to the
new maximum, restores all three dodge charges and both Ember Flask charges,
and clears the obsolete dodge recharge / flask healing timers. The HP HUD updates
before the existing level-up flourish. The current Hunt has no mana bar.
Ordinary equipment/stat application never refills resources; earned class stacks,
skill cooldowns, movement and active effects retain their state. A dead hunter
can still earn progression from a delayed kill but does not heal or revive.

The P2P host applies the same refresh to living remote hunters when the shared
party level rises, retaining their actual equipment and build. This remains in
the existing prototype authority layer pending the planned C++ Hunt migration.
Gate: `game/prototype/tests/level_up_probe.tscn` (`LEVEL UP OK`) exercises actual
creature deaths, immediate HUD/stat/resource refresh, no refill before/after a
real level transition, multi-level point awards, party parity and dead players.
The Codex export smoke repeats a real kill → level-up → HP/dodge/flask refill
inside the release PCK.

## 2. The levers (biggest first)

### L1 — Data-driven AI profiles for the bestiary (fun × species value)
~1000 generated species currently collapse into 3 hand-rolled archetypes +
wisp kiting; identity is tint + multipliers. tech/25 already specifies the
target: **AI profiles as pure data** (utility scorers + behavior-library
fragments), and the arena's `bot_drive` seam is exactly where a profile
executor plugs in. Per-family behavior — pack flanking, retreat-at-HP, ability
timing, day/night behavior (the 3-min cycle currently only tints) — is the
cheapest "the world feels alive" multiplier we own, and it feeds the same
profiles to hunt creatures, arena opponents, and bounty hunters.

### L2 — Run structure: in-run choices (fun, roguelite core)
The hunt is one persistent sandbox: gear/runes/tree are account-persistent and
there are **zero in-run choices**. The genre's fun engine is per-run build
divergence. Lever: pick-1-of-3 boons from Elite/Legendary kills (in-run only,
never touching the marketplace), night-fall escalation as the run timer (the
day/night cycle becomes the difficulty clock), and a hunt-end/boss-clear
summary that makes "one more run" the loop. This is also what makes the arena
meta meaningful: builds that *diverge* are what self-play should explore.

### L3 — Bosses as system-play, not stat twists (spectacle + difficulty canon)
Every phase transition today is a cooldown/tint change. The duo's fire+earth→
lava fusion is the one systemic spark — **generalize the field-combo table into
the boss-design primitive**: more inter-kit combos, phases that permanently
mutate the arena (floods, frozen floor, darkness), duo-wide field states. This
directly serves the Monster-Hunter-grade boss canon (§4) and is data-shaped
(field kinds + combo rules already exist).

### L4 — Pets as a second build axis (build variety ×2 for one system)
The capture loop currently feeds a stat stick: one species, one basic attack,
and its rolled skills are NEVER CAST (advertised in the UI — expectation
break). Wiring the mini data-driven executor (the class-skill executor's
pattern) so pets actually cast their signature/family skills on cooldowns,
plus pet↔player status synergies, doubles buildcraft surface and directly
raises pet marketplace value (canon §3: perfect-roll pets anchor value).

### L5 — The C++ port: dh-sim authority + RL throughput (the strategic one)
Unchanged from HANDOFF ("next architectural step"): vendor godot-cpp, move
combat authority from the prototype into `dh-sim`. It is *both* the
server-authoritative hard rule and the 100× RL throughput unlock (tech/25 —
Godot-in-the-loop training is the current ceiling; the arena's ES bootstrap
and datasets are designed to port unchanged).

### L6 — Radiance Cascades (graphics, already queued)
Phase 3 of the five-overhaul program: the baked SDF + light registry are the
substrate; fragment-only port at 320×180, profile mid-Android before
commitment. The single biggest known visual jump left in the planned work.

### L7 — Audio as a first-class layer (feel)
The SFX hook points exist (`play_sfx`/`play_ui` are called everywhere) but
there is no music/ambience layer, no combat intensity mix, no biome beds.
A reactive music + biome-ambience stack (layers keyed to danger/night/boss)
is an outsized atmosphere win for a modest, well-bounded effort.

## 3. The remaining polish backlog (next batch, from the same review)

Correctness: pet rolled skills never execute (L4); pre-death meteors vanish
while their telegraph beams persist (flush impacts or clear beams in
`pyre_sovereign._die`); bolts fly through walls (walkability check per step);
a stackable Spirit Essence can't be picked up with a full bag (allow on
stack-merge); buffs/fields tick wall-clock under hitstop (scene-time delta).

Usability/feel: buff icons + countdowns on the HUD; pet HP on pet chips;
damage-number DoT aggregation (MED caps at 16 — kill numbers get recycled);
epic+ sell confirmation or 3 s undo; character panel doesn't pause (pause in
solo or combat banner); boss bar vanishes on deaggro (persist to ~2 leash
ranges); telegraph shapes (arc for melee swipes, tracer for shooters);
respawn near the fight (nearest anchor/"last lantern") + death-gold as a
recoverable corpse drop; contextual first-time toasts (snare rule, mount
dismount, first elite); mount stray-press dismount lockout; HUD stats line →
icon chips.

Balance note from arena self-play: the scripted baseline currently beats
native creature AI on most matchups — expected (native is 3 archetypes), and
exactly what L1 fixes; the league needs L1 opponents to be meaningful.
