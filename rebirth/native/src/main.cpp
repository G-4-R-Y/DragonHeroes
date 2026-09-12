// REBIRTH / native — entry point.
//   rebirth-native --sim-only [--seconds S] [--verify] [--force-skill id]
//       headless gate: autopilot fight at 30 Hz, prints REBIRTH-NATIVE OK/FAIL,
//       steps/s and the state hash (--verify runs twice and compares hashes).
//   rebirth-native --capture <tag> [--frames N] [--force-skill id] [--size WxH]
//       windowed (X11/GLX/OpenGL 3.3), autopilot plays, writes captures/native_<tag>.ppm
//   rebirth-native [--autopilot]
//       play: WASD · Space dodge · J/LMB attack · K/RMB skill · E howl · Tab lock · R rematch · Esc
#include "geometry.hpp"
#include "sim.hpp"
#ifdef RB_WITH_GL
#include "render_gl.hpp"
#endif

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {
struct Args {
    bool sim_only = false, verify = false, autopilot = false;
    double seconds = 300.0;
    std::string capture, force, glb_dir;
    int frames = 240, w = 1280, h = 720;
};

rb::Skill parse_skill(const std::string& s) {
    if (s == "breath") return rb::Skill::Breath;
    if (s == "meteors") return rb::Skill::Meteors;
    if (s == "tail") return rb::Skill::Tail;
    if (s == "gust") return rb::Skill::Gust;
    if (s == "pounce") return rb::Skill::Pounce;
    return rb::Skill::Nil;
}

float lock_cam_yaw(const rb::State& s) {
    rb::Vec3 back = rb::normalize_xz(s.hunter.pos - s.dragon.pos);
    return std::atan2(back.x, back.z);
}

std::string used_list(const rb::State& s) {
    std::string out;
    for (size_t i = 1; i < s.dragon.used.size(); ++i)
        if (s.dragon.used[i] > 0) out += std::string(rb::skill_name(static_cast<rb::Skill>(i))) + ":" + std::to_string(s.dragon.used[i]) + " ";
    return out;
}

struct SimRun { rb::State s; uint64_t hash; double wall_s; uint64_t ticks; size_t events; };

SimRun run_sim(const Args& a, const rb::Valley& v) {
    SimRun r{};
    rb::reset_fight(r.s, v);
    r.s.force_next = parse_skill(a.force);
    auto t0 = std::chrono::steady_clock::now();
    while (r.s.time < a.seconds) {
        rb::Input in = rb::autopilot(r.s, lock_cam_yaw(r.s));
        rb::step(r.s, in, v);
        r.events += r.s.events.size();
        r.s.events.clear();
        if (rb::gate_missing(r.s).empty()) break;
    }
    r.wall_s = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
    r.ticks = r.s.tick;
    r.hash = rb::state_hash(r.s);
    return r;
}

int sim_only(const Args& a) {
    rb::Valley v;
    SimRun r = run_sim(a, v);
    const rb::State& s = r.s;
    std::string missing = rb::gate_missing(s);
    std::printf("rebirth-native: sim %.0fs in %.3fs wall · %llu ticks · %.0f ticks/s · %zu vfx events · hash %016llx\n",
        s.time, r.wall_s, static_cast<unsigned long long>(r.ticks), r.ticks / std::max(r.wall_s, 1e-9), r.events, static_cast<unsigned long long>(r.hash));
    if (a.verify) {
        SimRun r2 = run_sim(a, v);
        std::printf("rebirth-native: determinism %s (second run hash %016llx, %llu ticks)\n", r2.hash == r.hash && r2.ticks == r.ticks ? "OK" : "FAIL",
            static_cast<unsigned long long>(r2.hash), static_cast<unsigned long long>(r2.ticks));
        if (r2.hash != r.hash) missing += "determinism; ";
    }
    if (missing.empty()) {
        std::printf("REBIRTH-NATIVE OK — skills %s· enrage · iframe avoids %d · max combo %d · hits %d · dmg taken %.0f · kills %d · toast '%s' · rematch\n",
            used_list(s).c_str(), s.hunter.iframe_avoids, s.hunter.max_combo, s.hunter.hits, s.hunter.dmg_taken, s.kills, s.last_toast.c_str());
        return 0;
    }
    std::printf("REBIRTH-NATIVE FAIL — missing: %s· hunter hp %.0f dragon hp %.0f kills %d skills %s\n", missing.c_str(), s.hunter.hp, s.dragon.hp, s.kills, used_list(s).c_str());
    return 1;
}

void load_creature(const std::string& dir, const char* name, rb::MeshData& out, rb::MeshData (*fallback)()) {
    std::string path = dir + "/" + name + ".dhm";
    if (rb::load_dhm(path, out)) { std::printf("rebirth-native: loaded %s (%zu tris)\n", path.c_str(), out.idx.size() / 3); return; }
    out = fallback();
    std::printf("rebirth-native: %s.dhm not found in %s — code-built placeholder (%zu tris)\n", name, dir.c_str(), out.idx.size() / 3);
}
} // namespace

