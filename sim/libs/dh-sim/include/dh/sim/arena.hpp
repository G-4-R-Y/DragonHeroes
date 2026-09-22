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
// Episode cap. game/arena/arena.gd fights to `time_limit`, default 90 s (the
// league never overrides it), then decides on hp_frac; this was 60 s, so every
// slow mirror fight (bog_golem vs scripted averaged exactly 60.0 s here against
// 42 s there) ended on a different rule in the two runtimes (R55, 2026-09-19).
// inline constexpr std::uint32_t kMaxTicks = 60 * 60;    // 60 s episode cap
inline constexpr std::uint32_t kMaxTicks = 90 * 60;    // 90 s: arena.gd time_limit

enum class KitId : int { kNone = 0, kBoltVolley, kRadialSlam, kPounce, kFieldCast, kEnrage };
// kStorm is a PROJECTILE element, never a ground field: storm bolts detonate
// mire fields (the conduct combo, canon §12.41).
enum class FieldKind : int { kFire = 0, kEarth, kMire, kLava, kStorm };
enum class OppPolicy : int { kNative = 0, kScripted, kMlp };
// creature.gd::setup_archetype — the bestiary entry a build rides RESHAPES
// the chassis (game/arena/fighter.gd::setup -> setup_from_entry). R55
// (2026-09-19): the arena's marsh_drake and serpent are LUNGERS (0.22 s
// windup, pounce from 2.5-5.5 tiles), fen_boar and golem are BRUTES (0.55 s
// windup, 2.2-tile arc-free ground slam); the sim gave every body the stalker
// swing. "wisp" is a chassis (ProtoWisp), not an archetype, and maps here to
// kStalker exactly as setup_from_entry skips it.
enum class Archetype : int { kStalker = 0, kLunger, kBrute };
// Where a damage packet came from, for ml/eval/env_parity.py's by-source
// columns (R55): the three buckets the Godot arena can tell apart through
// proxy.gd — a contact hit (swing, slam, pounce), a projectile, a ground field.
enum class DmgSource : int { kContact = 0, kBolt, kField, kSourceCount };

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
    // A swing is a CONE, not a circle — creature.gd 90 deg, player.gd 110.
    // The sim had no arc at all until 2026-09-14, so every swing it threw
    // connected while its Godot twin missed whatever had circled out of the
    // cone during the windup. Measured: the same build took 2.24x the damage
    // per second in dh-env and its episodes ran half as long. Not carried on
    // DhFighterSpec on purpose — that struct crosses the C API BY VALUE, and
    // a silently-resized struct against a stale .so is the one failure mode
    // the optional-symbol rule exists to prevent. dh_env derives it from
    // is_player instead, which is already in the struct.
    float attack_arc_deg = 90.0f;
    float attack_cd = 1.2f;
    float body_radius = 8.0f;
    bool is_player = false;
    bool is_ranged = false;
    float special_cd = 6.0f;           // whirlwind/nova analog
    int dodge_max = 2;                 // 0 for creatures
    std::array<KitSpec, 4> kits{};
    int kit_count = 0;
    // creature.gd::windup_time — the telegraph BEFORE a swing lands, per body:
    // 0.35 default, 0.22 lunger, 0.55 brute, 0.3 wisp. Was the constant
    // kWindup for every body until R55 (2026-09-19); reaches the sim through
    // dh_env_set_body_traits (optional symbol), never through DhFighterSpec,
    // which crosses the C API by value and must not be resized.
    float windup_time = 0.35f;
    Archetype archetype = Archetype::kStalker;
    // creature.gd::setup_archetype elite affixes. Brutal (damage x1.5), Swift
    // (speed x1.4, cd x0.75) and Bulwark (max_hp x1.8) are pure STAT edits, so
    // dump_specs.gd already reads them off the finished body and they arrive
    // here inside the numbers above. `Fiery` is the one that is BEHAVIOUR: it
    // sets creature.gd's `fiery`, and _strike then lands a SECOND packet worth
    // half the swing as a "fire" element string, which proxy.gd books as BOLT
    // damage. Four of the six arena creatures wear an affix and one of them is
    // Fiery (cinder_drake), so this rode entirely outside the sim until R55-b.
    bool fiery = false;
};

