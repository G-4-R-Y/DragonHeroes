#include <cstdio>
#include <cstdlib>
#include <dh/sim/lair_campaign.hpp>
#include <dh/procgen/lairs.hpp>
using namespace dh::sim;
static unsigned failures=0;
#define REQUIRE(x) do { if(!(x)) { std::printf("FAIL %d: %s\n",__LINE__,#x); ++failures; } } while(false)
static void win(LairCampaign& c) {
    // Drive the full fight via ordinary skill input: no health/damage overrides.
    for(unsigned i=0;i<4000 && !c.trial.result;++i) {
        auto& t=c.trial;
        auto direction=t.enemies[0].pos-t.hunter.pos;
        const auto movement=length(direction)>42?unit(direction):TrialVec{};
        c.step({movement,t.enemies[0].pos,strike|mire|storm|command_pet,3});
    }
    REQUIRE(c.trial.result==1);
}
int main() {
    LairCampaign locked(LairMode::rush);
    locked.step({}); REQUIRE(locked.locked && locked.trial.tick==0 && locked.progress.items[0]==0);
    LairCampaign practice; win(practice);
    REQUIRE(practice.progress.clears[0]==0 && practice.progress.items[0]==0);
    LairCampaign lair(LairMode::lair);
    REQUIRE(lair.allowed_artifact(3)==0);
    win(lair);
    REQUIRE(lair.progress.clears[0]==1 && lair.progress.items[0]==1 && lair.unlocked_count==1);
    const auto once=lair.progress;
    for(unsigned i=0;i<100;++i) lair.step({});
    REQUIRE(lair.progress==once); // victory cannot award twice while viewing/bonding
    lair.step({{}, {},restart,0}); REQUIRE(lair.trial.result==0 && lair.progress==once);
    lair.trial.hunter.hp=0; lair.step({}); REQUIRE(lair.trial.result==2 && lair.progress==once);
    LairCampaign rush(LairMode::rush,0,once); win(rush);
    REQUIRE(!rush.locked && rush.progress.rush_clears[0]==1 && rush.progress.items[1]==1);
    REQUIRE(rush.allowed_artifact(1)==1 && rush.allowed_artifact(3)==0);
    rush.step({});
    rush.step({{}, {},pause|advance,1}); REQUIRE(rush.round==1 && rush.trial.result==1);
    rush.step({{}, {},advance,1});
    REQUIRE(rush.round==2 && rush.trial.difficulty>1 && rush.trial.result==0);
    REQUIRE(rush.trial.hunter.hp<=rush.trial.hunter.maximum && rush.trial.hunter.hp>0);
    rush.step({{}, {},advance,1}); REQUIRE(rush.round==2);
    for(unsigned i=0;i<100;++i) {
        LairCampaign replay(LairMode::lair); win(replay); REQUIRE(replay.progress==once);
    }
    unsigned found=0;
    for(unsigned seed=1;seed<=80;++seed) for(int cy=-4;cy<=4;++cy) for(int cx=-4;cx<=4;++cx) {
        const auto chunk=dh::procgen::generate_chunk(seed,cx,cy);
        const auto before=chunk.tiles;
        const auto a=dh::procgen::lair_entrances(seed,chunk),b=dh::procgen::lair_entrances(seed,chunk);
        REQUIRE(a.count==b.count && chunk.tiles==before);
        for(unsigned j=0;j<a.count;++j) {
            ++found; const auto e=a.entries[j];
            REQUIRE(e.x==b.entries[j].x && e.y==b.entries[j].y && e.lair==b.entries[j].lair);
            for(int dy=-2;dy<=2;++dy) for(int dx=-2;dx<=2;++dx) {
                const auto tile=chunk.tile_at(static_cast<int>(e.x)+dx,static_cast<int>(e.y)+dy);
                REQUIRE(tile==1 || tile==2);
            }
        }
    }
    REQUIRE(found>80);
    REQUIRE(dh::procgen::floor_div(-1,3)==-1 && dh::procgen::floor_div(-3,3)==-1);
    std::printf("LAIR OUTCOMES %s: full combat unlock, earned items, practice/locked/death/retry no grants, rush/rest, deterministic clear entrances (%u)\n",failures?"FAIL":"OK",found);
    return failures?EXIT_FAILURE:EXIT_SUCCESS;
}
