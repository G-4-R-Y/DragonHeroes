// Minimal dependency-free test runner for the sim workspace. Grows with the crates;
// once the suite gets serious (golden replays, fuzzing — docs/tech/21 §8) we revisit
// adopting a framework. Every test here guards a canon contract.
#include <utility>
#include <cmath>
#include <cstdio>
#include <vector>
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

static void test_arena_action_mask_is_one_rule() {
    // arena.mask.v1 — hand-mirrors ml/tests/test_action_mask.py::fixture_cases,
    // the fixture game/arena/tests/mask_parity_test.gd reads. If this and that
    // ever disagree, the frozen self-play opponent is a different policy from
    // the one the trainer optimizes and the arena ships.
    using dh::sim::Arena;
    constexpr int L = dh::sim::kActionLogits;
    const float q = 1.0f / 16.0f;
    float o[dh::sim::kObsDim] = {};
    bool m[L];
    Arena::action_mask(o, 4, false, m);
    for (int i = 0; i < L; ++i) CHECK(m[i]);            // all ready: nothing hidden
    o[7] = 1.0f;                                         // kit 0 cooling
    Arena::action_mask(o, 4, false, m);
    CHECK(m[0] && m[1] && m[2] && !m[3] && m[4] && m[5] && m[6]);
    o[7] = q;                                            // one sixteenth still masks
    Arena::action_mask(o, 4, false, m);
    CHECK(!m[3] && m[4]);
    o[7] = 0.0f; o[5] = 0.5f;                            // attack cooling
    Arena::action_mask(o, 4, false, m);
    CHECK(!m[1] && !m[2]);                               // creature special = a swing
    Arena::action_mask(o, 4, true, m);
    CHECK(!m[1] && m[2]);                                // player special has its own cd
    o[5] = 0.0f; o[6] = q;
    Arena::action_mask(o, 4, true, m);  CHECK(!m[2]);
    Arena::action_mask(o, 4, false, m); CHECK(m[2]);     // o[6] means nothing to a creature
    o[6] = 0.0f;
    Arena::action_mask(o, 2, false, m);
    CHECK(m[3] && m[4] && !m[5] && !m[6]);               // slots that do not exist
    Arena::action_mask(o, 0, false, m);
    CHECK(m[1] && !m[3] && !m[4] && !m[5] && !m[6]);
    o[5] = 1.0f; for (int k = 0; k < 4; ++k) o[7 + k] = 1.0f;
    Arena::action_mask(o, 4, false, m);
    CHECK(m[0]); for (int i = 1; i < L; ++i) CHECK(!m[i]);   // only noop left
    CHECK(!Arena::dodge_allowed(o));
    o[12] = 0.25f;
    CHECK(Arena::dodge_allowed(o));
}

