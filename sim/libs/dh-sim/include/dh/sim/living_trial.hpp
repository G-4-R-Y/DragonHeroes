#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <dh/sim/living_content.generated.hpp>

// Offline playable review: fixed 30 Hz, bounded storage, no I/O or Godot.
// All damage, cooldowns, movement, target selection and companion actions live here.
namespace dh::sim {
struct TrialVec {
    float x{}, y{};
    TrialVec operator+(TrialVec b) const { return {x+b.x,y+b.y}; }
    TrialVec operator-(TrialVec b) const { return {x-b.x,y-b.y}; }
    TrialVec operator*(float s) const { return {x*s,y*s}; }
};
inline float length(TrialVec p) { return std::sqrt(p.x*p.x+p.y*p.y); }
inline TrialVec unit(TrialVec p) { const auto l=length(p); return l>0.001f?p*(1.0f/l):TrialVec{1,0}; }
inline TrialVec arena_clamp(TrialVec p) { return {std::clamp(p.x,40.0f,600.0f),std::clamp(p.y,100.0f,262.0f)}; }
enum TrialButton : unsigned { strike=1, evade=2, mire=4, storm=8, command_pet=16, restart=32, pause=64, bond=128, stop=256, advance=512 };
struct TrialInput { TrialVec move{}, aim{440,180}; unsigned buttons{}, artifact{3}; };
struct TrialActor { TrialVec pos{}; float hp{}, maximum{}, ward{}; unsigned wet{}, hit{}, respawn{}; };
struct TrialVisual { unsigned kind{}, ttl{}, total{}, hostile{}; TrialVec a{}, b{}; float radius{}; };
struct TrialHazard { TrialVec pos{}; float radius{}, damage{}; unsigned delay{}, life{}, kind{}; bool active{}; };
struct TrialEcho { unsigned target{}, remaining{}; float damage{}; unsigned visual_life{14}; };

class LivingTrial {
public:
    static constexpr unsigned hz=30, visual_cap=32, hazard_cap=12;
    TrialActor hunter{{155,200},living_data::hunter_hp,living_data::hunter_hp,0,0,0,0};
    std::array<TrialActor,4> enemies{};
    TrialVec pet{125,210};
    std::array<TrialVisual,visual_cap> visuals{};
    std::array<TrialHazard,hazard_cap> hazards{};
    std::array<TrialEcho,16> echoes{};
    std::array<EffectState,8> effect_state{};
    std::array<unsigned,5> proc_counts{}; // enum EffectAction, stable wire order
    std::array<unsigned,5> cooldown{};   // melee, dodge, field, storm, pet
    std::uint64_t tick{};
    unsigned artifact{3}, phase{}, phase_clock{}, phase_seen{}, invulnerable{}, player_wet{}, result{}, bonds{};
    unsigned previous_buttons{}, pet_target{4}, overflow{};
    float mana{100}, total_damage{}, echo_damage{}, chain_damage{}, absorbed{};
    TrialVec dash_dir{1,0}, facing{1,0}, leap_start{}, leap_end{};

