#include <bit>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <dh/sim/living_trial.hpp>
using namespace dh::sim;
static unsigned failures=0;
#define REQUIRE(x) do { if(!(x)) { std::printf("FAIL %d: %s\n",__LINE__,#x); ++failures; } } while(false)

int main() {
    LivingTrial blade; blade.enemies[0].pos={185,200};
    blade.step({{}, {185,200},strike,0});
    const float after_root=blade.enemies[0].hp;
    for(unsigned i=0;i<10;++i) blade.step({{}, {185,200},0,0});
    REQUIRE(blade.enemies[0].hp<after_root);
    REQUIRE(blade.echo_damage>10 && blade.proc_counts[0]==1);
    // Real child damage does not generate an echo of an echo.
    for(unsigned i=0;i<60;++i) blade.step({{}, {185,200},0,0});
    REQUIRE(blade.proc_counts[0]==1);

    LivingTrial relic; relic.mana=40;
    relic.step({{1,0},{400,200},evade,1});
    REQUIRE(relic.mana>43 && relic.proc_counts[3]==1 && relic.invulnerable>0);
    const auto hp=relic.hunter.hp; relic.hurt_hunter(50);
    REQUIRE(relic.hunter.hp==hp);
    LivingTrial plain; plain.mana=40; plain.step({{1,0},{400,200},evade,0});
    REQUIRE(plain.mana<29 && plain.proc_counts[3]==0);

    LivingTrial mythic; mythic.hunter.pos={260,190};
    mythic.step({{},mythic.enemies[0].pos,mire|storm,2});
    REQUIRE(mythic.enemies[0].wet==0 && mythic.chain_damage>0);
    REQUIRE(mythic.proc_counts[1]==1 && mythic.enemies[1].hp<mythic.enemies[1].maximum);
    // Consumed Wet and the internal cooldown survive artifact switches.
    mythic.cooldown[3]=0; mythic.mana=100;
    mythic.step({{},mythic.enemies[0].pos,storm,3});
    REQUIRE(mythic.proc_counts[1]==1);

    LivingTrial divine; divine.pet=divine.enemies[0].pos;
    divine.step({{},divine.enemies[0].pos,command_pet,3});
    REQUIRE(divine.proc_counts[4]==1 && divine.hunter.ward==35);
    divine.hurt_hunter(20);
    REQUIRE(divine.hunter.hp==divine.hunter.maximum && divine.absorbed==20);

    LivingTrial phases; phases.hunter.hp=100000;
    for(unsigned i=0;i<900;++i) phases.step({{}, {450,180},0,0});
    REQUIRE(phases.phase_seen==(1u<<phases.definition().phase_count)-1);
    REQUIRE(phases.overflow==0);
    const auto paused_tick=phases.tick;
    phases.step({{1,1},{450,180},pause,0});
    REQUIRE(phases.tick==paused_tick);

    LivingTrial movement;
    for(unsigned i=0;i<100;++i) movement.step({{1,1},{450,180},0,0});
    REQUIRE(movement.hunter.pos.x<=600 && movement.hunter.pos.y<=262);
    // A death, retry and bond are actual simulation transitions.
    LivingTrial end; end.enemies[0].hp=0; end.step({});
    REQUIRE(end.result==1);
    end.step({{}, {},bond,3}); REQUIRE(end.bonds==1);
    const auto bonded_position=end.enemies[0].pos;
    end.step({{1,0}, {},0,3}); REQUIRE(end.enemies[0].pos.x!=bonded_position.x);
    end.step({{}, {},restart,3}); REQUIRE(end.result==0 && end.enemies[0].hp>0 && end.bonds==0);
    end.hunter.hp=0; end.step({}); REQUIRE(end.result==2);

    LivingTrial a,b;
    const auto start=std::chrono::steady_clock::now();
    for(unsigned i=0;i<30000;++i) {
        if(i%900==0) { a=LivingTrial{}; b=LivingTrial{}; }
        const TrialInput input{{i%100<50?1.0f:-1.0f,0},a.enemies[0].pos,
                               i%90<30?mire|storm|command_pet:strike|evade,i/50%4};
        a.step(input); b.step(input);
        REQUIRE(std::bit_cast<std::uint32_t>(a.hunter.hp)==std::bit_cast<std::uint32_t>(b.hunter.hp));
        REQUIRE(a.total_damage==b.total_damage && a.phase==b.phase && a.hunter.pos.x==b.hunter.pos.x);
    }
    const auto ns=std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count();
    std::printf("LIVING SIM %s: echo damage, chain/Wet, refund, ward, i-frames, 5 phases, pause, retry, bond, replay; %.0f ns/step\n",
                failures?"FAIL":"OK",static_cast<double>(ns)/60000);
    return failures?EXIT_FAILURE:EXIT_SUCCESS;
}
