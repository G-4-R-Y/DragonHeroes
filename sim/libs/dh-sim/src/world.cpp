#include <dh/sim/world.hpp>

#include <bit>

#include <dh/math/hash.hpp>

namespace dh::sim {

World::World(std::uint64_t seed) : ai_rng_(seed, /*stream=*/1) {}

EntityId World::spawn_creature(math::Vec2 position, float radius, float hp) {
    const EntityId id = entities_.create();
    entities_.pos[id.index] = position;
    entities_.vel[id.index] = {};
    entities_.radius[id.index] = radius;
    entities_.z_height[id.index] = 0.0f;
    entities_.hp[id.index] = hp;
    return id;
}

void World::step() {
    // Placeholder wander "AI": each creature occasionally re-rolls a direction from
    // the AI stream, then movement integrates. Real systems replace this in M1; the
    // point today is a deterministic, measurable tick.
    const std::uint32_t n = entities_.capacity();
    for (std::uint32_t i = 0; i < n; ++i) {
        if (!entities_.slot_alive(i)) continue;
        if (ai_rng_.next_bounded(kTickRate) == 0) {  // ~once per second
            const float angle = ai_rng_.next_float() * 6.2831853f;
            const float speed = 1.0f + ai_rng_.next_float() * 2.0f;  // 1–3 m/s
            entities_.vel[i] = {std::cos(angle) * speed, std::sin(angle) * speed};
        }
    }
    for (std::uint32_t i = 0; i < n; ++i) {
        if (!entities_.slot_alive(i)) continue;
        entities_.pos[i] += entities_.vel[i] * kTickDt;
    }
    ++tick_;
}

std::uint64_t World::state_hash() const {
    // FNV-1a over live entity state — the replay/determinism fingerprint.
    std::uint64_t h = 0xcbf29ce484222325ULL;
    const auto mix = [&h](std::uint64_t v) {
        h ^= v;
        h *= 0x100000001b3ULL;
    };
    mix(tick_);
    const std::uint32_t n = entities_.capacity();
    for (std::uint32_t i = 0; i < n; ++i) {
        if (!entities_.slot_alive(i)) continue;
        mix(std::bit_cast<std::uint32_t>(entities_.pos[i].x));
        mix(std::bit_cast<std::uint32_t>(entities_.pos[i].y));
        mix(std::bit_cast<std::uint32_t>(entities_.hp[i]));
    }
    return h;
}

} // namespace dh::sim
