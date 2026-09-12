// dh-sim arena — implementation. Faithful PORT of game/arena semantics, not a
// re-imagination: where the Godot side and this file disagree, the Godot arena
// stays the eval gate and this file is the bug. Coordinates are the arena's px
// frame (obs divides by 512 px, arena.obs.v1) — dh-sim World keeps canon meters.
#include <dh/sim/arena.hpp>

#include <cmath>
#include <cstring>

namespace dh::sim {
namespace {

constexpr float kTile = 16.0f;
constexpr float kBoltSpeed = 13.0f * kTile;
constexpr float kBoltLife = 3.0f;
constexpr float kSlamRadius = 2.2f * kTile;
constexpr float kSlamDelay = 0.45f;
constexpr float kFieldRadius = 2.5f * kTile;
constexpr float kFieldLife = 6.0f;
constexpr float kFieldTick = 0.25f;
constexpr float kWindup = 0.25f;
constexpr float kKitGate = 0.4f;
constexpr float kDodgeTime = 0.25f;
constexpr float kDodgeDash = 3.5f * kTile;
constexpr float kDodgeRegen = 4.0f;
constexpr float kAimNoise = 0.06f;    // policy.gd AIM_NOISE_RAD
constexpr float kPi = 3.14159265358979f;

float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

}  // namespace

Arena::Arena(const FighterSpec& a, const FighterSpec& b, OppPolicy opp,
             std::uint64_t seed)
    : opp_policy_(opp), combat_rng_(seed, 3), policy_rng_(seed, 5) {
    f_[0].spec = a;
    f_[1].spec = b;
    reset(seed);
}

Arena::Arena(const FighterSpec& a, const FighterSpec& a_buddy,
             const FighterSpec& b, const FighterSpec& b_buddy,
             OppPolicy opp, std::uint64_t seed)
    : opp_policy_(opp), squad_(true), combat_rng_(seed, 3), policy_rng_(seed, 5) {
    f_[0].spec = a;
    f_[0].has_buddy = true;
    f_[0].buddy_spec = a_buddy;
    f_[1].spec = b;
    f_[1].has_buddy = true;
    f_[1].buddy_spec = b_buddy;
    reset(seed);
}

// ---- squad body plumbing -----------------------------------------------------

math::Vec2 Arena::self_body_pos(const Fighter& f) const {
    return f.hp > 0.0f ? f.pos : f.pos2;
}

Arena::BodyRef Arena::nearest_enemy_body(int who, math::Vec2 from) const {
    const Fighter& foe = f_[1 - who];
    BodyRef best{1 - who, 0, foe.pos, foe.spec.body_radius};
    float best_d2 = 1e30f;
    if (foe.hp > 0.0f) {
        best_d2 = (foe.pos - from).length_sq();
    }
    if (foe.has_buddy && foe.hp2 > 0.0f) {
        const float d2 = (foe.pos2 - from).length_sq();
        if (foe.hp <= 0.0f || d2 < best_d2) {
            best = {1 - who, 1, foe.pos2, foe.buddy_spec.body_radius};
            best_d2 = d2;
        }
    } else if (foe.hp <= 0.0f) {
        best_d2 = 1e30f;   // no living body (caller guards foe.alive())
    }
    return best;
}

void Arena::hurt(const BodyRef& ref, float dmg) {
    Fighter& foe = f_[ref.fighter];
    if (ref.body == 0) foe.hp -= dmg;
    else foe.hp2 -= dmg;
}

void Arena::set_opp_mlp(const float* params, const int* layer_in,
                        const int* layer_out, int n_layers, const float* emb16) {
    mlp_params_ = params;
    mlp_layers_ = n_layers > 8 ? 8 : n_layers;
    for (int i = 0; i < mlp_layers_; ++i) {
        mlp_in_[i] = layer_in[i];
        mlp_out_[i] = layer_out[i];
    }
    if (emb16 != nullptr)
        std::memcpy(mlp_emb_, emb16, sizeof(mlp_emb_));
}

void Arena::reset(std::uint64_t seed) {
    const FighterSpec sa = f_[0].spec, sb = f_[1].spec;
    const FighterSpec ba = f_[0].buddy_spec, bb = f_[1].buddy_spec;
    const bool buddy_a = f_[0].has_buddy, buddy_b = f_[1].has_buddy;
    combat_rng_.reseed(seed, 3);
    policy_rng_.reseed(seed, 5);
    for (auto& p : projectiles_) p = Projectile{};
    for (auto& f : fields_) f = Field{};
    for (auto& p : pending_) p = Pending{};
    tick_ = 0;
    winner_ = -2;
    // symmetric spawns: ONE base angle, fighters opposite, 12.5 tiles out
    const float base_ang = policy_rng_.next_float() * 2.0f * kPi;
    for (int i = 0; i < 2; ++i) {
        f_[i] = Fighter{};
        f_[i].spec = i == 0 ? sa : sb;
        f_[i].hp = f_[i].spec.max_hp;
        f_[i].dodge_charges = f_[i].spec.dodge_max;
        f_[i].has_buddy = i == 0 ? buddy_a : buddy_b;
        f_[i].buddy_spec = i == 0 ? ba : bb;
        if (f_[i].has_buddy) f_[i].hp2 = f_[i].buddy_spec.max_hp;
        const float ang = base_ang + (i == 0 ? 0.0f : kPi);
        f_[i].pos = {std::cos(ang) * 12.5f * kTile, std::sin(ang) * 12.5f * kTile};
        f_[i].pos2 = f_[i].pos + math::Vec2{2.2f * kTile, 1.5f * kTile};
        delay_s_[i] = 0.15f + policy_rng_.next_float() * 0.10f;   // fairness
        strafe_t_[i] = retreat_t_[i] = 0.0f;
        strafe_dir_[i] = 1.0f;
    }
}

float Arena::gauss() {
    // Box-Muller on the policy stream (deterministic across platforms).
    const float u1 = 1.0f - policy_rng_.next_float();
    const float u2 = policy_rng_.next_float();
    return std::sqrt(-2.0f * std::log(u1)) * std::cos(2.0f * kPi * u2);
}

math::Vec2 Arena::clamp_disc(math::Vec2 p, float margin) const {
    const float max_r = kArenaRadius - margin;
    const float len = p.length();
    if (len > max_r && len > 0.0f)
        return p * (max_r / len);
    return p;
}

float Arena::hp_frac(int who) const { return f_[who].hp_frac(); }

int Arena::winner() const {
    if (winner_ == -2 && tick_ >= kMaxTicks) {
        const float a = f_[0].hp_frac(), b = f_[1].hp_frac();
        return std::fabs(a - b) < 0.001f ? -1 : (a > b ? 0 : 1);
    }
    return winner_ == -2 ? -2 : winner_;
}

// ---- policies ---------------------------------------------------------------
// Fairness (canon §9 §6): internal opponents read a DELAYED view of the world,
// exactly like the Godot policies. The learner's obs (dh_env_step out-param) is
// delayed the same way so training matches the eval gate's information state.

void Arena::build_obs(const Fighter& self, const Fighter& foe, float* o) const {
    const int dim = squad_ ? kObsV2Dim : kObsDim;   // caller's buffer is dim floats
    for (int i = 0; i < dim; ++i) o[i] = 0.0f;
    const math::Vec2 me = self_body_pos(self);
    o[0] = self.hp_frac();
    o[1] = clampf(me.x / 512.0f, -1.0f, 1.0f);
    o[2] = clampf(me.y / 512.0f, -1.0f, 1.0f);
    o[3] = clampf(self.vel.x / 100.0f, -2.0f, 2.0f);
    o[4] = clampf(self.vel.y / 100.0f, -2.0f, 2.0f);
    o[5] = clampf(self.attack_cd / self.spec.attack_cd, 0.0f, 1.0f);
    o[6] = clampf(self.special_cd / self.spec.special_cd, 0.0f, 1.0f);
    for (int i = 0; i < 4 && i < self.spec.kit_count; ++i)
        o[7 + i] = clampf(self.kit_cd[i] / self.spec.kits[i].cd, 0.0f, 1.0f);
    o[13] = self.slow_t > 0.0f ? 1.0f : 0.0f;
    o[14] = (self.burn_t > 0.0f || self.bleed_t > 0.0f) ? 1.0f : 0.0f;
    if (self.spec.is_player) {
        o[11] = 0.0f;  // combo charges are a Godot-player nuance: v1 keeps 0
        o[12] = self.spec.dodge_max > 0
                ? static_cast<float>(self.dodge_charges) /
                  static_cast<float>(self.spec.dodge_max) : 0.0f;
    }
    if (foe.alive()) {
        // aim at the foe's NEAREST living body (duo/squad targeting)
        const int who = static_cast<int>(&self - f_);
        const BodyRef tgt = nearest_enemy_body(who, me);
        const math::Vec2 rel = tgt.pos - me;
        const float dist = rel.length();
        o[15] = foe.hp_frac();
        o[16] = clampf(rel.x / 512.0f, -1.0f, 1.0f);
        o[17] = clampf(rel.y / 512.0f, -1.0f, 1.0f);
        o[18] = clampf(dist / 512.0f, 0.0f, 1.0f);
        if (dist > 0.01f) {
            const float ang = std::atan2(rel.y, rel.x);
            o[19] = std::sin(ang);
            o[20] = std::cos(ang);
        }
        o[21] = clampf(tgt.radius / 16.0f, 0.0f, 2.0f);
        o[22] = (tgt.body == 0 ? foe.windup_t : foe.windup2_t) > 0.0f ? 1.0f : 0.0f;
    }
    // squad: ally block [31..35] — own buddy (arena.obs.v2)
    if (squad_ && self.has_buddy) {
        o[31] = self.hp2 > 0.0f ? self.hp2 / self.buddy_spec.max_hp : 0.0f;
        const math::Vec2 rel2 = self.pos2 - me;
        o[32] = clampf(rel2.x / 512.0f, -1.0f, 1.0f);
        o[33] = clampf(rel2.y / 512.0f, -1.0f, 1.0f);
        o[34] = clampf(rel2.length() / 512.0f, 0.0f, 1.0f);
        o[35] = self.windup2_t > 0.0f ? 1.0f : 0.0f;
    }
    // two nearest hostile projectiles
    int slot = 0;
    float best_d2[2] = {1e30f, 1e30f};
    for (const auto& p : projectiles_) {
        if (!p.alive || p.owner == (&self - f_)) continue;
        const math::Vec2 rel = p.pos - me;
        const float d2 = rel.length_sq();
        if (slot < 2 && d2 < best_d2[slot]) {
            if (slot == 0 && d2 < best_d2[0]) { best_d2[1] = best_d2[0]; }
            best_d2[slot] = d2;
            o[23 + slot * 4] = clampf(rel.x / 512.0f, -1.0f, 1.0f);
            o[24 + slot * 4] = clampf(rel.y / 512.0f, -1.0f, 1.0f);
            o[25 + slot * 4] = clampf(p.vel.x / 256.0f, -2.0f, 2.0f);
            o[26 + slot * 4] = clampf(p.vel.y / 256.0f, -2.0f, 2.0f);
            ++slot;
        }
    }
}

Action Arena::native_act(int who, float /*dt*/) {
    // creature.gd essence: chase to reach, wind up, hit; kits off the rate gate.
    Action act{};
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    if (me.windup_t > 0.0f || !foe.alive() || me.hp <= 0.0f) return act;
    const BodyRef tgt = nearest_enemy_body(who, me.pos);
    const math::Vec2 to_foe = (tgt.pos - me.pos).normalized_or_zero();
    const float dist = (tgt.pos - me.pos).length();
    const float reach = me.spec.attack_reach + tgt.radius;
    if (me.spec.is_ranged) {
        // hold a 4-7 tile band, bolt on cooldown
        if (dist < 4.0f * kTile) act = {-to_foe.x, -to_foe.y, 0};
        else if (dist > 7.0f * kTile) act = {to_foe.x, to_foe.y, 0};
        if (me.attack_cd <= 0.0f && dist < 9.0f * kTile) act.act = 1;
    } else {
        if (dist > reach * 0.85f) act = {to_foe.x, to_foe.y, 0};
        if (me.attack_cd <= 0.0f && dist <= reach) act.act = 1;
    }
    // kits off cooldown, range-checked (fighter.gd's native driver)
    if (act.act == 0 && me.kit_gate <= 0.0f) {
        for (int i = 0; i < me.spec.kit_count; ++i) {
            if (me.kit_cd[i] <= 0.0f && dist <= me.spec.kits[i].range) {
                act.act = 3 + i;
                break;
            }
        }
    }
    return act;
}

Action Arena::scripted_act(int who, float dt) {
    // Port of scripted_policy.gd (the R1 baseline), same decision order.
    Action act{};
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    if (!foe.alive() || me.windup_t > 0.0f || me.hp <= 0.0f) return act;
    strafe_t_[who] -= dt;
    if (strafe_t_[who] <= 0.0f) {
        strafe_t_[who] = 0.8f + policy_rng_.next_float() * 0.8f;
        strafe_dir_[who] = policy_rng_.next_float() < 0.5f ? -1.0f : 1.0f;
    }
    if (me.hp_frac() < 0.25f && retreat_t_[who] <= 0.0f) retreat_t_[who] = 2.5f;
    retreat_t_[who] = retreat_t_[who] > dt ? retreat_t_[who] - dt : 0.0f;
    const BodyRef tgt = nearest_enemy_body(who, me.pos);
    const math::Vec2 to_foe = (tgt.pos - me.pos).normalized_or_zero();
    const float dist = (tgt.pos - me.pos).length();
    // dodge a close windup
    const float foe_windup = tgt.body == 0 ? foe.windup_t : foe.windup2_t;
    if (foe_windup > 0.0f && dist < 3.0f * kTile && me.dodge_charges > 0) {
        act = {-to_foe.x, -to_foe.y, 7};
        return act;
    }
    float band_lo = 0.5f * me.spec.attack_reach, band_hi = me.spec.attack_reach;
    if (me.spec.is_ranged) { band_lo = 4.0f * kTile; band_hi = 7.0f * kTile; }
    if (retreat_t_[who] > 0.0f) act = {-to_foe.x, -to_foe.y, 0};
    else if (dist > band_hi) act = {to_foe.x, to_foe.y, 0};
    else if (dist < band_lo) act = {-to_foe.x, -to_foe.y, 0};
    else {
        const math::Vec2 strafe{-to_foe.y * strafe_dir_[who], to_foe.x * strafe_dir_[who]};
        act = {strafe.x * 0.7f, strafe.y * 0.7f, 0};
    }
    // skills -> special -> attack, in range
    for (int i = 0; i < me.spec.kit_count; ++i) {
        if (me.kit_cd[i] <= 0.0f && dist < 6.0f * kTile) { act.act = 3 + i; return act; }
    }
    if (me.special_cd <= 0.0f && dist < band_hi + kTile) { act.act = 2; return act; }
    if (me.attack_cd <= 0.0f &&
        ((!me.spec.is_ranged && dist < band_hi + 8.0f) ||
         (me.spec.is_ranged && dist < 9.0f * kTile)))
        act.act = 1;
    return act;
}

Action Arena::mlp_act(int who) {
    Action act{};
    if (mlp_params_ == nullptr || mlp_layers_ <= 0 || squad_)
        return scripted_act(who, kArenaDt);   // squad: MLP opp unsupported (obs v2)
    float buf_a[96], buf_b[96];
    build_obs(f_[who], f_[1 - who], buf_a);
    std::memcpy(buf_a + kObsDim, mlp_emb_, sizeof(mlp_emb_));
    // forward: tanh hidden layers, linear head [move2, logits7, dodge1].
    // Param packing (dh_env.cpp contract): per layer [W row-major out×in][b out].
    const float* w = mlp_params_;
    const float* src = buf_a;
    float* dst = buf_b;
    int src_n = mlp_in_[0];
    for (int l = 0; l < mlp_layers_; ++l) {
        const int rows = mlp_out_[l];
        const bool tanh_act = (l < mlp_layers_ - 1);
        const float* bias = w + rows * src_n;
        for (int r = 0; r < rows; ++r) {
            float s = bias[r];
            for (int c = 0; c < src_n; ++c) s += w[r * src_n + c] * src[c];
            dst[r] = tanh_act ? std::tanh(s) : s;
        }
        w += rows * src_n + rows;
        src = dst;
        dst = (dst == buf_b) ? buf_a : buf_b;
        src_n = rows;
    }
    act.move_x = clampf(src[0], -1.0f, 1.0f);
    act.move_y = clampf(src[1], -1.0f, 1.0f);
    int best = 0;
    for (int i = 1; i < kActionLogits; ++i)
        if (src[2 + i] > src[2 + best]) best = i;
    act.act = best;
    return act;
}

// ---- combat -----------------------------------------------------------------

void Arena::melee_hit(int who) {
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    const BodyRef tgt = nearest_enemy_body(who, me.pos);
    const float reach = me.spec.attack_reach + tgt.radius + 0.3f * kTile;
    if (!foe.alive() || (tgt.pos - me.pos).length() > reach) return;
    if (foe.dodge_t > 0.0f) return;    // i-frames
    float dmg = me.spec.damage;
    if (me.enrage_t > 0.0f) dmg *= 1.5f;
    if (me.spec.is_ranged) {
        // ranged basic = a single bolt instead of a contact hit
        for (auto& p : projectiles_) {
            if (p.alive) continue;
            const math::Vec2 dir = (tgt.pos - me.pos).normalized_or_zero();
            p = Projectile{me.pos, dir * kBoltSpeed, dmg, kBoltLife, who,
                           FieldKind::kFire, true};
            return;
        }
        return;
    }
    hurt(tgt, dmg);
}

void Arena::exec_kit(int who, int slot) {
    Fighter& me = f_[who];
    const KitSpec& kit = me.spec.kits[slot];
    me.kit_cd[slot] = kit.cd;
    me.kit_gate = kKitGate;
    const float dmg_mul = me.enrage_t > 0.0f ? 1.5f : 1.0f;
    const BodyRef tgt = nearest_enemy_body(who, me.pos);
    switch (kit.id) {
        case KitId::kBoltVolley: {
            const math::Vec2 base = (tgt.pos - me.pos).normalized_or_zero();
            for (int j = 0; j < 3; ++j) {
                for (auto& p : projectiles_) {
                    if (p.alive) continue;
                    const float ang = (-12.0f + 12.0f * static_cast<float>(j)) *
                                      kPi / 180.0f + gauss() * kAimNoise;
                    const math::Vec2 dir{base.x * std::cos(ang) - base.y * std::sin(ang),
                                         base.x * std::sin(ang) + base.y * std::cos(ang)};
                    p = Projectile{me.pos, dir * kBoltSpeed,
                                   me.spec.damage * 0.8f * dmg_mul, kBoltLife,
                                   who, kit.field, true};
                    break;
                }
            }
            break;
        }
        case KitId::kRadialSlam:
            for (auto& pd : pending_) {
                if (pd.alive) continue;
                pd = Pending{kSlamDelay, who, true};
                break;
            }
            break;
        case KitId::kPounce: {
            const math::Vec2 dir = (tgt.pos - me.pos).normalized_or_zero();
            me.pos = clamp_disc(me.pos + dir * 3.0f * kTile, me.spec.body_radius);
            const float reach = me.spec.attack_reach + tgt.radius;
            Fighter& foe = f_[1 - who];
            if (foe.alive() && foe.dodge_t <= 0.0f &&
                (tgt.pos - me.pos).length() <= reach)
                hurt(tgt, me.spec.damage * dmg_mul);
            break;
        }
        case KitId::kFieldCast: {
            // fire cast onto an earth field fuses into lava (arena.gd parity)
            if (kit.field == FieldKind::kFire) {
                for (auto& g : fields_) {
                    if (g.alive && g.kind == FieldKind::kEarth &&
                        (g.pos - tgt.pos).length() < (g.radius + kFieldRadius) * 0.75f) {
                        g.kind = FieldKind::kLava;
                        g.dps += me.spec.damage * 0.3f;
                        return;
                    }
                }
            }
            for (auto& f : fields_) {
                if (f.alive) continue;
                f = Field{tgt.pos, kFieldRadius, kFieldLife, 0.0f,
                          me.spec.damage * 0.3f * dmg_mul, kit.field, who, true};
                break;
            }
            break;
        }
        case KitId::kEnrage:
            me.enrage_t = 4.0f;
            break;
        default:
            break;
    }
}

void Arena::buddy_tick(int who) {
    // Squad buddy: an autonomous melee body — chase the nearest enemy body,
    // wind up, strike. No kits of its own (the pack's bruiser, not its brain).
    Fighter& me = f_[who];
    if (!me.has_buddy || me.hp2 <= 0.0f) return;
    Fighter& foe = f_[1 - who];
    if (!foe.alive()) return;
    if (me.windup2_t > 0.0f) {
        me.windup2_t -= kArenaDt;
        if (me.windup2_t <= 0.0f) {
            const BodyRef tgt = nearest_enemy_body(who, me.pos2);
            const float reach = me.buddy_spec.attack_reach + tgt.radius + 0.3f * kTile;
            if (foe.dodge_t <= 0.0f && (tgt.pos - me.pos2).length() <= reach)
                hurt(tgt, me.buddy_spec.damage);
        }
        return;
    }
    const BodyRef tgt = nearest_enemy_body(who, me.pos2);
    const math::Vec2 to_foe = (tgt.pos - me.pos2).normalized_or_zero();
    const float dist = (tgt.pos - me.pos2).length();
    const float reach = me.buddy_spec.attack_reach + tgt.radius;
    if (dist > reach * 0.85f) {
        float speed = me.buddy_spec.move_speed;
        if (me.slow2_t > 0.0f) speed *= 0.65f;
        me.pos2 = clamp_disc(me.pos2 + to_foe * (speed * kArenaDt),
                             me.buddy_spec.body_radius);
    } else if (me.attack_cd2 <= 0.0f) {
        me.windup2_t = kWindup;
        me.attack_cd2 = me.buddy_spec.attack_cd;
    }
    me.attack_cd2 = me.attack_cd2 > kArenaDt ? me.attack_cd2 - kArenaDt : 0.0f;
    me.slow2_t = me.slow2_t > kArenaDt ? me.slow2_t - kArenaDt : 0.0f;
}

void Arena::apply_action(int who, const Action& act) {
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    if (me.hp <= 0.0f) return;   // a fallen primary acts no more (buddy is autonomous)
    // movement (slow 35%, enrage haste 30%) — applied here; dash acts below
    float speed = me.spec.move_speed;
    if (me.slow_t > 0.0f) speed *= 0.65f;
    if (me.enrage_t > 0.0f) speed *= 1.3f;
    math::Vec2 mv{act.move_x, act.move_y};
    const float ml = mv.length();
    if (ml > 1.0f) mv = mv * (1.0f / ml);
    if (me.windup_t <= 0.0f)
        me.pos = clamp_disc(me.pos + mv * (speed * kArenaDt), me.spec.body_radius);
    switch (act.act) {
        case 1:
            if (me.attack_cd <= 0.0f && me.windup_t <= 0.0f) {
                if (me.spec.is_ranged) { melee_hit(who); me.attack_cd = me.spec.attack_cd; }
                else { me.windup_t = kWindup; me.attack_cd = me.spec.attack_cd; }
            }
            break;
        case 2:
            if (me.special_cd <= 0.0f) {
                me.special_cd = me.spec.special_cd;
                const BodyRef tgt = nearest_enemy_body(who, me.pos);
                const float r = kSlamRadius + tgt.radius;
                if (foe.alive() && foe.dodge_t <= 0.0f &&
                    (tgt.pos - me.pos).length() <= r)
                    hurt(tgt, me.spec.damage * 1.2f *
                         (me.enrage_t > 0.0f ? 1.5f : 1.0f));
            }
            break;
        case 3: case 4: case 5: case 6: {
            const int slot = act.act - 3;
            if (slot < me.spec.kit_count && me.kit_cd[slot] <= 0.0f)
                exec_kit(who, slot);
            break;
        }
        case 7:
            if (me.dodge_charges > 0 && me.dodge_t <= 0.0f) {
                --me.dodge_charges;
                me.dodge_t = kDodgeTime;
                const math::Vec2 dir = ml > 0.01f ? mv * (1.0f / (ml > 1.0f ? 1.0f : 1.0f))
                                       : (me.pos - foe.pos).normalized_or_zero();
                me.pos = clamp_disc(me.pos + dir.normalized_or_zero() * kDodgeDash,
                                    me.spec.body_radius);
            }
            break;
        default:
            break;
    }
}

bool Arena::step(const Action& learner_act) {
    if (done()) return true;
    const math::Vec2 prev[2] = {f_[0].pos, f_[1].pos};
    const math::Vec2 prev2[2] = {f_[0].pos2, f_[1].pos2};
    // 1. opponent mind, then both act (the learner is fighter 0)
    Action opp{};
    switch (opp_policy_) {
        case OppPolicy::kNative:   opp = native_act(1, kArenaDt); break;
        case OppPolicy::kScripted: opp = scripted_act(1, kArenaDt); break;
        case OppPolicy::kMlp:      opp = mlp_act(1); break;
    }
    apply_action(0, learner_act);
    apply_action(1, opp);
    buddy_tick(0);
    buddy_tick(1);
    // 2. windups resolve into hits
    for (int i = 0; i < 2; ++i) {
        if (f_[i].windup_t > 0.0f) {
            f_[i].windup_t -= kArenaDt;
            if (f_[i].windup_t <= 0.0f) melee_hit(i);
        }
    }
    // 3. pending slams
    for (auto& pd : pending_) {
        if (!pd.alive) continue;
        pd.t -= kArenaDt;
        if (pd.t > 0.0f) continue;
        pd.alive = false;
        Fighter& me = f_[pd.who];
        Fighter& foe = f_[1 - pd.who];
        const BodyRef tgt = nearest_enemy_body(pd.who, me.pos);
        const float r = kSlamRadius + tgt.radius;
        if (foe.alive() && foe.dodge_t <= 0.0f &&
            (tgt.pos - me.pos).length() <= r)
            hurt(tgt, me.spec.damage * 1.5f * (me.enrage_t > 0.0f ? 1.5f : 1.0f));
    }
    // 4. projectiles (storm bolts DETONATE mire fields: conduct combo §12.41)
    for (auto& p : projectiles_) {
        if (!p.alive) continue;
        p.pos += p.vel * kArenaDt;
        p.life -= kArenaDt;
        if (p.life <= 0.0f || p.pos.length() > kArenaRadius + kTile) { p.alive = false; continue; }
        if (p.kind == FieldKind::kStorm) {
            for (auto& f : fields_) {
                if (!f.alive || f.kind != FieldKind::kMire) continue;
                if ((p.pos - f.pos).length() > f.radius) continue;
                // burst: field owner's enemy takes 2x bolt damage in 1.5x radius
                Fighter& victim = f_[1 - f.owner];
                if (victim.alive() && victim.dodge_t <= 0.0f &&
                    (victim.pos - f.pos).length() <= f.radius * 1.5f)
                    victim.hp -= p.damage * 2.0f;
                f.alive = false;   // the field is consumed
                p.alive = false;
                break;
            }
            if (!p.alive) continue;
        }
        Fighter& foe = f_[1 - p.owner];
        if (foe.alive() && foe.dodge_t <= 0.0f) {
            const BodyRef tgt = nearest_enemy_body(p.owner, p.pos);
            if ((tgt.pos - p.pos).length() <= tgt.radius + 2.0f) {
                hurt(tgt, p.damage);
                p.alive = false;
            }
        }
    }
    // 5. fields (owner-exempt; mire slows; contact refreshes the DoT flag)
    for (auto& f : fields_) {
        if (!f.alive) continue;
        f.until -= kArenaDt;
        if (f.until <= 0.0f) { f.alive = false; continue; }
        f.tick -= kArenaDt;
        if (f.tick > 0.0f) continue;
        f.tick = kFieldTick;
        Fighter& foe = f_[1 - f.owner];
        // fields hit EVERY enemy body inside (squad: the pack shares the ground)
        for (int body = 0; body < 2; ++body) {
            if (body == 1 && !foe.has_buddy) break;
            const math::Vec2 bpos = body == 0 ? foe.pos : foe.pos2;
            const float brad = body == 0 ? foe.spec.body_radius
                                         : foe.buddy_spec.body_radius;
            const float bhp = body == 0 ? foe.hp : foe.hp2;
            if (bhp <= 0.0f || (bpos - f.pos).length() >= f.radius + brad) continue;
            if (f.dps > 0.0f) {
                if (body == 0) { foe.hp -= f.dps * kFieldTick; foe.burn_t = 0.5f; }
                else foe.hp2 -= f.dps * kFieldTick;
            }
            if (f.kind == FieldKind::kMire) {
                if (body == 0) foe.slow_t = 0.5f;
                else foe.slow2_t = 0.5f;
            }
        }
    }
    // 6. timers
    for (int i = 0; i < 2; ++i) {
        Fighter& me = f_[i];
        me.attack_cd = me.attack_cd > kArenaDt ? me.attack_cd - kArenaDt : 0.0f;
        me.special_cd = me.special_cd > kArenaDt ? me.special_cd - kArenaDt : 0.0f;
        me.slow_t = me.slow_t > kArenaDt ? me.slow_t - kArenaDt : 0.0f;
        me.burn_t = me.burn_t > kArenaDt ? me.burn_t - kArenaDt : 0.0f;
        me.enrage_t = me.enrage_t > kArenaDt ? me.enrage_t - kArenaDt : 0.0f;
        me.dodge_t = me.dodge_t > kArenaDt ? me.dodge_t - kArenaDt : 0.0f;
        me.kit_gate = me.kit_gate > kArenaDt ? me.kit_gate - kArenaDt : 0.0f;
        for (int k = 0; k < 4; ++k)
            me.kit_cd[k] = me.kit_cd[k] > kArenaDt ? me.kit_cd[k] - kArenaDt : 0.0f;
        if (me.dodge_charges < me.spec.dodge_max) {
            me.dodge_regen += kArenaDt;
            if (me.dodge_regen >= kDodgeRegen) { me.dodge_regen = 0.0f; ++me.dodge_charges; }
        }
    }
    // 7. velocities for the obs (from actual movement this tick)
    for (int i = 0; i < 2; ++i) {
        f_[i].vel = (f_[i].pos - prev[i]) * (1.0f / kArenaDt);
        f_[i].vel2 = (f_[i].pos2 - prev2[i]) * (1.0f / kArenaDt);
    }
    ++tick_;
    // 8. outcome
    if (!f_[0].alive() || !f_[1].alive())
        winner_ = f_[0].alive() ? 0 : (f_[1].alive() ? 1 : -1);
    else if (tick_ >= kMaxTicks) {
        const float a = f_[0].hp_frac(), b = f_[1].hp_frac();
        winner_ = std::fabs(a - b) < 0.001f ? -1 : (a > b ? 0 : 1);
    }
    return done();
}

void Arena::obs(float* out31) const {
    build_obs(f_[0], f_[1], out31);
}

std::uint64_t Arena::state_hash() const {
    // FNV-1a over the full combat state — the determinism fingerprint.
    std::uint64_t h = 0xcbf29ce484222325ULL;
    const auto mix_bytes = [&h](const void* p, std::size_t n) {
        const auto* b = static_cast<const unsigned char*>(p);
        for (std::size_t i = 0; i < n; ++i) { h ^= b[i]; h *= 0x100000001b3ULL; }
    };
    mix_bytes(&tick_, sizeof(tick_));
    for (const auto& f : f_) {
        mix_bytes(&f.pos, sizeof(f.pos));
        mix_bytes(&f.hp, sizeof(f.hp));
        mix_bytes(&f.attack_cd, sizeof(f.attack_cd));
        mix_bytes(&f.windup_t, sizeof(f.windup_t));
    }
    for (const auto& p : projectiles_)
        if (p.alive) mix_bytes(&p.pos, sizeof(p.pos));
    return h;
}

}  // namespace dh::sim
