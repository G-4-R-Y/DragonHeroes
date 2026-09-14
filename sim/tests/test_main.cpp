// Minimal dependency-free test runner for the sim workspace. Grows with the crates;
// once the suite gets serious (golden replays, fuzzing — docs/tech/21 §8) we revisit
// adopting a framework. Every test here guards a canon contract.
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include <dh/math/geom.hpp>
#include <dh/math/hash.hpp>
#include <dh/net/quantize.hpp>
#include <dh/procgen/chunk.hpp>
#include <dh/sim/arena.hpp>
#include <dh/sim/world.hpp>
#include <dh/sim/effects.hpp>

static int g_failures = 0;

#define CHECK(cond)                                                          \
    do {                                                                     \
        if (!(cond)) {                                                       \
            std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);      \
            ++g_failures;                                                    \
        }                                                                    \
    } while (0)

static void test_entity_generational_ids() {
    dh::sim::EntityStore store;
    const auto a = store.create();
    store.destroy(a);
    CHECK(!store.is_alive(a));
    const auto b = store.create();       // reuses the slot...
    CHECK(b.index == a.index);
    CHECK(b.gen != a.gen);               // ...with a bumped generation
    CHECK(store.is_alive(b));
    CHECK(!store.is_alive(a));           // stale handle stays dead
}

static void test_world_determinism() {
    // Canon (docs/tech/21): same seed + same call sequence → bit-identical state.
    auto run = [](std::uint64_t seed) {
        dh::sim::World w(seed);
        for (int i = 0; i < 40; ++i)
            w.spawn_creature({static_cast<float>(i), 2.0f}, 0.5f, 100.0f);
        for (int t = 0; t < 300; ++t) w.step();
        return w.state_hash();
    };
    CHECK(run(42) == run(42));
    CHECK(run(42) != run(43));
}

static void test_geometry() {
    using namespace dh::math;
    CHECK(circle_overlap({0, 0}, 1.0f, {1.5f, 0}, 0.6f));
    CHECK(!circle_overlap({0, 0}, 1.0f, {3.0f, 0}, 0.5f));

    // Projectile CCD: a fast projectile must not tunnel through a body.
    const auto hit = swept_circle_hit({-10, 0}, {20, 0}, 0.1f, {0, 0}, 0.5f);
    CHECK(hit.has_value());
    CHECK(*hit > 0.4f && *hit < 0.5f);  // contact just before the midpoint
    CHECK(!swept_circle_hit({-10, 5}, {20, 0}, 0.1f, {0, 0}, 0.5f).has_value());
    CHECK(!swept_circle_hit({10, 0}, {20, 0}, 0.1f, {0, 0}, 0.5f).has_value());  // moving away

    // Melee arc: in front and in reach, yes; behind, no.
    const float cos45 = 0.70710678f;  // 90° total arc
    CHECK(arc_contains({0, 0}, {1, 0}, cos45, 2.0f, {1.5f, 0.5f}, 0.3f));
    CHECK(!arc_contains({0, 0}, {1, 0}, cos45, 2.0f, {-1.5f, 0}, 0.3f));

    CHECK(capsule_circle_overlap({0, 0}, {4, 0}, 0.3f, {2, 0.5f}, 0.3f));
    CHECK(!capsule_circle_overlap({0, 0}, {4, 0}, 0.3f, {2, 2.0f}, 0.3f));
}

static void test_procgen_determinism() {
    // Canon (docs/tech/24): same seed + coords → byte-identical chunk, and chunks are
    // independently computable (constant-time random access).
    const auto a = dh::procgen::generate_chunk(7, 5, -3);
    const auto b = dh::procgen::generate_chunk(7, 5, -3);
    CHECK(a.tiles == b.tiles);
    const auto c = dh::procgen::generate_chunk(8, 5, -3);
    CHECK(a.tiles != c.tiles);
    const auto d = dh::procgen::generate_chunk(7, 6, -3);
    CHECK(a.tiles != d.tiles);
    CHECK(a.generator_version == dh::procgen::kGeneratorVersion);
}

