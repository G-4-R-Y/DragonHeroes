#pragma once
#include <cstdint>

// Determinism canon (docs/tech/21): every sim system draws from its own seeded PCG
// stream; no global RNG, no wall clock. dh-procgen additionally uses only stateless
// integer hashing (hash.hpp) for constant-time random access.
namespace dh::math {

// PCG32 (O'Neill) — small, fast, statistically solid, trivially serializable.
class Pcg32 {
public:
    constexpr Pcg32() = default;
    constexpr Pcg32(std::uint64_t seed, std::uint64_t stream) { reseed(seed, stream); }

    constexpr void reseed(std::uint64_t seed, std::uint64_t stream) {
        state_ = 0u;
        inc_ = (stream << 1u) | 1u;
        next_u32();
        state_ += seed;
        next_u32();
    }

    constexpr std::uint32_t next_u32() {
        const std::uint64_t old = state_;
        state_ = old * 6364136223846793005ULL + inc_;
        const auto xorshifted = static_cast<std::uint32_t>(((old >> 18u) ^ old) >> 27u);
        const auto rot = static_cast<std::uint32_t>(old >> 59u);
        return (xorshifted >> rot) | (xorshifted << ((32u - rot) & 31u));
    }

    // Uniform in [0, bound) without modulo bias (Lemire).
    constexpr std::uint32_t next_bounded(std::uint32_t bound) {
        const std::uint64_t m = static_cast<std::uint64_t>(next_u32()) * bound;
        return static_cast<std::uint32_t>(m >> 32u);
    }

    // Uniform float in [0, 1).
    constexpr float next_float() {
        return static_cast<float>(next_u32() >> 8u) * (1.0f / 16777216.0f);
    }

    constexpr std::uint64_t state() const { return state_; }

private:
    std::uint64_t state_ = 0x853c49e6748fea9bULL;
    std::uint64_t inc_ = 0xda3e39cb94b95bdbULL;
};

} // namespace dh::math
