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
// creature.gd::windup_time. Was 0.25 here until 2026-09-14 — a telegraph
// 100 ms shorter than the one the shipping game draws, which is 100 ms of
// dodge window the learner never had to find.
// R55 (2026-09-19) made the telegraph per body: the live value is
// BodySpec::windup_time (arena.hpp), which still DEFAULTS to this 0.35 f,
// so the number below is the default's provenance, not dead weight.
// Commented rather than deleted: clang's -Wunused-const-variable + -Werror
// broke the mingw cross-build on it (2026-09-22), and gcc stayed quiet, so
// the Linux build never noticed the constant had gone unused.
// constexpr float kWindup = 0.35f;
// creature.gd::_strike: `_state = "recover"; _timer = 0.4` — the built-in mind
// neither chases nor swings until it runs out (R55, 2026-09-19).
constexpr float kRecover = 0.4f;
constexpr float kKnockback = 6.0f;    // creature.gd::take_damage nudge
constexpr float kKitGate = 0.4f;
constexpr float kDodgeTime = 0.25f;
constexpr float kDodgeDash = 3.5f * kTile;
constexpr float kDodgeRegen = 4.0f;
constexpr float kAimNoise = 0.06f;    // policy.gd AIM_NOISE_RAD
constexpr float kPi = 3.14159265358979f;
// R59 (2026-09-21): creature.gd::_separate — body separation. Each creature
// pushes only ITSELF out of an overlap, so two creatures resolve symmetrically
// (both run it) and creature-vs-player is one-sided: ProtoPlayer has no
// _separate, and the hero must never be shoved out of his own swing.
constexpr float kSeparateRate = 4.0f;          // /s, creature vs creature
constexpr float kSeparateRatePlayer = 12.0f;   // /s, creature vs a player body

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

void Arena::hurt(const BodyRef& ref, float dmg, math::Vec2 from_dir, DmgSource src) {
    Fighter& foe = f_[ref.fighter];
    // KNOCKBACK. creature.gd::take_damage ends with `_move(from_dir * 6.0)`,
    // so in the shipping game every landed hit shoves the victim 6 px away and
    // the attacker has to re-close before the next swing. The sim had none, so
    // its duellists stayed glued together and traded faster than the arena's —
    // part of why a dh-env episode ended in 27 s where the arena's ran 40.
    if (from_dir.length() > 0.0f) {
        const math::Vec2 d = from_dir.normalized_or_zero();
        if (ref.body == 0)
            foe.pos = clamp_disc(foe.pos + d * kKnockback, foe.spec.body_radius);
        else
            foe.pos2 = clamp_disc(foe.pos2 + d * kKnockback, foe.buddy_spec.body_radius);
    }
    // Every damage packet in the arena goes through here, so the tally below is
    // exhaustive by construction rather than by the caller remembering. Only
    // the accounting is conditional: a packet landing on a body that is already
    // down is still applied (changing that would change the dynamics and the
    // determinism hash) but is not counted, matching game/arena/proxy.gd, which
    // returns early on `dead`.
    const int si = static_cast<int>(src);
    if (ref.body == 0) {
        if (foe.hp > 0.0f) { damage_taken_[ref.fighter] += dmg; damage_by_source_[ref.fighter][si] += dmg; }
        foe.hp -= dmg;
    } else {
        if (foe.hp2 > 0.0f) { damage_taken_[ref.fighter] += dmg; damage_by_source_[ref.fighter][si] += dmg; }
        foe.hp2 -= dmg;
    }
}

