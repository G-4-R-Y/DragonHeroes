#pragma once
#include <filesystem>
#include <dh/sim/lair_campaign.hpp>
// Filesystem operations belong to dh-server, never the simulation library.
struct LairProfile {
    std::filesystem::path path;
    std::intptr_t handle{-1};
    explicit LairProfile(const char* name);
    ~LairProfile();
    LairProfile(const LairProfile&)=delete;
    LairProfile& operator=(const LairProfile&)=delete;
    bool lock();
    bool read(dh::sim::LairProgress& progress) const;
    bool write(const dh::sim::LairProgress& progress) const;
};
int lair_profile_query(const char* path);