static void test_quantization() {
    const dh::math::Vec2 p{123.456f, -7.891f};
    const auto q = dh::net::quantize(p);
    const auto r = dh::net::dequantize(q);
    CHECK(std::abs(r.x - p.x) < 0.001f);  // mm precision
    CHECK(std::abs(r.y - p.y) < 0.001f);
}

// Arena (docs/tech/25): the RL env core guards the same canon contracts as the
// Godot arena it twins — determinism first (docs/tech/21), episodes terminate,
// obs stays the exact 31-float arena.obs.v1 with sane ranges.
static dh::sim::Arena make_test_arena(std::uint64_t seed, dh::sim::OppPolicy opp) {
    dh::sim::FighterSpec boar;   // fen-boar-ish bruiser with a pounce
    boar.max_hp = 160.0f; boar.damage = 14.0f; boar.move_speed = 72.0f;
    boar.attack_reach = 28.0f; boar.attack_cd = 1.2f; boar.body_radius = 9.0f;
    boar.kits[0] = {dh::sim::KitId::kPounce, 5.0f, 128.0f, dh::sim::FieldKind::kFire};
    boar.kit_count = 1;
    dh::sim::FighterSpec drake;  // cinder-drake-ish caster: volley + fire field
    drake.max_hp = 110.0f; drake.damage = 10.0f; drake.move_speed = 68.0f;
    drake.attack_reach = 26.0f; drake.attack_cd = 1.4f; drake.body_radius = 8.0f;
    drake.is_ranged = true;
    drake.kits[0] = {dh::sim::KitId::kBoltVolley, 4.0f, 160.0f, dh::sim::FieldKind::kFire};
    drake.kits[1] = {dh::sim::KitId::kFieldCast, 8.0f, 144.0f, dh::sim::FieldKind::kFire};
    drake.kit_count = 2;
    return dh::sim::Arena(boar, drake, opp, seed);
}

static void test_arena_action_budget_binds_both_sides() {
    // FAIRNESS (canon §9 §6): 6 commits a second, burst-bound. A build whose
    // cooldowns already limit it below six proves nothing, so this uses a
    // gatling build (ranged, 0.05 s cooldown, no windup) that WANTS 20/s.
    dh::sim::FighterSpec gun;
    gun.max_hp = 400.0f; gun.damage = 3.0f; gun.move_speed = 90.0f;
    gun.attack_reach = 200.0f; gun.attack_cd = 0.05f; gun.body_radius = 9.0f;
    gun.is_ranged = true; gun.kit_count = 0;
    dh::sim::FighterSpec wall = gun;
    wall.max_hp = 4000.0f;                  // outlasts 10 s of fire
    auto commits = [&](int cap) {
        dh::sim::Arena a(gun, wall, dh::sim::OppPolicy::kScripted, 3);
        a.set_action_budget(cap);
        int n = 0;
        for (int t = 0; t < 600 && !a.step({0.0f, 0.0f, 1}); ++t)
            if (a.last_commit(0) >= 0) ++n;
        return n;
    };
    const int capped = commits(6), uncapped = commits(0);
    CHECK(capped <= 6 * 10 + 1);            // 6 a second over 10 s, plus edge
    CHECK(uncapped > capped * 2);           // and the cap is what did it
}

