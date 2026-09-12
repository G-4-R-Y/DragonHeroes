// REBIRTH / native — simulation rules (see sim.hpp). Mirrors rebirth/godot3d.
#include "sim.hpp"

#include <algorithm>
#include <cmath>

namespace rb {

namespace {
constexpr float kPi = 3.14159265358979f;
constexpr float kTau = 2.f * kPi;

float clampf(float v, float lo, float hi) { return std::max(lo, std::min(hi, v)); }
float deg(float r) { return r * 180.f / kPi; }
float rad(float d) { return d * kPi / 180.f; }

float lcg(uint32_t& s) {  // deterministic [0,1)
    s = s * 1664525u + 1013904223u;
    return (s >> 8) * (1.0f / 16777216.0f);
}

constexpr std::array<SkillDef, 6> kSkills{{
    {0, 0, 0, 0, 0, 0, 0},                          // None
    {1.10f, 1.20f, 1.60f, 3.0f, 15.0f, 30.f, 5.f},  // Breath
    {1.40f, 0.50f, 1.00f, 9.0f, 60.0f, 24.f, 9.f},  // Meteors
    {0.80f, 0.30f, 1.20f, 0.0f, 7.0f, 22.f, 4.f},   // Tail
    {0.90f, 0.30f, 1.90f, 0.0f, 7.5f, 12.f, 6.f},   // Gust
    {1.00f, 0.55f, 1.30f, 3.0f, 30.0f, 34.f, 8.f},  // Pounce
}};

struct Combo { float startup, active, recover, dmg, reach, arc; };
constexpr std::array<Combo, 3> kCombo{{
    {0.12f, 0.10f, 0.22f, 10.f, 2.6f, 70.f},
    {0.10f, 0.10f, 0.22f, 10.f, 2.6f, 70.f},
    {0.16f, 0.12f, 0.34f, 18.f, 2.9f, 90.f},
}};
constexpr Combo kSkill{0.18f, 0.16f, 0.36f, 45.f, 3.4f, 100.f};
constexpr float kSkillLunge = 4.f;

void ground(Vec3& p, const Heightfield& hf) { p.y = hf.height_at(p.x, p.z); }

void clamp_radius(Vec3& p, float r) {
    float l = length_xz(p);
    if (l > r) { p.x *= r / l; p.z *= r / l; }
}

Event ev(Event::Kind k, Vec3 pos, float a = 0, float b = 0, float c = 0, std::array<float, 3> col = {1, 1, 1}) {
    Event e; e.kind = k; e.pos = pos; e.a = a; e.b = b; e.c = c; e.color = col; return e;
}
} // namespace

// --- vector helpers -----------------------------------------------------------

float length(Vec3 v) { return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z); }
float length_xz(Vec3 v) { return std::sqrt(v.x * v.x + v.z * v.z); }
Vec3 normalize_xz(Vec3 v) {
    float l = length_xz(v);
    if (l < 1e-6f) return {0, 0, -1};
    return {v.x / l, 0, v.z / l};
}
Vec3 lerp(Vec3 a, Vec3 b, float t) { return a + (b - a) * t; }
Vec3 forward(float yaw) { return {-std::sin(yaw), 0, -std::cos(yaw)}; }
Vec3 right(float yaw) { return {std::cos(yaw), 0, -std::sin(yaw)}; }
float yaw_to(Vec3 from, Vec3 to) { Vec3 d = to - from; return std::atan2(-d.x, -d.z); }
float angle_diff(float a, float b) {
    float d = std::fmod(b - a + kPi, kTau);
    if (d < 0) d += kTau;
    return d - kPi;
}
const char* skill_name(Skill s) {
    switch (s) {
        case Skill::Breath: return "breath"; case Skill::Meteors: return "meteors"; case Skill::Tail: return "tail";
        case Skill::Gust: return "gust"; case Skill::Pounce: return "pounce"; default: return "none";
    }
}
const SkillDef& skill_def(Skill s) { return kSkills[static_cast<size_t>(s)]; }

// --- reset -----------------------------------------------------------------------

void reset_fight(State& s, const Heightfield& hf) {
    // stats survive the rematch (they are the gates); everything else resets
    const Hunter oh = s.hunter; const Dragon od = s.dragon; const Pet op = s.pet;
    Hunter h; h.pos = {0, 0, 16}; ground(h.pos, hf);
    h.iframe_avoids = oh.iframe_avoids; h.max_combo = oh.max_combo; h.hits = oh.hits; h.dodges = oh.dodges;
    h.skills = oh.skills; h.dmg_taken = oh.dmg_taken; h.distance = oh.distance;
    Dragon d; d.pos = {0, 0, -8}; ground(d.pos, hf);
    d.used = od.used; d.skills_used = od.skills_used; d.hits_landed = od.hits_landed; d.dmg_dealt = od.dmg_dealt;
    h.yaw = yaw_to(h.pos, d.pos);
    d.yaw = yaw_to(d.pos, h.pos);
    h.locked = true;
    d.cds[static_cast<size_t>(Skill::Meteors)] = 4.f;
    d.cds[static_cast<size_t>(Skill::Pounce)] = 3.f;
    h.prev = h.pos; d.prev = d.pos;
    Pet p; p.pos = h.pos + Vec3{-1.6f, 0, 1.4f}; ground(p.pos, hf); p.prev = p.pos;
    p.nips = op.nips; p.howls = op.howls;
    s.hunter = h; s.dragon = d; s.pet = p;
    s.fields.clear();
    s.loop = Loop::Fight; s.loop_t = 0;
    s.rng = 11;
}

