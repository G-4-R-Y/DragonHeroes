// Local preview host. UDP is loopback-only; an ephemeral client port + token
// bind the child process to one Godot presenter. No network/economy integration.
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <thread>
#include <dh/sim/living_trial.hpp>
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

int living_preview(unsigned client_port, unsigned token) {
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
    dh::sim::LivingTrial trial;
    dh::sim::TrialInput input;
    std::uint32_t last_sequence=0,snapshot_sequence=0;
    using Clock=std::chrono::steady_clock;
    auto deadline=Clock::now(); auto last_input=deadline;
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
            if(buttons>511 || artifact>3) continue;
            input={{x,y},{ax,ay},buttons,artifact}; last_sequence=sequence; last_input=Clock::now();
        }
        if(input.buttons&dh::sim::stop) break;
        // A missing controller must never keep moving/casting indefinitely.
        if(Clock::now()-last_input>std::chrono::milliseconds(250)) input.buttons=dh::sim::pause;
        trial.step(input);
        std::array<float,512> values{}; unsigned count=0;
        auto put=[&](auto v) { values[count++]=static_cast<float>(v); };
        put(last_sequence); put(trial.tick); put(trial.artifact); put(trial.result); put(trial.bonds);
        put(trial.phase); put(trial.phase_clock); put(dh::sim::living_data::phases[trial.phase].windup);
        put(dh::sim::living_data::phases[trial.phase].recovery); put(trial.mana);
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
        write32(packet.data(),0x31534c44u); write32(packet.data()+4,token);
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
