// Local preview host. UDP is loopback-only; an ephemeral client port + token
// bind the child process to one Godot presenter. No network/economy integration.
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <thread>
#include "lair_profile.hpp"
#include <dh/procgen/lairs.hpp>
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
using Socket=SOCKET;
static void close_socket(Socket s) { closesocket(s); }
#else
#include <arpa/inet.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <unistd.h>
using Socket=int;
static void close_socket(Socket s) { close(s); }
#endif

namespace {
std::uint32_t read32(const unsigned char* p) {
    return static_cast<std::uint32_t>(p[0])|(static_cast<std::uint32_t>(p[1])<<8)|
           (static_cast<std::uint32_t>(p[2])<<16)|(static_cast<std::uint32_t>(p[3])<<24);
}
void write32(unsigned char* p,std::uint32_t value) {
    for(unsigned i=0;i<4;++i) p[i]=static_cast<unsigned char>(value>>(8*i));
}
float read_float(const unsigned char* p) { return std::bit_cast<float>(read32(p)); }
}

int living_preview(unsigned client_port, unsigned token, const char* profile_path, const char* mode_name, const char* lair_id, std::uint64_t seed, const char* entrance) {
    using namespace dh::sim;
    LairMode mode=LairMode::practice;
    if(mode_name) {
        if(std::strcmp(mode_name,"lair")==0) mode=LairMode::lair;
        else if(std::strcmp(mode_name,"rush")==0) mode=LairMode::rush;
        else if(std::strcmp(mode_name,"practice")!=0) return 2;
    }
    unsigned lair=0;
    if(lair_id) {
        bool found=false;
        for(unsigned i=0;i<dh::content::lairs::definitions.size();++i)
            if(dh::content::lairs::definitions[i].id==lair_id) { lair=i; found=true; break; }
        if(!found) return 2;
    }
    bool entrance_valid=mode!=LairMode::lair;
    if(mode==LairMode::lair && entrance) {
        long long cx=0,cy=0; char tail=0;
        if(std::sscanf(entrance,"%lld,%lld%c",&cx,&cy,&tail)==2 && std::abs(cx)<=10000000 && std::abs(cy)<=10000000) {
            const auto entries=dh::procgen::lair_entrances(seed,dh::procgen::generate_chunk(seed,cx,cy));
            for(unsigned i=0;i<entries.count;++i) if(entries.entries[i].lair==lair) entrance_valid=true;
        }
    }
    LairProgress saved;
    LairProfile profile(profile_path);
    const bool profile_ok=mode==LairMode::practice || (profile.lock() && profile.read(saved));
    LairCampaign campaign(mode,lair,saved);
    unsigned save_status=profile_ok?0:2; // 0 clean, 1 saving, 2 failed/preserved
    if(!profile_ok || !entrance_valid) campaign.locked=true;
    auto& trial=campaign.trial;
    if(client_port==0 || client_port>65535 || token==0) return 2;
#ifdef _WIN32
    WSADATA data{}; if(WSAStartup(MAKEWORD(2,2),&data)!=0) return 3;
#endif
    const Socket sock=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP);
#ifdef _WIN32
    if(sock==INVALID_SOCKET) { WSACleanup(); return 3; }
    u_long nonblocking=1; ioctlsocket(sock,FIONBIO,&nonblocking);
#else
    if(sock<0) return 3;
    fcntl(sock,F_SETFL,O_NONBLOCK);
