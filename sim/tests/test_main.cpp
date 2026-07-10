// Minimal dependency-free test runner for the sim workspace. Grows with the crates;
// once the suite gets serious (golden replays, fuzzing — docs/tech/21 §8) we revisit
// adopting a framework. Every test here guards a canon contract.
#include <cstdio>
#include <cstdlib>

#include <dh/math/geom.hpp>
#include <dh/math/hash.hpp>
#include <dh/net/quantize.hpp>
#include <dh/procgen/chunk.hpp>
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

int main() {
    test_entity_generational_ids();
    test_world_determinism();
    test_geometry();
    test_procgen_determinism();
    test_quantization();
    if (g_failures == 0) {
        std::printf("sim-tests: all checks passed\n");
        return EXIT_SUCCESS;
    }
    std::printf("sim-tests: %d check(s) FAILED\n", g_failures);
    return EXIT_FAILURE;
}
