// Offline executable: validated DHE1 data -> real dh-sim command evaluation.
// This is an authoring probe, not the live world or an item/money writer.
#include <dh/sim/effects.hpp>
#include <chrono>
#include <cstdio>
#include <fstream>
#include <stdexcept>
#include <vector>

static std::uint32_t u32(std::istream& in) {
    unsigned char b[4]{};
    if (!in.read(reinterpret_cast<char*>(b), 4)) throw std::runtime_error("truncated program");
    return std::uint32_t(b[0]) | (std::uint32_t(b[1]) << 8) |
           (std::uint32_t(b[2]) << 16) | (std::uint32_t(b[3]) << 24);
}
int main(int argc, char** argv) {
    using namespace dh::sim;
    if (argc != 2) { std::fprintf(stderr, "usage: dh-effect-lab <effects.bin>\n"); return 2; }
    try {
        std::ifstream input(argv[1], std::ios::binary);
        if (u32(input) != 0x31454844u) throw std::runtime_error("unsupported DHE1 header");
        const auto count = u32(input);
        if (count < 1 || count > 64) throw std::runtime_error("invalid effect count");
        std::vector<EffectDef> defs;
        defs.reserve(count);
        for (std::uint32_t i = 0; i < count; ++i) {
            EffectDef d;
            d.trigger = static_cast<EffectTrigger>(u32(input));
            d.tags=u32(input); d.requires_status=u32(input); d.consumes=u32(input);
            d.action=static_cast<EffectAction>(u32(input));
            d.magnitude_permille=u32(input); d.cooldown_ticks=u32(input);
            d.max_targets=u32(input); d.budget=u32(input);
            if (!valid_effect(d)) throw std::runtime_error("invalid effect operands");
            defs.push_back(d);
        }
        if (input.peek() != std::char_traits<char>::eof()) throw std::runtime_error("trailing program data");
        std::printf("{\"format\":\"effect-lab.1\",\"traces\":[");
        for (std::size_t i=0; i<defs.size(); ++i) {
            const auto& d=defs[i]; EffectState state;
            EffectEvent event{d.trigger,d.tags,d.requires_status,0,0};
            const auto first=evaluate_effect(d,state,event);
            event.statuses=d.requires_status;
            const bool cooldown_blocked=!evaluate_effect(d,state,event);
            event.tick=d.cooldown_ticks; event.proc_depth=1;
            const bool recursion_blocked=!evaluate_effect(d,state,event);
            event.proc_depth=0;
            const auto next=evaluate_effect(d,state,event);
            if (!first || !next || !cooldown_blocked || !recursion_blocked)
                throw std::runtime_error("effect outcome gate failed");
            std::printf("%s{\"handle\":%zu,\"action\":%u,\"magnitude_permille\":%u,"
                        "\"max_targets\":%u,\"cooldown_blocked\":true,\"recursion_blocked\":true}",
                        i ? "," : "",i,static_cast<unsigned>(first->action),
                        first->magnitude_permille,first->max_targets);
        }
        std::vector<EffectState> states(count);
        std::uint64_t checksum=0;
        constexpr std::uint64_t iterations=1000000;
        const auto start=std::chrono::steady_clock::now();
        for (std::uint64_t i=0;i<iterations;++i) {
            const auto index=i%count; const auto& d=defs[index];
            EffectEvent event{d.trigger,d.tags,d.requires_status,i,0};
            if (const auto c=evaluate_effect(d,states[index],event)) checksum+=c->magnitude_permille;
        }
        const auto ns=std::chrono::duration<double,std::nano>(std::chrono::steady_clock::now()-start).count();
        std::printf("],\"evaluations\":%llu,\"ns_per_evaluation\":%.2f,\"checksum\":%llu}\n",
            static_cast<unsigned long long>(iterations),ns/iterations,static_cast<unsigned long long>(checksum));
        return 0;
    } catch (const std::exception& e) { std::fprintf(stderr,"EFFECT LAB FAILED: %s\n",e.what()); return 1; }
}
