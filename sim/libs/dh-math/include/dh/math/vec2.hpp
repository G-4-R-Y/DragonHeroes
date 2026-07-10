#pragma once
#include <cmath>

namespace dh::math {

// Simulation-plane vector. Units are meters (1 tile = 1 m, canon §4).
struct Vec2 {
    float x = 0.0f;
    float y = 0.0f;

    constexpr Vec2 operator+(Vec2 o) const { return {x + o.x, y + o.y}; }
    constexpr Vec2 operator-(Vec2 o) const { return {x - o.x, y - o.y}; }
    constexpr Vec2 operator*(float s) const { return {x * s, y * s}; }
    constexpr Vec2& operator+=(Vec2 o) { x += o.x; y += o.y; return *this; }

    constexpr float dot(Vec2 o) const { return x * o.x + y * o.y; }
    constexpr float length_sq() const { return x * x + y * y; }
    float length() const { return std::sqrt(length_sq()); }

    Vec2 normalized_or_zero() const {
        const float len_sq = length_sq();
        if (len_sq <= 0.0f) return {};
        const float inv = 1.0f / std::sqrt(len_sq);
        return {x * inv, y * inv};
    }
};

} // namespace dh::math
