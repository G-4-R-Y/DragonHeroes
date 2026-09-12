#include "geometry.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>

namespace rb {

namespace {
constexpr float kPi = 3.14159265358979f;
Vec3 cross(Vec3 a, Vec3 b) { return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}; }
Vec3 norm(Vec3 v) { float l = length(v); return l < 1e-8f ? Vec3{0, 1, 0} : v * (1.f / l); }
float smoothstep(float a, float b, float x) { float t = std::clamp((x - a) / (b - a), 0.f, 1.f); return t * t * (3.f - 2.f * t); }
float lerpf(float a, float b, float t) { return a + (b - a) * t; }
uint32_t hash2(int32_t x, int32_t y, uint32_t seed) {
    uint32_t h = static_cast<uint32_t>(x) * 374761393u + static_cast<uint32_t>(y) * 668265263u + seed * 2246822519u;
    h = (h ^ (h >> 13)) * 1274126177u;
    return h ^ (h >> 16);
}
float value_noise(float x, float z, uint32_t seed) {
    int xi = static_cast<int>(std::floor(x)), zi = static_cast<int>(std::floor(z));
    float fx = x - xi, fz = z - zi;
    fx = fx * fx * (3.f - 2.f * fx); fz = fz * fz * (3.f - 2.f * fz);
    auto v = [&](int a, int b) { return (hash2(a, b, seed) & 0xFFFF) / 32767.5f - 1.f; };
    float a = lerpf(v(xi, zi), v(xi + 1, zi), fx);
    float b = lerpf(v(xi, zi + 1), v(xi + 1, zi + 1), fx);
    return lerpf(a, b, fz);
}
struct Lcg {
    uint32_t s;
    float next() { s = s * 1664525u + 1013904223u; return (s >> 8) * (1.0f / 16777216.0f); }
    float range(float a, float b) { return a + (b - a) * next(); }
};
} // namespace

// --- MeshData ------------------------------------------------------------------------------

void MeshData::tri(Vec3 a, Vec3 b, Vec3 c, Vec3 col) {
    Vec3 n = norm(cross(b - a, c - a));
    uint32_t base = static_cast<uint32_t>(verts.size());
    for (Vec3 p : {a, b, c}) verts.push_back({p.x, p.y, p.z, n.x, n.y, n.z, col.x, col.y, col.z});
    idx.insert(idx.end(), {base, base + 1, base + 2});
}
void MeshData::quad(Vec3 a, Vec3 b, Vec3 c, Vec3 d, Vec3 col) { tri(a, b, c, col); tri(a, c, d, col); }
void MeshData::box(Vec3 c, Vec3 s, Vec3 col, float yaw) {
    float sx = s.x / 2, sy = s.y / 2, sz = s.z / 2, cs = std::cos(yaw), sn = std::sin(yaw);
    auto p = [&](float x, float y, float z) { return Vec3{c.x + x * cs + z * sn, c.y + y, c.z - x * sn + z * cs}; };
    Vec3 v[8] = {p(-sx, -sy, -sz), p(sx, -sy, -sz), p(sx, sy, -sz), p(-sx, sy, -sz), p(-sx, -sy, sz), p(sx, -sy, sz), p(sx, sy, sz), p(-sx, sy, sz)};
    quad(v[0], v[3], v[2], v[1], col); quad(v[4], v[5], v[6], v[7], col); quad(v[0], v[4], v[7], v[3], col);
    quad(v[1], v[2], v[6], v[5], col); quad(v[3], v[7], v[6], v[2], col); quad(v[0], v[1], v[5], v[4], col);
}
void MeshData::ellipsoid(Vec3 c, Vec3 r, Vec3 col, int seg, int rings) {
    std::vector<std::vector<Vec3>> g(rings + 1, std::vector<Vec3>(seg));
    for (int i = 0; i <= rings; ++i) {
        float phi = kPi * i / rings;
        for (int j = 0; j < seg; ++j) {
            float th = 2 * kPi * j / seg;
            g[i][j] = {c.x + r.x * std::sin(phi) * std::cos(th), c.y + r.y * std::cos(phi), c.z + r.z * std::sin(phi) * std::sin(th)};
        }
    }
    for (int i = 0; i < rings; ++i)
        for (int j = 0; j < seg; ++j) quad(g[i][j], g[i + 1][j], g[i + 1][(j + 1) % seg], g[i][(j + 1) % seg], col);
}
void MeshData::append(const MeshData& o, Vec3 off, float scale) {
    uint32_t base = static_cast<uint32_t>(verts.size());
    for (Vertex v : o.verts) { v.px = v.px * scale + off.x; v.py = v.py * scale + off.y; v.pz = v.pz * scale + off.z; verts.push_back(v); }
    for (uint32_t i : o.idx) idx.push_back(base + i);
}