void Arena::set_opp_mlp(const float* params, const int* layer_in,
                        const int* layer_out, int n_layers, const float* emb16,
                        const int* acts) {
    const int layers = n_layers > 8 ? 8 : n_layers;
    for (int i = 0; i < layers; ++i) {
        if (layer_in[i] > kMlpMaxUnits || layer_out[i] > kMlpMaxUnits) {
            mlp_params_ = nullptr;      // too wide: refuse, do not truncate
            mlp_layers_ = 0;            // mlp_act() then falls back to scripted
            return;
        }
    }
    mlp_params_ = params;
    mlp_layers_ = layers;
    for (int i = 0; i < mlp_layers_; ++i) {
        mlp_in_[i] = layer_in[i];
        mlp_out_[i] = layer_out[i];
        // No acts array = the historical shape: tanh hidden, linear head.
        mlp_acts_[i] = acts != nullptr ? acts[i]
                                       : (i < mlp_layers_ - 1 ? kActTanh : kActLinear);
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
    damage_taken_[0] = damage_taken_[1] = 0.0f;
    for (auto& row : damage_by_source_) for (auto& v : row) v = 0.0f;
    last_commit_[0] = last_commit_[1] = -1;
    obs_log_n_ = 0;                 // the fairness ring starts empty each episode
    commit_n_[0] = commit_n_[1] = 0;
    for (int i = 0; i < 2; ++i)
        for (int j = 0; j < kActionBudget; ++j) commit_t_[i][j] = -kBudgetWindow;
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
        // Draw FIRST, override after: an ablation that skipped the draw would
        // shift the whole policy RNG stream and the two runs would differ by
        // more than the delay, which is the one thing being measured.
        const float sampled = 0.15f + policy_rng_.next_float() * 0.10f;
        delay_s_[i] = delay_override_ >= 0.0f ? delay_override_ : sampled;
        strafe_t_[i] = retreat_t_[i] = 0.0f;
        strafe_dir_[i] = 1.0f;
    }
    push_fairness_frame();   // tick 0 exists before the first step asks for it
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
    // creature.gd's built-in mind (_chase -> windup -> recover) plus
    // fighter.gd::pre_tick's native kit driver. Neither is a policy: creature.gd
    // chases `target_override.global_position` straight off the scene tree and
    // the arena's 150-250 ms observation delay (policy.gd::delayed_obs) exists
    // only for ArenaPolicy minds — so this reads the LIVE state, not percept().
    //
    // R55 (2026-09-19). The previous port (kept below, commented) decided on the
    // stale percept, swung from `attack_reach + foe_radius` where creature.gd
    // swings from `attack_reach * 0.9`, knew neither the lunger pounce nor the
    // brute slam nor the 0.4 s recover, and fired kits only on ticks it was not
    // swinging. Measured on the converged nets (tech/39 §2): drake, serpent and
    // shade natives hit 2-3x harder in the arena than here.
    Action act{};
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    if (!foe.alive() || me.hp <= 0.0f) return act;
    if (me.windup_t <= 0.0f) me.pounce_pending = false;   // a pounce lives only inside its windup
    const BodyRef tgt = nearest_enemy_body(who, me.pos);
    const math::Vec2 to = tgt.pos - me.pos;
    const float dist = to.length();
    const math::Vec2 to_foe = to.normalized_or_zero();
    // _state "windup" and "recover" only tick their timers: no chase, no swing.
    const bool frozen = me.windup_t > 0.0f || me.recover_t > 0.0f;
    if (!frozen) {
        if (me.spec.is_ranged) {
            // wisp.gd: hold a 4-7 tile band, bolt on cooldown
            if (dist < 4.0f * kTile) act = {-to_foe.x, -to_foe.y, 0};
            else if (dist > 7.0f * kTile) act = {to_foe.x, to_foe.y, 0};
            if (me.attack_cd <= 0.0f && dist < 9.0f * kTile) act.act = 1;
        } else if (me.spec.archetype == Archetype::kLunger && me.attack_cd <= 0.0f &&
                   dist >= 2.5f * kTile && dist <= 5.5f * kTile) {
            // creature.gd::_chase, lunger: leap onto the target from mid-range —
            // the windup flash IS the tell; _strike dashes onto _pounce_target.
            me.pounce_pending = true;
            me.pounce_target = tgt.pos;
            act.act = 1;
        } else if (dist <= me.spec.attack_reach * 0.9f && me.attack_cd <= 0.0f) {
            act.act = 1;                       // _begin_windup(to_player.normalized())
        } else {
            act = {to_foe.x, to_foe.y, 0};     // _move(to_player.normalized() * _speed() * delta)
        }
    }
    // fighter.gd::pre_tick native kit driver — a SEPARATE CHANNEL from the
    // body's state machine. pre_tick fires the first ready kit whose range
    // covers the LIVE distance every frame, whatever the body is doing (mid
    // windup, mid recover, mid swing), then holds a 0.4 s gate (_kit_fire_t).
    //
    // R55-b (2026-09-21): this used to write the kit into the returned Action,
    // where it COMPETED with the swing for the single act slot and, worse, was
    // never reached at all on a frozen frame — and a knife-fighting body is
    // frozen for windup 0.22 s + recover 0.4 s of every 1.12 s cycle, 55% of
    // them. Measured on the converged drake: the native opponent's bolt damage
    // in dh-env was HALF the arena's (30.9 vs 58.2 per 10 s). Fire it here, on
    // its own channel, and leave `act` to the body:
    //     if (me.kit_gate <= 0.0f) {
    //         for (int i = 0; i < me.spec.kit_count; ++i) {
    //             if (me.kit_cd[i] <= 0.0f && dist <= me.spec.kits[i].range) {
    //                 if (act.act == 1) me.pounce_pending = false;
    //                 act.act = 3 + i;
    //                 break;
    //             }
    //         }
    //     }
    if (me.kit_gate <= 0.0f) {
        for (int i = 0; i < me.spec.kit_count; ++i) {
            if (me.kit_cd[i] <= 0.0f && dist <= me.spec.kits[i].range) {
                exec_kit(who, i);      // sets kit_cd[i] AND the 0.4 s gate
                break;
            }
        }
    }
    return act;
}

