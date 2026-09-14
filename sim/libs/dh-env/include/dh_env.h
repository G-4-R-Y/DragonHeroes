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
/* Dodge is a SEPARATE head output, not an eighth action: policy_net.py::act
 * returns (move, pick, dodge) and game/arena/neural_policy.gd spends them as
 * "attempt the pick, dodge only if it was refused". OR this bit into `act` to
 * say the same thing here; `act & 7` stays the pick. Values 0..7 are unchanged
 * (7 still means dodge and nothing else), so no existing caller moves.
 * Call dh_env_action_dodge_bit() to detect a library that predates the bit --
 * an ignored dodge flag is invisible in every metric, and that is exactly how
 * it went unnoticed until 2026-09-14. */
#define DH_ENV_ACT_DODGE 8

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
/* Same, plus per-layer activation codes (Ricardo, 2026-09-13: "net hyperparams
 * should be configurable, as to test new architectures"):
 *     0 linear   1 tanh   2 relu   3 leaky_relu (slope 0.01)
 * matching ml/training/arch.py and dh-godot's DhPolicyNet. `acts` may be NULL,
 * which is exactly dh_env_set_opp_weights (tanh hidden, linear head).
 *
 * This is a SECOND symbol rather than a sixth argument on the first, on purpose.
 * The caller is ctypes (ml/env/dh_env.py) against a .so built separately: adding
 * a parameter would let a stale library read a register that was never set, and
 * the damage — a self-play opponent quietly running the wrong policy — is
 * invisible in every metric PPO prints. A missing SYMBOL is not invisible. */
DH_API void dh_env_set_opp_weights_acts(DhEnv* env, const float* params,
                                        const int32_t* layer_in, const int32_t* layer_out,
                                        int32_t n_layers, const float* emb16,
                                        const int32_t* acts);
DH_API void dh_env_reset(DhEnv* env, uint64_t seed, float* out_obs31);
/* Steps the learner (fighter A); the opponent runs its internal policy.
 * Returns 1 when the episode is done. out_obs31 may be NULL. */
DH_API int dh_env_step(DhEnv* env, float move_x, float move_y, int32_t act,
                       float* out_obs31);
/* -2 fighting, -1 draw, 0 learner (A) won, 1 opponent (B) won. */
/* ---- batched stepping (docs/tech/25 §R1) ---------------------------------
 * Ricardo, 2026-09-13: "A batched step across all environments, or a few
 * worker processes, is roughly sixteen times of headroom sitting there. -->
 * do it!"  The PPO rollout used to cross the ctypes boundary 3-4 times PER ENV
 * PER TICK (step + two hp_frac + winner), which is why end-to-end throughput
 * was 32k steps/s against the 527k the sim itself can do. These two calls move
 * the whole per-tick fan-out into C++: one call steps every env, returns their
 * observations, done flags, hp fractions and winners in caller-owned arrays,
 * and can spread the envs over a persistent worker pool (the envs share
 * nothing, so this is embarrassingly parallel).
 *
 * envs      : n environment handles; all must have the same obs_dim
 * move_xy   : 2n floats, (x, y) per env      acts: n ints
 * out_obs   : n * obs_dim floats, post-step  (NULL to skip)
 * out_done  : n int32, 1 when the episode ended on this tick (NULL to skip)
 * out_hp    : 2n floats, [learner, opponent] per env (NULL to skip)
 * out_winner: n int32, dh_env_winner after the step (NULL to skip)
 * n_threads : <= 1 steps serially on the calling thread; otherwise the envs
 *             are drained by that many persistent workers. The pool is created
 *             on first use and reused; ask for the same number every call.
 * Returns how many envs reported done this tick.
 * Episodes are NOT auto-reset: the caller still owns the boundary (it needs
 * the terminal observation first). Reset the finished ones with
 * dh_env_reset_many, which takes the subset and writes their obs compactly. */
DH_API int32_t dh_env_step_many(DhEnv* const* envs, int32_t n,
                                const float* move_xy, const int32_t* acts,
                                float* out_obs, int32_t* out_done,
                                float* out_hp, int32_t* out_winner,
                                int32_t n_threads);
DH_API void dh_env_reset_many(DhEnv* const* envs, int32_t n,
                              const uint64_t* seeds, float* out_obs);
/* Tears the worker pool down (tests, and before fork()). Safe to call always. */
DH_API void dh_env_shutdown_pool(void);

DH_API int dh_env_winner(const DhEnv* env);
DH_API float dh_env_hp_frac(const DhEnv* env, int32_t who);
/* Raw damage dealt TO `who` (0 learner, 1 opponent) so far this episode — the
 * twin of the Godot arena's `dmg_taken_a`/`dmg_taken_b`. Read it at the episode
 * boundary, before the reset that clears it. Added for ml/eval/env_parity.py:
 * hp_frac says the two runtimes disagree, this says whether the disagreement is
 * in how OFTEN hits land or in how HARD they land. */
DH_API float dh_env_damage_taken(const DhEnv* env, int32_t who);
/* Returns DH_ENV_ACT_DODGE. Absent in a library built before 2026-09-14, which
 * is how a caller tells that the dodge bit would be silently dropped. */
DH_API int32_t dh_env_action_dodge_bit(void);
DH_API uint64_t dh_env_tick(const DhEnv* env);
DH_API void dh_env_destroy(DhEnv* env);

#ifdef __cplusplus
}
#endif

#endif /* DH_ENV_H */