// --- Valley ------------------------------------------------------------------------------------

float Valley::noise(float x, float z) const {
    float sum = 0, amp = 1, freq = 0.035f, tot = 0;
    for (int o = 0; o < 4; ++o) { sum += value_noise(x * freq, z * freq, 7u + o) * amp; tot += amp; amp *= 0.5f; freq *= 2.f; }
    return sum / tot;
}
float Valley::height_at(float x, float z) const {
    float r = std::sqrt(x * x + z * z);
    float rim = smoothstep(kBowlR, kBowlR + 28.f, r) * kRimH;
    float amp = lerpf(0.12f, 4.5f, smoothstep(kBowlR - 6.f, kBowlR + 20.f, r));
    return rim + noise(x, z) * amp;
}
Vec3 Valley::normal_at(float x, float z) const {
    float e = 0.5f;
    return norm({height_at(x - e, z) - height_at(x + e, z), 2.f * e, height_at(x, z - e) - height_at(x, z + e)});
}
Vec3 Valley::color_at(float x, float z, float h) const {
    float r = std::sqrt(x * x + z * z);
    Vec3 earth{0.17f, 0.135f, 0.11f}, scorch{0.11f, 0.09f, 0.085f}, moss{0.10f, 0.16f, 0.09f}, rock{0.23f, 0.22f, 0.25f};
    Vec3 c = lerp(earth, scorch, std::clamp(1.f - r / 12.f, 0.f, 1.f) * 0.7f);
    c = lerp(c, moss, smoothstep(kBowlR - 4.f, kBowlR + 10.f, r));
    c = lerp(c, rock, smoothstep(6.f, 16.f, h));
    float v = value_noise(x * 0.11f + 100.f, z * 0.11f, 99u) * 0.06f;
    return c + Vec3{v, v, v};
}
MeshData Valley::terrain() const {
    MeshData m;
    const int n = kGrid;
    float cell = kSize / n;
    for (int i = 0; i <= n; ++i)
        for (int j = 0; j <= n; ++j) {
            float x = -kSize / 2 + i * cell, z = -kSize / 2 + j * cell, h = height_at(x, z);
            Vec3 nn = normal_at(x, z), c = color_at(x, z, h);
            m.verts.push_back({x, h, z, nn.x, nn.y, nn.z, c.x, c.y, c.z});
        }
    uint32_t w = n + 1;
    for (uint32_t i = 0; i < static_cast<uint32_t>(n); ++i)
        for (uint32_t j = 0; j < static_cast<uint32_t>(n); ++j) {
            uint32_t a = i * w + j, b = a + 1, c = a + w, d = c + 1;
            m.idx.insert(m.idx.end(), {a, b, c, b, d, c});
        }
    return m;
}
MeshData Valley::rocks(uint32_t seed, int count) const {
    MeshData m; Lcg rng{seed};
    for (int i = 0; i < count; ++i) {
        float ang = rng.next() * 2 * kPi, r = rng.range(kBowlR - 3.f, kBowlR + 34.f);
        float x = std::cos(ang) * r, z = std::sin(ang) * r;
        Vec3 s{rng.range(1.f, 4.5f), rng.range(0.8f, 3.5f), rng.range(1.f, 4.f)};
        float yaw = rng.next() * 2 * kPi;
        rng.next(); rng.next();
        m.box({x, height_at(x, z) + s.y * 0.25f, z}, s, {0.20f, 0.19f, 0.22f}, yaw);
    }
    return m;
}
std::vector<Valley::Prop> Valley::lights(uint32_t seed) const {
    std::vector<Prop> out; Lcg rng{seed + 3};
    for (int i = 0; i < 10; ++i) {
        float ang = (i / 10.f) * 2 * kPi + rng.range(-0.3f, 0.3f), r = rng.range(12.f, kBowlR - 2.f);
        Vec3 p{std::cos(ang) * r, 0, std::sin(ang) * r}; p.y = height_at(p.x, p.z);
        out.push_back({p, {0.25f, 0.9f, 0.8f}, 7.5f, 1.3f, false});
    }
    for (int i = 0; i < 4; ++i) {
        float ang = (i / 4.f) * 2 * kPi + 0.6f, r = 21.f;
        Vec3 p{std::cos(ang) * r, 0, std::sin(ang) * r}; p.y = height_at(p.x, p.z);
        out.push_back({p, {1.0f, 0.55f, 0.2f}, 13.f, 2.6f, true});
    }
    return out;
}
MeshData Valley::props(const std::vector<Prop>& ls) const {
    MeshData m; Lcg rng{41};
    for (const Prop& p : ls) {
        if (p.pit) {
            MeshData disc = unit_disc(24);
            for (auto& v : disc.verts) { v.r = 1.0f; v.g = 0.42f; v.b = 0.08f; }
            m.append(disc, p.pos + Vec3{0, 0.12f, 0}, 1.3f);
            m.box(p.pos + Vec3{0, 0.1f, 0}, {3.0f, 0.2f, 3.0f}, {0.12f, 0.08f, 0.06f});
        } else {
            for (int k = 0; k < 3; ++k) {
                Vec3 off{rng.range(-0.8f, 0.8f), 0.3f, rng.range(-0.8f, 0.8f)};
                float s = rng.range(0.6f, 1.2f);
                m.ellipsoid(p.pos + off, {0.35f * s, 0.35f * s, 0.35f * s}, {0.25f, 0.95f, 0.85f}, 8, 5);
            }
        }
    }
    return m;
}