// Learner command: move vector (clamped to unit length) + act id
// (0 noop, 1 attack, 2 special, 3..6 skill slots, 7 dodge).
//
// `dodge` is a SEPARATE flag, not an eighth action, because that is what the
// network head actually is: ml/training/policy_net.py::act returns
// (move, pick, dodge) — three outputs — and the shipping arena
// (game/arena/neural_policy.gd) spends them as "attempt the pick; dodge only if
// the pick was refused". Folding dodge into the act id made the same weights
// mean three different things in three runtimes (2026-09-14): an OVERRIDE for
// anything driving dh-env externally, a FALLBACK in the Godot arena, and
// nothing at all in mlp_act, which never read the logit. Measured cost on the
// deployed fen_boar net: it dodged on 95-98% of ticks in dh-env for a build
// with dodge_max = 0, so 95-98% of its ticks were guaranteed no-ops, and it
// dealt 0.087 health bars per episode against the arena's 0.816.
// act 7 still means "dodge, nothing else" so old callers are unchanged.
struct Action {
    float move_x = 0.0f;
    float move_y = 0.0f;
    int act = 0;
    bool dodge = false;      // fallback: fires only if `act` was refused
};

class Arena {
  public:
    Arena(const FighterSpec& a, const FighterSpec& b, OppPolicy opp, std::uint64_t seed);
    // Squad mode: each side gets a buddy body (arena.obs.v2, 36 floats).
    Arena(const FighterSpec& a, const FighterSpec& a_buddy,
          const FighterSpec& b, const FighterSpec& b_buddy,
          OppPolicy opp, std::uint64_t seed);

    // Ricardo's curriculum, 2026-09-14: "learn from scripts first and, once
    // reliably wiining against it, self playing". The opponent's MIND is not
    // part of the arena's state, so it can change between episodes without
    // disturbing determinism — every state_hash is a function of the seed and
    // the actions, not of who chose them. Switching to kMlp without weights set
    // would fight an unset net, so that is refused.
    bool set_opp_policy(OppPolicy p) {
        if (p == OppPolicy::kMlp && !has_opp_mlp()) return false;
        opp_policy_ = p;
        return true;
    }
    OppPolicy opp_policy() const { return opp_policy_; }

    // R55 (2026-09-19): per-body swing shape, read off the Godot body by
    // game/arena/tools/dump_specs.gd. Applies from the next reset() on (the
    // spec is copied into the fighter there) and to the current episode's
    // spec as well, so a caller that sets it right after construction, before
    // the first reset, sees one consistent body throughout.
    void set_body_traits(int who, Archetype archetype, float windup_time) {
        FighterSpec& s = f_[who & 1].spec;
        s.archetype = archetype;
        if (windup_time > 0.0f) s.windup_time = windup_time;
    }

    // R55-b (2026-09-21): the Fiery elite affix (see FighterSpec::fiery). Its
    // own entry point for the same reason set_body_traits has one — a widened
    // signature would let a stale .so be called with the wrong arity, while a
    // missing symbol fails loudly on the Python side.
    void set_body_affix(int who, bool fiery) { f_[who & 1].spec.fiery = fiery; }

