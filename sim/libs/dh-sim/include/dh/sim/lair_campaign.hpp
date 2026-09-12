#pragma once
#include <dh/sim/living_trial.hpp>

namespace dh::sim {
struct LairProgress {
    static constexpr unsigned limit=1000000;
    std::array<unsigned,8> clears{}, rush_clears{};
    std::array<unsigned,4> items{};
    bool operator==(const LairProgress&) const = default;
};
enum class LairMode : unsigned { practice=0, lair=1, rush=2 };
// The host observes actual simulation victories. There is no client reward command.
class LairCampaign {
public:
    LivingTrial trial;
    LairProgress progress;
    LairMode mode;
    unsigned round{1}, reward{4}, unlocked_count{}, previous_buttons{};
    bool awarded{}, locked{};
    LairCampaign(LairMode m=LairMode::practice,unsigned lair=0,LairProgress saved={})
        : trial(lair),progress(saved),mode(m) {
        for(unsigned i=0;i<dh::content::lairs::definitions.size();++i) if(progress.clears[i]) ++unlocked_count;
        locked=mode==LairMode::rush && !progress.clears[trial.lair_index];
    }
    unsigned allowed_artifact(unsigned requested) const {
        return requested<4 && (mode==LairMode::practice || requested==0 || progress.items[requested]) ? requested:0;
    }
    void step(TrialInput input) {
        if(locked || (input.buttons&pause)) return;
        const auto edges=input.buttons&~previous_buttons; previous_buttons=input.buttons;
        input.artifact=allowed_artifact(input.artifact);
        if(edges&restart) {
            round=1; trial=LivingTrial{trial.lair_index}; awarded=false; reward=4;
        } else if((edges&advance) && trial.result==1 && awarded) {
            auto next=trial.lair_index;
            if(mode==LairMode::rush) {
                for(unsigned n=1;n<=dh::content::lairs::definitions.size();++n) {
                    const unsigned id=(trial.lair_index+n)%dh::content::lairs::definitions.size();
                    if(progress.clears[id]) { next=id; break; }
                }
                round=std::min(round+1,10000u);
            }
            const auto hp=trial.hunter.hp;
            const float scale=mode==LairMode::rush?std::min(dh::content::lairs::rush_hp_cap,1+(round-1)*dh::content::lairs::rush_hp_step):1;
            trial=LivingTrial{next,scale};
            if(mode==LairMode::rush) trial.hunter.hp=std::min(trial.hunter.maximum,hp+trial.hunter.maximum*dh::content::lairs::rush_rest_heal_fraction);
            awarded=false; reward=4;
        }
        input.buttons &= ~(restart|advance);
        trial.step(input);
        if(trial.result==1 && !awarded) {
            awarded=true;
            if(mode==LairMode::practice) return;
            const auto id=trial.lair_index;
            const auto& def=trial.definition();
            reward=def.rewards[(progress.clears[id]+progress.rush_clears[id])%def.reward_count];
            if(mode==LairMode::lair) {
                if(!progress.clears[id]) ++unlocked_count;
                progress.clears[id]=std::min(progress.clears[id]+1,LairProgress::limit);
            } else progress.rush_clears[id]=std::min(progress.rush_clears[id]+1,LairProgress::limit);
            progress.items[reward]=std::min(progress.items[reward]+1,LairProgress::limit);
        }
    }
};
}