// --- placeholders (mirror make_placeholder_glb.py) ----------------------------------------------

MeshData placeholder_dragon() {
    MeshData m;
    Vec3 hide{0.22f, 0.09f, 0.08f}, belly{0.45f, 0.26f, 0.13f}, wing{0.32f, 0.11f, 0.11f}, glow{1.f, 0.55f, 0.1f}, horn{0.1f, 0.09f, 0.09f};
    m.ellipsoid({0, 1.9f, 0.2f}, {1.35f, 1.2f, 3.1f}, hide, 14, 8);
    m.ellipsoid({0, 1.3f, -0.9f}, {1.05f, 0.8f, 1.7f}, belly, 10, 6);
    for (int k = 0; k < 5; ++k) { float t = k / 4.f; m.ellipsoid({0, 2.4f + t * 1.9f, -2.6f - t * 1.9f}, {0.6f - t * 0.12f, 0.6f - t * 0.12f, 0.7f}, hide, 8, 4); }
    m.box({0, 4.35f, -5.1f}, {1.1f, 0.9f, 2.2f}, hide);
    m.box({0, 4.05f, -6.0f}, {0.8f, 0.35f, 1.0f}, belly);
    for (float s : {-1.f, 1.f}) {
        m.ellipsoid({s * 0.45f, 4.55f, -5.75f}, {0.13f, 0.13f, 0.13f}, glow, 6, 3);
        m.box({s * 0.45f, 5.15f, -4.6f}, {0.2f, 1.1f, 0.2f}, horn);
        Vec3 root{s * 1.2f, 2.7f, -0.4f};
        Vec3 tips[4] = {{s * 6.6f, 3.9f, -2.4f}, {s * 7.4f, 3.4f, 0.2f}, {s * 6.4f, 3.0f, 2.6f}, {s * 3.4f, 2.4f, 3.2f}};
        for (int i = 0; i < 3; ++i) { m.tri(root, tips[i], tips[i + 1], wing); m.tri(root, tips[i + 1], tips[i], wing); }
        m.box({s * 1.1f, 0.75f, 1.6f}, {0.55f, 1.5f, 0.7f}, hide);
        m.box({s * 1.0f, 0.7f, -1.4f}, {0.45f, 1.4f, 0.6f}, hide);
    }
    for (int k = 0; k < 7; ++k) { float t = k / 6.f; m.ellipsoid({std::sin(t * 2.2f) * 0.8f, 1.7f - t * 0.9f, 3.0f + t * 4.2f}, {0.55f - t * 0.42f, 0.55f - t * 0.42f, 0.75f}, hide, 8, 4); }
    return m;
}
MeshData placeholder_hunter() {
    MeshData m;
    Vec3 leather{0.17f, 0.13f, 0.12f}, skin{0.62f, 0.48f, 0.38f}, steel{0.78f, 0.8f, 0.88f}, cloth{0.28f, 0.12f, 0.10f};
    m.ellipsoid({0, 1.05f, 0}, {0.33f, 0.55f, 0.24f}, leather, 10, 6);
    m.box({0, 0.35f, 0}, {0.42f, 0.7f, 0.3f}, cloth);
    m.ellipsoid({0, 1.78f, 0}, {0.19f, 0.2f, 0.19f}, skin, 8, 5);
    m.ellipsoid({0, 1.86f, 0.02f}, {0.23f, 0.17f, 0.24f}, leather, 8, 4);
    for (float s : {-1.f, 1.f}) { m.box({s * 0.42f, 1.15f, 0}, {0.16f, 0.7f, 0.16f}, leather); m.box({s * 0.14f, 0.f, 0}, {0.18f, 0.3f, 0.32f}, leather); }
    m.box({0.46f, 1.6f, -0.05f}, {0.07f, 1.15f, 0.03f}, steel);
    m.box({0.46f, 1.05f, -0.05f}, {0.3f, 0.05f, 0.07f}, steel);
    return m;
}
MeshData placeholder_pet() {
    MeshData m;
    Vec3 fur{0.33f, 0.30f, 0.37f}, dark{0.2f, 0.18f, 0.24f}, glow{0.4f, 1.f, 0.9f};
    m.ellipsoid({0, 0.55f, 0}, {0.3f, 0.3f, 0.6f}, fur, 10, 6);
    m.ellipsoid({0, 0.75f, -0.66f}, {0.24f, 0.22f, 0.26f}, fur, 8, 5);
    for (float s : {-1.f, 1.f}) {
        m.box({s * 0.13f, 1.0f, -0.62f}, {0.08f, 0.24f, 0.06f}, dark);
        m.ellipsoid({s * 0.09f, 0.78f, -0.86f}, {0.04f, 0.04f, 0.04f}, glow, 6, 3);
        m.box({s * 0.16f, 0.2f, 0.35f}, {0.12f, 0.4f, 0.12f}, dark);
        m.box({s * 0.16f, 0.2f, -0.35f}, {0.12f, 0.4f, 0.12f}, dark);
    }
    return m;
}