static void test_arena_minds_read_the_delayed_world() {
    // The half of the fairness layer that was missing longest: obs() delayed
    // the LEARNER's view while scripted_act/native_act read f_[] live, so
    // dh-env's opponent fought on information its Godot twin never has.
    //
    // What this pins is CONSUMPTION, not advantage. A stale view is not
    // uniformly worse — MEASURED over 8 seeds against a circling learner, the
    // damage a scripted mind lands moves around by a few percent either way
    // and no monotone claim survives. What must hold is that the delay reaches
    // the decision at all: change only this number and the fight must differ.
    auto fight = [](float delay) {
        auto a = make_test_arena(9, dh::sim::OppPolicy::kScripted);
        a.set_obs_delay(delay);
        a.reset(9);
        for (int t = 0; t < 900 && !a.step({std::cos(static_cast<float>(t) * 0.04f),
                                            std::sin(static_cast<float>(t) * 0.04f),
                                            0}); ++t) {}
        return a.state_hash();
    };
    CHECK(fight(0.0f) == fight(0.0f));      // still deterministic
    CHECK(fight(0.0f) != fight(0.25f));     // and the delay is actually read
    // Pinning the delay must not consume a different number of RNG draws than
    // sampling it, or the ablation would be measuring two changes at once.
    CHECK(fight(0.25f) != fight(0.15f));

    // The delay is per side, in range, and resampled per reset unless pinned.
    auto arena = make_test_arena(9, dh::sim::OppPolicy::kScripted);
    for (int side = 0; side < 2; ++side) {
        CHECK(arena.obs_delay(side) >= 0.15f);
        CHECK(arena.obs_delay(side) <= 0.25f);
    }
    arena.set_obs_delay(0.2f);
    CHECK(arena.obs_delay(0) == 0.2f && arena.obs_delay(1) == 0.2f);
    arena.set_obs_delay(-1.0f);
    arena.reset(10);
    CHECK(arena.obs_delay(1) >= 0.15f && arena.obs_delay(1) <= 0.25f);
}

static void test_arena_swing_is_a_cone_not_a_circle() {
    // creature.gd::_strike and player.gd::_arc_hit both gate on an ARC around
    // the direction the swing was committed to; the sim had no arc at all, so
    // every swing it threw connected. Walk a target THROUGH the cone edge:
    // in reach the whole time, hit only while it is in front.
    const dh::math::Vec2 aim{1.0f, 0.0f};
    CHECK(dh::sim::Arena::in_arc({10.0f, 0.0f}, aim, 90.0f, 8.0f));    // dead ahead
    CHECK(dh::sim::Arena::in_arc({10.0f, 9.0f}, aim, 90.0f, 8.0f));    // inside 45 deg
    CHECK(!dh::sim::Arena::in_arc({10.0f, 30.0f}, aim, 90.0f, 8.0f));  // outside it
    CHECK(!dh::sim::Arena::in_arc({-10.0f, 0.0f}, aim, 90.0f, 8.0f));  // behind
    CHECK(dh::sim::Arena::in_arc({-10.0f, 0.0f}, aim, 110.0f, 40.0f)); // point blank
    // A wider cone can never hit less than a narrower one.
    for (float y = -40.0f; y <= 40.0f; y += 5.0f)
        if (dh::sim::Arena::in_arc({10.0f, y}, aim, 90.0f, 8.0f))
            CHECK(dh::sim::Arena::in_arc({10.0f, y}, aim, 110.0f, 8.0f));
}

static void test_arena_determinism() {
    auto run = [](std::uint64_t seed) {
        auto arena = make_test_arena(seed, dh::sim::OppPolicy::kScripted);
        dh::sim::Action hold{0.5f, 0.1f, 0};
        for (int t = 0; t < 600 && !arena.step(hold); ++t) {}
        return arena.state_hash();
    };
    CHECK(run(42) == run(42));
    CHECK(run(42) != run(43));
}

static void test_arena_terminates() {
    for (auto opp : {dh::sim::OppPolicy::kNative, dh::sim::OppPolicy::kScripted}) {
        auto arena = make_test_arena(7, opp);
        // the "learner" chases and attacks — a policy that must end episodes
        bool done = false;
        for (std::uint32_t t = 0; t < dh::sim::kMaxTicks && !done; ++t) {
            float o[dh::sim::kObsDim];
            arena.obs(o);
            const float dx = o[16] * 512.0f, dy = o[17] * 512.0f;
            const float len = std::sqrt(dx * dx + dy * dy);
            dh::sim::Action chase{len > 1.0f ? dx / len : 0.0f,
                                  len > 1.0f ? dy / len : 0.0f,
                                  len < 40.0f ? 1 : 0};
            done = arena.step(chase);
        }
        CHECK(done);
        CHECK(arena.winner() >= -1 && arena.winner() <= 1);
    }
}

