#pragma once
#include <cstdint>
#include <vector>

#include <dh/math/vec2.hpp>

// Struct-of-arrays entity store with generational indices (docs/tech/21 §2):
// data-oriented, cache-friendly iteration, stable handles that survive reuse of
// slots. Deliberately NOT a general ECS framework and NOT Godot nodes.
namespace dh::sim {

struct EntityId {
    std::uint32_t index = 0;
    std::uint32_t gen = 0;
    constexpr bool operator==(const EntityId&) const = default;
};

class EntityStore {
public:
    EntityId create() {
        std::uint32_t idx;
        if (!free_list_.empty()) {
            idx = free_list_.back();
            free_list_.pop_back();
            alive_[idx] = true;
        } else {
            idx = static_cast<std::uint32_t>(alive_.size());
            alive_.push_back(true);
            gen_.push_back(0);
            pos.push_back({});
            vel.push_back({});
            radius.push_back(0.5f);
            z_height.push_back(0.0f);
            hp.push_back(0.0f);
        }
        return {idx, gen_[idx]};
    }

    // Destroys the slot and bumps its generation so stale handles go dead.
    void destroy(EntityId id) {
        if (!is_alive(id)) return;
        alive_[id.index] = false;
        ++gen_[id.index];
        free_list_.push_back(id.index);
    }

    bool is_alive(EntityId id) const {
        return id.index < alive_.size() && alive_[id.index] && gen_[id.index] == id.gen;
    }

    std::uint32_t capacity() const { return static_cast<std::uint32_t>(alive_.size()); }
    bool slot_alive(std::uint32_t idx) const { return alive_[idx]; }

    // Hot data, indexed by slot. Systems iterate slots 0..capacity() checking
    // slot_alive — stable order is part of the determinism contract (docs/tech/21).
    std::vector<math::Vec2> pos;
    std::vector<math::Vec2> vel;
    std::vector<float> radius;
    std::vector<float> z_height;
    std::vector<float> hp;

private:
    std::vector<bool> alive_;
    std::vector<std::uint32_t> gen_;
    std::vector<std::uint32_t> free_list_;
};

} // namespace dh::sim
