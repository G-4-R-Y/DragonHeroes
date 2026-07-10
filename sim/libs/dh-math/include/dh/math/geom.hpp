#pragma once
#include <algorithm>
#include <optional>

#include "vec2.hpp"

// Combat geometry on the flat 2D simulation plane (canon §1, §6): bodies are circles
// or capsules, melee is swept arcs, projectiles are swept circles (CCD). z-height
// gating happens above this layer — these tests are pure plane geometry.
namespace dh::math {

inline bool circle_overlap(Vec2 a, float ra, Vec2 b, float rb) {
    const float r = ra + rb;
    return (b - a).length_sq() <= r * r;
}

// Closest point on segment [p0,p1] to point q — the core of capsule tests.
inline Vec2 closest_point_on_segment(Vec2 p0, Vec2 p1, Vec2 q) {
    const Vec2 d = p1 - p0;
    const float len_sq = d.length_sq();
    if (len_sq <= 0.0f) return p0;
    const float t = std::clamp((q - p0).dot(d) / len_sq, 0.0f, 1.0f);
    return p0 + d * t;
}

// Capsule (segment p0..p1 with radius rc) vs circle.
inline bool capsule_circle_overlap(Vec2 p0, Vec2 p1, float rc, Vec2 c, float r) {
    const Vec2 cp = closest_point_on_segment(p0, p1, c);
    return circle_overlap(cp, rc, c, r);
}

// Swept circle vs static circle (projectile CCD): a circle of radius `r_moving`
// travels from `from` by `delta` this tick; returns the earliest hit time t in [0,1]
// against a static circle at `center` with radius `r_static`, or nullopt on miss.
inline std::optional<float> swept_circle_hit(Vec2 from, Vec2 delta, float r_moving,
                                             Vec2 center, float r_static) {
    const Vec2 m = from - center;
    const float r = r_moving + r_static;
    const float b = m.dot(delta);
    const float c = m.length_sq() - r * r;
    if (c <= 0.0f) return 0.0f;          // already overlapping at tick start
    if (b >= 0.0f) return std::nullopt;  // moving away
    const float a = delta.length_sq();
    if (a <= 0.0f) return std::nullopt;  // not moving
    const float disc = b * b - a * c;
    if (disc < 0.0f) return std::nullopt;
    const float t = (-b - std::sqrt(disc)) / a;
    if (t < 0.0f || t > 1.0f) return std::nullopt;
    return t;
}

// Melee arc test: is `target` inside the arc centered at `origin`, facing `facing`
// (unit vector), with angular half-width `cos_half_angle` (pass cos(θ/2)) and reach?
inline bool arc_contains(Vec2 origin, Vec2 facing, float cos_half_angle, float reach,
                         Vec2 target, float target_radius) {
    const Vec2 to = target - origin;
    const float max_d = reach + target_radius;
    if (to.length_sq() > max_d * max_d) return false;
    const Vec2 dir = to.normalized_or_zero();
    if (dir.length_sq() == 0.0f) return true;  // on top of the origin
    return dir.dot(facing) >= cos_half_angle;
}

} // namespace dh::math
