#pragma once
#include <array>
#include <dh/procgen/chunk.hpp>
#include <dh/content/lairs.generated.hpp>
#include <dh/math/hash.hpp>

namespace dh::procgen {
struct LairEntrance { unsigned lair{}, x{}, y{}; };
struct LairEntrances { std::array<LairEntrance,8> entries{}; unsigned count{}; };
inline std::int64_t floor_div(std::int64_t n, std::int64_t d) { return n/d - (n%d<0); }
// Separate POI version: adding entrances never changes a previously generated tile.
// One selected chunk per region/lair, at most eight clear, non-overlapping pads.
inline LairEntrances lair_entrances(std::uint64_t seed, const Chunk& chunk) {
    LairEntrances result;
    for(unsigned id=0;id<dh::content::lairs::definitions.size();++id) {
        const auto& def=dh::content::lairs::definitions[id];
        const auto span=static_cast<std::int64_t>(def.region_chunks);
        const auto rx=floor_div(chunk.cx+span/2,span), ry=floor_div(chunk.cy+span/2,span);
        const auto hash=dh::math::hash_coords(seed,rx,ry,def.salt);
        const auto cx=rx*span + (rx==0 && ry==0?0:static_cast<std::int64_t>(hash%span)-span/2);
        const auto cy=ry*span + (rx==0 && ry==0?0:static_cast<std::int64_t>((hash>>16)%span)-span/2);
        if(chunk.cx!=cx || chunk.cy!=cy) continue;
        for(unsigned k=0;k<3600;++k) {
            const auto cell=static_cast<unsigned>((hash+k)%3600);
            const unsigned x=2+cell%60, y=2+cell/60;
            bool clear=true;
            for(int dy=-2;dy<=2 && clear;++dy) for(int dx=-2;dx<=2;++dx) {
                const auto tile=chunk.tile_at(static_cast<int>(x)+dx,static_cast<int>(y)+dy);
                if(tile!=static_cast<unsigned>(Tile::Grass) && tile!=static_cast<unsigned>(Tile::Forest)) { clear=false; break; }
            }
            for(unsigned j=0;j<result.count;++j) {
                const int dx=static_cast<int>(x)-static_cast<int>(result.entries[j].x);
                const int dy=static_cast<int>(y)-static_cast<int>(result.entries[j].y);
                if(dx*dx+dy*dy<100) clear=false;
            }
            if(clear) { result.entries[result.count++]={id,x,y}; break; }
        }
    }
    return result;
}
}
