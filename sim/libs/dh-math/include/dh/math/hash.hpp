#pragma once
#include <cstdint>

// Stateless integer hashing for procgen's constant-time random access contract
// (docs/tech/24): same seed + coordinates → same output, no sequential draws, and —
// because it is pure integer math — bit-exact across platforms and compilers.
namespace dh::math {

constexpr std::uint64_t splitmix64(std::uint64_t x) {
    x += 0x9e3779b97f4a7c15ULL;
    x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9ULL;
    x = (x ^ (x >> 27)) * 0x94d049bb133111ebULL;
    return x ^ (x >> 31);
}

// Hash a (seed, x, y[, channel]) tuple to 64 bits. `channel` separates independent
// procgen layers (elevation, climate, POI...) drawn at the same coordinates.
constexpr std::uint64_t hash_coords(std::uint64_t seed, std::int64_t x, std::int64_t y,
                                    std::uint64_t channel = 0) {
    std::uint64_t h = splitmix64(seed ^ (channel * 0x9e3779b97f4a7c15ULL));
    h = splitmix64(h ^ static_cast<std::uint64_t>(x));
    h = splitmix64(h ^ static_cast<std::uint64_t>(y));
    return h;
}

// Uniform float in [0, 1) from a hash — for value-noise lattices.
constexpr float hash_to_unit_float(std::uint64_t h) {
    return static_cast<float>(h >> 40) * (1.0f / 16777216.0f);
}

} // namespace dh::math