static void test_arena_obs_schema() {
    auto arena = make_test_arena(11, dh::sim::OppPolicy::kScripted);
    float o[dh::sim::kObsDim];
    arena.obs(o);
    for (int i = 0; i < dh::sim::kObsDim; ++i)
        CHECK(std::isfinite(o[i]));
    CHECK(o[0] == 1.0f && o[15] == 1.0f);        // full hp at spawn
    const float dx = o[16] * 512.0f, dy = o[17] * 512.0f;   // foe rel pos
    const float dist = std::sqrt(dx * dx + dy * dy);
    CHECK(dist > 300.0f && dist < 500.0f);       // symmetric 12.5-tile spawns
    CHECK(o[18] > 0.5f && o[18] < 1.0f);         // normalized distance agrees
    // A kit cast lights up a cooldown slot (o[7..10]) — but NOT IMMEDIATELY.
    // FAIRNESS (canon §9 §6): obs() returns the world as it was 150-250 ms ago,
    // the same view game/arena/policy.gd::delayed_obs gives every policy. This
    // used to be absent from the sim entirely (delay_s_ was sampled and never
    // read), so PPO trained at zero latency while the gate measured 200 ms —
    // and the identical policy scored win 1.00 in dh-env against 0-12 in the
    // arena. The assertion order below is the contract: stale first, then true.
    dh::sim::Action cast{0.0f, 0.0f, 3};
    arena.step(cast);
    arena.obs(o);
    CHECK(o[7] == 0.0f);          // one tick later the learner cannot know yet
    for (int i = 0; i < 20; ++i) arena.step({0.0f, 0.0f, 0});   // > 0.25 s
    arena.obs(o);
    CHECK(o[7] > 0.0f);           // ...and now it does
}

static void test_arena_obs_is_delayed_for_fairness() {
    // The delay is a RANGE (0.15-0.25 s), sampled per reset, so pin the
    // property rather than a tick count: the learner's view must lag the truth
    // by somewhere between 9 and 15 ticks at 60 Hz, and must never run ahead.
    auto arena = make_test_arena(11, dh::sim::OppPolicy::kScripted);
    float o[dh::sim::kObsDim];
    // Walk one way for a while; the reported position must trail the real one.
    for (int i = 0; i < 60; ++i) arena.step({1.0f, 0.0f, 0});
    arena.obs(o);
    const float seen_x = o[1] * 512.0f;
    float truth[dh::sim::kObsDim];
    arena.obs_now(truth);
    const float real_x = truth[1] * 512.0f;
    CHECK(real_x > seen_x);                       // the view LAGS, never leads
    // 0.15-0.25 s of travel at this build's speed, with slack for clamping.
    const float lag = real_x - seen_x;
    CHECK(lag > 0.5f && lag < 60.0f);

    // Before enough history exists the oldest frame is used rather than an
    // invented one — the same thing ArenaPolicy does with its own ring.
    arena.reset(11);
    arena.obs(o);
    CHECK(o[0] == 1.0f && o[15] == 1.0f);         // a real frame, not zeros
}

static void test_arena_conduct_combo() {
    // Canon §12.41: a storm bolt inside a mire field detonates it — 2x bolt
    // damage on the field owner's enemy, field consumed. A lays mire on B;
    // B's own storm volley detonates it at B's feet (the 1v1 anti-synergy).
    dh::sim::FighterSpec serpent;   // mire fields, negligible other damage
    serpent.max_hp = 500.0f; serpent.damage = 1.0f; serpent.move_speed = 60.0f;
    serpent.kits[0] = {dh::sim::KitId::kFieldCast, 0.5f, 999.0f, dh::sim::FieldKind::kMire};
    serpent.kit_count = 1;
    dh::sim::FighterSpec wisp;      // storm volley, 10 dmg -> 8/bolt -> 16 burst
    wisp.max_hp = 500.0f; wisp.damage = 10.0f; wisp.move_speed = 60.0f;
    wisp.kits[0] = {dh::sim::KitId::kBoltVolley, 0.1f, 999.0f, dh::sim::FieldKind::kStorm};
    wisp.kit_count = 1;
    dh::sim::Arena arena(serpent, wisp, dh::sim::OppPolicy::kNative, 5);
    bool burst_seen = false;
    for (int t = 0; t < 1200 && !burst_seen; ++t) {
        const float hp_before = arena.hp_frac(1);
        arena.step({0.0f, 0.0f, 3});   // learner (A=serpent) idles; B is native
        // B's hp dropping by >= a full burst (16/500) in ONE step = conduct
        if (hp_before - arena.hp_frac(1) >= 15.0f / 500.0f) burst_seen = true;
    }
    CHECK(burst_seen);
}

