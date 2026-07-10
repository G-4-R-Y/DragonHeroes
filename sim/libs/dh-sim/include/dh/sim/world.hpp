#pragma once
#include <cstdint>

#include <dh/math/rng.hpp>
#include <dh/sim/entity_store.hpp>

namespace dh::sim {

// Canon §6: fixed 30 Hz tick; tick count is the only clock inside the sim.
inline constexpr std::uint32_t kTickRate = 30;
inline constexpr float kTickDt = 1.0f / static_cast<float>(kTickRate);

// M0 skeleton of the authoritative world. The full ordered tick pipeline
// (input → AI → movement → combat → projectiles → fields → status → events →
// snapshot, docs/tech/21 §3) grows system by system; today it integrates movement
// and proves the determinism contract end to end (replay hash, golden tests).
class World {
public:
    explicit World(std::uint64_t seed);

    EntityId spawn_creature(math::Vec2 position, float radius, float hp);

    // Advances exactly one 30 Hz tick. Deterministic: same seed + same call
    // sequence → bit-identical state (enforced by sim-tests).
    void step();

    std::uint64_t tick() const { return tick_; }
    std::uint64_t state_hash() const;

    EntityStore& entities() { return entities_; }
    const EntityStore& entities() const { return entities_; }

private:
    EntityStore entities_;
    math::Pcg32 ai_rng_;   // per-system stream (docs/tech/21 determinism rules)
    std::uint64_t tick_ = 0;
};

} // namespace dh::sim