// --- hunter ----------------------------------------------------------------------

namespace {
bool hunter_arc_hit(State& s, float reach, float arc_deg, float dmg) {
    Hunter& h = s.hunter; Dragon& d = s.dragon;
    if (d.state == DragonState::Dead) return false;
    Vec3 to = d.pos - h.pos; to.y = 0;
    float dist = std::max(length_xz(to) - Dragon::kHitRadius, 0.f);
    if (dist > reach) return false;
    Vec3 f = forward(h.yaw), n = normalize_xz(to);
    float ang = deg(std::acos(clampf(f.x * n.x + f.z * n.z, -1.f, 1.f)));
    if (length_xz(to) > Dragon::kHitRadius && ang > arc_deg * 0.5f) return false;
    d.hp = std::max(d.hp - dmg, 0.f);
    h.hits++;
    s.events.push_back(ev(Event::Spark, h.pos + f * std::min(length_xz(to) - Dragon::kHitRadius * 0.5f, reach) + Vec3{0, 1.4f, 0}, 0, 0, 0, {1.f, 0.85f, 0.5f}));
    if (d.hp <= 0.f) {
        d.state = DragonState::Dead; d.punishable = false; d.meteors.clear();
        s.events.push_back(ev(Event::Slain, d.pos));
    }
    return true;
}

bool hunter_take_damage(State& s, float amount, Vec3 from, float knockback) {
    Hunter& h = s.hunter;
    if (h.state == HunterState::Dead) return false;
    if (h.iframes > 0.f) {
        h.iframe_avoids++;
        s.events.push_back(ev(Event::Spark, h.pos + Vec3{0, 1.2f, 0}, 0, 0, 0, {0.6f, 0.8f, 1.f}));
        return false;
    }
    h.hp = std::max(h.hp - amount, 0.f);
    h.dmg_taken += amount;
    Vec3 away = normalize_xz(h.pos - from);
    h.knock = away * (knockback * 3.f);
    s.events.push_back(ev(Event::Spark, h.pos + Vec3{0, 1.2f, 0}, 0, 0, 0, {1.f, 0.3f, 0.2f}));
    if (h.hp <= 0.f) { h.state = HunterState::Dead; return true; }
    h.state = HunterState::Hitstun; h.t = 0; h.hit_done = false;
    return true;
}

void hunter_enter(Hunter& h, HunterState st) { h.state = st; h.t = 0; h.hit_done = false; }

bool hunter_try_actions(State& s, Vec3 move) {
    Hunter& h = s.hunter; const Dragon& d = s.dragon;
    if (h.buf_dodge > 0.f && h.dodge_charges > 0) {
        h.buf_dodge = 0; h.dodge_charges--; h.dodges++;
        if (length_xz(move) > 0.1f) h.dodge_dir = normalize_xz(move);
        else if (h.locked) h.dodge_dir = normalize_xz(h.pos - d.pos);
        else h.dodge_dir = forward(h.yaw);
        h.iframes = Hunter::kDodgeIframes;
        hunter_enter(h, HunterState::Dodge);
        return true;
    }
    if (h.buf_skill > 0.f && h.skill_cd <= 0.f) {
        h.buf_skill = 0; h.skill_cd = Hunter::kSkillCd; h.skills++;
        if (h.locked) h.yaw = yaw_to(h.pos, d.pos);
        hunter_enter(h, HunterState::Skill);
        return true;
    }
    if (h.buf_attack > 0.f) {
        h.buf_attack = 0;
        if (h.combo_link <= 0.f) { h.combo_step = 0; h.combo_hits = 0; }
        if (h.locked) h.yaw = yaw_to(h.pos, d.pos);
        hunter_enter(h, HunterState::Attack);
        return true;
    }
    return false;
}

void hunter_face(Hunter& h, Vec3 dir, float dt, float rate) {
    if (length_xz(dir) < 0.01f) return;
    float want = std::atan2(-dir.x, -dir.z);
    h.yaw += angle_diff(h.yaw, want) * (1.f - std::exp(-dt * rate));
}

void hunter_step(State& s, const Input& in, const Heightfield& hf) {
    Hunter& h = s.hunter; Dragon& d = s.dragon;
    h.prev = h.pos;
    if (h.state == HunterState::Dead) return;
    const float dt = static_cast<float>(kDt);
    h.t += dt;
    h.iframes = std::max(h.iframes - dt, 0.f);
    h.skill_cd = std::max(h.skill_cd - dt, 0.f);
    h.combo_link = std::max(h.combo_link - dt, 0.f);
    if (h.combo_link == 0.f && h.state != HunterState::Attack) { h.combo_step = 0; h.combo_hits = 0; }
    if (h.dodge_charges < Hunter::kDodgeCharges) {
        h.dodge_recharge += dt;
        if (h.dodge_recharge >= Hunter::kDodgeRecharge) { h.dodge_recharge = 0; h.dodge_charges++; }
    }
    h.buf_dodge = std::max(h.buf_dodge - dt, 0.f);
    h.buf_attack = std::max(h.buf_attack - dt, 0.f);
    h.buf_skill = std::max(h.buf_skill - dt, 0.f);
    if (in.dodge) h.buf_dodge = Hunter::kBuffer;
    if (in.attack) h.buf_attack = Hunter::kBuffer;
    if (in.skill) h.buf_skill = Hunter::kBuffer;
    Vec3 cf = forward(in.cam_yaw), cr = right(in.cam_yaw);
    Vec3 move = cr * in.move_x + cf * in.move_y;
    if (length_xz(move) > 1.f) move = normalize_xz(move);
    Vec3 before = h.pos;
    switch (h.state) {
        case HunterState::Idle:
            if (hunter_try_actions(s, move)) break;
            if (length_xz(move) > 0.01f) h.pos += move * (Hunter::kSpeed * dt);
            if (h.locked && d.state != DragonState::Dead) hunter_face(h, d.pos - h.pos, dt, 10.f);
            else hunter_face(h, move, dt, 14.f);
            break;
        case HunterState::Dodge: {
            float k = h.t / Hunter::kDodgeDur;
            float speed = (Hunter::kDodgeDist / Hunter::kDodgeDur) * (1.6f - 1.2f * k);
            h.pos += h.dodge_dir * (speed * dt);
            if (!h.locked) hunter_face(h, h.dodge_dir, dt, 14.f);
            if (h.t >= Hunter::kDodgeDur) hunter_enter(h, HunterState::Idle);
            break;
        }
        case HunterState::Attack: {
            const Combo& c = kCombo[static_cast<size_t>(h.combo_step)];
            float total = c.startup + c.active + c.recover;
            if (h.t >= c.startup && !h.hit_done) {
                h.hit_done = true;
                s.events.push_back(ev(Event::Slash, h.pos, h.yaw, c.reach, 0, {0.9f, 0.95f, 1.f}));
                if (hunter_arc_hit(s, c.reach, c.arc, c.dmg)) { h.combo_hits++; h.max_combo = std::max(h.max_combo, h.combo_hits); }
            }
            if (h.t >= c.startup + c.active && h.buf_dodge > 0.f && h.dodge_charges > 0) {
                h.combo_link = Hunter::kComboLink;
                hunter_try_actions(s, {});
                break;
            }
            if (h.t >= total) {
                h.combo_step = (h.combo_step + 1) % 3;
                h.combo_link = Hunter::kComboLink;
                hunter_enter(h, HunterState::Idle);
                hunter_try_actions(s, {});
            }
            break;
        }
        case HunterState::Skill: {
            float total = kSkill.startup + kSkill.active + kSkill.recover;
            if (h.t < kSkill.startup + 0.06f) h.pos += forward(h.yaw) * (kSkillLunge / (kSkill.startup + 0.06f) * dt);
            if (h.t >= kSkill.startup && !h.hit_done) {
                h.hit_done = true;
                s.events.push_back(ev(Event::Slash, h.pos, h.yaw, kSkill.reach, 0, {1.f, 0.55f, 0.2f}));
                Vec3 fp = h.pos + forward(h.yaw) * 1.8f; ground(fp, hf);
                s.fields.push_back({fp, 1.4f, 2.5f});
                s.events.push_back(ev(Event::Field, fp, 1.4f, 2.5f));
                hunter_arc_hit(s, kSkill.reach, kSkill.arc, kSkill.dmg);
            }
            if (h.t >= total) hunter_enter(h, HunterState::Idle);
            break;
        }
        case HunterState::Hitstun:
            h.pos += h.knock * dt;
            h.knock = lerp(h.knock, {}, 1.f - std::exp(-dt * 8.f));
            if (h.t >= Hunter::kHitstun) hunter_enter(h, HunterState::Idle);
            break;
        case HunterState::Dead: break;
    }
    clamp_radius(h.pos, hf.bowl_radius() + 8.f);
    ground(h.pos, hf);
    h.distance += length_xz(h.pos - before);
}
} // namespace

