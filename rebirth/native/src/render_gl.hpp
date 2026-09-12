// REBIRTH / native — the smallest 3D client: X11 window + GLX + OpenGL 3.3
// core, one lit shader (vertex colour, moon directional, up to 16 point lights
// — fire pits, glowshrooms, lantern, fire fields, meteors, enrage aura — fog,
// emissive), one unlit additive shader for telegraphs. No engine, no
// dependencies beyond libGL/libX11. Renders at display rate and interpolates
// the 30 Hz sim (CLAUDE.md #2). Windowed GL only: NEVER Vulkan from an agent
// shell (parent docs/harness/README.md).
#pragma once
#include "geometry.hpp"
#include "sim.hpp"

#include <array>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace rb {

struct KeyState {
    bool w = false, a = false, s = false, d = false;
    bool dodge = false, attack = false, skill = false, pet = false, lock = false, rematch = false, quit = false;
    float mouse_dx = 0, mouse_dy = 0;
    bool grab_request = false;
};

struct Camera {
    float yaw = 0, pitch = -0.30f, dist = 7.5f;
    Vec3 pos{}, focus{};
    bool started = false;
    void update(const State& s, float alpha, const Heightfield& hf, float dt, bool locked);
};

struct PointLight { Vec3 pos; Vec3 color; float range; };

class Renderer {
public:
    Renderer(int w, int h, const std::string& title);
    ~Renderer();
    Renderer(const Renderer&) = delete;
    Renderer& operator=(const Renderer&) = delete;
    bool ok() const { return ok_; }
    void poll(KeyState& keys);
    void upload_world(const Valley& v, const std::vector<Valley::Prop>& lights);
    void set_creatures(const MeshData& hunter, const MeshData& dragon, const MeshData& pet);
    void consume_events(State& s);        // drains s.events into VFX pools
    void frame(const State& s, float alpha, const Camera& cam, double time, float frame_dt);
    void swap();
    bool read_ppm(const std::string& path);
    int width() const { return w_; }
    int height() const { return h_; }
    int vfx_overflow() const { return overflow_; }
    std::string gl_renderer() const { return gl_renderer_; }
private:
    struct Impl;
    std::unique_ptr<Impl> p_;
    bool ok_ = false;
    int w_, h_;
    int overflow_ = 0;
    std::string gl_renderer_;
};

} // namespace rb
