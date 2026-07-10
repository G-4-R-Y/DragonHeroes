#pragma once
#include <array>
#include <cstdint>

// dh-procgen (docs/tech/24): infinite, seeded, deterministic, constant-time random
// access — same seed + chunk coords → byte-identical chunk, forever, on every
// platform. All randomness is stateless integer hashing (dh/math/hash.hpp).
namespace dh::procgen {

inline constexpr std::int32_t kChunkSize = 64;  // 64×64 tiles, 1 tile = 1 m (canon §4)

// Every chunk records the generator version that produced it; weekly world drops
// bump the version and only ever apply to virgin space (docs/tech/24 §5).
inline constexpr std::uint32_t kGeneratorVersion = 1;

enum class Tile : std::uint16_t {
    Water = 0,
    Grass = 1,
    Forest = 2,
    Rock = 3,
};

struct Chunk {
    std::int64_t cx = 0;
    std::int64_t cy = 0;
    std::uint32_t generator_version = kGeneratorVersion;
    std::array<std::uint16_t, kChunkSize * kChunkSize> tiles{};

    std::uint16_t tile_at(std::int32_t x, std::int32_t y) const {
        return tiles[static_cast<std::size_t>(y) * kChunkSize + static_cast<std::size_t>(x)];
    }
};

// Generates the base (pre-delta) chunk at (cx, cy) for `world_seed`.
Chunk generate_chunk(std::uint64_t world_seed, std::int64_t cx, std::int64_t cy);

} // namespace dh::procgen