static void test_arena_opponent_mind_can_change_between_episodes() {
    // Ricardo's curriculum, 2026-09-14: "learn from scripts first and, once
    // reliably wiining against it, self playing". Switching the opponent's MIND
    // must change the fight and must NOT change determinism: state_hash is a
    // function of the seed and the actions taken, not of who chose them.
    // cinder_drake's real numbers, run 600 ticks (10 s): MEASURED, the two
    // minds are still identical at 200 ticks because both are just closing the
    // distance, and diverge only once the fight starts — native settles into a
    // 0.449/0.449 standoff where scripted reaches 0.316/0.669. A tankier pair can end an episode in the same state from
    // either mind, which would make this test pass for the wrong reason.
    dh::sim::FighterSpec s;
    s.max_hp = 87.36f; s.damage = 9.632f; s.move_speed = 107.532f;
    s.attack_reach = 28.8f; s.attack_cd = 0.9f; s.body_radius = 9.84f;
    s.special_cd = 6.0f;

    const auto play = [&](dh::sim::OppPolicy p) {
        dh::sim::Arena a(s, s, p, 11);
        a.reset(4242);
        for (int t = 0; t < 600; ++t) if (a.step({1.0f, 0.0f, 1})) break;
        return a.state_hash();
    };
    const std::uint64_t h_scripted = play(dh::sim::OppPolicy::kScripted);
    const std::uint64_t h_native = play(dh::sim::OppPolicy::kNative);
    CHECK(h_scripted != h_native);          // the two minds really do differ

    // Same arena, switched between episodes, reproduces each one exactly.
    dh::sim::Arena a(s, s, dh::sim::OppPolicy::kScripted, 11);
    a.reset(4242);
    for (int t = 0; t < 600; ++t) if (a.step({1.0f, 0.0f, 1})) break;
    CHECK(a.state_hash() == h_scripted);
    CHECK(a.set_opp_policy(dh::sim::OppPolicy::kNative));
    CHECK(a.opp_policy() == dh::sim::OppPolicy::kNative);
    a.reset(4242);
    for (int t = 0; t < 600; ++t) if (a.step({1.0f, 0.0f, 1})) break;
    CHECK(a.state_hash() == h_native);

    // kMlp with no weights is REFUSED rather than fighting an unset net — a
    // curriculum that silently promoted into a null opponent would look like a
    // policy that suddenly got much better.
    CHECK(!a.set_opp_policy(dh::sim::OppPolicy::kMlp));
    CHECK(a.opp_policy() == dh::sim::OppPolicy::kNative);
}