    // Frozen opponent net (OppPolicy::kMlp): flat row-major weights + biases,
    // layer row sizes [in0,out0,in1,out1,...], and the 16-float embedding row
    // appended to the obs (policy_net.py layout: obs31 ++ emb16, tanh hidden).
    // Frozen-opponent MLP. Widest layer this accepts: kMlpMaxUnits. A net wider
    // than that is REJECTED (the opponent falls back to scripted) rather than
    // written past the forward pass's activation buffers — teacher-sized nets
    // (256x256, ml/training/distill.py) reach here through PPO self-play, and
    // a silent stack overwrite is the worst possible way to find that out.
    static constexpr int kMlpMaxUnits = 512;
    // Per-layer activation CODES, same numbering as ml/training/arch.py and
    // dh-godot's DhPolicyNet: 0 linear, 1 tanh, 2 relu, 3 leaky_relu(0.01).
    // `acts` may be nullptr, which means what this always meant — tanh on every
    // hidden layer, linear head. An unknown code is treated as linear.
    // (Ricardo, 2026-09-13: "net hyperparams should be configurable, as to test
    // new architectures" — this is PPO's FROZEN SELF-PLAY OPPONENT, so a relu
    // policy played here as tanh is a different opponent than the one trained.)
    enum MlpAct : int { kActLinear = 0, kActTanh = 1, kActRelu = 2, kActLeakyRelu = 3 };
    static constexpr float kMlpLeakySlope = 0.01f;
    void set_opp_mlp(const float* params, const int* layer_in, const int* layer_out,
                     int n_layers, const float* emb16, const int* acts = nullptr);
    bool has_opp_mlp() const { return mlp_params_ != nullptr && mlp_layers_ > 0; }

    void reset(std::uint64_t seed);
    bool step(const Action& act);        // true once the episode is done
    // FAIRNESS ABLATION (probes and tests only; the shipping default is the
    // sampled 150-250 ms). Pinning the delay is how ml/eval/fairness_probe.py
    // proved that this one number, alone, flips a verdict from win 1.00 to
    // 0.00 — it needs to be settable from outside, not monkey-patched.
    // seconds < 0 restores "resample per reset".
    void set_obs_delay(float seconds) {
        delay_override_ = seconds;
        if (seconds >= 0.0f) delay_s_[0] = delay_s_[1] = seconds;   // now, too
    }
    float obs_delay(int side) const { return delay_s_[side & 1]; }
    // commits per second; <= 0 means uncapped (what the sim did before).
    void set_action_budget(int commits_per_s) {
        // The stamp ring holds kActionBudget entries, so it cannot police a cap
        // looser than that — anything above it is the uncapped case anyway.
        budget_cap_ = commits_per_s > kActionBudget ? kActionBudget : commits_per_s;
    }
    int action_budget() const { return budget_cap_; }

    // The swing cone test, shared by melee strikes and the buddy's. Public
    // because it is pure geometry and the suite pins it directly.
    static bool in_arc(const math::Vec2& to_tgt, const math::Vec2& aim,
                       float arc_deg, float tgt_radius);

    void obs(float* out) const;          // learner obs, DELAYED (canon §9 §6)
    // The undelayed truth. For probes, tests and replay traces only — a policy
    // that reads this is not playing the game the gate measures.
    void obs_now(float* out) const { build_obs(f_[0], f_[1], out); }
    int obs_dim() const { return squad_ ? kObsV2Dim : kObsDim; }
    int winner() const;                  // -1 undecided/draw, 0 = A, 1 = B
    bool done() const { return winner_ != -2; }
    float hp_frac(int who) const;
    // Total RAW damage this fighter has been dealt this episode, both bodies.
    // The twin of game/arena/fighter.gd::damage_taken, and deliberately the
    // same quantity: the packet as swung, before any clamp to the remaining
    // hit points, so a 40-damage blow on a 5-hp body counts 40 in both. Damage
    // aimed at a body that is already down counts in neither (the Godot proxy
    // returns early on `dead`). Exists so ml/eval/env_parity.py can say WHICH
    // term the two runtimes disagree on instead of only that they disagree:
    // hp_frac alone cannot separate "hits rarely land" from "hits land soft".
    float damage_taken(int who) const { return damage_taken_[who & 1]; }
    // The same tally split by DmgSource (contact / bolt / field); the three
    // sum to damage_taken. The twin of the arena row's dmg_{contact,bolt,field}.
    float damage_by_source(int who, DmgSource src) const {
        return damage_by_source_[who & 1][static_cast<int>(src)];
    }
    // The action id that actually COMMITTED on the last step for this fighter,
    // or -1 if the chosen action was refused (on cooldown, no such kit slot,
    // act 0). The twin of game/arena/fighter.gd's `ok`.
    //
    // Exists because a trainer that pays for INTENT pays for nothing: PPO's kit
    // bonus fired on "the agent selected a kit", and a kit on an 8 s cooldown is
    // selectable for 480 ticks per cast, so spamming one kit earned 3600 x 0.02
    // = 72 per episode against a terminal worth 1. The policy duly collapsed to
    // that single action on 100.000% of ticks (measured 2026-09-14,
    // cinder_drake v6.0). Pay for effect, never for intent.
    int last_commit(int who) const { return last_commit_[who & 1]; }

