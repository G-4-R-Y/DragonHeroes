#pragma once
#include <cstdint>
#include <limits>
#include <optional>

// Living-world effect command evaluator. No I/O, Godot, RNG or hot-path allocation.
// Caller owns one EffectState per (owner, equipped effect), and supplies authoritative
// root events. Outputs are requests; the host resolves targets and applies combat.
// New combinations are data. New verbs require a versioned engine change.
namespace dh::sim {
enum class EffectTrigger : std::uint32_t { hit, dodge, pet_hit, field_combo };
enum class EffectAction : std::uint32_t { echo, chain, burst, resource, ward };
struct EffectDef {
    EffectTrigger trigger{};
    std::uint32_t tags{}, requires_status{}, consumes{};
    EffectAction action{};
    std::uint32_t magnitude_permille{}, cooldown_ticks{}, max_targets{}, budget{};
};
struct EffectState { std::uint64_t next_tick{}; bool exhausted{}; };
struct EffectEvent {
    EffectTrigger trigger{};
    std::uint32_t tags{}, statuses{};
    std::uint64_t tick{};
    std::uint32_t proc_depth{};
};
struct EffectCommand {
    EffectAction action{};
    std::uint32_t magnitude_permille{}, max_targets{}, proc_depth{1};
};
inline bool valid_effect(const EffectDef& d) {
    return static_cast<std::uint32_t>(d.trigger) <= 3 &&
           static_cast<std::uint32_t>(d.action) <= 4 &&
           d.tags < 256 && d.requires_status < 16 && d.consumes < 16 &&
           (d.consumes & d.requires_status) == d.consumes &&
           d.magnitude_permille >= 1 && d.magnitude_permille <= 1000 &&
           d.cooldown_ticks >= 1 && d.cooldown_ticks <= 900 &&
           d.max_targets >= 1 && d.max_targets <= 8 && d.budget >= 1 && d.budget <= 60;
}
inline std::optional<EffectCommand> evaluate_effect(
    const EffectDef& d, EffectState& state, EffectEvent& event) {
    if (!valid_effect(d) || state.exhausted || event.proc_depth != 0 ||
        event.tick < state.next_tick || event.trigger != d.trigger ||
        (event.tags & d.tags) != d.tags ||
        (event.statuses & d.requires_status) != d.requires_status) return std::nullopt;
    event.statuses &= ~d.consumes;
    if (event.tick > std::numeric_limits<std::uint64_t>::max() - d.cooldown_ticks)
        state.exhausted = true;
    else state.next_tick = event.tick + d.cooldown_ticks;
    return EffectCommand{d.action, d.magnitude_permille, d.max_targets, 1};
}
} // namespace dh::sim