    unsigned lair_index{};
    float difficulty{1};
    const auto& definition() const { return dh::content::lairs::definitions[lair_index]; }
    explicit LivingTrial(unsigned lair=0, float scale=1) : lair_index(std::min(lair,static_cast<unsigned>(dh::content::lairs::definitions.size()-1))), difficulty(scale) {
        const float hp=definition().boss_hp*difficulty;
        enemies[0]={{435,187},hp,hp,0,0,0,0};
        enemies[1]={{368,235},180,180,0,0,0,0};
        enemies[2]={{515,230},180,180,0,0,0,0};
        enemies[3]={{535,132},180,180,0,0,0,0};
    }
    void visual(unsigned kind, TrialVec a, TrialVec b, float radius, unsigned ttl, unsigned hostile=0) {
        auto it=std::find_if(visuals.begin(),visuals.end(),[](const auto& v){return v.ttl==0;});
        if(it==visuals.end()) { ++overflow; return; }
        *it={kind,ttl,ttl,hostile,a,b,radius};
    }
    void hazard(TrialVec p,float radius,float damage,unsigned delay,unsigned life,unsigned kind) {
        auto it=std::find_if(hazards.begin(),hazards.end(),[](const auto& h){return h.life==0;});
        if(it==hazards.end()) { ++overflow; return; }
        *it={arena_clamp(p),radius,damage,delay,life,kind,false};
    }
    int target(TrialVec point, float radius, TrialVec origin, float reach) const {
        int found=-1; float best=radius;
        for(unsigned i=0;i<enemies.size();++i) {
            const auto& a=enemies[i]; const float d=length(a.pos-point);
            if(a.hp>0 && d<best && length(a.pos-origin)<=reach) { found=static_cast<int>(i); best=d; }
        }
        return found;
    }
    float base_damage() const { return living_data::base_damage+living_data::affixes[artifact]*living_data::affix_damage_per_point; }
    void hurt_enemy(unsigned index,float damage) {
        auto& a=enemies[index]; if(a.hp<=0) return;
        if(index==0 && definition().phases[phase].verb==4 && phase_clock>definition().phases[phase].windup) damage*=1.35f;
        const float shield=std::min(a.ward,damage); a.ward-=shield; damage-=shield;
        const float dealt=std::min(a.hp,damage); a.hp-=dealt; total_damage+=dealt; a.hit=5;
        if(a.hp==0 && index>0) a.respawn=180;
    }
    void hurt_hunter(float damage) {
        if(invulnerable || result) return;
        const float shield=std::min(hunter.ward,damage); hunter.ward-=shield; damage-=shield; absorbed+=shield;
        hunter.hp=std::max(0.0f,hunter.hp-damage); hunter.hit=5;
    }
    void trigger(EffectTrigger kind, unsigned tags, unsigned index, float root_damage) {
        EffectEvent event{kind,tags,index<4 && enemies[index].wet?1u:0u,tick,0};
        for(unsigned n=0;n<living_data::effects.size();++n) {
            if(!(living_data::artifact_masks[artifact]&(1u<<n))) continue;
            const auto command=evaluate_effect(living_data::effects[n],effect_state[n],event);
            if(!command) continue;
            const auto action=command->action;
            const unsigned duration=living_data::visual_ticks[n];
            ++proc_counts[static_cast<unsigned>(action)];
            const float amount=static_cast<float>(command->magnitude_permille)/1000.0f;
            if(action==EffectAction::echo && index<4) {
                auto slot=std::find_if(echoes.begin(),echoes.end(),[](const auto& e){return e.remaining==0;});
                if(slot!=echoes.end()) *slot={index,9,root_damage*amount,duration};
                else ++overflow;
            } else if(action==EffectAction::chain && index<4) {
                unsigned hits=0;
                for(unsigned j=0;j<4 && hits<command->max_targets;++j) {
                    if(j==index || enemies[j].hp<=0 || length(enemies[j].pos-enemies[index].pos)>220) continue;
                    // Child damage never calls trigger(), and cannot consume another Wet mark.
                    hurt_enemy(j,root_damage*amount); chain_damage+=root_damage*amount; ++hits;
                    visual(2,enemies[index].pos,enemies[j].pos,0,duration);
                }
            } else if(action==EffectAction::resource) {
                mana=std::min(100.0f,mana+100.0f*amount); visual(3,hunter.pos,hunter.pos,22,duration);
            } else if(action==EffectAction::ward) {
                hunter.ward=std::max(hunter.ward,hunter.maximum*amount);
                visual(4,hunter.pos,hunter.pos,25,duration);
            }
        }
        if(index<4 && !(event.statuses&1u)) enemies[index].wet=0;
    }
    void attack(const TrialInput& input) {
        if((input.buttons&strike) && !cooldown[0]) {
            cooldown[0]=11; const int t=target(hunter.pos,62,hunter.pos,62);
            visual(0,hunter.pos,hunter.pos+facing*50,45,8);
            if(t>=0) { hurt_enemy(static_cast<unsigned>(t),base_damage()); trigger(EffectTrigger::hit,2,static_cast<unsigned>(t),base_damage()); }
        }
        if((input.buttons&evade) && !cooldown[1] && mana>=12) {
            mana-=12; cooldown[1]=24; invulnerable=8; dash_dir=length(input.move)>0.1f?unit(input.move):facing;
            trigger(EffectTrigger::dodge,4,4,0); visual(3,hunter.pos,hunter.pos-dash_dir*30,15,12);
        }
        if((input.buttons&mire) && !cooldown[2] && mana>=18) {
            mana-=18; cooldown[2]=75;
            TrialVec point=input.aim;
            if(length(point-hunter.pos)>215) point=hunter.pos+unit(point-hunter.pos)*215;
            point=arena_clamp(point); visual(5,point,point,48,45);
            for(unsigned i=0;i<4;++i) if(enemies[i].hp>0 && length(enemies[i].pos-point)<58) {
                enemies[i].wet=150; hurt_enemy(i,8);
            }
        }
        if((input.buttons&storm) && !cooldown[3] && mana>=22) {
            const int t=target(input.aim,65,hunter.pos,240);
            if(t>=0) {
                mana-=22; cooldown[3]=36; const auto id=static_cast<unsigned>(t);
                const float damage=base_damage()*1.3f;
                hurt_enemy(id,damage); visual(2,hunter.pos,enemies[id].pos,0,12);
                trigger(EffectTrigger::hit,1,id,damage);
            }
        }
        if((input.buttons&command_pet) && !cooldown[4]) {
            const int t=target(input.aim,100,hunter.pos,650);
            if(t>=0) { cooldown[4]=90; pet_target=static_cast<unsigned>(t); }
        }
    }
    void boss_step() {
        auto& boss=enemies[0]; const auto def=definition().phases[phase];
        if(phase_clock==0) {
            phase_seen|=1u<<phase;
            if(def.verb==0) {
                for(int k=-1;k<=1;++k) hazard(hunter.pos+TrialVec{static_cast<float>(k*65),22},def.radius,def.damage,def.windup,100,0);
            } else if(def.verb==1) {
                hazard(hunter.pos,def.radius,def.damage,def.windup,12,1);
            } else if(def.verb==2) {
                leap_start=boss.pos;
                leap_end=arena_clamp(hunter.pos+TrialVec{hunter.pos.x>320?-90.0f:90.0f,0});
                hazard(leap_end,def.radius,def.damage,def.windup,10,2);
                visual(6,boss.pos,leap_end,def.radius,def.windup,1);
            } else if(def.verb==3) {
                hazard(boss.pos,def.radius,def.damage,def.windup,10,3);
                hazard(boss.pos,def.radius+12,def.damage*0.65f,def.windup+17,10,3);
            } else {
                boss.ward=95;
                hazard(boss.pos,def.radius,def.damage,def.windup,10,4);
            }
        }
        if(def.verb==2 && phase_clock>=def.windup && phase_clock<def.windup+9)
            boss.pos=leap_start+(leap_end-leap_start)*(static_cast<float>(phase_clock-def.windup+1)/9.0f);
        if(def.verb==4 && phase_clock==def.windup) boss.ward=0;
        ++phase_clock;
        if(phase_clock>=def.windup+def.recovery) {
            phase=(phase+1)%definition().phase_count; phase_clock=0;
        }
    }
    void step(TrialInput input) {
        const unsigned edges=input.buttons&~previous_buttons;
        previous_buttons=input.buttons;
        if(edges&restart) { *this=LivingTrial{lair_index,difficulty}; previous_buttons=input.buttons; }
        artifact=std::min(input.artifact,3u);
        if(input.buttons&pause) return;
        ++tick;
        for(auto& v:visuals) if(v.ttl) --v.ttl;
        for(auto& cd:cooldown) if(cd) --cd;
        for(auto& a:enemies) { if(a.wet) --a.wet; if(a.hit) --a.hit; }
        if(hunter.hit) --hunter.hit;
        if(player_wet) --player_wet;
        if(result) {
            if(result==1 && (edges&bond)) bonds=1;
            if(bonds) {
                const float magnitude=length(input.move);
                if(magnitude>1) input.move=input.move*(1.0f/magnitude);
                hunter.pos=arena_clamp(hunter.pos+input.move*(living_data::move_speed/hz));
                enemies[0].pos=enemies[0].pos+(hunter.pos+TrialVec{-42,-8}-enemies[0].pos)*0.07f;
                pet=pet+(hunter.pos+TrialVec{-20,12}-pet)*0.1f;
            }
            return;
        }
        mana=std::min(100.0f,mana+0.28f);
        hunter.ward=std::max(0.0f,hunter.ward-0.04f);
        facing=unit(input.aim-hunter.pos);
        const float magnitude=length(input.move);
        if(magnitude>1) input.move=input.move*(1.0f/magnitude);
        if(invulnerable) { --invulnerable; hunter.pos=arena_clamp(hunter.pos+dash_dir*(520.0f/hz)); }
        else hunter.pos=arena_clamp(hunter.pos+input.move*(living_data::move_speed/hz));
        attack(input);
        if(pet_target<4 && enemies[pet_target].hp>0) {
            auto& foe=enemies[pet_target]; const float distance=length(foe.pos-pet);
            pet=pet+unit(foe.pos-pet)*std::min(distance,11.0f);
            if(distance<18) {
                foe.wet=150; hurt_enemy(pet_target,18); visual(5,foe.pos,foe.pos,24,16);
                trigger(EffectTrigger::pet_hit,8,pet_target,18); pet_target=4;
            }
        } else { pet_target=4; const auto goal=hunter.pos+TrialVec{-24,12}; pet=pet+(goal-pet)*0.12f; }
        for(auto& echo:echoes) if(echo.remaining && --echo.remaining==0) {
            if(enemies[echo.target].hp>0) {
                hurt_enemy(echo.target,echo.damage); echo_damage+=echo.damage;
                visual(1,enemies[echo.target].pos,enemies[echo.target].pos+TrialVec{30,-15},35,echo.visual_life);
            }
        }
        if(enemies[0].hp>0) boss_step();
        for(auto& h:hazards) {
            if(!h.life) continue;
            if(h.delay) { --h.delay; continue; }
            const bool inside=length(hunter.pos-h.pos)<h.radius+7;
            if(!h.active) {
                h.active=true; visual(7,h.pos,h.pos,h.radius,12,1);
                if(inside) {
                    const float bonus=h.kind==1 && player_wet?1.5f:1.0f;
                    hurt_hunter(h.damage*bonus);
                    if(h.kind==1) player_wet=0;
                }
            }
            if(h.kind==0 && inside) {
                player_wet=90;
                if(tick%30==0) hurt_hunter(h.damage*0.3f);
            }
            --h.life;
        }
        for(unsigned i=1;i<4;++i) {
            auto& a=enemies[i];
            if(a.hp<=0 && a.respawn && --a.respawn==0) a.hp=a.maximum;
        }
        if(enemies[0].hp<=0) {
            result=1; for(auto& h:hazards) h.life=0;
            for(unsigned i=1;i<4;++i) enemies[i].hp=0;
        }
        else if(hunter.hp<=0) result=2;
    }
};
} // namespace dh::sim
