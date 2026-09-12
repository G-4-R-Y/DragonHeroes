// REBIRTH / native — CPU geometry: the valley heightfield (same bowl formula as
// godot3d/scripts/valley.gd), a tiny mesh builder for placeholders/telegraph
// shapes, and the .dhm loader (rebirth/assets/tools/glb_to_dhm.py output).
#pragma once
#include "sim.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace rb {

struct Vertex { float px, py, pz, nx, ny, nz, r, g, b; };

struct MeshData {
    std::vector<Vertex> verts;
    std::vector<uint32_t> idx;
    void tri(Vec3 a, Vec3 b, Vec3 c, Vec3 col);
    void quad(Vec3 a, Vec3 b, Vec3 c, Vec3 d, Vec3 col);
    void box(Vec3 center, Vec3 size, Vec3 col, float yaw = 0.f);
    void ellipsoid(Vec3 center, Vec3 radii, Vec3 col, int seg = 10, int rings = 6);
    void append(const MeshData& o, Vec3 offset, float scale = 1.f);
};

class Valley final : public Heightfield {
public:
    static constexpr float kSize = 180.f, kBowlR = 30.f, kRimH = 22.f;
    static constexpr int kGrid = 84;
    float height_at(float x, float z) const override;
    float bowl_radius() const override { return kBowlR; }
    Vec3 normal_at(float x, float z) const;
    Vec3 color_at(float x, float z, float h) const;
    MeshData terrain() const;
    MeshData rocks(uint32_t seed = 7, int count = 160) const;
    struct Prop { Vec3 pos; Vec3 color; float range, energy; bool pit; };
    std::vector<Prop> lights(uint32_t seed = 7) const;   // glowshrooms + fire pits
    MeshData props(const std::vector<Prop>& lights) const;  // emissive shroom caps + pit discs
private:
    float noise(float x, float z) const;   // fbm value noise, [-1,1]
};

// Placeholder creatures when no .dhm is present (mirrors make_placeholder_glb.py).
MeshData placeholder_dragon();
MeshData placeholder_hunter();
MeshData placeholder_pet();

// Unit shapes for telegraphs/vfx (XZ plane, forward -Z).
MeshData unit_ring(int segs = 64, float thickness = 0.06f);
MeshData unit_sector(float half_deg, int segs = 16);
MeshData unit_disc(int segs = 32);
MeshData unit_sphere(int seg = 12, int rings = 8);

bool load_dhm(const std::string& path, MeshData& out);

} // namespace rb
