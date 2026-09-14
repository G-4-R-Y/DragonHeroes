// dh-sim — the self-play ARENA sim (docs/design/23, docs/tech/25): a deterministic,
// allocation-free-after-reset 2-fighter combat core for RL training. This is the
// C++ twin of game/arena — same obs schema ("arena.obs.v1", 31 floats), same
// command semantics (move + act logits), same kits — tuned for >= 100k steps/s
// single-thread so PPO-grade sample volumes stop depending on Godot workers.
//
// Canon boundaries honored: no Godot, no I/O. Fighter stats and (optional) frozen
// opponent MLP weights are handed in by the caller; content lives in game/ and
// reaches us via ml/env/specs.json + the dh-env C API.
#pragma once

#include <array>
#include <cstdint>

#include <dh/math/rng.hpp>
#include <dh/math/vec2.hpp>

namespace dh::sim {

inline constexpr int kObsDim = 31;        // arena.obs.v1 — do not reorder
inline constexpr int kObsV2Dim = 36;      // arena.obs.v2: v1 + ally block [31..35]
inline constexpr int kActionLogits = 7;   // noop, attack, special, skill1..4
inline constexpr float kArenaDt = 1.0f / 60.0f;
inline constexpr float kArenaRadius = 26.0f * 16.0f;   // world_stub.gd ring (px)
inline constexpr std::uint32_t kMaxTicks = 60 * 60;    // 60 s episode cap

enum class KitId : int { kNone = 0, kBoltVolley, kRadialSlam, kPounce, kFieldCast, kEnrage };
// kStorm is a PROJECTILE element, never a ground field: storm bolts detonate
// mire fields (the conduct combo, canon §12.41).
enum class FieldKind : int { kFire = 0, kEarth, kMire, kLava, kStorm };
enum class OppPolicy : int { kNative = 0, kScripted, kMlp };

struct KitSpec {
    KitId id = KitId::kNone;
    float cd = 6.0f;
    float range = 7.0f * 16.0f;
    FieldKind field = FieldKind::kFire;   // field_cast payload; bolt tint otherwise
};

struct FighterSpec {
    float max_hp = 100.0f;
    float damage = 10.0f;
    float move_speed = 4.5f * 16.0f;   // px/s (creature.gd default)
    float attack_reach = 1.8f * 16.0f;
    float attack_cd = 1.2f;
    float body_radius = 8.0f;
    bool is_player = false;
    bool is_ranged = false;
    float special_cd = 6.0f;           // whirlwind/nova analog
    int dodge_max = 2;                 // 0 for creatures
    std::array<KitSpec, 4> kits{};
    int kit_count = 0;
};

// Learner command: move vector (clamped to unit length) + act id
// (0 noop, 1 attack, 2 special, 3..6 skill slots, 7 dodge).
struct Action {
    float move_x = 0.0f;
    float move_y = 0.0f;
    int act = 0;
};

class Arena {
  public:
    Arena(const FighterSpec& a, const FighterSpec& b, OppPolicy opp, std::uint64_t seed);
    // Squad mode: each side gets a buddy body (arena.obs.v2, 36 floats).
    Arena(const FighterSpec& a, const FighterSpec& a_buddy,
          const FighterSpec& b, const FighterSpec& b_buddy,
          OppPolicy opp, std::uint64_t seed);

    // Frozen opponent net (OppPolicy::kMlp): flat row-major weights + biases,
    // layer row sizes [in0,out0,in1,out1,...], and the 16-float embedding row
    // appended to the obs (policy_net.py layout: obs31 ++ emb16, tanh hidden).
    // Frozen-opponent MLP. Widest layer this accepts: kMlpMaxUnits. A net wider
    // than that is REJECTED (the opponent falls back to scripted) rather than
    // written past the forward pass's activation buffers — teacher-sized nets
    // (256x256, ml/training/distill.py) reach here through PPO self-play, and
    // a silent stack overwrite is the worst possible way to find that out.
    static constexpr int kMlpMaxUnits = 512;
    void set_opp_mlp(const float* params, const int* layer_in, const int* layer_out,
                     int n_layers, const float* emb16);
    bool has_opp_mlp() const { return mlp_params_ != nullptr && mlp_layers_ > 0; }