static void test_arena_reports_what_actually_committed() {
    // last_commit() is the difference between paying for INTENT and paying for
    // EFFECT. PPO's kit bonus fired whenever the agent SELECTED a kit, and a kit
    // on an 8 s cooldown stays selectable for 480 ticks per cast, so spamming
    // one earned 3600 x 0.02 = 72 reward per episode against a terminal worth 1.
    // The policy collapsed onto that one action on 100.000% of ticks.
    dh::sim::FighterSpec caster;
    caster.max_hp = 400.0f; caster.damage = 20.0f; caster.move_speed = 70.0f;
    caster.attack_reach = 30.0f; caster.attack_cd = 1.0f; caster.body_radius = 8.0f;
    caster.kits[0] = {dh::sim::KitId::kFieldCast, 8.0f, 999.0f, dh::sim::FieldKind::kFire};
    caster.kit_count = 1;
    dh::sim::FighterSpec dummy = caster;
    dummy.damage = 0.0f; dummy.move_speed = 0.0f; dummy.kit_count = 0;

    dh::sim::Arena a(caster, dummy, dh::sim::OppPolicy::kScripted, 3);
    int selected = 0, committed = 0;
    for (int t = 0; t < 600; ++t) {
        if (a.step({0.0f, 0.0f, 3})) break;    // pick kit slot 0 EVERY tick
        ++selected;
        if (a.last_commit(0) == 3) ++committed;
    }
    CHECK(selected > 400);                     // it really did ask 600 times
    CHECK(committed >= 1);                     // ...the kit really did fire
    // 8 s at 60 Hz is 480 ticks: at most two casts in 600, never 600.
    CHECK(committed <= 3);

    // A refused action reports -1 rather than the action id.
    dh::sim::Arena b(caster, dummy, dh::sim::OppPolicy::kScripted, 3);
    b.step({0.0f, 0.0f, 3});                   // fires, cooldown starts
    CHECK(b.last_commit(0) == 3);
    b.step({0.0f, 0.0f, 3});                   // on cooldown now
    CHECK(b.last_commit(0) == -1);
    b.step({0.0f, 0.0f, 5});                   // slot 2: this build has none
    CHECK(b.last_commit(0) == -1);
    b.step({0.0f, 0.0f, 0});                   // noop is never a commitment
    CHECK(b.last_commit(0) == -1);
}

static void test_arena_dodge_is_a_fallback() {
    // The contract the shipping arena defines (game/arena/neural_policy.gd):
    //     match pick: 1 -> cmd_attack() ... ;  if dodge_logit > 0 and NOT ok:
    //     cmd_dodge()
    // so a dodge flag must never cost the agent its attack. dh-env used to fold
    // dodge into the act id, which made it an OVERRIDE instead, and a build with
    // dodge_max = 0 then spent 95-98% of its ticks on a guaranteed no-op.
    dh::sim::FighterSpec brawler;
    brawler.max_hp = 400.0f; brawler.damage = 20.0f; brawler.move_speed = 90.0f;
    brawler.attack_reach = 40.0f; brawler.attack_cd = 0.4f; brawler.body_radius = 9.0f;
    brawler.dodge_max = 0;                     // exactly the fen_boar case
    dh::sim::FighterSpec target = brawler;
    target.max_hp = 4000.0f; target.damage = 0.0f; target.move_speed = 0.0f;
    target.attack_cd = 99.0f;

    // Chase and swing, with the dodge flag raised on every single tick.
    auto fight = [&](bool dodge_flag) {
        dh::sim::Arena a(brawler, target, dh::sim::OppPolicy::kScripted, 21);
        for (int t = 0; t < 900; ++t) {
            float o[dh::sim::kObsDim];
            a.obs(o);
            const float dx = o[16] * 512.0f, dy = o[17] * 512.0f;
            const float len = std::sqrt(dx * dx + dy * dy) + 1e-6f;
            dh::sim::Action act{dx / len, dy / len, 1, dodge_flag};
            if (a.step(act)) break;
        }
        return a.damage_taken(1);
    };
    const float plain = fight(false);
    const float flagged = fight(true);
    CHECK(plain > 0.0f);                       // the attack lands at all
    CHECK(flagged == plain);                   // ...and the flag costs nothing

    // An act id of 7 still means dodge and nothing else, so callers written
    // before the flag existed are unchanged.
    dh::sim::Arena seven(brawler, target, dh::sim::OppPolicy::kScripted, 21);
    for (int t = 0; t < 900; ++t) {
        float o[dh::sim::kObsDim];
        seven.obs(o);
        const float dx = o[16] * 512.0f, dy = o[17] * 512.0f;
        const float len = std::sqrt(dx * dx + dy * dy) + 1e-6f;
        if (seven.step({dx / len, dy / len, 7})) break;
    }
    CHECK(seven.damage_taken(1) == 0.0f);      // never attacked, as before
}