    // arena.mask.v1 (R50, 2026-09-19; ml/env/dh_env.py::action_mask). Which of
    // the kActionLogits a policy may pick, from the obs it SEES plus two body
    // constants. ONE rule in five runtimes — the torch trainer, the numpy twin,
    // game/arena/neural_policy.gd, ml/eval/env_parity.py and mlp_act() below —
    // so "argmax of the head" means the same action everywhere. Static and
    // pure on purpose: it must not read live fighter state, only the (delayed)
    // observation, or the frozen opponent would decode on information its
    // Godot twin does not have.
    //   0 always | 1 o[5]<=0 | 2 player: o[6]<=0, creature: o[5]<=0 |
    //   3+k k<kit_count && o[7+k]<=0 | dodge flag: o[12]>0
    static void action_mask(const float* o, int kit_count, bool is_player,
                            bool allowed[kActionLogits]);
    static bool dodge_allowed(const float* o) { return o[12] > 0.0f; }
    std::uint64_t tick() const { return tick_; }
    std::uint64_t state_hash() const;    // determinism fingerprint (tests)

  private:
    struct Fighter {
        FighterSpec spec;
        math::Vec2 pos{}, vel{};
        float hp = 0.0f;
        float attack_cd = 0.0f, special_cd = 0.0f;
        float windup_t = 0.0f;           // > 0: telegraphing a melee hit
        // The direction the swing was COMMITTED to, locked when the windup
        // begins (creature.gd::_begin_windup stores _attack_dir the same way).
        // Locking it is what lets a circling target leave the cone.
        math::Vec2 aim{1.0f, 0.0f}, aim2{1.0f, 0.0f};
        float slow_t = 0.0f, burn_t = 0.0f, bleed_t = 0.0f, dot_dps = 0.0f;
        float enrage_t = 0.0f;
        float dodge_t = 0.0f;            // i-frames remaining
        int dodge_charges = 0;
        float dodge_regen = 0.0f;
        float kit_cd[4] = {0, 0, 0, 0};
        float kit_gate = 0.0f;           // native kit rate limit (0.4 s)
        // creature.gd "recover": 0.4 s after a strike lands in which the
        // built-in mind neither chases nor swings (_strike sets _timer = 0.4,
        // the state machine only ticks it). bot_attack never reads it, so a
        // policy-driven body is unaffected — its attack_cd is longer anyway.
        float recover_t = 0.0f;
        // Lunger pounce (creature.gd::_chase -> _strike): the swing committed
        // from 2.5-5.5 tiles dashes up to 3 tiles onto WHERE THE TARGET WAS at
        // the commit, then runs the ordinary reach + arc test from there.
        bool pounce_pending = false;
        math::Vec2 pounce_target{};
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
    math::Vec2 commit_aim(int who);      // the direction a swing is locked to
    void apply_action(int who, const Action& act);
    void exec_kit(int who, int slot);
    void melee_hit(int who);
    void buddy_tick(int who);            // squad buddy: chase + basic attack
    // nearest LIVING enemy body: position + radius + which body to hurt
    struct BodyRef { int fighter = 0; int body = 0; math::Vec2 pos{}; float radius = 8.0f; };
    BodyRef nearest_enemy_body(int who, math::Vec2 from) const;
    math::Vec2 self_body_pos(const Fighter& f) const;
    // `from_dir` is the direction of the blow: creature.gd::take_damage nudges
    // the victim 6 px along it on EVERY landed packet, and the arena's proxy
    // passes it straight through. Zero means no nudge (fields, DoTs).
    void hurt(const BodyRef& ref, float dmg, math::Vec2 from_dir = {},
              DmgSource src = DmgSource::kContact);
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
    float damage_taken_[2] = {0.0f, 0.0f};   // per-episode, reset() clears it
    float damage_by_source_[2][static_cast<int>(DmgSource::kSourceCount)] = {};
    int last_commit_[2] = {-1, -1};          // per-TICK, apply_action sets it
    math::Pcg32 combat_rng_;
    math::Pcg32 policy_rng_;
    // scripted-policy state (per fighter, only index 1 used today)
    float strafe_dir_[2] = {1.0f, 1.0f};
    float strafe_t_[2] = {0.0f, 0.0f};
    float retreat_t_[2] = {0.0f, 0.0f};
    // FAIRNESS (canon §9 §6). This field was SAMPLED here and never read
    // anywhere — grep 2026-09-14 found exactly two occurrences, this one and
    // its assignment — while game/arena/policy.gd delayed every policy by
    // 150-250 ms. So PPO trained on zero-latency information and the gate
    // measured the same net on 200 ms-stale information, which is the inverse
    // of the canon rule ("baked into TRAINING, not patched at inference").
    // MEASURED: the identical heuristic scores win 1.00 in dh-env and 0-12 in
    // the arena; imposing this delay inside dh-env drops it to 0.00, which is
    // the whole divergence.
    float delay_s_[2] = {0.2f, 0.2f};    // fairness obs delay, sampled per reset
    float delay_override_ = -1.0f;       // >= 0 pins it (ablation)
    // Ring of past observation frames, newest last — the twin of
    // ArenaPolicy::_obs_log, same 24-frame depth (0.4 s at 60 Hz, comfortably
    // more than the 0.25 s worst case).
    static constexpr int kObsLog = 24;
    // Per SIDE: side 1's self-view cannot be mirrored out of side 0's (its own
    // cooldowns are simply not in there), so a frozen-net opponent needs its
    // own ring. One extra build_obs a tick.
    float obs_log_[2][kObsLog][kObsV2Dim] = {};
    float obs_log_t_[kObsLog] = {};
    int obs_log_n_ = 0;                  // frames written since reset
    // What a MIND is allowed to know about the other side. The learner reads
    // its stale world through obs(); the built-in minds used to read f_[] live,
    // which is why they landed 1.70-2.28x the damage their Godot twins land
    // (dps_taken, the gap that flipped the gate verdict). scripted_policy.gd
    // takes foe pos, distance, foe windup and its own hp out of delayed_obs()
    // and everything else (own cooldowns, own position) live; so does this.
    struct Percept {
        math::Vec2 foe_pos{};            // where the foe WAS, delay_s_ ago
        float foe_radius = 0.0f;
        float foe_dist = 0.0f;           // obs[18], measured at that time
        float foe_windup = 0.0f;         // obs[22]
        float self_hp_frac = 1.0f;       // obs[0]
        bool foe_alive = true;
    };
    Percept percept_log_[2][kObsLog] = {};
    void push_fairness_frame();          // one ring write: obs + both percepts
    Percept percept(int who) const;      // the frame that side may act on now
    int fair_frame_at(float target) const;   // ring index, oldest if none fits
    // Burst-binding action budget (policy.gd ACTION_BUDGET/BUDGET_WINDOW): a
    // mind may COMMIT (attack/special/kit/dodge) at most 6 times a second.
    // Enforced in apply_action for both sides at once — the learner's action
    // arrives from outside, so the cap cannot live in the minds like it does
    // in GDScript. A refused commit costs nothing, exactly as cmd_* returning
    // false costs nothing there.
    static constexpr int kActionBudget = 6;
    static constexpr float kBudgetWindow = 1.0f;
    int budget_cap_ = kActionBudget;     // <= 0 uncaps it (ablation)
    float commit_t_[2][kActionBudget] = {};
    int commit_n_[2] = {0, 0};
    bool budget_ok(int who) const;
    void note_commit_time(int who);
    // frozen opponent MLP
    const float* mlp_params_ = nullptr;
    std::array<int, 8> mlp_in_{}, mlp_out_{}, mlp_acts_{};
    int mlp_layers_ = 0;
    float mlp_emb_[16] = {};
};

}  // namespace dh::sim