// --- dragon ----------------------------------------------------------------------

namespace {
size_t idx(Skill s) { return static_cast<size_t>(s); }

Vec3 to_hunter(const State& s) { Vec3 t = s.hunter.pos - s.dragon.pos; t.y = 0; return t; }
float surface_dist(const State& s) { return std::max(length_xz(to_hunter(s)) - Dragon::kHitRadius, 0.f); }
float rel_angle_deg(const State& s) {
    Vec3 f = forward(s.dragon.yaw), n = normalize_xz(to_hunter(s));
    float dot = clampf(f.x * n.x + f.z * n.z, -1.f, 1.f);
    return deg(std::acos(dot));
}
float tele_time(const Dragon& d, Skill sk) { return skill_def(sk).tele * (d.enraged ? 0.8f : 1.f); }

void dragon_enter(Dragon& d, DragonState st) { d.state = st; d.t = 0; d.act_done = false; d.aim_locked = false; }

void dragon_face(State& s, float rate) {
    Dragon& d = s.dragon;
    Vec3 to = to_hunter(s);
    if (length_xz(to) < 0.03f) return;
    float want = std::atan2(-to.x, -to.z);
    float diff = angle_diff(d.yaw, want);
    float mx = rate * static_cast<float>(kDt);
    d.yaw += clampf(diff, -mx, mx);
}

bool legal(const State& s, Skill sk) {
    const Dragon& d = s.dragon;
    if (d.cds[idx(sk)] > 0.f) return false;
    float dist = surface_dist(s);
    const SkillDef& def = skill_def(sk);
    if (dist < def.min_d || dist > def.max_d) return false;
    float rel = rel_angle_deg(s);
    switch (sk) {
        case Skill::Breath: case Skill::Gust: return rel < 70.f;
        case Skill::Tail: return rel > 95.f || (d.enraged && dist < 3.f);
        case Skill::Pounce: return d.enraged || dist > 14.f;
        default: return true;
    }
}

void dragon_deal(State& s, float dmg, float knockback) {
    if (hunter_take_damage(s, dmg, s.dragon.pos, knockback)) { s.dragon.hits_landed++; s.dragon.dmg_dealt += dmg; }
}

void end_telegraphs(State& s) { s.events.push_back(ev(Event::ConeEnd, {})); s.events.push_back(ev(Event::RingEnd, {})); }

void show_telegraph(State& s) {
    Dragon& d = s.dragon;
    float dur = tele_time(d, d.skill) + skill_def(d.skill).act;
    switch (d.skill) {
        case Skill::Breath:
            s.events.push_back(ev(Event::Cone, d.pos, d.yaw, Dragon::kBreathRange, dur, {1.f, 0.35f, 0.1f}));
            break;
        case Skill::Meteors: {
            int n = d.enraged ? 5 : 3;
            d.meteors.clear();
            for (int i = 0; i < n; ++i) {
                Vec3 off{};
                if (i > 0) { float a = (i / static_cast<float>(n)) * kTau; off = Vec3{std::cos(a), 0, std::sin(a)} * (3.2f + i * 0.6f); }
                Vec3 p = s.hunter.pos + off;
                d.meteors.push_back({p, -1.f, false});
                s.events.push_back(ev(Event::Ring, p, Dragon::kMeteorR, dur + 1.f, 0, {1.f, 0.4f, 0.1f}));
            }
            break;
        }
        case Skill::Tail:
            for (float off : {0.f, rad(60.f), -rad(60.f)})
                s.events.push_back(ev(Event::Cone, d.pos, d.yaw + kPi + off, Dragon::kTailReach + Dragon::kHitRadius, dur, {1.f, 0.5f, 0.15f}));
            break;
        case Skill::Gust:
            s.events.push_back(ev(Event::Ring, d.pos, Dragon::kGustR + Dragon::kHitRadius, dur, 0, {0.6f, 0.75f, 1.f}));
            break;
        case Skill::Pounce:
            d.pounce_to = s.hunter.pos;
            s.events.push_back(ev(Event::Ring, d.pounce_to, Dragon::kPounceR, dur, 0, {1.f, 0.25f, 0.1f}));
            break;
        default: break;
    }
}

void start_skill(State& s, Skill sk) {
    Dragon& d = s.dragon;
    d.skill = sk;
    d.cds[idx(sk)] = skill_def(sk).cd;
    d.used[idx(sk)]++;
    d.skills_used++;
    dragon_enter(d, DragonState::Tele);
    d.telegraph_left = tele_time(d, sk);
    show_telegraph(s);
}

void decide(State& s) {
    Dragon& d = s.dragon;
    float dist = surface_dist(s);
    float rel = rel_angle_deg(s);
    Skill pick = Skill::Nil;
    if (s.force_next != Skill::Nil && legal(s, s.force_next)) { pick = s.force_next; s.force_next = Skill::Nil; }
    else if (legal(s, Skill::Tail)) pick = Skill::Tail;
    else if (dist > 9.f && legal(s, Skill::Meteors)) pick = Skill::Meteors;
    else if (dist > 3.f && legal(s, Skill::Pounce)) pick = Skill::Pounce;
    else if (legal(s, Skill::Gust) && dist < 4.f && (d.enraged || lcg(s.rng) < 0.35f)) pick = Skill::Gust;
    else if (legal(s, Skill::Breath) && dist >= 3.f) pick = Skill::Breath;
    else if (legal(s, Skill::Gust)) pick = Skill::Gust;
    if (pick == Skill::Nil) {
        if (rel > 70.f || dist > 3.6f) dragon_enter(d, DragonState::Approach); else dragon_enter(d, DragonState::Idle);
        return;
    }
    start_skill(s, pick);
}

bool in_cone(const State& s, Vec3 p, float range, float half_deg) {
    const Dragon& d = s.dragon;
    Vec3 to = p - d.pos; to.y = 0;
    float l = length_xz(to);
    if (l > range + Dragon::kHitRadius) return false;
    if (l <= Dragon::kHitRadius) return true;
    Vec3 f = forward(d.yaw), n = normalize_xz(to);
    return deg(std::acos(clampf(f.x * n.x + f.z * n.z, -1.f, 1.f))) <= half_deg;
}

void begin_act(State& s) {
    Dragon& d = s.dragon;
    dragon_enter(d, DragonState::Act);
    if (d.skill == Skill::Meteors) {
        for (auto& m : d.meteors) { m.land_in = 0.9f; s.events.push_back(ev(Event::MeteorFall, m.pos, 0.9f)); }
    } else if (d.skill == Skill::Pounce) {
        d.pounce_from = d.pos;
        Vec3 to = d.pounce_to - d.pos;
        if (length_xz(to) > 0.01f) d.yaw = std::atan2(-to.x, -to.z);
    }
}

void tick_act(State& s, const Heightfield& hf) {
    Dragon& d = s.dragon;
    const SkillDef& def = skill_def(d.skill);
    switch (d.skill) {
        case Skill::Breath:
            if (!d.act_done && in_cone(s, s.hunter.pos, Dragon::kBreathRange, Dragon::kBreathHalfDeg)) { d.act_done = true; dragon_deal(s, def.dmg, 4.f); }
            if (d.t >= def.act - 0.02f && !d.aim_locked) {
                d.aim_locked = true;   // reuse as "field spawned" latch for the act phase
                s.events.push_back(ev(Event::ConeEnd, {}));
                Vec3 c = d.pos + forward(d.yaw) * (Dragon::kHitRadius + 4.5f); ground(c, hf);
                float r = d.enraged ? 3.2f : 2.6f;
                s.fields.push_back({c, r, 7.f});
                s.events.push_back(ev(Event::Field, c, r, 7.f));
            }
            break;
        case Skill::Tail:
            if (!d.act_done && d.t >= 0.05f) {
                d.act_done = true;
                if (rel_angle_deg(s) > 80.f && surface_dist(s) <= Dragon::kTailReach) dragon_deal(s, def.dmg, 6.f);
                end_telegraphs(s);
            }
            break;
        case Skill::Gust:
            if (!d.act_done && d.t >= 0.05f) {
                d.act_done = true;
                if (rel_angle_deg(s) < 100.f && surface_dist(s) <= Dragon::kGustR) dragon_deal(s, def.dmg, 9.f);
                s.events.push_back(ev(Event::Ring, d.pos, Dragon::kGustR + Dragon::kHitRadius, 0.35f, 0, {0.7f, 0.85f, 1.f}));
                end_telegraphs(s);
            }
            break;
        case Skill::Pounce: {
            float k = clampf(d.t / def.act, 0.f, 1.f);
            Vec3 p = lerp(d.pounce_from, d.pounce_to, k);
            d.pos.x = p.x; d.pos.z = p.z;
            d.body_y = std::sin(k * kPi) * 5.f;
            if (k >= 1.f && !d.act_done) {
                d.act_done = true; d.body_y = 0;
                Vec3 hp = s.hunter.pos - d.pounce_to;
                if (surface_dist(s) <= Dragon::kPounceR + 0.5f || length_xz(hp) <= Dragon::kPounceR) dragon_deal(s, def.dmg, 7.f);
                s.events.push_back(ev(Event::Ring, d.pos, Dragon::kPounceR + Dragon::kHitRadius, 0.3f, 0, {1.f, 0.4f, 0.1f}));
                s.events.push_back(ev(Event::Spark, d.pos + Vec3{0, 0.5f, 0}, 0, 0, 0, {0.8f, 0.6f, 0.4f}));
                end_telegraphs(s);
            }
            break;
        }
        default: break;
    }
    if (d.t >= def.act) { dragon_enter(d, DragonState::Recover); d.punishable = true; }
}

void tick_meteors(State& s, const Heightfield& hf) {
    Dragon& d = s.dragon;
    const float dt = static_cast<float>(kDt);
    for (auto& m : d.meteors) {
        if (m.land_in < 0.f || m.applied) continue;
        m.land_in -= dt;
        if (m.land_in <= 0.f) {
            m.applied = true;
            Vec3 lp = m.pos; ground(lp, hf);
            s.events.push_back(ev(Event::Spark, lp + Vec3{0, 0.5f, 0}, 0, 0, 0, {1.f, 0.6f, 0.2f}));
            s.fields.push_back({lp, 2.2f, 3.5f});
            s.events.push_back(ev(Event::Field, lp, 2.2f, 3.5f));
            if (length_xz(s.hunter.pos - m.pos) <= Dragon::kMeteorR) dragon_deal(s, skill_def(Skill::Meteors).dmg, 5.f);
        }
    }
}

void tick_fields(State& s) {
    const float dt = static_cast<float>(kDt);
    for (auto& f : s.fields) f.left -= dt;
    s.fields.erase(std::remove_if(s.fields.begin(), s.fields.end(), [](const Field& f) { return f.left <= 0.f; }), s.fields.end());
    Dragon& d = s.dragon;
    d.field_tick -= dt;
    if (d.field_tick <= 0.f) {
        d.field_tick = 0.5f;
        if (s.hunter.state != HunterState::Dead) {
            for (const auto& f : s.fields) {
                if (length_xz(s.hunter.pos - f.pos) <= f.radius) {
                    if (hunter_take_damage(s, 4.f, s.hunter.pos + forward(s.hunter.yaw), 0.5f)) d.dmg_dealt += 4.f;
                    break;
                }
            }
        }
    }
}

void enrage(State& s) {
    Dragon& d = s.dragon;
    d.enraged = true;
    s.enraged_seen = true;
    d.cds[idx(Skill::Pounce)] = 0.f;
    d.retreat_pending = true;
    s.events.push_back(ev(Event::Enrage, d.pos));
    s.events.push_back(ev(Event::Ring, d.pos, Dragon::kHitRadius + 6.f, 0.8f, 0, {1.f, 0.1f, 0.05f}));
}

void dragon_step(State& s, const Heightfield& hf) {
    Dragon& d = s.dragon;
    d.prev = d.pos;
    if (d.state == DragonState::Dead) return;
    const float dt = static_cast<float>(kDt);
    d.t += dt;
    for (auto& c : d.cds) c = std::max(c - dt, 0.f);
    tick_meteors(s, hf);
    tick_fields(s);
    if (!d.enraged && d.hp <= Dragon::kHpMax * Dragon::kEnrageAt) enrage(s);
    if (d.enraged && (d.state == DragonState::Idle || d.state == DragonState::Approach || d.state == DragonState::Recover) && surface_dist(s) < 6.f) {
        d.retreat_timer += dt;
        if (d.retreat_timer >= Dragon::kRetreatEvery) { d.retreat_timer = 0; d.retreat_pending = true; }
    }
    bool hunter_alive = s.hunter.state != HunterState::Dead;
    switch (d.state) {
        case DragonState::Idle:
            d.punishable = false;
            if (hunter_alive) {
                d.think -= dt;
                if (d.think <= 0.f) {
                    d.think = 0.35f;
                    if (d.retreat_pending) { d.retreat_pending = false; d.retreat_timer = 0; dragon_enter(d, DragonState::Retreat); }
                    else decide(s);
                }
            }
            break;
        case DragonState::Approach:
            dragon_face(s, Dragon::kTurn * (d.enraged ? 1.3f : 1.f));
            if (surface_dist(s) > 3.6f) d.pos += forward(d.yaw) * (Dragon::kSpeed * (d.enraged ? 1.3f : 1.f) * dt);
            d.think -= dt;
            if (d.think <= 0.f) { d.think = 0.35f; decide(s); }
            break;
        case DragonState::Tele:
            d.telegraph_left = std::max(tele_time(d, d.skill) - d.t, 0.f);
            if (d.telegraph_left > Dragon::kCommit && (d.skill == Skill::Breath || d.skill == Skill::Gust || d.skill == Skill::Pounce)) {
                dragon_face(s, Dragon::kTeleTurn);
                if (d.skill == Skill::Breath) {
                    s.events.push_back(ev(Event::ConeEnd, {}));
                    s.events.push_back(ev(Event::Cone, d.pos, d.yaw, Dragon::kBreathRange, d.telegraph_left + skill_def(d.skill).act, {1.f, 0.35f, 0.1f}));
                } else if (d.skill == Skill::Pounce) {
                    d.pounce_to = s.hunter.pos;
                    s.events.push_back(ev(Event::RingEnd, {}));
                    s.events.push_back(ev(Event::Ring, d.pounce_to, Dragon::kPounceR, d.telegraph_left + skill_def(d.skill).act, 0, {1.f, 0.25f, 0.1f}));
                }
            } else if (!d.aim_locked) {
                d.aim_locked = true;
            }
            if (d.telegraph_left <= 0.f) begin_act(s);
            break;
        case DragonState::Act: tick_act(s, hf); break;
        case DragonState::Recover:
            d.punishable = true;
            if (d.t >= skill_def(d.skill).recover) { d.punishable = false; dragon_enter(d, DragonState::Idle); }
            break;
        case DragonState::Stagger:
            d.punishable = true;
            if (d.t >= 1.1f) { d.punishable = false; dragon_enter(d, DragonState::Idle); }
            break;
        case DragonState::Retreat: {
            float k = clampf(d.t / Dragon::kRetreatS, 0.f, 1.f);
            d.pos += forward(d.yaw) * (-(Dragon::kRetreatM / Dragon::kRetreatS) * dt);
            clamp_radius(d.pos, hf.bowl_radius() - 2.f);
            d.body_y = std::sin(k * kPi) * 3.f;
            if (d.t >= Dragon::kRetreatS) {
                d.body_y = 0;
                d.cds[idx(Skill::Meteors)] = 0.f;
                d.cds[idx(Skill::Pounce)] = std::min(d.cds[idx(Skill::Pounce)], 2.5f);
                d.think = 0.05f;
                dragon_enter(d, DragonState::Idle);
            }
            break;
        }
        case DragonState::Dead: break;
    }
    ground(d.pos, hf);
}

void dragon_stagger(State& s, float dur) {
    Dragon& d = s.dragon;
    if (d.state == DragonState::Dead) return;
    end_telegraphs(s);
    d.meteors.erase(std::remove_if(d.meteors.begin(), d.meteors.end(), [](const Dragon::Meteor& m) { return m.land_in < 0.f; }), d.meteors.end());
    dragon_enter(d, DragonState::Stagger);
    d.t = 1.1f - dur;
    d.punishable = true;
    s.events.push_back(ev(Event::Spark, d.pos + Vec3{0, 4.f, 0}, 0, 0, 0, {0.5f, 1.f, 0.9f}));
}

// --- pet -----------------------------------------------------------------------------

void pet_step(State& s, const Input& in, const Heightfield& hf) {
    Pet& p = s.pet; Hunter& h = s.hunter; Dragon& d = s.dragon;
    p.prev = p.pos;
    const float dt = static_cast<float>(kDt);
    p.nip_cd = std::max(p.nip_cd - dt, 0.f);
    p.howl_cd = std::max(p.howl_cd - dt, 0.f);
    if (h.state == HunterState::Dead) return;
    Vec3 heel = h.pos - forward(h.yaw) * 1.6f - right(h.yaw) * 1.4f;
    Vec3 to_d = d.pos - p.pos; to_d.y = 0;
    float sd = length_xz(to_d) - Dragon::kHitRadius;
    Vec3 want = heel;
    bool alive = d.state != DragonState::Dead;
    if (p.nip_cd <= 0.f && sd < Pet::kNipRange + 3.f && alive) want = d.pos - normalize_xz(to_d) * (Dragon::kHitRadius + 1.2f);
    Vec3 dv = want - p.pos; dv.y = 0;
    float dl = length_xz(dv);
    if (dl > 0.3f) {
        p.pos += normalize_xz(dv) * std::min(Pet::kSpeed * dt, dl);
        p.yaw += angle_diff(p.yaw, std::atan2(-dv.x, -dv.z)) * (1.f - std::exp(-dt * 10.f));
    }
    ground(p.pos, hf);
    if (p.nip_cd <= 0.f && sd <= Pet::kNipRange && alive) {
        p.nip_cd = Pet::kNipCd; p.nips++;
        d.hp = std::max(d.hp - Pet::kNipDmg, 0.f);
        s.events.push_back(ev(Event::Spark, p.pos + normalize_xz(to_d) * 1.2f + Vec3{0, 1.f, 0}, 0, 0, 0, {0.5f, 1.f, 0.9f}));
        if (d.hp <= 0.f) { d.state = DragonState::Dead; d.punishable = false; d.meteors.clear(); s.events.push_back(ev(Event::Slain, d.pos)); }
    }
    if (in.pet && p.howl_cd <= 0.f) {
        p.howl_cd = Pet::kHowlCd; p.howls++;
        s.events.push_back(ev(Event::Ring, p.pos, 3.f, 0.6f, 0, {0.3f, 1.f, 0.9f}));
        if (h.state != HunterState::Dead) h.hp = std::min(h.hp + Pet::kHowlHeal, Hunter::kHpMax);
        if (length_xz(to_d) <= Pet::kHowlRange) dragon_stagger(s, 1.1f);
    }
}
} // namespace