static void test_arena_damage_accounting() {
    // damage_taken() is the twin of game/arena/fighter.gd::damage_taken, added
    // so ml/eval/env_parity.py can name WHICH term the two runtimes disagree on.
    // Three things have to hold or the number is not comparable to the arena's:
    // it starts at zero, it accounts for EVERY damage path (including the two
    // that used to bypass hurt() — mire detonation and field dps), and it is
    // raw, so a kill costs at least the victim's whole health bar.
    auto arena = make_test_arena(3, dh::sim::OppPolicy::kNative);
    CHECK(arena.damage_taken(0) == 0.0f);
    CHECK(arena.damage_taken(1) == 0.0f);

    // A caster whose ONLY damage is a fire field: if field dps were still
    // bypassing hurt() this stays at zero while the victim's health falls.
    dh::sim::FighterSpec burner;
    // damage feeds the field (dps = damage * 0.3), so it cannot be zero; the
    // learner simply never issues act 1, so no melee packet is ever swung.
    burner.max_hp = 600.0f; burner.damage = 30.0f; burner.move_speed = 60.0f;
    burner.attack_reach = 1.0f; burner.attack_cd = 99.0f;
    burner.kits[0] = {dh::sim::KitId::kFieldCast, 0.5f, 999.0f, dh::sim::FieldKind::kLava};
    burner.kit_count = 1;
    dh::sim::FighterSpec dummy;
    dummy.max_hp = 600.0f; dummy.damage = 0.0f; dummy.move_speed = 0.0f;
    dummy.attack_reach = 1.0f; dummy.attack_cd = 99.0f;
    dh::sim::Arena fire(burner, dummy, dh::sim::OppPolicy::kScripted, 4);
    const float hp0 = fire.hp_frac(1);
    for (int t = 0; t < 900; ++t)
        if (fire.step({0.0f, 0.0f, 3})) break;
    const float lost = (hp0 - fire.hp_frac(1)) * 600.0f;
    CHECK(lost > 0.0f);                              // the field did land
    CHECK(fire.damage_taken(1) >= lost - 0.5f);      // ...and it was counted

    // Raw, not clamped: whoever died absorbed at least a full health bar.
    dh::sim::Arena duel(make_test_arena(9, dh::sim::OppPolicy::kNative));
    bool done = false;
    for (std::uint32_t t = 0; t < dh::sim::kMaxTicks && !done; ++t)
        done = duel.step({0.0f, 0.0f, 1});
    const int w = duel.winner();
    if (w == 0 || w == 1) {
        const int loser = 1 - w;
        const float bar = loser == 0 ? 160.0f : 110.0f;
        CHECK(duel.damage_taken(loser) >= bar - 0.01f);
    }
    // reset() clears the tally rather than carrying it into the next episode.
    duel.reset(9);
    CHECK(duel.damage_taken(0) == 0.0f);
    CHECK(duel.damage_taken(1) == 0.0f);
}