int main(int argc, char** argv) {
    Args a;
    const char* env_dir = std::getenv("REBIRTH_GLB_DIR");
    a.glb_dir = env_dir ? env_dir : RB_ASSET_DIR;
    for (int i = 1; i < argc; ++i) {
        std::string s = argv[i];
        auto next = [&]() -> std::string { return i + 1 < argc ? argv[++i] : ""; };
        if (s == "--sim-only") a.sim_only = true;
        else if (s == "--verify") a.verify = true;
        else if (s == "--autopilot") a.autopilot = true;
        else if (s == "--seconds") a.seconds = std::atof(next().c_str());
        else if (s == "--capture") a.capture = next();
        else if (s == "--frames") a.frames = std::atoi(next().c_str());
        else if (s == "--force-skill") a.force = next();
        else if (s == "--glb-dir") a.glb_dir = next();
        else if (s == "--size") { std::string v = next(); if (std::sscanf(v.c_str(), "%dx%d", &a.w, &a.h) != 2) { std::fprintf(stderr, "bad --size\n"); return 2; } }
        else { std::fprintf(stderr, "unknown arg %s\n", s.c_str()); return 2; }
    }
    if (a.sim_only) return sim_only(a);
#ifndef RB_WITH_GL
    std::fprintf(stderr, "built without GL (REBIRTH_WITH_GL=OFF); use --sim-only\n");
    return 2;
#else
    rb::Valley v;
    rb::State s;
    rb::reset_fight(s, v);
    s.force_next = parse_skill(a.force);
    bool autopilot = a.autopilot || !a.capture.empty();
    rb::Renderer r(a.w, a.h, "Dragon Heroes: Rebirth (native)");
    if (!r.ok()) { std::fprintf(stderr, "rebirth-native: no GL window (need an X11 display + OpenGL 3.3); use --sim-only\n"); return 2; }
    std::printf("rebirth-native: %s · %dx%d · sim %.0f Hz · mode %s\n", r.gl_renderer().c_str(), r.width(), r.height(), rb::kTickHz, autopilot ? (a.capture.empty() ? "autopilot" : "capture") : "play");
    r.upload_world(v, v.lights());
    rb::MeshData mh, md, mp;
    load_creature(a.glb_dir, "hunter", mh, rb::placeholder_hunter);
    load_creature(a.glb_dir, "dragon", md, rb::placeholder_dragon);
    load_creature(a.glb_dir, "pet", mp, rb::placeholder_pet);
    r.set_creatures(mh, md, mp);
    rb::Camera cam;
    cam.yaw = lock_cam_yaw(s);
    rb::KeyState keys;
    using clock = std::chrono::steady_clock;
    auto last = clock::now();
    double acc = 0, sim_time = 0;
    std::vector<double> frame_ms;
    frame_ms.reserve(100000);
    int frames = 0, slow = 0;
    int rc = 0;
    while (!keys.quit) {
        auto now = clock::now();
        double dt = std::chrono::duration<double>(now - last).count();
        last = now;
        dt = std::min(dt, 0.25);
        r.poll(keys);
        acc += dt;
        int steps = 0;
        while (acc >= rb::kDt && steps < 5) {
            rb::Input in;
            if (autopilot) in = rb::autopilot(s, cam.yaw);
            else {
                in.move_x = (keys.d ? 1.f : 0.f) - (keys.a ? 1.f : 0.f);
                in.move_y = (keys.w ? 1.f : 0.f) - (keys.s ? 1.f : 0.f);
                in.dodge = keys.dodge; in.attack = keys.attack; in.skill = keys.skill; in.pet = keys.pet; in.lock = keys.lock; in.rematch = keys.rematch;
                in.cam_yaw = cam.yaw;
                keys.dodge = keys.attack = keys.skill = keys.pet = keys.lock = keys.rematch = false;
            }
            rb::step(s, in, v);
            r.consume_events(s);
            acc -= rb::kDt; sim_time += rb::kDt; steps++;
        }
        if (steps == 5) acc = 0;   // hitch: drop time rather than spiral
        if (!autopilot) { cam.yaw -= keys.mouse_dx * 0.0035f; cam.pitch = std::clamp(cam.pitch - keys.mouse_dy * 0.0035f, -1.15f, 0.30f); }
        float alpha = static_cast<float>(acc / rb::kDt);
        cam.update(s, alpha, v, static_cast<float>(dt), s.hunter.locked);
        auto f0 = clock::now();
        r.frame(s, alpha, cam, sim_time, static_cast<float>(dt));
        r.swap();
        double fms = std::chrono::duration<double, std::milli>(clock::now() - f0).count();
        frame_ms.push_back(fms);
        if (fms > 16.7) slow++;
        frames++;
        if (!a.capture.empty() && frames == a.frames) {
            std::string path = std::string(RB_CAPTURE_DIR) + "/native_" + a.capture + ".ppm";
            bool ok = r.read_ppm(path);
            std::printf("rebirth-native: capture %s -> %s (%dx%d) at sim t=%.1fs · hunter hp %.0f · dragon hp %.0f (%s%s)\n", ok ? "OK" : "FAIL", path.c_str(), r.width(), r.height(), sim_time, s.hunter.hp, s.dragon.hp, rb::skill_name(s.dragon.skill), s.dragon.enraged ? ", enraged" : "");
            rc = ok ? 0 : 1;
            break;
        }
    }
    if (!frame_ms.empty()) {
        std::vector<double> sorted = frame_ms;
        std::sort(sorted.begin(), sorted.end());
        double avg = 0; for (double m : frame_ms) avg += m; avg /= static_cast<double>(frame_ms.size());
        std::printf("rebirth-native: %d frames · render avg %.2f ms · p99 %.2f ms · max %.2f ms · >16.7ms: %d · vfx overflow %d · kills %d · skills %s\n",
            frames, avg, sorted[static_cast<size_t>(static_cast<double>(sorted.size() - 1) * 0.99)], sorted.back(), slow, r.vfx_overflow(), s.kills, used_list(s).c_str());
    }
    return rc;
#endif
}
