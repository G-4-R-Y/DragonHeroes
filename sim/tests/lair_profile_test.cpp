#include "../libs/dh-server/src/lair_profile.hpp"
#include <chrono>
#include <fstream>
#include <cstdio>
int main() {
    const auto root=std::filesystem::path("lair-profile-test-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
    std::filesystem::create_directory(root);
    const auto path=(root/"collection.txt").string();
    bool passed=true;
    {
        LairProfile first(path.c_str()), second(path.c_str());
        dh::sim::LairProgress p;
        passed &= first.read(p) && p.items[0]==0 && first.lock() && !second.lock();
        p.clears[0]=1; p.rush_clears[0]=2; p.items={1,1,1,0};
        passed &= first.write(p);
        dh::sim::LairProgress copy;
        passed &= second.read(copy) && p==copy;
        p.items[3]=2; passed &= first.write(p) && second.read(copy) && copy==p;
    }
    {
        LairProfile reopened(path.c_str()); dh::sim::LairProgress p;
        passed &= reopened.lock() && reopened.read(p) && p.items[3]==2;
        std::ofstream(path)<<"DH_LAIRS 1\nI unknown.item.id 1\nEND\n";
        auto before=p; passed &= !reopened.read(p) && p==before;
        std::ofstream(path)<<"DH_LAIRS 1\nEND\ntrailing";
        passed &= !reopened.read(p);
        std::ofstream(path)<<"DH_LAIRS 1\nL fen_bells.lair.bell_shrine 0 10\nEND\n";
        passed &= !reopened.read(p);
        std::ofstream(path)<<"DH_LAIRS 1\nL fen_bells.lair.bell_shrine 1 0\nL fen_bells.lair.bell_shrine 1 0\nEND\n";
        passed &= !reopened.read(p);
    }
    {
        const auto encoded=(root/std::filesystem::path(u8"coleção-竜.txt")).u8string();
        const std::string unicode_path(encoded.begin(),encoded.end());
        LairProfile unicode(unicode_path.c_str()); dh::sim::LairProgress p,copy;
        p.clears[0]=1; p.items[0]=1;
        passed &= unicode.lock() && unicode.write(p) && unicode.read(copy) && copy==p;
    }
    std::filesystem::remove_all(root); // only this test's uniquely created directory
    std::printf("LAIR PROFILE %s: atomic replacement, reopen, exclusive writer, malformed/unknown/duplicate preservation\n",passed?"OK":"FAIL");
    return passed?0:1;
}
