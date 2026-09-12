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
    // step once with a kit cast: creature cooldown slots must light up (o[7..10])
    dh::sim::Action cast{0.0f, 0.0f, 3};
    arena.step(cast);
    arena.obs(o);
    CHECK(o[7] > 0.0f);
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

int main() {
    test_entity_generational_ids();
    test_world_determinism();
    test_geometry();
    test_procgen_determinism();
    test_quantization();
    test_arena_determinism();
    test_arena_terminates();
    test_arena_obs_schema();
    test_arena_conduct_combo();
    test_arena_squad_mode();
    if (g_failures == 0) {
        std::printf("sim-tests: all checks passed\n");
        return EXIT_SUCCESS;
    }
    std::printf("sim-tests: %d check(s) FAILED\n", g_failures);
    return EXIT_FAILURE;
}
