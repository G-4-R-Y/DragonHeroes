#include "lair_profile.hpp"
#include <fstream>
#include <sstream>
#include <cstdio>
#include <cstring>
#ifdef _WIN32
#include <windows.h>
#else
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#endif
using namespace dh::content;
LairProfile::LairProfile(const char* name) : path(name?std::filesystem::path(std::u8string(name,name+std::strlen(name))):std::filesystem::path{}) {}
LairProfile::~LairProfile() {
    if(handle==-1) return;
#ifdef _WIN32
    CloseHandle(reinterpret_cast<HANDLE>(handle));
#else
    close(static_cast<int>(handle));
#endif
}
bool LairProfile::lock() {
    if(path.empty()) return false;
    auto lock_path=path; lock_path += ".lock";
#ifdef _WIN32
    const auto h=CreateFileW(lock_path.c_str(),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(h==INVALID_HANDLE_VALUE) return false;
    handle=reinterpret_cast<std::intptr_t>(h);
#else
    const int fd=open(lock_path.c_str(),O_RDWR|O_CREAT,0600);
    if(fd<0) return false;
    if(flock(fd,LOCK_EX|LOCK_NB)!=0) { close(fd); return false; }
    handle=fd;
#endif
    return true;
}
bool LairProfile::read(dh::sim::LairProgress& progress) const {
    std::error_code ec;
    if(!std::filesystem::exists(path,ec)) return !ec;
    if(std::filesystem::file_size(path,ec)>16384 || ec) return false;
    std::ifstream file(path); if(!file) return false;
    std::string magic; unsigned version=0;
    if(!(file>>magic>>version) || magic!="DH_LAIRS" || version!=1) return false;
    dh::sim::LairProgress parsed;
    std::array<bool,8> seen_lair{}; std::array<bool,4> seen_item{};
    std::string kind,id,extra; unsigned a=0,b=0; bool end=false;
    while(file>>kind) {
        if(kind=="END") { end=true; break; }
        if(!(file>>id>>a) || a>dh::sim::LairProgress::limit) return false;
        bool found=false;
        if(kind=="L") {
            if(!(file>>b) || b>dh::sim::LairProgress::limit || (!a && b)) return false;
            for(unsigned i=0;i<lairs::definitions.size();++i) if(lairs::definitions[i].id==id) {
                if(seen_lair[i]) return false;
                seen_lair[i]=found=true; parsed.clears[i]=a; parsed.rush_clears[i]=b;
            }
        } else if(kind=="I") {
            for(unsigned i=0;i<4;++i) if(lairs::artifact_ids[i]==id) {
                if(seen_item[i]) return false;
                seen_item[i]=found=true; parsed.items[i]=a;
            }
        }
        if(!found) return false; // unknown data is preserved on disk, never silently overwritten
    }
    if(!end || (file>>extra)) return false;
    progress=parsed; return true;
}
bool LairProfile::write(const dh::sim::LairProgress& progress) const {
    if(handle==-1) return false;
    auto temp=path; temp += ".tmp";
    {
        std::ofstream file(temp,std::ios::trunc); if(!file) return false;
        file<<"DH_LAIRS 1\n";
        for(unsigned i=0;i<lairs::definitions.size();++i) file<<"L "<<lairs::definitions[i].id<<' '<<progress.clears[i]<<' '<<progress.rush_clears[i]<<'\n';
        for(unsigned i=0;i<4;++i) file<<"I "<<lairs::artifact_ids[i]<<' '<<progress.items[i]<<'\n';
        file<<"END\n"; file.flush(); if(!file) return false;
    }
#ifdef _WIN32
    const auto fd=CreateFileW(temp.c_str(),GENERIC_WRITE,0,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(fd==INVALID_HANDLE_VALUE) return false;
    const bool flushed=FlushFileBuffers(fd); CloseHandle(fd);
    return flushed && MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH);
#else
    const int fd=open(temp.c_str(),O_RDONLY); if(fd<0) return false;
    const bool flushed=fsync(fd)==0; close(fd); if(!flushed) return false;
    std::error_code ec; std::filesystem::rename(temp,path,ec); if(ec) return false;
    const auto parent=path.parent_path().empty()?std::filesystem::path("."):path.parent_path();
    const int dir=open(parent.c_str(),O_RDONLY|O_DIRECTORY);
    if(dir>=0) { fsync(dir); close(dir); }
    return true;
#endif
}
int lair_profile_query(const char* name) {
    dh::sim::LairProgress progress;
    if(!name || !LairProfile(name).read(progress)) { std::puts("{\"error\":\"Cannot read lair collection; the existing save has been preserved.\"}"); return 2; }
    std::printf("{\"lairs\":[");
    for(unsigned i=0;i<lairs::definitions.size();++i) std::printf("%s{\"id\":\"%.*s\",\"clears\":%u,\"rush_clears\":%u}",i?",":"",static_cast<int>(lairs::definitions[i].id.size()),lairs::definitions[i].id.data(),progress.clears[i],progress.rush_clears[i]);
    std::printf("],\"items\":[%u,%u,%u,%u]}\n",progress.items[0],progress.items[1],progress.items[2],progress.items[3]);
    return 0;
}