// --- unit shapes ---------------------------------------------------------------------------------

MeshData unit_ring(int segs, float thickness) {
    MeshData m; float ri = 1.f - thickness;
    for (int i = 0; i < segs; ++i) {
        float a0 = 2 * kPi * i / segs, a1 = 2 * kPi * (i + 1) / segs;
        Vec3 o0{std::cos(a0), 0, std::sin(a0)}, o1{std::cos(a1), 0, std::sin(a1)};
        m.quad(o0 * ri, o1 * ri, o1, o0, {1, 1, 1});
    }
    return m;
}
MeshData unit_sector(float half_deg, int segs) {
    MeshData m; float a0 = -half_deg * kPi / 180.f, a1 = half_deg * kPi / 180.f;
    for (int i = 0; i < segs; ++i) {
        float t0 = a0 + (a1 - a0) * i / segs, t1 = a0 + (a1 - a0) * (i + 1) / segs;
        m.tri({0, 0, 0}, {std::sin(t0), 0, -std::cos(t0)}, {std::sin(t1), 0, -std::cos(t1)}, {1, 1, 1});
    }
    return m;
}
MeshData unit_disc(int segs) {
    MeshData m;
    for (int i = 0; i < segs; ++i) {
        float a0 = 2 * kPi * i / segs, a1 = 2 * kPi * (i + 1) / segs;
        m.tri({0, 0, 0}, {std::cos(a1), 0, std::sin(a1)}, {std::cos(a0), 0, std::sin(a0)}, {1, 1, 1});
    }
    return m;
}
MeshData unit_sphere(int seg, int rings) { MeshData m; m.ellipsoid({0, 0, 0}, {1, 1, 1}, {1, 1, 1}, seg, rings); return m; }

// --- .dhm -------------------------------------------------------------------------------------------

bool load_dhm(const std::string& path, MeshData& out) {
    FILE* f = std::fopen(path.c_str(), "rb");
    if (!f) return false;
    char magic[4]; uint32_t nv = 0, ni = 0;
    bool ok = std::fread(magic, 1, 4, f) == 4 && std::memcmp(magic, "DHM1", 4) == 0 && std::fread(&nv, 4, 1, f) == 1 && std::fread(&ni, 4, 1, f) == 1;
    if (ok && nv < 5000000u && ni < 15000000u) {
        out.verts.resize(nv); out.idx.resize(ni);
        ok = std::fread(out.verts.data(), sizeof(Vertex), nv, f) == nv && std::fread(out.idx.data(), 4, ni, f) == ni;
    } else ok = false;
    std::fclose(f);
    if (!ok) { out.verts.clear(); out.idx.clear(); }
    return ok;
}

} // namespace rb