    void reset(std::uint64_t seed);
    bool step(const Action& act);        // true once the episode is done
    void obs(float* out) const;          // learner obs (31 or 36 by squad flag)
    int obs_dim() const { return squad_ ? kObsV2Dim : kObsDim; }
    int winner() const;                  // -1 undecided/draw, 0 = A, 1 = B
    bool done() const { return winner_ != -2; }
    float hp_frac(int who) const;
    std::uint64_t tick() const { return tick_; }
    std::uint64_t state_hash() const;    // determinism fingerprint (tests)

  private:
    struct Fighter {
        FighterSpec spec;
        math::Vec2 pos{}, vel{};
        float hp = 0.0f;
        float attack_cd = 0.0f, special_cd = 0.0f;
        float windup_t = 0.0f;           // > 0: telegraphing a melee hit
        float slow_t = 0.0f, burn_t = 0.0f, bleed_t = 0.0f, dot_dps = 0.0f;
        float enrage_t = 0.0f;
        float dodge_t = 0.0f;            // i-frames remaining
        int dodge_charges = 0;
        float dodge_regen = 0.0f;
        float kit_cd[4] = {0, 0, 0, 0};
        float kit_gate = 0.0f;           // native kit rate limit (0.4 s)
        // squad mode (arena.obs.v2): an optional second BODY — the buddy
        // (game/arena duo semantics: one fighter, two bodies, shared fate)
        bool has_buddy = false;
        FighterSpec buddy_spec{};
        math::Vec2 pos2{}, vel2{};
        float hp2 = 0.0f, attack_cd2 = 0.0f, windup2_t = 0.0f, slow2_t = 0.0f;
        bool alive() const { return hp > 0.0f || (has_buddy && hp2 > 0.0f); }
        float hp_frac() const {
            const float a = hp > 0.0f ? hp / spec.max_hp : 0.0f;
            if (!has_buddy) return a;
            const float b = hp2 > 0.0f ? hp2 / buddy_spec.max_hp : 0.0f;
            return (a + b) * 0.5f;
        }
    };
    struct Projectile {
        math::Vec2 pos{}, vel{};
        float damage = 0.0f, life = 0.0f;
        int owner = 0;
        FieldKind kind = FieldKind::kFire;
        bool alive = false;
    };
    struct Field {
        math::Vec2 pos{};
        float radius = 0.0f, until = 0.0f, tick = 0.0f, dps = 0.0f;
        FieldKind kind = FieldKind::kFire;
        int owner = 0;
        bool alive = false;
    };
    // Pending radial-slam resolutions (telegraph -> hit).
    struct Pending { float t = 0.0f; int who = 0; bool alive = false; };

    void build_obs(const Fighter& self, const Fighter& foe, float* out31) const;
    Action native_act(int who, float dt);
    Action scripted_act(int who, float dt);
    Action mlp_act(int who);
    void apply_action(int who, const Action& act);
    void exec_kit(int who, int slot);
    void melee_hit(int who);
    void buddy_tick(int who);            // squad buddy: chase + basic attack
    // nearest LIVING enemy body: position + radius + which body to hurt
    struct BodyRef { int fighter = 0; int body = 0; math::Vec2 pos{}; float radius = 8.0f; };
    BodyRef nearest_enemy_body(int who, math::Vec2 from) const;
    math::Vec2 self_body_pos(const Fighter& f) const;
    void hurt(const BodyRef& ref, float dmg);
    math::Vec2 clamp_disc(math::Vec2 p, float margin) const;
    float gauss();                       // Box-Muller on the policy stream

    Fighter f_[2];
    std::array<Projectile, 64> projectiles_{};
    std::array<Field, 16> fields_{};
    std::array<Pending, 8> pending_{};
    OppPolicy opp_policy_;
    bool squad_ = false;
    std::uint64_t tick_ = 0;
    int winner_ = -2;                    // -2 fighting, -1 draw, 0/1
    math::Pcg32 combat_rng_;
    math::Pcg32 policy_rng_;
    // scripted-policy state (per fighter, only index 1 used today)
    float strafe_dir_[2] = {1.0f, 1.0f};
    float strafe_t_[2] = {0.0f, 0.0f};
    float retreat_t_[2] = {0.0f, 0.0f};
    float delay_s_[2] = {0.2f, 0.2f};    // fairness obs delay, sampled per reset
    // frozen opponent MLP
    const float* mlp_params_ = nullptr;
    std::array<int, 8> mlp_in_{}, mlp_out_{};
    int mlp_layers_ = 0;
    float mlp_emb_[16] = {};
};

}  // namespace dh::sim