static void test_arena_squad_mode() {
    // 2v2 squad (arena.obs.v2): each side fields a buddy body; episodes end
    // only when BOTH of a fighter's bodies fall; obs carries the ally block.
    dh::sim::FighterSpec boar;
    boar.max_hp = 160.0f; boar.damage = 14.0f; boar.move_speed = 72.0f;
    boar.kits[0] = {dh::sim::KitId::kPounce, 5.0f, 128.0f, dh::sim::FieldKind::kFire};
    boar.kit_count = 1;
    dh::sim::FighterSpec pup = boar;   // pack tactics: two of the same
    pup.max_hp = 90.0f; pup.damage = 8.0f;
    dh::sim::FighterSpec wisp;
    wisp.max_hp = 90.0f; wisp.damage = 10.0f; wisp.move_speed = 76.0f;
    wisp.is_ranged = true;
    wisp.kits[0] = {dh::sim::KitId::kBoltVolley, 2.5f, 160.0f, dh::sim::FieldKind::kStorm};
    wisp.kits[1] = {dh::sim::KitId::kFieldCast, 8.0f, 144.0f, dh::sim::FieldKind::kMire};
    wisp.kit_count = 2;
    dh::sim::Arena arena(boar, pup, wisp, wisp, dh::sim::OppPolicy::kNative, 9);
    CHECK(arena.obs_dim() == dh::sim::kObsV2Dim);
    float o[dh::sim::kObsV2Dim];
    arena.obs(o);
    CHECK(o[31] == 1.0f);              // buddy alive at spawn
    CHECK(o[34] > 0.0f);               // ...at a nonzero offset
    bool done = false;
    for (std::uint32_t t = 0; t < dh::sim::kMaxTicks && !done; ++t) {
        arena.obs(o);
        const float dx = o[16] * 512.0f, dy = o[17] * 512.0f;
        const float len = std::sqrt(dx * dx + dy * dy) + 1e-6f;
        done = arena.step({dx / len, dy / len, len < 40.0f ? 1 : 0});
        for (int i = 0; i < dh::sim::kObsV2Dim; ++i) CHECK(std::isfinite(o[i]));
    }
    CHECK(done);
    CHECK(arena.winner() >= -1 && arena.winner() <= 1);
}

static void test_effect_commands() {
    using namespace dh::sim;
    // Storm on Wet consumes the setup exactly once; subsequent procs cannot recurse.
    EffectDef def{EffectTrigger::hit,1,1,1,EffectAction::chain,250,90,3,24};
    EffectState owner_a, owner_b;
    EffectEvent e{EffectTrigger::hit,1,1,0,0};
    const auto command=evaluate_effect(def,owner_a,e);
    CHECK(command && command->max_targets==3 && command->magnitude_permille==250);
    CHECK(e.statuses==0);
    e.statuses=1;
    CHECK(!evaluate_effect(def,owner_a,e)); // same owner's cooldown
    CHECK(evaluate_effect(def,owner_b,e)); // independent owner
    e={EffectTrigger::hit,1,1,90,1};
    CHECK(!evaluate_effect(def,owner_a,e)); // child proc is forbidden
    e.proc_depth=0; e.tags=2;
    CHECK(!evaluate_effect(def,owner_a,e)); // tag mismatch
    e.tags=1; e.statuses=0;
    CHECK(!evaluate_effect(def,owner_a,e)); // setup absent
    e.statuses=1; e.trigger=EffectTrigger::dodge;
    CHECK(!evaluate_effect(def,owner_a,e)); // trigger mismatch
    e.trigger=EffectTrigger::hit;
    CHECK(evaluate_effect(def,owner_a,e)); // exact cooldown boundary
    CHECK(!evaluate_effect(def,owner_b,e)); // status cannot be consumed twice
    def.max_targets=9;
    CHECK(!valid_effect(def));
    def.max_targets=3;
    e.tick=std::numeric_limits<std::uint64_t>::max(); e.statuses=1;
    CHECK(evaluate_effect(def,owner_a,e));
    e.statuses=1;
    CHECK(!evaluate_effect(def,owner_a,e)); // tick overflow fails closed
}

int main() {
    test_effect_commands();
    test_entity_generational_ids();
    test_world_determinism();
    test_geometry();
    test_procgen_determinism();
    test_quantization();
    test_arena_determinism();
    test_arena_terminates();
    test_arena_obs_schema();
    test_arena_obs_is_delayed_for_fairness();
    test_arena_action_budget_binds_both_sides();
    test_arena_minds_read_the_delayed_world();
    test_arena_swing_is_a_cone_not_a_circle();
    test_arena_conduct_combo();
    test_arena_opponent_mind_can_change_between_episodes();
    test_arena_reports_what_actually_committed();
    test_arena_dodge_is_a_fallback();
    test_arena_damage_accounting();
    test_arena_squad_mode();
    if (g_failures == 0) {
        std::printf("sim-tests: all checks passed\n");
        return EXIT_SUCCESS;
    }
    std::printf("sim-tests: %d check(s) FAILED\n", g_failures);
    return EXIT_FAILURE;
}