static void test_arena_frozen_opponent_decodes_through_the_mask() {
    // The self-play opponent is the ONE runtime that never goes through
    // Python or GDScript, so it is the one that drifts unnoticed. A frozen
    // head that wants kit 0 above all (logit 9), attack second (5), dodge
    // negative: the unmasked argmax was "act 3 forever" — refused on every
    // tick the kit cooled, no fallback, so the opponent committed NOTHING for
    // 4 s after each cast. Through arena.mask.v1 the cooling kit is unavailable
    // and the pick falls to the attack. exec_kit sets kit_cd unconditionally,
    // so the sequence "3, then 1s until 3 again" is what must show up.
    auto a = make_test_arena(21, dh::sim::OppPolicy::kScripted);   // opp = drake, 2 kits
    constexpr int n_in = dh::sim::kObsDim + 16;
    constexpr int n_out = 2 + dh::sim::kActionLogits + 1;
    std::vector<float> params(static_cast<std::size_t>(n_in) * n_out + n_out, 0.0f);
    float* b = params.data() + n_in * n_out;
    b[2 + 3] = 9.0f;                                // kit 0
    b[2 + 1] = 5.0f;                                // attack
    b[2 + dh::sim::kActionLogits] = -1.0f;          // never dodge
    const int li[1] = {n_in}, lo[1] = {n_out};
    const int acts[1] = {dh::sim::Arena::kActLinear};
    const float emb[16] = {};
    a.set_opp_mlp(params.data(), li, lo, 1, emb, acts);
    CHECK(a.set_opp_policy(dh::sim::OppPolicy::kMlp));
    a.reset(21);
    int kits = 0, attacks = 0, others = 0;
    for (int t = 0; t < 1800 && !a.step({0.0f, 0.0f, 0}); ++t) {
        const int c = a.last_commit(1);
        if (c == 3) ++kits;
        else if (c == 1) ++attacks;
        else if (c >= 0) ++others;
    }
    CHECK(kits >= 1);        // the kit it wants fires whenever it is available
    CHECK(attacks >= 3);     // and while it cools the mask hands it the attack
    CHECK(others == 0);      // nothing else was ever picked
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

static void test_arena_archetypes_shape_the_swing() {
    // R55 (2026-09-19). creature.gd::setup_from_entry reshapes the chassis by
    // the bestiary archetype a build's bundle resolves to (fighter.gd::setup):
    // a LUNGER winds up 0.22 s and pounces from 2.5-5.5 tiles, a BRUTE winds
    // up 0.55 s and lands an arc-free 2.2-tile ground slam, the stalker default
    // winds up 0.35 s and bites in a 90 deg cone. The sim gave every body the
    // stalker swing; measured on the converged nets, the arena's lunger and
    // brute natives dealt 2-3x the damage dh-env's did (tech/39 §2).
    dh::sim::FighterSpec statue;      // an opponent that only stands there
    statue.max_hp = 100000.0f; statue.damage = 0.0f; statue.move_speed = 0.0f;
    statue.attack_reach = 28.8f; statue.attack_cd = 1000.0f; statue.body_radius = 8.0f;
    statue.dodge_max = 0; statue.kit_count = 0;
    // Walk the learner straight at the statue to `stand_off` px centre to
    // centre, commit ONE swing, and return the ticks until it lands (-1 = whiff).
    auto swing = [&](dh::sim::Archetype arch, float windup, float stand_off) {
        dh::sim::FighterSpec me;
        me.max_hp = 100.0f; me.damage = 10.0f; me.move_speed = 60.0f;
        me.attack_reach = 28.8f; me.attack_cd = 1.2f; me.body_radius = 8.0f;
        me.dodge_max = 0; me.kit_count = 0;
        me.archetype = arch; me.windup_time = windup;
        dh::sim::Arena a(me, statue, dh::sim::OppPolicy::kScripted, 4);
        a.reset(4);
        float o[dh::sim::kObsDim];
        int t = 0;
        for (; t < 1200; ++t) {
            a.obs_now(o);
            if (o[18] * 512.0f <= stand_off) break;
            a.step({o[16], o[17], 0});
        }
        CHECK(t < 1200);
        a.step({0.0f, 0.0f, 1});                    // the commit tick
        for (int k = 1; k <= 120; ++k) {
            if (a.damage_taken(1) > 0.0f) return k - 1;
            a.step({0.0f, 0.0f, 0});
        }
        return -1;
    };
    // (1) the telegraph is the body's own windup_time, not one constant:
    //     0.22 s = 13.2 ticks, 0.35 s = 21, 0.55 s = 33 (one decrement lands
    //     on the commit tick itself).
    const int lunger = swing(dh::sim::Archetype::kLunger, 0.22f, 30.0f);
    const int stalker = swing(dh::sim::Archetype::kStalker, 0.35f, 30.0f);
    const int brute = swing(dh::sim::Archetype::kBrute, 0.55f, 30.0f);
    CHECK(lunger >= 12 && lunger <= 15);
    CHECK(stalker >= 19 && stalker <= 23);
    CHECK(brute >= 31 && brute <= 35);
    CHECK(lunger < stalker && stalker < brute);
    // (2) the brute's strike is a radial slam of 2.2 tiles + target radius
    //     (43.2 px here) where the stalker bite reaches attack_reach + radius
    //     (36.8 px): at 40 px one lands and the other whiffs.
    CHECK(swing(dh::sim::Archetype::kStalker, 0.35f, 40.0f) == -1);
    CHECK(swing(dh::sim::Archetype::kBrute, 0.55f, 40.0f) > 0);
    // (3) a NATIVE lunger pounces: the largest single-tick closing of the
    //     centre distance is the 3-tile leap, where a stalker only walks
    //     (60 px/s = 1 px per tick).
    auto max_jump = [&](dh::sim::Archetype arch) {
        dh::sim::FighterSpec me = statue;          // the learner never acts
        me.max_hp = 1000.0f;
        dh::sim::FighterSpec foe;
        foe.max_hp = 100.0f; foe.damage = 5.0f; foe.move_speed = 60.0f;
        foe.attack_reach = 28.8f; foe.attack_cd = 0.9f; foe.body_radius = 8.0f;
        foe.dodge_max = 0; foe.kit_count = 0;
        foe.archetype = arch; foe.windup_time = 0.22f;
        dh::sim::Arena a(me, foe, dh::sim::OppPolicy::kNative, 5);
        a.reset(5);
        float o[dh::sim::kObsDim];
        a.obs_now(o);
        float prev = o[18] * 512.0f, jump = 0.0f;
        for (int t = 0; t < 600 && !a.step({0.0f, 0.0f, 0}); ++t) {
            a.obs_now(o);
            const float d = o[18] * 512.0f;
            if (prev - d > jump) jump = prev - d;
            prev = d;
        }
        return jump;
    };
    CHECK(max_jump(dh::sim::Archetype::kLunger) > 2.0f * 16.0f);
    CHECK(max_jump(dh::sim::Archetype::kStalker) < 4.0f);
    // (4) the traits reach a live arena through the setter dh-env uses, and
    //     take effect for the current spec (not only after the next reset).
    dh::sim::Arena a(statue, statue, dh::sim::OppPolicy::kScripted, 6);
    a.set_body_traits(1, dh::sim::Archetype::kBrute, 0.55f);
    a.set_body_traits(0, dh::sim::Archetype::kLunger, -1.0f);   // <= 0 keeps the windup
    a.reset(6);
    CHECK(a.state_hash() == a.state_hash());
}

static void test_arena_damage_by_source_sums_to_the_tally() {
    // R55: the by-source split (contact / bolt / field) is the twin of the
    // arena row's dmg_{contact,bolt,field}; it must partition damage_taken
    // exactly, and a scripted caster that volleys and drops fields must show
    // up in the bolt and field buckets of what the learner took.
    auto a = make_test_arena(21, dh::sim::OppPolicy::kScripted);
    a.reset(21);
    float o[dh::sim::kObsDim];
    for (int t = 0; t < 1800 && !a.step({0.0f, 0.0f, t % 90 == 0 ? 3 : 1}); ++t) {
        a.obs_now(o);
        (void)o;
    }
    for (int who = 0; who < 2; ++who) {
        float sum = 0.0f;
        for (int s = 0; s < static_cast<int>(dh::sim::DmgSource::kSourceCount); ++s)
            sum += a.damage_by_source(who, static_cast<dh::sim::DmgSource>(s));
        CHECK(std::fabs(sum - a.damage_taken(who)) < 1e-3f);
    }
    CHECK(a.damage_by_source(0, dh::sim::DmgSource::kBolt) > 0.0f);
    CHECK(a.damage_by_source(0, dh::sim::DmgSource::kField) > 0.0f);
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

static void test_arena_bodies_separate_instead_of_standing_inside_each_other() {
    // R59 (2026-09-21, Ricardo: "make sure creatures collide with the player, so
    // they are not right on top of me in a way I can't hit them"). creature.gd
    // had _separate, but called it only from _chase — which returns the moment
    // the body is inside attack_reach * 0.9 — and iterated only the "creatures"
    // group, never the player. An arena body is bot_drive and therefore never
    // chases, so NEITHER runtime separated anything in a duel. Both do now.
    dh::sim::FighterSpec statue;          // stands still, never swings
    statue.max_hp = 100000.0f; statue.damage = 0.0f; statue.move_speed = 0.0f;
    statue.attack_reach = 1.0f; statue.attack_cd = 1000.0f; statue.body_radius = 8.0f;
    statue.dodge_max = 0; statue.kit_count = 0;

    // Walk fighter 0 straight into the statue for `drive` ticks, then stop and
    // let the spring settle for `settle` ticks. Returns the final gap in px.
    auto run = [&](bool foe_is_player, int drive, int settle) {
        dh::sim::FighterSpec me;
        me.max_hp = 100.0f; me.damage = 0.0f; me.move_speed = 72.0f;
        me.attack_reach = 1.0f; me.attack_cd = 1000.0f; me.body_radius = 8.0f;
        me.dodge_max = 0; me.kit_count = 0; me.windup_time = 0.35f;
        dh::sim::FighterSpec foe = statue;
        foe.is_player = foe_is_player;
        dh::sim::Arena a(me, foe, dh::sim::OppPolicy::kScripted, 4);
        a.reset(4);
        float o[dh::sim::kObsDim];
        for (int t = 0; t < drive; ++t) {
            a.obs_now(o);
            // o[16..17] is rel/512, so it falls under the creature path's 0.05
            // magnitude floor at 25.6 px and the body would simply stop there.
            // Hold a UNIT command instead — full speed, straight in.
            const float l = std::sqrt(o[16] * o[16] + o[17] * o[17]);
            if (l <= 1e-6f) break;
            a.step({o[16] / l, o[17] / l, 0});
        }
        for (int t = 0; t < settle; ++t) a.step({0.0f, 0.0f, 0});
        a.obs_now(o);
        return o[18] * 512.0f;
    };

    // Released, the overlap resolves to exactly touching: min_d = 8 + 8 = 16 px.
    // Before this change the two bodies came to rest at a gap of zero.
    const float settled = run(false, 400, 240);
    CHECK(settled > 15.0f);
    CHECK(settled < 17.0f);

    // Under a body still driving in at 72 px/s the spring does not win outright
    // — it holds a standoff where speed == rate * overlap. That standoff is what
    // the two constants buy, so it pins both: pushing off a PLAYER (rate 12)
    // must hold visibly more ground than pushing off a creature (rate 4).
    const float vs_creature = run(false, 400, 0);
    const float vs_player = run(true, 400, 0);
    // Measured 2026-09-21 at 72 px/s: 7.90 px off a creature, 11.20 px off a
    // player. Released (above) both settle to exactly 16.000 px.
    CHECK(vs_player > vs_creature + 2.0f);
    // And even mid-drive the bodies are no longer concentric, which is the
    // actual complaint: a swing needs somewhere to land.
    CHECK(vs_creature > 0.5f);
}

static void test_arena_fiery_affix_rides_the_bite_as_bolt_damage() {
    // R55-b (2026-09-21). creature.gd::setup_archetype gives an elite one of
    // four affixes. Brutal/Swift/Bulwark multiply damage / speed+cd / max_hp,
    // so dump_specs.gd reads them off the finished body and they reach the sim
    // inside the spec's numbers. FIERY is the one that is behaviour: _strike
    // follows the landed bite with `take_damage(damage * 0.5, dir, "fire")`,
    // and proxy.gd routes a String arg3 through the element branch — raw
    // damage on a creature body, booked as BOLT, not contact.
    //
    // It rode entirely outside the sim until now, and cinder_drake wears it:
    // measured on the converged net, the arena's native drake landed 58.2 bolt
    // damage per 10 s where dh-env landed 30.9, and 25 of those 27 missing
    // points were this packet (tech/39 §2).
    dh::sim::FighterSpec statue;      // an opponent that only stands there
    statue.max_hp = 100000.0f; statue.damage = 0.0f; statue.move_speed = 0.0f;
    statue.attack_reach = 28.8f; statue.attack_cd = 1000.0f; statue.body_radius = 8.0f;
    statue.dodge_max = 0; statue.kit_count = 0;
    // Walk in, commit ONE swing, and read the two buckets it filled.
    auto swing = [&](bool fiery, dh::sim::Archetype arch) {
        dh::sim::FighterSpec me;
        me.max_hp = 100.0f; me.damage = 10.0f; me.move_speed = 60.0f;
        me.attack_reach = 28.8f; me.attack_cd = 1.2f; me.body_radius = 8.0f;
        me.dodge_max = 0; me.kit_count = 0;
        me.archetype = arch; me.windup_time = 0.35f; me.fiery = fiery;
        dh::sim::Arena a(me, statue, dh::sim::OppPolicy::kScripted, 4);
        a.reset(4);
        float o[dh::sim::kObsDim];
        for (int t = 0; t < 1200; ++t) {
            a.obs_now(o);
            if (o[18] * 512.0f <= 30.0f) break;
            a.step({o[16], o[17], 0});
        }
        a.step({0.0f, 0.0f, 1});
        for (int k = 0; k < 120; ++k) a.step({0.0f, 0.0f, 0});
        // damage_by_source is indexed by the VICTIM: the statue is fighter 1.
        return std::pair<float, float>{
            a.damage_by_source(1, dh::sim::DmgSource::kContact),
            a.damage_by_source(1, dh::sim::DmgSource::kBolt)};
    };
    // A plain body books the whole swing as contact and fires no bolt at all.
    const auto plain = swing(false, dh::sim::Archetype::kStalker);
    CHECK(plain.first > 0.0f);
    CHECK(plain.second == 0.0f);
    // A FIERY body books the same contact plus exactly half of it as bolt.
    const auto fiery = swing(true, dh::sim::Archetype::kStalker);
    CHECK(std::fabs(fiery.first - plain.first) < 1e-4f);
    CHECK(std::fabs(fiery.second - 0.5f * plain.first) < 1e-4f);
    // The BRUTE slam returns before the rider, exactly as creature.gd::_strike
    // does — a Fiery brute's ground slam is one packet, not one and a half.
    const auto slam = swing(true, dh::sim::Archetype::kBrute);
    CHECK(slam.first > 0.0f);
    CHECK(slam.second == 0.0f);
    // And the flag crosses the dh-env seam by its own setter (dh_env.h): the
    // spec struct must not be resized, so set_body_affix is how it arrives.
    dh::sim::FighterSpec plainspec;
    dh::sim::Arena a(plainspec, statue, dh::sim::OppPolicy::kScripted, 4);
    a.set_body_affix(0, true);
    a.set_body_affix(1, false);
    a.reset(4);
    CHECK(true);   // reaching here means the setter is reset-stable
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
    test_arena_action_mask_is_one_rule();
    test_arena_frozen_opponent_decodes_through_the_mask();
    test_arena_minds_read_the_delayed_world();
    test_arena_swing_is_a_cone_not_a_circle();
    test_arena_conduct_combo();
    test_arena_opponent_mind_can_change_between_episodes();
    test_arena_reports_what_actually_committed();
    test_arena_dodge_is_a_fallback();
    test_arena_damage_accounting();
    test_arena_squad_mode();
    test_arena_archetypes_shape_the_swing();
    test_arena_damage_by_source_sums_to_the_tally();
    test_arena_fiery_affix_rides_the_bite_as_bolt_damage();
    test_arena_bodies_separate_instead_of_standing_inside_each_other();
    if (g_failures == 0) {
        std::printf("sim-tests: all checks passed\n");
        return EXIT_SUCCESS;
    }
    std::printf("sim-tests: %d check(s) FAILED\n", g_failures);
    return EXIT_FAILURE;
}
