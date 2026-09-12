/* dh-env — C API over dh-sim's arena (docs/tech/25). The primary RL surface:
 * PufferLib-style envs are C; Python reaches this via ml/env/dh_env.py (ctypes).
 * No I/O: fighter stats and opponent weights are handed in by the caller.
 *
 * obs: arena.obs.v1, 31 floats (DH_ENV_OBS_DIM).
 * action: move_x, move_y clamped to unit circle; act 0 noop, 1 attack,
 *         2 special, 3..6 skill slots, 7 dodge.
 */
#ifndef DH_ENV_H
#define DH_ENV_H

#include <stdint.h>

#ifdef _WIN32
#define DH_API __declspec(dllexport)
#else
#define DH_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define DH_ENV_OBS_DIM 31
#define DH_ENV_MAX_KITS 4

enum DhKitId { DH_KIT_NONE = 0, DH_KIT_BOLT_VOLLEY, DH_KIT_RADIAL_SLAM,
               DH_KIT_POUNCE, DH_KIT_FIELD_CAST, DH_KIT_ENRAGE };
enum DhFieldKind { DH_FIELD_FIRE = 0, DH_FIELD_EARTH, DH_FIELD_MIRE, DH_FIELD_LAVA,
                   DH_FIELD_STORM /* projectile element: detonates mire fields */ };
enum DhOppPolicy { DH_OPP_NATIVE = 0, DH_OPP_SCRIPTED, DH_OPP_MLP };

typedef struct {
    float max_hp, damage, move_speed, attack_reach, attack_cd, body_radius;
    float special_cd;
    int32_t is_player, is_ranged, dodge_max, kit_count;
    int32_t kit_id[DH_ENV_MAX_KITS];      /* DhKitId */
    float kit_cd[DH_ENV_MAX_KITS];
    float kit_range[DH_ENV_MAX_KITS];
    int32_t kit_field[DH_ENV_MAX_KITS];   /* DhFieldKind */
} DhFighterSpec;

typedef struct DhEnv DhEnv;

DH_API DhEnv* dh_env_create(DhFighterSpec a, DhFighterSpec b, int32_t opp_policy,
                            uint64_t seed);
/* Squad mode (2v2, arena.obs.v2 = 36 floats): each side fields a second,
 * autonomous melee body. Check dh_env_obs_dim for the obs width. */
DH_API DhEnv* dh_env_create_squad(DhFighterSpec a, DhFighterSpec a_buddy,
                                  DhFighterSpec b, DhFighterSpec b_buddy,
                                  int32_t opp_policy, uint64_t seed);
DH_API int32_t dh_env_obs_dim(const DhEnv* env);
/* Frozen opponent net (DH_OPP_MLP). Packing: per layer [W row-major out x in]
 * then [b out], layers concatenated; layer_in/out arrays, n_layers <= 8;
 * emb16 = the content embedding row (policy_net.py layout). `params` must
 * outlive the env (borrowed pointer — the sim does no copies). */
DH_API void dh_env_set_opp_weights(DhEnv* env, const float* params,
                                   const int32_t* layer_in, const int32_t* layer_out,
                                   int32_t n_layers, const float* emb16);
DH_API void dh_env_reset(DhEnv* env, uint64_t seed, float* out_obs31);
/* Steps the learner (fighter A); the opponent runs its internal policy.
 * Returns 1 when the episode is done. out_obs31 may be NULL. */
DH_API int dh_env_step(DhEnv* env, float move_x, float move_y, int32_t act,
                       float* out_obs31);
/* -2 fighting, -1 draw, 0 learner (A) won, 1 opponent (B) won. */
DH_API int dh_env_winner(const DhEnv* env);
DH_API float dh_env_hp_frac(const DhEnv* env, int32_t who);
DH_API uint64_t dh_env_tick(const DhEnv* env);
DH_API void dh_env_destroy(DhEnv* env);

#ifdef __cplusplus
}
#endif

#endif /* DH_ENV_H */