// --- the tick ----------------------------------------------------------------------------

void step(State& s, const Input& in, const Heightfield& hf) {
    const float dt = static_cast<float>(kDt);
    s.tick++;
    s.time += kDt;
    s.loop_t += dt;
    Hunter& h = s.hunter; Dragon& d = s.dragon;
    if (in.lock) h.locked = !h.locked;
    if (in.rematch && s.loop != Loop::Fight && s.loop_t > 1.f) {
        int kills = s.kills;
        reset_fight(s, hf);
        s.kills = kills;
        s.rematch_seen = s.kills > 0;
        s.events.push_back(ev(Event::Rematch, {}));
    }
    bool dragon_was_alive = d.state != DragonState::Dead;
    bool hunter_was_alive = h.state != HunterState::Dead;
    hunter_step(s, in, hf);
    dragon_step(s, hf);
    pet_step(s, in, hf);
    if (dragon_was_alive && d.state == DragonState::Dead && s.loop == Loop::Fight) {
        s.loop = Loop::Drop; s.loop_t = 0; s.kills++;
        static const char* kDrops[] = {"Cinderscale Fang", "Ember-Heart Core", "Wyrmking's Talon", "Ashen Wing Membrane"};
        Event e = ev(Event::Toast, d.pos);
        e.text = std::string("LEGENDARY DROP — ") + kDrops[(s.kills - 1) % 4];
        s.last_toast = e.text; s.toasts++;
        s.events.push_back(e);
        s.events.push_back(ev(Event::Ring, d.pos, 4.f, 1.2f, 0, {1.f, 0.85f, 0.3f}));
        s.events.push_back(ev(Event::Ring, d.pos, 7.f, 1.6f, 0, {1.f, 0.85f, 0.3f}));
    }
    if (hunter_was_alive && h.state == HunterState::Dead && s.loop == Loop::Fight) {
        s.loop = Loop::Dead; s.loop_t = 0;
        Event e = ev(Event::Toast, h.pos); e.text = "SLAIN BY THE WYRM"; s.last_toast = e.text; s.toasts++;
        s.events.push_back(e);
    }
}

