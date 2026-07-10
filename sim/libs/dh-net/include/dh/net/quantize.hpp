#pragma once
#include <cstdint>

#include <dh/math/vec2.hpp>

// dh-net (docs/tech/22): byte-packed delta snapshots at 20 Hz. M0 scope: the
// quantization primitives the wire format is built on. The snapshot encoder/decoder,
// delta baselines, and ENet transport land in M2.
namespace dh::net {

// Positions travel as millimeter-precision i32 (±2,147 km of world — plenty for the
// per-zone local coordinates snapshots actually carry).
struct QuantizedPos {
    std::int32_t x_mm = 0;
    std::int32_t y_mm = 0;
};

inline QuantizedPos quantize(math::Vec2 p) {
    return {static_cast<std::int32_t>(p.x * 1000.0f),
            static_cast<std::int32_t>(p.y * 1000.0f)};
}

inline math::Vec2 dequantize(QuantizedPos q) {
    return {static_cast<float>(q.x_mm) * 0.001f, static_cast<float>(q.y_mm) * 0.001f};
}

} // namespace dh::net
