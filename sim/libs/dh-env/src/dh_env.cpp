// dh-env — C API implementation: thin lifetime/spec translation over dh::sim::Arena.
#include <dh_env.h>

#include <dh/sim/arena.hpp>

namespace {

dh::sim::FighterSpec to_cpp(const DhFighterSpec& s) {
    dh::sim::FighterSpec out;
    out.max_hp = s.max_hp;
    out.damage = s.damage;
    out.move_speed = s.move_speed;
    out.attack_reach = s.attack_reach;
    out.attack_cd = s.attack_cd;
    out.body_radius = s.body_radius;
    out.special_cd = s.special_cd > 0.0f ? s.special_cd : 6.0f;
    out.is_player = s.is_player != 0;
    out.is_ranged = s.is_ranged != 0;
    out.dodge_max = s.dodge_max;
    out.kit_count = s.kit_count > DH_ENV_MAX_KITS ? DH_ENV_MAX_KITS : s.kit_count;
    for (int i = 0; i < out.kit_count; ++i) {
        out.kits[i].id = static_cast<dh::sim::KitId>(s.kit_id[i]);
        out.kits[i].cd = s.kit_cd[i];
        out.kits[i].range = s.kit_range[i];
        out.kits[i].field = static_cast<dh::sim::FieldKind>(s.kit_field[i]);
    }
    return out;
}

}  // namespace

struct DhEnv {
    dh::sim::Arena arena;
    DhEnv(DhFighterSpec a, DhFighterSpec b, int32_t opp, uint64_t seed)
        : arena(to_cpp(a), to_cpp(b), static_cast<dh::sim::OppPolicy>(opp), seed) {}
    DhEnv(DhFighterSpec a, DhFighterSpec ab, DhFighterSpec b, DhFighterSpec bb,
          int32_t opp, uint64_t seed)
        : arena(to_cpp(a), to_cpp(ab), to_cpp(b), to_cpp(bb),
                static_cast<dh::sim::OppPolicy>(opp), seed) {}
};

DhEnv* dh_env_create(DhFighterSpec a, DhFighterSpec b, int32_t opp_policy,
                     uint64_t seed) {
    return new DhEnv(a, b, opp_policy, seed);
}

DhEnv* dh_env_create_squad(DhFighterSpec a, DhFighterSpec a_buddy,
                           DhFighterSpec b, DhFighterSpec b_buddy,
                           int32_t opp_policy, uint64_t seed) {
    return new DhEnv(a, a_buddy, b, b_buddy, opp_policy, seed);
}

int32_t dh_env_obs_dim(const DhEnv* env) { return env->arena.obs_dim(); }

void dh_env_set_opp_weights(DhEnv* env, const float* params,
                            const int32_t* layer_in, const int32_t* layer_out,
                            int32_t n_layers, const float* emb16) {
    env->arena.set_opp_mlp(params, layer_in, layer_out, n_layers, emb16);
}

void dh_env_reset(DhEnv* env, uint64_t seed, float* out_obs31) {
    env->arena.reset(seed);
    if (out_obs31 != nullptr) env->arena.obs(out_obs31);
}

int dh_env_step(DhEnv* env, float move_x, float move_y, int32_t act,
                float* out_obs31) {
    const dh::sim::Action a{move_x, move_y, act};
    const bool done = env->arena.step(a);
    if (out_obs31 != nullptr) env->arena.obs(out_obs31);
    return done ? 1 : 0;
}

int dh_env_winner(const DhEnv* env) { return env->arena.winner(); }

float dh_env_hp_frac(const DhEnv* env, int32_t who) {
    return env->arena.hp_frac(who != 0 ? 1 : 0);
}

uint64_t dh_env_tick(const DhEnv* env) { return env->arena.tick(); }

void dh_env_destroy(DhEnv* env) { delete env; }