// --- autopilot (same policy as godot3d/scripts/autopilot.gd) ---------------------------

Input autopilot(const State& s, float cam_yaw) {
    Input i; i.cam_yaw = cam_yaw;
    const Hunter& h = s.hunter; const Dragon& d = s.dragon; const Pet& p = s.pet;
    auto local = [&](Vec3 dir) {
        if (length_xz(dir) < 0.01f) { i.move_x = 0; i.move_y = 0; return; }
        Vec3 n = normalize_xz(dir), r = right(cam_yaw), f = forward(cam_yaw);
        i.move_x = n.x * r.x + n.z * r.z; i.move_y = n.x * f.x + n.z * f.z;
    };
    if (s.loop != Loop::Fight) { if (s.loop_t > 2.f) i.rematch = true; return i; }
    if (h.state == HunterState::Dead || d.state == DragonState::Dead) return i;
    Vec3 to = d.pos - h.pos; to.y = 0;
    float dist = std::max(length_xz(to) - Dragon::kHitRadius, 0.f);
    Vec3 dir = normalize_xz(to);
    float side_sign = ((s.tick / 300) % 2 == 0) ? 1.f : -1.f;
    Vec3 side = Vec3{-dir.z, 0, dir.x} * side_sign;   // dir x up
    constexpr float kDodgeAt = 0.22f;
    if (d.state == DragonState::Tele && d.telegraph_left <= kDodgeAt && h.state == HunterState::Idle) {
        i.dodge = true;
        if (d.skill == Skill::Tail) local(dir * -1.f + side * 0.4f);
        else if (d.skill == Skill::Gust) local(dir * -1.f);
        else local(side);
        return i;
    }
    if (d.state == DragonState::Act && d.skill == Skill::Breath && dist < 6.f) { local(side); return i; }
    bool punish = d.punishable || d.state == DragonState::Stagger;
    if (punish) {
        if (dist > 2.2f) local(dir);
        else if (h.skill_cd <= 0.f && h.state == HunterState::Idle) i.skill = true;
        else i.attack = true;
    } else if (d.state == DragonState::Tele) {
        if (d.skill == Skill::Meteors) local(side);
        else if (dist < 4.5f) local(dir * -1.f);
        else if (dist > 6.f) local(dir);
        else local(side * 0.6f);
    } else {
        if (dist > 2.6f) local(dir);
        else if (d.state != DragonState::Act) i.attack = true;
    }
    if (p.howl_cd <= 0.f && dist < 12.f) i.pet = true;
    return i;
}