#endif
    sockaddr_in local{}; local.sin_family=AF_INET; local.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    if(bind(sock,reinterpret_cast<sockaddr*>(&local),sizeof(local))!=0) { close_socket(sock); return 3; }
    sockaddr_in client=local; client.sin_port=htons(static_cast<unsigned short>(client_port));
    dh::sim::TrialInput input;
    std::uint32_t last_sequence=0,snapshot_sequence=0;
    using Clock=std::chrono::steady_clock;
    auto deadline=Clock::now(); auto last_input=deadline; auto save_retry=deadline;
    bool dirty=false;
    unsigned queued_impulses=0;
    std::array<unsigned char,4096> packet{};
    while(Clock::now()-last_input<std::chrono::seconds(12)) {
        for(unsigned drained=0;drained<64;++drained) {
            sockaddr_in from{};
#ifdef _WIN32
            int size=sizeof(from);
#else
            socklen_t size=sizeof(from);
#endif
            const auto n=recvfrom(sock,reinterpret_cast<char*>(packet.data()),static_cast<int>(packet.size()),0,
                                  reinterpret_cast<sockaddr*>(&from),&size);
            if(n<0) break;
            if(n!=36 || from.sin_addr.s_addr!=client.sin_addr.s_addr || from.sin_port!=client.sin_port ||
               read32(packet.data())!=0x31494c44u || read32(packet.data()+4)!=token) continue;
            const auto sequence=read32(packet.data()+8);
            if(sequence<=last_sequence) continue;
            const float x=read_float(packet.data()+12),y=read_float(packet.data()+16);
            const float ax=read_float(packet.data()+20),ay=read_float(packet.data()+24);
            if(!std::isfinite(x)||!std::isfinite(y)||!std::isfinite(ax)||!std::isfinite(ay) ||
               std::abs(x)>1 || std::abs(y)>1 || ax<0 || ax>640 || ay<0 || ay>360) continue;
            const auto buttons=read32(packet.data()+28),artifact=read32(packet.data()+32);
            if(buttons>1023 || artifact>3) continue;
            queued_impulses |= buttons & (restart|advance|bond|stop);
            input={{x,y},{ax,ay},buttons,artifact}; last_sequence=sequence; last_input=Clock::now();
        }
        input.buttons |= queued_impulses;
        if(input.buttons&dh::sim::stop) break;
        // A missing controller must never keep moving/casting indefinitely.
        if(Clock::now()-last_input>std::chrono::milliseconds(250)) input.buttons=dh::sim::pause;
        const auto before=campaign.progress;
        if(!dirty) {
            campaign.step(input);
            if(!(input.buttons&dh::sim::pause)) queued_impulses=0;
        }
        if(!(before==campaign.progress)) { dirty=true; save_status=1; }
        if(dirty && Clock::now()>=save_retry) {
            if(profile.write(campaign.progress)) { dirty=false; save_status=0; }
            else { save_status=2; save_retry=Clock::now()+std::chrono::seconds(1); }
        }
        std::array<float,512> values{}; unsigned count=0;
        auto put=[&](auto v) { values[count++]=static_cast<float>(v); };
        put(last_sequence); put(trial.tick); put(trial.artifact); put(trial.result); put(trial.bonds);
        put(trial.phase); put(trial.phase_clock); put(trial.definition().phases[trial.phase].windup);
        put(trial.definition().phases[trial.phase].recovery); put(trial.mana);
        put(trial.hunter.pos.x); put(trial.hunter.pos.y); put(trial.hunter.hp); put(trial.hunter.maximum);
        put(trial.hunter.ward); put(trial.invulnerable); put(trial.player_wet); put(trial.pet.x); put(trial.pet.y);
        for(auto cd:trial.cooldown) put(cd);
        for(auto procs:trial.proc_counts) put(procs);
        put(trial.total_damage); put(trial.echo_damage); put(trial.chain_damage); put(trial.absorbed);
        put(trial.overflow); put(trial.phase_seen);
        for(const auto& a:trial.enemies) {
            put(a.pos.x);put(a.pos.y);put(a.hp);put(a.maximum);put(a.ward);put(a.wet);put(a.hit);put(a.respawn);
        }
        for(const auto& h:trial.hazards) {
            put(h.pos.x);put(h.pos.y);put(h.radius);put(h.delay);put(h.life);put(h.kind);put(h.active);
        }
        for(const auto& v:trial.visuals) {
            put(v.kind);put(v.a.x);put(v.a.y);put(v.b.x);put(v.b.y);put(v.radius);put(v.ttl);put(v.total);put(v.hostile);
        }
        put(trial.lair_index); put(static_cast<unsigned>(mode)); put(campaign.round); put(!profile_ok?3:!entrance_valid?2:campaign.locked?1:0);
        put(campaign.reward); put(campaign.unlocked_count); put(save_status);
        for(auto count:campaign.progress.items) put(count);
        put(campaign.progress.clears[trial.lair_index]); put(campaign.progress.rush_clears[trial.lair_index]);
        write32(packet.data(),0x32534c44u); write32(packet.data()+4,token);
        write32(packet.data()+8,++snapshot_sequence); write32(packet.data()+12,count);
        write32(packet.data()+16,dh::sim::living_data::simulation_stamp);
        for(unsigned i=0;i<count;++i) write32(packet.data()+20+i*4,std::bit_cast<std::uint32_t>(values[i]));
        sendto(sock,reinterpret_cast<const char*>(packet.data()),static_cast<int>(20+count*4),0,
               reinterpret_cast<const sockaddr*>(&client),sizeof(client));
        deadline+=std::chrono::microseconds(33333);
        if(deadline<Clock::now()-std::chrono::milliseconds(100)) deadline=Clock::now();
        std::this_thread::sleep_until(deadline);
    }
    close_socket(sock);
#ifdef _WIN32
    WSACleanup();
#endif
    return 0;
}
