// dh-env — C API implementation: thin lifetime/spec translation over dh::sim::Arena.
#include <dh_env.h>

#include <dh/sim/arena.hpp>

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

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


// ---- worker pool for dh_env_step_many --------------------------------------
// The envs share nothing, so a tick across N of them is embarrassingly
// parallel -- but a 32-env tick is only tens of microseconds of work, so
// spawning threads per call would cost more than it saves. These workers are
// created once and parked on a condition variable between ticks; the calling
// thread drains the same queue, so n_threads=1 costs nothing at all.
class Pool {
public:
    explicit Pool(int workers) {
        for (int i = 0; i < workers; ++i) threads_.emplace_back([this] { loop(); });
    }
    ~Pool() {
        {
            std::lock_guard<std::mutex> lk(m_);
            stop_ = true;
            ++epoch_;
        }
        start_.notify_all();
        for (auto& t : threads_) t.join();
    }
    int workers() const { return static_cast<int>(threads_.size()); }

    void run(int n, const std::function<void(int)>& body) {
        {
            std::lock_guard<std::mutex> lk(m_);
            body_ = &body;
            n_ = n;
            next_.store(0, std::memory_order_relaxed);
            busy_ = workers();
            ++epoch_;
        }
        start_.notify_all();
        drain();                       // the caller is a worker too
        std::unique_lock<std::mutex> lk(m_);
        done_.wait(lk, [this] { return busy_ == 0; });
        body_ = nullptr;
    }

private:
    void drain() {
        const std::function<void(int)>* body = body_;
        const int n = n_;
        for (;;) {
            const int i = next_.fetch_add(1, std::memory_order_relaxed);
            if (i >= n) return;
            (*body)(i);
        }
    }
    void loop() {
        uint64_t seen = 0;
        for (;;) {
            {
                std::unique_lock<std::mutex> lk(m_);
                start_.wait(lk, [&] { return stop_ || epoch_ != seen; });
                seen = epoch_;
                if (stop_) return;
            }
            drain();
            {
                std::lock_guard<std::mutex> lk(m_);
                --busy_;
            }
            done_.notify_one();
        }
    }

    std::vector<std::thread> threads_;
    std::mutex m_;
    std::condition_variable start_, done_;
    const std::function<void(int)>* body_ = nullptr;
    std::atomic<int> next_{0};
    int n_ = 0, busy_ = 0;
    uint64_t epoch_ = 0;
    bool stop_ = false;
};

std::mutex g_pool_m;
Pool* g_pool = nullptr;
int g_pool_size = 0;

Pool* pool_for(int n_threads) {
    if (n_threads <= 1) return nullptr;
    std::lock_guard<std::mutex> lk(g_pool_m);
    if (g_pool != nullptr && g_pool_size == n_threads) return g_pool;
    delete g_pool;                       // a resize is rare: tear down, rebuild
    g_pool = new Pool(n_threads - 1);    // the caller thread is the n-th worker
    g_pool_size = n_threads;
    return g_pool;
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

void dh_env_set_opp_weights_acts(DhEnv* env, const float* params,
                                 const int32_t* layer_in, const int32_t* layer_out,
                                 int32_t n_layers, const float* emb16,
                                 const int32_t* acts) {
    env->arena.set_opp_mlp(params, layer_in, layer_out, n_layers, emb16, acts);
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

int32_t dh_env_step_many(DhEnv* const* envs, int32_t n, const float* move_xy,
                         const int32_t* acts, float* out_obs, int32_t* out_done,
                         float* out_hp, int32_t* out_winner, int32_t n_threads) {
    if (envs == nullptr || n <= 0) return 0;
    const int stride = envs[0]->arena.obs_dim();
    std::atomic<int32_t> n_done{0};

    const auto body = [&](int i) {
        DhEnv* e = envs[i];
        const dh::sim::Action a{move_xy[2 * i], move_xy[2 * i + 1], acts[i]};
        const bool done = e->arena.step(a);
        if (out_obs != nullptr) e->arena.obs(out_obs + static_cast<size_t>(i) * stride);
        if (out_done != nullptr) out_done[i] = done ? 1 : 0;
        if (out_hp != nullptr) {
            out_hp[2 * i] = e->arena.hp_frac(0);
            out_hp[2 * i + 1] = e->arena.hp_frac(1);
        }
        if (out_winner != nullptr) out_winner[i] = e->arena.winner();
        if (done) n_done.fetch_add(1, std::memory_order_relaxed);
    };

    Pool* p = pool_for(n_threads);
    if (p == nullptr) {
        for (int i = 0; i < n; ++i) body(i);
    } else {
        p->run(n, body);
    }
    return n_done.load(std::memory_order_relaxed);
}

void dh_env_reset_many(DhEnv* const* envs, int32_t n, const uint64_t* seeds,
                       float* out_obs) {
    if (envs == nullptr || n <= 0) return;
    const int stride = envs[0]->arena.obs_dim();
    for (int i = 0; i < n; ++i) {
        envs[i]->arena.reset(seeds[i]);
        if (out_obs != nullptr) envs[i]->arena.obs(out_obs + static_cast<size_t>(i) * stride);
    }
}

void dh_env_shutdown_pool(void) {
    std::lock_guard<std::mutex> lk(g_pool_m);
    delete g_pool;
    g_pool = nullptr;
    g_pool_size = 0;
}

int dh_env_winner(const DhEnv* env) { return env->arena.winner(); }

float dh_env_hp_frac(const DhEnv* env, int32_t who) {
    return env->arena.hp_frac(who != 0 ? 1 : 0);
}

uint64_t dh_env_tick(const DhEnv* env) { return env->arena.tick(); }

void dh_env_destroy(DhEnv* env) { delete env; }