// --- hash + gate -------------------------------------------------------------------------

uint64_t state_hash(const State& s) {
    uint64_t h = 1469598103934665603ull;
    auto mix = [&](float v) {
        int32_t q = static_cast<int32_t>(std::lround(v * 1000.f));
        h ^= static_cast<uint64_t>(static_cast<uint32_t>(q));
        h *= 1099511628211ull;
    };
    mix(s.hunter.pos.x); mix(s.hunter.pos.z); mix(s.hunter.hp); mix(s.hunter.yaw);
    mix(s.dragon.pos.x); mix(s.dragon.pos.z); mix(s.dragon.hp); mix(s.dragon.yaw);
    mix(s.pet.pos.x); mix(s.pet.pos.z);
    mix(static_cast<float>(s.kills)); mix(static_cast<float>(s.fields.size()));
    return h;
}

std::string gate_missing(const State& s) {
    std::string miss;
    int distinct = 0;
    for (size_t i = 1; i < s.dragon.used.size(); ++i) if (s.dragon.used[i] > 0) distinct++;
    if (distinct < 5) miss += "skills " + std::to_string(distinct) + "/5; ";
    if (!s.enraged_seen) miss += "enrage; ";
    if (s.hunter.iframe_avoids < 1) miss += "iframe_avoid; ";
    if (s.hunter.max_combo < 3) miss += "combo3; ";
    if (s.kills < 1) miss += "kill; ";
    if (s.toasts < 1) miss += "toast; ";
    if (!s.rematch_seen) miss += "rematch; ";
    return miss;
}

} // namespace rb
