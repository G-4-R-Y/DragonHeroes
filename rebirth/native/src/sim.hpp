// REBIRTH / native — the vertical slice's simulation, engine-free.
// Fixed 30 Hz step (CLAUDE.md #2: the sim runs at fixed 30 Hz, the client
// interpolates), deterministic (integer tick, seeded LCG, no wall clock), no
// I/O, no GL. The renderer only ever reads SimState and drains SimEvents.
// The rules mirror rebirth/godot3d (same numbers; see docs/02-status.md
// "shared combat table") so both experiments answer the same feel question.
// When dh-sim's arena grows a 3D-space variant this file is what it replaces.
#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>

namespace rb {

constexpr double kTickHz = 30.0;
constexpr double kDt = 1.0 / kTickHz;

struct Vec3 {
    float x = 0, y = 0, z = 0;
    Vec3 operator+(Vec3 o) const { return {x + o.x, y + o.y, z + o.z}; }
    Vec3 operator-(Vec3 o) const { return {x - o.x, y - o.y, z - o.z}; }
    Vec3 operator*(float s) const { return {x * s, y * s, z * s}; }
    Vec3& operator+=(Vec3 o) { x += o.x; y += o.y; z += o.z; return *this; }
};
float length(Vec3 v);
float length_xz(Vec3 v);
Vec3 normalize_xz(Vec3 v);
Vec3 lerp(Vec3 a, Vec3 b, float t);
float yaw_to(Vec3 from, Vec3 to);           // yaw such that forward(yaw) points from->to
Vec3 forward(float yaw);                    // -Z at yaw 0 (glTF/Godot convention)
Vec3 right(float yaw);
float angle_diff(float a, float b);         // shortest signed b-a

// The terrain the sim walks on (defined in valley.hpp).
struct Heightfield {
    virtual ~Heightfield() = default;
    virtual float height_at(float x, float z) const = 0;
    virtual float bowl_radius() const = 0;
};

struct Input {
    float move_x = 0, move_y = 0;   // camera-relative strafe / forward, [-1,1]
    bool dodge = false, attack = false, skill = false, pet = false, lock = false, rematch = false;
    float cam_yaw = 0;              // to resolve camera-relative movement
};

enum class HunterState : uint8_t { Idle, Dodge, Attack, Skill, Hitstun, Dead };
enum class DragonState : uint8_t { Idle, Approach, Tele, Act, Recover, Stagger, Retreat, Dead };
enum class Skill : uint8_t { Nil, Breath, Meteors, Tail, Gust, Pounce };
const char* skill_name(Skill s);

struct SkillDef { float tele, act, recover, min_d, max_d, dmg, cd; };
const SkillDef& skill_def(Skill s);

struct Hunter {
    static constexpr float kHpMax = 100.f, kSpeed = 6.2f, kDodgeDur = 0.42f, kDodgeDist = 6.f,
        kDodgeIframes = 0.28f, kDodgeRecharge = 1.8f, kBuffer = 0.15f, kComboLink = 0.45f,
        kHitstun = 0.30f, kSkillCd = 6.f;
    static constexpr int kDodgeCharges = 3;
    Vec3 pos{0, 0, 16}, prev{};
    float yaw = 0;
    float hp = kHpMax;
    HunterState state = HunterState::Idle;
    float t = 0, iframes = 0, skill_cd = 0, combo_link = 0, dodge_recharge = 0;
    int combo_step = 0, combo_hits = 0, dodge_charges = kDodgeCharges;
    float buf_dodge = 0, buf_attack = 0, buf_skill = 0;
    Vec3 dodge_dir{}, knock{};
    bool hit_done = false, locked = false;
    // stats (gates)
    int iframe_avoids = 0, max_combo = 0, hits = 0, dodges = 0, skills = 0;
    float dmg_taken = 0, distance = 0;
};

struct Dragon {
    static constexpr float kHpMax = 600.f, kHitRadius = 2.4f, kSpeed = 4.2f, kTurn = 2.0f,
        kTeleTurn = 1.2f, kEnrageAt = 0.40f, kCommit = 0.35f, kBreathRange = 14.f,
        kBreathHalfDeg = 35.f, kMeteorR = 3.2f, kTailReach = 7.f, kGustR = 7.5f, kPounceR = 3.6f,
        kRetreatS = 0.6f, kRetreatM = 14.f, kRetreatEvery = 18.f;
    Vec3 pos{0, 0, -8}, prev{};
    float yaw = 0, body_y = 0;
    float hp = kHpMax;
    DragonState state = DragonState::Idle;
    Skill skill = Skill::Nil;
    float t = 0, think = 0.6f, telegraph_left = 0, field_tick = 0, retreat_timer = 0;
    bool enraged = false, punishable = false, act_done = false, aim_locked = false, retreat_pending = false;
    std::array<float, 6> cds{};      // indexed by Skill
    std::array<int, 6> used{};
    Vec3 pounce_from{}, pounce_to{};
    struct Meteor { Vec3 pos; float land_in; bool applied; };
    std::vector<Meteor> meteors;
    int skills_used = 0, hits_landed = 0;
    float dmg_dealt = 0;
};

struct Pet {
    static constexpr float kSpeed = 8.f, kNipCd = 4.f, kNipDmg = 6.f, kNipRange = 4.5f,
        kHowlCd = 12.f, kHowlRange = 14.f, kHowlHeal = 10.f;
    Vec3 pos{}, prev{};
    float yaw = 0, nip_cd = 1.f, howl_cd = 2.f;
    int nips = 0, howls = 0;
};

struct Field { Vec3 pos; float radius, left; };

// What the renderer needs to draw feedback. Drained every tick by the client.
struct Event {
    enum Kind : uint8_t { Ring, Cone, ConeEnd, RingEnd, Field, MeteorFall, Spark, Slash, Toast, Enrage, Slain, Rematch } kind;
    Vec3 pos{};
    float a = 0, b = 0, c = 0;    // ring: radius, dur · cone: yaw, range, dur · field: radius, dur · meteor: fall_time
    int handle = 0;
    std::array<float, 3> color{1, 1, 1};
    std::string text;
};

enum class Loop : uint8_t { Fight, Drop, Dead };

struct State {
    uint64_t tick = 0;
    double time = 0;
    Loop loop = Loop::Fight;
    float loop_t = 0;
    int kills = 0;
    Hunter hunter;
    Dragon dragon;
    Pet pet;
    std::vector<Field> fields;
    std::vector<Event> events;   // drained by the caller
    uint32_t rng = 11;           // LCG
    int next_handle = 1;
    std::string last_toast;
    int toasts = 0;
    bool enraged_seen = false, rematch_seen = false;
    Skill force_next = Skill::Nil;
};

void reset_fight(State& s, const Heightfield& hf);
void step(State& s, const Input& in, const Heightfield& hf);   // ONE 30 Hz tick
Input autopilot(const State& s, float cam_yaw);
uint64_t state_hash(const State& s);

// Gate: same outcomes the Godot selftest asserts. Returns empty string on pass.
std::string gate_missing(const State& s);

} // namespace rb