// ---- the pre-R55 native port, for the diff (see the note in native_act) ----
// Action Arena::native_act(int who, float /*dt*/) {
//     // creature.gd essence: chase to reach, wind up, hit; kits off the rate gate.
//     Action act{};
//     Fighter& me = f_[who];
//     Fighter& foe = f_[1 - who];
//     if (me.windup_t > 0.0f || !foe.alive() || me.hp <= 0.0f) return act;
//     // FAIRNESS: decide on the stale view, not on f_[]. Own state (windup,
//     // cooldowns, position) stays live — fighter.gd's cmd_* resolve live too.
//     const Percept p = percept(who);
//     const math::Vec2 to_foe = (p.foe_pos - me.pos).normalized_or_zero();
//     const float dist = p.foe_dist;
//     const float reach = me.spec.attack_reach + p.foe_radius;
//     if (me.spec.is_ranged) {
//         // hold a 4-7 tile band, bolt on cooldown
//         if (dist < 4.0f * kTile) act = {-to_foe.x, -to_foe.y, 0};
//         else if (dist > 7.0f * kTile) act = {to_foe.x, to_foe.y, 0};
//         if (me.attack_cd <= 0.0f && dist < 9.0f * kTile) act.act = 1;
//     } else {
//         if (dist > reach * 0.85f) act = {to_foe.x, to_foe.y, 0};
//         if (me.attack_cd <= 0.0f && dist <= reach) act.act = 1;
//     }
//     // kits off cooldown, range-checked (fighter.gd's native driver)
//     if (act.act == 0 && me.kit_gate <= 0.0f) {
//         for (int i = 0; i < me.spec.kit_count; ++i) {
//             if (me.kit_cd[i] <= 0.0f && dist <= me.spec.kits[i].range) {
//                 act.act = 3 + i;
//                 break;
//             }
//         }
//     }
//     return act;
// }
//
Action Arena::scripted_act(int who, float dt) {
    // Port of scripted_policy.gd (the R1 baseline), same decision order.
    Action act{};
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    // R55 (2026-09-19): a policy-driven body keeps WALKING through its own
    // windup — fighter.gd::pre_tick moves it before creature.gd ticks _state,
    // and scripted_policy.gd issues cmd_move every frame; only cmd_attack /
    // cmd_special are refused meanwhile (bot_attack: `_state == "windup"`),
    // which apply_action enforces. This returned an empty Action for the whole
    // telegraph, freezing the body 0.35 s per swing:
    // if (!foe.alive() || me.windup_t > 0.0f || me.hp <= 0.0f) return act;
    if (!foe.alive() || me.hp <= 0.0f) return act;
    const Percept p = percept(who);      // FAIRNESS: the stale view, as above
    strafe_t_[who] -= dt;
    if (strafe_t_[who] <= 0.0f) {
        strafe_t_[who] = 0.8f + policy_rng_.next_float() * 0.8f;
        strafe_dir_[who] = policy_rng_.next_float() < 0.5f ? -1.0f : 1.0f;
    }
    if (p.self_hp_frac < 0.25f && retreat_t_[who] <= 0.0f) retreat_t_[who] = 2.5f;
    retreat_t_[who] = retreat_t_[who] > dt ? retreat_t_[who] - dt : 0.0f;
    const math::Vec2 to_foe = (p.foe_pos - me.pos).normalized_or_zero();
    const float dist = p.foe_dist;
    // dodge a close windup — the reaction is gated by the delay, which is the
    // entire point: 200 ms is most of kWindup, so a telegraph seen this late
    // is a telegraph half spent.
    const float foe_windup = p.foe_windup;
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

void Arena::action_mask(const float* o, int kit_count, bool is_player,
                        bool allowed[kActionLogits]) {
    // A cooldown fraction is EXACTLY 0.0f when ready (build_obs clamps
    // cd / spec_cd at 0), so <= 0 is the test in every runtime.
    const bool attack_ready = o[5] <= 0.0f;
    allowed[0] = true;
    allowed[1] = attack_ready;
    // fighter.gd::cmd_special sends a creature's "special" to bot_attack — one
    // more basic swing on the basic cooldown; only a geared player has o[6].
    allowed[2] = is_player ? (o[6] <= 0.0f) : attack_ready;
    for (int k = 0; k < 4; ++k)
        allowed[3 + k] = k < kit_count && o[7 + k] <= 0.0f;
}

Action Arena::mlp_act(int who) {
    Action act{};
    if (mlp_params_ == nullptr || mlp_layers_ <= 0 || squad_)
        return scripted_act(who, kArenaDt);   // squad: MLP opp unsupported (obs v2)
    // Sized by kMlpMaxUnits, not by the shipping net: set_opp_mlp refuses
    // anything wider, so the loop below can never run past these.
    float buf_a[kMlpMaxUnits], buf_b[kMlpMaxUnits];
    // FAIRNESS: a frozen net opponent reads the same stale world its live twin
    // reads through obs(). who==1 here, so this is the mirror of obs()'s frame.
    if (obs_log_n_ > 0) {
        const float now = static_cast<float>(tick_) * kArenaDt;
        const float* src = obs_log_[who & 1][fair_frame_at(now - delay_s_[who & 1])];
        for (int i = 0; i < kObsDim; ++i) buf_a[i] = src[i];
    } else {
        build_obs(f_[who], f_[1 - who], buf_a);
    }
    std::memcpy(buf_a + kObsDim, mlp_emb_, sizeof(mlp_emb_));
    // arena.mask.v1, decided on the obs the net SEES — before the forward pass
    // below reuses buf_a as an activation buffer and overwrites it.
    bool allowed[kActionLogits];
    action_mask(buf_a, f_[who].spec.kit_count, f_[who].spec.is_player, allowed);
    const bool dodge_ok = dodge_allowed(buf_a);
    // forward: per-layer activation from mlp_acts_, head [move2, logits7, dodge1].
    // Param packing (dh_env.cpp contract): per layer [W row-major out×in][b out].
    // This is float32 where the Godot arena runs float64, so it was never a
    // bit-exact twin of dh-godot — it is the self-play opponent, not a server.
    // What must match is the FUNCTION: the same activation, layer for layer.
    const float* w = mlp_params_;
    const float* src = buf_a;
    float* dst = buf_b;
    int src_n = mlp_in_[0];
    for (int l = 0; l < mlp_layers_; ++l) {
        const int rows = mlp_out_[l];
        const int act_code = mlp_acts_[l];
        const float* bias = w + rows * src_n;
        for (int r = 0; r < rows; ++r) {
            float s = bias[r];
            for (int c = 0; c < src_n; ++c) s += w[r * src_n + c] * src[c];
            switch (act_code) {
                case kActTanh:      dst[r] = std::tanh(s); break;
                case kActRelu:      dst[r] = s > 0.0f ? s : 0.0f; break;
                case kActLeakyRelu: dst[r] = s > 0.0f ? s : kMlpLeakySlope * s; break;
                default:            dst[r] = s; break;
            }
        }
        w += rows * src_n + rows;
        src = dst;
        dst = (dst == buf_b) ? buf_a : buf_b;
        src_n = rows;
    }
    act.move_x = clampf(src[0], -1.0f, 1.0f);
    act.move_y = clampf(src[1], -1.0f, 1.0f);
    // pre-mask decode, kept for the record (2026-09-14 .. 2026-09-19):
    // int best = 0;
    // for (int i = 1; i < kActionLogits; ++i)
    //     if (src[2 + i] > src[2 + best]) best = i;
    // act.act = best;
    // act.dodge = src[2 + kActionLogits] > 0.0f;
    //
    // MASKED argmax: first max among the AVAILABLE logits (strict >, like the
    // numpy, torch and GDScript loops). allowed[0] is always true, so best >= 0.
    int best = -1;
    for (int i = 0; i < kActionLogits; ++i)
        if (allowed[i] && (best < 0 || src[2 + i] > src[2 + best])) best = i;
    act.act = best;
    // The head is [move2, logits7, dodge1] and this used to read only the
    // first two blocks, so the frozen self-play opponent silently played a
    // policy that could never dodge — a different policy than the same weights
    // in game/arena/neural_policy.gd. Same fallback rule as the arena, now
    // gated on a visible charge like every other runtime.
    act.dodge = dodge_ok && src[2 + kActionLogits] > 0.0f;
    return act;
}

// ---- combat -----------------------------------------------------------------

math::Vec2 Arena::commit_aim(int who) {
    // What the body points at when it swings. A creature body takes the LIVE
    // direction (fighter.gd::proxy_of_enemy_dir); a geared player body takes
    // the policy's aim, which is the DELAYED foe position through gaussian
    // dispersion (policy.gd::noisy_aim). Both are the reference behaviour —
    // the sim used to have no aim at all.
    const Fighter& me = f_[who];
    if (!me.spec.is_player) {
        const BodyRef tgt = nearest_enemy_body(who, me.pos);
        const math::Vec2 d = (tgt.pos - me.pos).normalized_or_zero();
        return d.length() > 0.0f ? d : math::Vec2{1.0f, 0.0f};
    }
    const Percept p = percept(who);
    const math::Vec2 d = (p.foe_pos - me.pos).normalized_or_zero();
    if (d.length() <= 0.0f) return math::Vec2{1.0f, 0.0f};
    const float a = gauss() * kAimNoise;
    return {d.x * std::cos(a) - d.y * std::sin(a),
            d.x * std::sin(a) + d.y * std::cos(a)};
}

bool Arena::in_arc(const math::Vec2& to_tgt, const math::Vec2& aim,
                   float arc_deg, float tgt_radius) {
    // player.gd::_arc_hit / creature.gd::_strike, same test: inside the cone,
    // with a point-blank exemption because a zero vector has no direction.
    const float len = to_tgt.length();
    if (len <= 0.5f * tgt_radius) return true;
    const float cos_half = std::cos(arc_deg * 0.5f * kPi / 180.0f);
    const math::Vec2 n = to_tgt.normalized_or_zero();
    return n.x * aim.x + n.y * aim.y >= cos_half;
}

void Arena::melee_hit(int who) {
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    const BodyRef tgt = nearest_enemy_body(who, me.pos);
    if (!foe.alive()) return;
    // ENRAGE IS SPEED ONLY. creature.gd's _enrage_t appears in exactly four
    // places — the declaration ("failed snare: +30% speed while > 0"), the
    // timer, _speed()'s 1.3x, and the setter. There is no damage multiplier
    // anywhere in the shipping body. The sim invented a 1.5x on every packet.
    float dmg = me.spec.damage;
    // if (me.enrage_t > 0.0f) dmg *= 1.5f;   // not in creature.gd
    if (me.spec.is_ranged) {
        // Ranged basic = a single bolt instead of a contact hit. It is FIRED
        // here and resolved by the projectile loop, so neither the melee reach
        // nor the target's i-frames belong in front of it.
        //
        // BUG THIS REPLACES (2026-09-14): the two lines below used to sit above
        // this branch, unchanged from the melee path —
        //     const float reach = me.spec.attack_reach + tgt.radius + 0.3f*kTile;
        //     if (!foe.alive() || (tgt.pos - me.pos).length() > reach) return;
        //     if (foe.dodge_t > 0.0f) return;
        // — so a bolt needed the shooter to be inside ~2.5 tiles while both
        // built-in minds only ever FIRE from a 4-7 tile band, and refused the
        // shot if the target happened to be dodging. Measured effect: a
        // scripted ranged drake landed ZERO basic-attack damage on a standing
        // target in 15 s. Its Godot twin (player.gd::_cast_bolt, the Mage kit)
        // has no range gate at all — the bolt's own life and speed are the
        // range — which is what this now matches.
        for (auto& p : projectiles_) {
            if (p.alive) continue;
            const math::Vec2 dir = (tgt.pos - me.pos).normalized_or_zero();
            p = Projectile{me.pos, dir * kBoltSpeed, dmg, kBoltLife, who,
                           FieldKind::kFire, true};
            return;
        }
        return;
    }
    // creature.gd::_strike tests `attack_reach + body_radius`, full stop. The
    // `+ 0.3 * kTile` this used to carry was 4.8 px of reach nobody in the
    // arena has — 11% on a boar's 42.7 px envelope — and _strike_recoil, the
    // only forward motion in that path, is a sprite pose tween that never
    // moves global_position.
    // const float reach = me.spec.attack_reach + tgt.radius + 0.3f * kTile;
    //
    // R55 (2026-09-19): creature.gd::_strike is shaped by the ARCHETYPE the
    // bestiary entry gave the body (fighter.gd::setup -> setup_from_entry),
    // and the arena's fen_boar/golem are brutes, its marsh_drake/serpent
    // lungers. Every body used to get the stalker bite below.
    if (me.spec.archetype == Archetype::kBrute) {
        // brute: a GROUND SLAM — radial 2.2 tiles + target radius, no arc
        // ("dodge OUT, not around"), same packet as the swing.
        if ((tgt.pos - me.pos).length() > kSlamRadius + tgt.radius) return;
        if (foe.dodge_t > 0.0f) return;    // i-frames
        hurt(tgt, dmg, (tgt.pos - me.pos).normalized_or_zero());
        return;
    }
    if (me.spec.archetype == Archetype::kLunger && me.pounce_pending) {
        // lunger pounce: dash up to 3 tiles onto where the target WAS at the
        // commit (`_pounce_target`), then the ordinary bite from the landing
        // spot. creature.gd steps the dash through is_walkable; the arena's
        // walkable set is the ring, so clamp_disc is that gate here.
        me.pounce_pending = false;
        math::Vec2 dash = me.pounce_target - me.pos;
        const float dl = dash.length();
        if (dl > 3.0f * kTile) dash = dash * (3.0f * kTile / dl);
        me.pos = clamp_disc(me.pos + dash, me.spec.body_radius);
    }
    const float reach = me.spec.attack_reach + tgt.radius;
    const math::Vec2 to_tgt = tgt.pos - me.pos;
    if (to_tgt.length() > reach) return;
    if (!in_arc(to_tgt, me.aim, me.spec.attack_arc_deg, tgt.radius)) return;
    if (foe.dodge_t > 0.0f) return;    // i-frames
    hurt(tgt, dmg, me.aim);
    // Fiery affix: creature.gd::_strike follows the landed bite with
    // `take_damage(damage * 0.5, _attack_dir, "fire")`. A String arg3 routes
    // through proxy.gd's element branch — RAW damage on a creature body, no
    // resist — and is booked as BOLT, not contact. Only this path carries it:
    // the brute slam returns above, exactly as _strike does.
    if (me.spec.fiery) hurt(tgt, dmg * 0.5f, me.aim, DmgSource::kBolt);
}

void Arena::exec_kit(int who, int slot) {
    Fighter& me = f_[who];
    const KitSpec& kit = me.spec.kits[slot];
    me.kit_cd[slot] = kit.cd;
    me.kit_gate = kKitGate;
    const float dmg_mul = 1.0f;   // enrage is speed only (creature.gd::_speed)
    const BodyRef tgt = nearest_enemy_body(who, me.pos);
    switch (kit.id) {
        case KitId::kBoltVolley: {
            const math::Vec2 base = (tgt.pos - me.pos).normalized_or_zero();
            for (int j = 0; j < 3; ++j) {
                for (auto& p : projectiles_) {
                    if (p.alive) continue;
                    // R55-b (2026-09-21): the fan is EXACT. fighter.gd::cmd_aim
                    // is `if body is ProtoPlayer`, so a creature never reads
                    // bot_aim at all, and _kit_exec fires down
                    // (foe_pos - from).normalized() rotated by the fan angle and
                    // nothing else. This added policy.gd's human-dispersion
                    // noise to a body the arena never applies it to:
                    // const float ang = (-12.0f + 12.0f * static_cast<float>(j)) *
                    //                   kPi / 180.0f + gauss() * kAimNoise;
                    const float ang = (-12.0f + 12.0f * static_cast<float>(j)) *
                                      kPi / 180.0f;
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
                hurt(tgt, me.spec.damage * dmg_mul, dir);
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
            const float reach = me.buddy_spec.attack_reach + tgt.radius;
            const math::Vec2 to_tgt = tgt.pos - me.pos2;
            if (foe.dodge_t <= 0.0f && to_tgt.length() <= reach &&
                in_arc(to_tgt, me.aim2, me.buddy_spec.attack_arc_deg, tgt.radius))
                hurt(tgt, me.buddy_spec.damage, me.aim2);
        }
        return;
    }
    const BodyRef tgt = nearest_enemy_body(who, me.pos2);
    const math::Vec2 to_foe = (tgt.pos - me.pos2).normalized_or_zero();
    const float dist = (tgt.pos - me.pos2).length();
    const float reach = me.buddy_spec.attack_reach + tgt.radius;
    if (dist > reach * 0.85f) {
        float speed = me.buddy_spec.move_speed;
        if (me.slow2_t > 0.0f) speed *= 0.7f;   // creature.gd::_speed
        me.pos2 = clamp_disc(me.pos2 + to_foe * (speed * kArenaDt),
                             me.buddy_spec.body_radius);
    } else if (me.attack_cd2 <= 0.0f) {
        me.windup2_t = me.buddy_spec.windup_time;   // R55: per body; was kWindup
        me.attack_cd2 = me.buddy_spec.attack_cd;
        me.aim2 = to_foe.length() > 0.0f ? to_foe : math::Vec2{1.0f, 0.0f};
    }
    me.attack_cd2 = me.attack_cd2 > kArenaDt ? me.attack_cd2 - kArenaDt : 0.0f;
    me.slow2_t = me.slow2_t > kArenaDt ? me.slow2_t - kArenaDt : 0.0f;
}

void Arena::apply_action(int who, const Action& act) {
    Fighter& me = f_[who];
    Fighter& foe = f_[1 - who];
    if (me.hp <= 0.0f) return;   // a fallen primary acts no more (buddy is autonomous)
    // MOVEMENT, and the two bodies spend a move command differently.
    // fighter.gd::pre_tick, verbatim:
    //   player body:   _move_dir.limit_length(1.0) * move_speed * (0.65 if slowed)
    //   creature body: if len > 0.05: _move_dir.NORMALIZED() * _speed()
    //                  where _speed() = move_speed * (1.3 if enraged) * (0.7 if slowed)
    // The creature path throws the MAGNITUDE away: any command longer than
    // 0.05 moves at full speed, and anything shorter does not move at all.
    // The sim scaled by the magnitude for everyone, so the deployed net —
    // |move| 0.110 — crawled at 11% speed in training and ran at 100% in the
    // arena with the same weights. PPO was tuning a number the shipping
    // runtime never reads.
    float speed = me.spec.move_speed;
    math::Vec2 mv{act.move_x, act.move_y};
    const float ml = mv.length();
    if (me.spec.is_player) {
        if (me.slow_t > 0.0f) speed *= 0.65f;      // the player path's own slow
        if (ml > 1.0f) mv = mv * (1.0f / ml);      // limit_length, not normalize
    } else {
        if (me.slow_t > 0.0f) speed *= 0.7f;       // creature.gd::_speed
        if (me.enrage_t > 0.0f) speed *= 1.3f;
        mv = ml > 0.05f ? mv * (1.0f / ml) : math::Vec2{};
    }
    // WHO IS ALLOWED TO WALK WHILE WINDING UP. In the arena a policy-driven
    // body moves from fighter.gd::pre_tick, which runs before the body's
    // _physics_process and does not look at `_state` at all — so it keeps
    // walking through its own windup. A NATIVE body moves from creature.gd's
    // own state machine, whose "windup" branch only ticks the timer, so it
    // freezes. The sim froze everyone. Side 0 is always externally driven;
    // side 1 is native only under OppPolicy::kNative.
    const bool policy_driven = (who & 1) == 0 || opp_policy_ != OppPolicy::kNative;
    if (me.windup_t <= 0.0f || policy_driven)
        me.pos = clamp_disc(me.pos + mv * (speed * kArenaDt), me.spec.body_radius);
    // The dodge body, shared by the explicit act 7 and the act.dodge fallback.
    const auto do_dodge = [&]() {
        if (me.dodge_charges <= 0 || me.dodge_t > 0.0f) return;
        --me.dodge_charges;
        me.dodge_t = kDodgeTime;
        const math::Vec2 dir = ml > 0.01f ? mv * (1.0f / (ml > 1.0f ? 1.0f : 1.0f))
                               : (me.pos - foe.pos).normalized_or_zero();
        me.pos = clamp_disc(me.pos + dir.normalized_or_zero() * kDodgeDash,
                            me.spec.body_radius);
    };
    // `committed` is game/arena/fighter.gd's `ok`: did the chosen command get
    // accepted, or was it refused (on cooldown, no such slot, act 0)? The
    // arena's neural policy dodges only when it was refused, and so do we.
    bool committed = false;
    last_commit_[who & 1] = -1;
    // FAIRNESS: the burst-binding rate cap (policy.gd ACTION_BUDGET). Over
    // budget, every commit is refused and only movement survives the tick —
    // the same shape as can_commit() returning false in GDScript, except it is
    // enforced here because the learner's action arrives from outside.
    // R55-b: the budget is policy.gd's rate cap and binds only a POLICY-driven
    // body. A native body has no policy — creature.gd swings from its own state
    // machine and fighter.gd::pre_tick fires its kits; neither ever reaches
    // can_commit(). This capped an opponent the arena never caps:
    // if (!budget_ok(who & 1)) return;
    if (policy_driven && !budget_ok(who & 1)) return;
    switch (act.act) {
        case 1:
            if (me.attack_cd <= 0.0f && me.windup_t <= 0.0f) {
                me.aim = commit_aim(who);      // locked HERE, spent later
                if (me.spec.is_ranged) {
                    // instant, like player.gd::_cast_bolt: cooldown starts now
                    melee_hit(who);
                    me.attack_cd = me.spec.attack_cd;
                } else {
                    // A swing costs windup THEN cooldown. creature.gd sets
                    // _cd inside _strike, after the windup has run; this used
                    // to set it here, at the commit, which made the sim's
                    // attack period attack_cd where the arena's is
                    // windup_time + attack_cd — 1.20 s against 1.55 s, i.e.
                    // 29% more swings per second for the same content.
                    me.windup_t = me.spec.windup_time;   // R55: per body; was kWindup for all
                }
                committed = true;
            }
            break;
        case 2:
            // A GEARED body has a special: whirlwind / frost nova / fan of
            // knives, on its own cooldown (player.gd, via fighter.gd::
            // cmd_special). A CREATURE body has none — fighter.gd sends the
            // same call straight to bot_attack, so its "special" is one more
            // ordinary swing sharing the ordinary cooldown.
            //
            // The sim gave every fighter the geared version: an instant,
            // arc-free, 1.2x-damage AoE every 6 s that the arena never
            // performs. On a creature build that is a whole phantom damage
            // source, and every arena build shipping today is kind=creature.
            if (!me.spec.is_player) {
                if (me.attack_cd <= 0.0f && me.windup_t <= 0.0f) {
                    me.aim = commit_aim(who);
                    if (me.spec.is_ranged) {
                        melee_hit(who);
                        me.attack_cd = me.spec.attack_cd;
                    } else {
                        me.windup_t = me.spec.windup_time;   // R55: per body; was kWindup for all
                    }
                    committed = true;
                }
                break;
            }
            if (me.special_cd <= 0.0f) {
                me.special_cd = me.spec.special_cd;
                committed = true;
                const BodyRef tgt = nearest_enemy_body(who, me.pos);
                const float r = kSlamRadius + tgt.radius;
                if (foe.alive() && foe.dodge_t <= 0.0f &&
                    (tgt.pos - me.pos).length() <= r)
                    hurt(tgt, me.spec.damage * 1.2f,
                         (tgt.pos - me.pos).normalized_or_zero());
            }
            break;
        case 3: case 4: case 5: case 6: {
            const int slot = act.act - 3;
            if (slot < me.spec.kit_count && me.kit_cd[slot] <= 0.0f) {
                exec_kit(who, slot);
                committed = true;
            }
            break;
        }
        case 7:
            do_dodge();
            committed = true;      // act 7 IS the commitment, spent or not
            break;
        default:
            break;
    }
    if (act.dodge && !committed) {
        const int before = me.dodge_charges;
        do_dodge();
        if (me.dodge_charges < before) { committed = true; last_commit_[who & 1] = 7; }
    } else if (committed) {
        last_commit_[who & 1] = act.act;
    }
    // Only an ACCEPTED command spends budget — a cast refused on cooldown is
    // free, exactly as a cmd_* returning false never reaches note_commit().
    if (committed) note_commit_time(who & 1);
}

// creature.gd::_separate, ported verbatim in rule and in constants. Up to four
// bodies live in a duel (two fighters, each with an optional buddy); a creature
// pushes off every OTHER live body, at the creature rate or, when the other one
// is a player, at the faster one. Sequential and in place, the same way Godot
// runs each creature's _physics_process one after another against already-moved
// neighbours. Until 2026-09-21 NEITHER runtime ran this in a duel — the arena
// only called _separate from _chase, and an arena body is bot_drive, so it never
// chases — which is why adding it to creature.gd required adding it here too.
void Arena::separate_bodies() {
    struct Body {
        math::Vec2* pos;
        float radius;
        bool is_player;
        bool live;
    };
    Body b[4] = {
        {&f_[0].pos,  f_[0].spec.body_radius,       f_[0].spec.is_player,
         f_[0].hp > 0.0f},
        {&f_[0].pos2, f_[0].buddy_spec.body_radius, f_[0].buddy_spec.is_player,
         f_[0].has_buddy && f_[0].hp2 > 0.0f},
        {&f_[1].pos,  f_[1].spec.body_radius,       f_[1].spec.is_player,
         f_[1].hp > 0.0f},
        {&f_[1].pos2, f_[1].buddy_spec.body_radius, f_[1].buddy_spec.is_player,
         f_[1].has_buddy && f_[1].hp2 > 0.0f},
    };
    for (int i = 0; i < 4; ++i) {
        if (!b[i].live || b[i].is_player) continue;   // ProtoPlayer has no _separate
        for (int j = 0; j < 4; ++j) {
            if (i == j || !b[j].live) continue;
            const math::Vec2 d = *b[i].pos - *b[j].pos;
            const float min_d = b[i].radius + b[j].radius;
            const float d2 = d.length_sq();
            if (d2 >= min_d * min_d || d2 <= 0.0001f) continue;
            const float dist = std::sqrt(d2);
            const float rate = b[j].is_player ? kSeparateRatePlayer : kSeparateRate;
            const float push = (min_d - dist) * rate * kArenaDt / dist;
            *b[i].pos = clamp_disc(*b[i].pos + d * push, b[i].radius);
        }
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
            if (f_[i].windup_t <= 0.0f) {
                melee_hit(i);
                f_[i].attack_cd = f_[i].spec.attack_cd;   // _strike sets _cd
                // _strike: `_state = "recover"; _timer = 0.4` — creature bodies
                // only; player.gd has no such state (R55).
                if (!f_[i].spec.is_player) f_[i].recover_t = kRecover;
            }
        }
    }
    // 2b. body separation (R59). In creature.gd this is the last thing
    // _physics_process does, after the state machine has resolved the windup —
    // so it sits here, after step 2 and before the slams, not next to movement.
    // A STAGGERED body is deliberately exempt there (stagger is CC, it must not
    // drift); the sim has no stagger, so there is nothing to exempt.
    separate_bodies();
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
            hurt(tgt, me.spec.damage * 1.5f,
                 (tgt.pos - me.pos).normalized_or_zero());
    }
    // 4. projectiles (storm bolts DETONATE mire fields: conduct combo §12.41)
    for (auto& p : projectiles_) {
        if (!p.alive) continue;
        const math::Vec2 p_from = p.pos;   // this tick's travel, for the swept test
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
                    hurt({1 - f.owner, 0, victim.pos, victim.spec.body_radius},
                         p.damage * 2.0f, {}, DmgSource::kBolt);
                f.alive = false;   // the field is consumed
                p.alive = false;
                break;
            }
            if (!p.alive) continue;
        }
        Fighter& foe = f_[1 - p.owner];
        if (foe.alive() && foe.dodge_t <= 0.0f) {
            const BodyRef tgt = nearest_enemy_body(p.owner, p.pos);
            // projectile.gd: a SEGMENT-vs-circle test over the frame's travel
            // ("poor man's CCD") with the bolt's own radius — 4 px, 3 for the
            // arcane/storm tint. This was a point test at +2 px (R55):
            // if ((tgt.pos - p.pos).length() <= tgt.radius + 2.0f) {
            const math::Vec2 seg = p.pos - p_from;
            const float seg2 = seg.x * seg.x + seg.y * seg.y;
            float t = 0.0f;
            if (seg2 > 0.0f) {
                const math::Vec2 rel = tgt.pos - p_from;
                t = (rel.x * seg.x + rel.y * seg.y) / seg2;
                t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
            }
            const math::Vec2 closest = p_from + seg * t;
            // projectile.gd: `var radius := 4.0`, and the only setter that
            // moves it is set_steel() (3.0) — the Rogue's fan of knives.
            // set_arcane()/set_violet()/set_frost() are TINTS: a storm bolt is
            // still 4 px wide. This shrank every storm bolt by a quarter:
            // const float bolt_r = p.kind == FieldKind::kStorm ? 3.0f : 4.0f;
            const float bolt_r = 4.0f;
            if ((tgt.pos - closest).length() <= tgt.radius + bolt_r) {
                hurt(tgt, p.damage, p.vel.normalized_or_zero(), DmgSource::kBolt);
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
                hurt({1 - f.owner, body, bpos, brad}, f.dps * kFieldTick, {}, DmgSource::kField);
                if (body == 0) foe.burn_t = 0.5f;
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
        me.recover_t = me.recover_t > kArenaDt ? me.recover_t - kArenaDt : 0.0f;
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
    push_fairness_frame();       // fairness ring: this tick's truth, read later
    // 8. outcome
    if (!f_[0].alive() || !f_[1].alive())
        winner_ = f_[0].alive() ? 0 : (f_[1].alive() ? 1 : -1);
    else if (tick_ >= kMaxTicks) {
        const float a = f_[0].hp_frac(), b = f_[1].hp_frac();
        winner_ = std::fabs(a - b) < 0.001f ? -1 : (a > b ? 0 : 1);
    }
    return done();
}

void Arena::push_fairness_frame() {
    // Newest frame goes at the end of the ring; the caller reads whichever one
    // is old enough. Cost is one build_obs plus two nearest-body queries per
    // tick, which the learner's own obs call was already paying most of.
    const int slot = obs_log_n_ % kObsLog;
    obs_log_t_[slot] = static_cast<float>(tick_) * kArenaDt;
    for (int who = 0; who < 2; ++who) {
        const Fighter& me = f_[who];
        const Fighter& foe = f_[1 - who];
        build_obs(me, foe, obs_log_[who][slot]);
        const BodyRef tgt = nearest_enemy_body(who, me.pos);
        Percept& p = percept_log_[who][slot];
        p.foe_pos = tgt.pos;
        p.foe_radius = tgt.radius;
        p.foe_dist = (tgt.pos - me.pos).length();
        p.foe_windup = tgt.body == 0 ? foe.windup_t : foe.windup2_t;
        p.self_hp_frac = me.hp_frac();
        p.foe_alive = foe.alive();
    }
    ++obs_log_n_;
}

int Arena::fair_frame_at(float target) const {
    // Oldest frame first, take the newest one that is old ENOUGH — and if none
    // is (the opening ticks), the oldest available, which is what the Godot
    // policy does with its own ring rather than inventing a frame.
    const int have = obs_log_n_ < kObsLog ? obs_log_n_ : kObsLog;
    const int oldest = obs_log_n_ - have;
    int pick = oldest;
    for (int i = oldest; i < obs_log_n_; ++i) {
        if (obs_log_t_[i % kObsLog] <= target) pick = i;
        else break;
    }
    return pick % kObsLog;
}

Arena::Percept Arena::percept(int who) const {
    const Fighter& me = f_[who];
    const Fighter& foe = f_[1 - who];
    if (obs_log_n_ <= 0) {               // before the first frame exists
        const BodyRef tgt = nearest_enemy_body(who, me.pos);
        return Percept{tgt.pos, tgt.radius, (tgt.pos - me.pos).length(),
                       tgt.body == 0 ? foe.windup_t : foe.windup2_t,
                       me.hp_frac(), foe.alive()};
    }
    const float now = static_cast<float>(tick_) * kArenaDt;
    return percept_log_[who][fair_frame_at(now - delay_s_[who])];
}

bool Arena::budget_ok(int who) const {
    // 6 commits inside a 1 s sliding window, counted off the ring of stamps.
    if (budget_cap_ <= 0) return true;               // ablated
    const float now = static_cast<float>(tick_) * kArenaDt;
    int live = 0;
    const int have = commit_n_[who] < kActionBudget ? commit_n_[who] : kActionBudget;
    for (int i = 0; i < have; ++i)
        if (now - commit_t_[who][i] <= kBudgetWindow) ++live;
    return live < budget_cap_;
}

void Arena::note_commit_time(int who) {
    commit_t_[who][commit_n_[who] % kActionBudget] =
        static_cast<float>(tick_) * kArenaDt;
    ++commit_n_[who];
}

void Arena::obs(float* out31) const {
    // FAIRNESS (canon §9 §6): the learner sees the world as it was 150-250 ms
    // ago, exactly as game/arena/policy.gd::delayed_obs does. Without this,
    // PPO trained at zero latency and the gate measured the same net at 200 ms,
    // and the identical policy scored win 1.00 in dh-env against 0-12 in the
    // arena. This is an OUTPUT, not simulation state, so no state_hash moves.
    const int dim = obs_dim();
    if (obs_log_n_ <= 0) {                 // before the first frame exists
        build_obs(f_[0], f_[1], out31);
        return;
    }
    const float now = static_cast<float>(tick_) * kArenaDt;
    const float* src = obs_log_[0][fair_frame_at(now - delay_s_[0])];
    for (int i = 0; i < dim; ++i) out31[i] = src[i];
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
        mix_bytes(&f.aim, sizeof(f.aim));   // decides whether the swing lands
    }
    for (const auto& p : projectiles_)
        if (p.alive) mix_bytes(&p.pos, sizeof(p.pos));
    return h;
}

}  // namespace dh::sim
