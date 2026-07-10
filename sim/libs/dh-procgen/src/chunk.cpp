#include <dh/procgen/chunk.hpp>

#include <dh/math/hash.hpp>

namespace dh::procgen {
namespace {

// Value noise on an integer lattice with bilinear interpolation. Lattice values come
// from stateless coordinate hashing, so any point is computable in isolation
// (constant-time random access — no neighbor dependency chains).
float value_noise(std::uint64_t seed, std::uint64_t channel, float x, float y,
                  float cell_size) {
    const float fx = x / cell_size;
    const float fy = y / cell_size;
    const auto x0 = static_cast<std::int64_t>(fx >= 0 ? fx : fx - 1.0f);
    const auto y0 = static_cast<std::int64_t>(fy >= 0 ? fy : fy - 1.0f);
    const float tx = fx - static_cast<float>(x0);
    const float ty = fy - static_cast<float>(y0);

    const auto lattice = [&](std::int64_t lx, std::int64_t ly) {
        return dh::math::hash_to_unit_float(dh::math::hash_coords(seed, lx, ly, channel));
    };
    const float v00 = lattice(x0, y0);
    const float v10 = lattice(x0 + 1, y0);
    const float v01 = lattice(x0, y0 + 1);
    const float v11 = lattice(x0 + 1, y0 + 1);

    // Smoothstep fade for C1 continuity at lattice edges.
    const float sx = tx * tx * (3.0f - 2.0f * tx);
    const float sy = ty * ty * (3.0f - 2.0f * ty);
    const float a = v00 + (v10 - v00) * sx;
    const float b = v01 + (v11 - v01) * sx;
    return a + (b - a) * sy;
}

} // namespace

Chunk generate_chunk(std::uint64_t world_seed, std::int64_t cx, std::int64_t cy) {
    Chunk chunk;
    chunk.cx = cx;
    chunk.cy = cy;

    // M0 placeholder stack: one elevation channel + one moisture channel classified
    // into four tiles. The real layered stack (climate, domain-warped Voronoi biomes,
    // features, POIs — docs/tech/24 §3) replaces this classification, keeping the
    // same deterministic access pattern.
    constexpr std::uint64_t kElevation = 1;
    constexpr std::uint64_t kMoisture = 2;
    for (std::int32_t ty = 0; ty < kChunkSize; ++ty) {
        for (std::int32_t tx = 0; tx < kChunkSize; ++tx) {
            const float wx = static_cast<float>(cx * kChunkSize + tx);
            const float wy = static_cast<float>(cy * kChunkSize + ty);
            const float elev = 0.65f * value_noise(world_seed, kElevation, wx, wy, 48.0f) +
                               0.35f * value_noise(world_seed, kElevation + 16, wx, wy, 12.0f);
            const float moist = value_noise(world_seed, kMoisture, wx, wy, 64.0f);

            Tile tile = Tile::Grass;
            if (elev < 0.35f) tile = Tile::Water;
            else if (elev > 0.78f) tile = Tile::Rock;
            else if (moist > 0.55f) tile = Tile::Forest;
            chunk.tiles[static_cast<std::size_t>(ty) * kChunkSize +
                        static_cast<std::size_t>(tx)] = static_cast<std::uint16_t>(tile);
        }
    }
    return chunk;
}

} // namespace dh::procgen
