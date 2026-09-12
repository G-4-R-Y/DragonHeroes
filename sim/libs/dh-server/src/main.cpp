// dh-server — headless zone/match server binary (docs/tech/22). M0 scope: the
// benchmark harness the roadmap requires before anything is stacked on the sim
// (docs/business/31, M0 exit gate): spawn N entities, run T ticks, report ns/tick
// and the deterministic state hash.
//
// ENet transport, AOI, Agones SDK, and ONNX policy serving arrive in M2+.
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <dh/math/hash.hpp>
#include <dh/procgen/chunk.hpp>
#include <dh/sim/world.hpp>

int living_preview(unsigned client_port, unsigned token);

namespace {

std::uint64_t arg_u64(int argc, char** argv, const char* name, std::uint64_t fallback) {
    for (int i = 1; i + 1 < argc; ++i) {
        if (std::strcmp(argv[i], name) == 0) return std::strtoull(argv[i + 1], nullptr, 10);
    }
    return fallback;
}

const char* arg_str(int argc, char** argv, const char* name) {
    for (int i = 1; i + 1 < argc; ++i) {
        if (std::strcmp(argv[i], name) == 0) return argv[i + 1];
    }
    return nullptr;
}

// --dump-chunks R --out file.json: emit the base world around the origin as JSON so
// the Godot prototype renders the REAL dh-procgen output (no engine-side worldgen).
// --dump-window "cx0,cy0,cx1,cy1" --out file.json: same schema over any inclusive
// chunk rect — the prototype's streaming window (docs/tech/29) requests exactly
// the chunks it is missing; determinism comes free from generate_chunk.
int dump_rect(std::uint64_t seed, std::int64_t cx0, std::int64_t cy0, std::int64_t cx1,
              std::int64_t cy1, const char* out_path) {
    std::FILE* f = std::fopen(out_path, "w");
    if (!f) {
        std::fprintf(stderr, "cannot open %s\n", out_path);
        return EXIT_FAILURE;
    }
    std::fprintf(f, "{\"seed\":%llu,\"chunk_size\":%d,\"generator_version\":%u,\"chunks\":[",
                 static_cast<unsigned long long>(seed), dh::procgen::kChunkSize,
                 dh::procgen::kGeneratorVersion);
    bool first = true;
    for (std::int64_t cy = cy0; cy <= cy1; ++cy) {
        for (std::int64_t cx = cx0; cx <= cx1; ++cx) {
            const auto chunk = dh::procgen::generate_chunk(seed, cx, cy);
            std::fprintf(f, "%s{\"cx\":%lld,\"cy\":%lld,\"tiles\":[", first ? "" : ",",
                         static_cast<long long>(cx), static_cast<long long>(cy));
            first = false;
            for (std::size_t i = 0; i < chunk.tiles.size(); ++i) {
                std::fprintf(f, "%s%u", i ? "," : "", chunk.tiles[i]);
            }
            std::fprintf(f, "]}");
        }
    }
    std::fprintf(f, "]}\n");
    std::fclose(f);
    std::printf("dumped %lld chunks (rect %lld,%lld..%lld,%lld) to %s\n",
                static_cast<long long>((cx1 - cx0 + 1) * (cy1 - cy0 + 1)),
                static_cast<long long>(cx0), static_cast<long long>(cy0),
                static_cast<long long>(cx1), static_cast<long long>(cy1), out_path);
    return EXIT_SUCCESS;
}

} // namespace

int main(int argc, char** argv) {
    if(argc>1 && std::strcmp(argv[1],"--living-preview")==0)
        return living_preview(static_cast<unsigned>(arg_u64(argc,argv,"--client-port",0)),
                              static_cast<unsigned>(arg_u64(argc,argv,"--token",0)));
    const std::uint64_t seed = arg_u64(argc, argv, "--seed", 42);
    const std::uint64_t entities = arg_u64(argc, argv, "--entities", 500);
    const std::uint64_t ticks = arg_u64(argc, argv, "--ticks", 3000);

    if (const std::uint64_t radius = arg_u64(argc, argv, "--dump-chunks", 0); radius > 0) {
        const char* out = arg_str(argc, argv, "--out");
        const auto r = static_cast<std::int64_t>(radius);
        return dump_rect(seed, -r, -r, r, r, out ? out : "chunks.json");
    }
    if (const char* rect = arg_str(argc, argv, "--dump-window"); rect != nullptr) {
        long long cx0 = 0, cy0 = 0, cx1 = 0, cy1 = 0;
        if (std::sscanf(rect, "%lld,%lld,%lld,%lld", &cx0, &cy0, &cx1, &cy1) != 4 ||
            cx1 < cx0 || cy1 < cy0) {
            std::fprintf(stderr, "--dump-window expects cx0,cy0,cx1,cy1 (inclusive)\n");
            return EXIT_FAILURE;
        }
        const char* out = arg_str(argc, argv, "--out");
        return dump_rect(seed, cx0, cy0, cx1, cy1, out ? out : "chunks.json");
    }

    dh::sim::World world(seed);
    for (std::uint64_t i = 0; i < entities; ++i) {
        const std::uint64_t h = dh::math::hash_coords(seed, static_cast<std::int64_t>(i), 0, 99);
        const float x = dh::math::hash_to_unit_float(h) * 128.0f;
        const float y = dh::math::hash_to_unit_float(dh::math::splitmix64(h)) * 128.0f;
        world.spawn_creature({x, y}, 0.5f, 100.0f);
    }

    // Touch procgen so the benchmark reflects chunk generation cost too.
    const auto chunk = dh::procgen::generate_chunk(seed, 0, 0);

    const auto start = std::chrono::steady_clock::now();
    for (std::uint64_t t = 0; t < ticks; ++t) world.step();
    const auto end = std::chrono::steady_clock::now();

    const auto total_ns =
        std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
    const double ns_per_tick = static_cast<double>(total_ns) / static_cast<double>(ticks);
    const double budget_ns = 1e9 / static_cast<double>(dh::sim::kTickRate);

    std::printf("dh-server M0 benchmark harness\n");
    std::printf("  seed=%llu entities=%llu ticks=%llu\n",
                static_cast<unsigned long long>(seed),
                static_cast<unsigned long long>(entities),
                static_cast<unsigned long long>(ticks));
    std::printf("  ns/tick        : %.0f (budget %.0f at %u Hz -> %.2f%% used)\n",
                ns_per_tick, budget_ns, dh::sim::kTickRate, 100.0 * ns_per_tick / budget_ns);
    std::printf("  state hash     : %016llx\n",
                static_cast<unsigned long long>(world.state_hash()));
    std::printf("  chunk(0,0) gen : v%u, tile(0,0)=%u\n", chunk.generator_version,
                chunk.tile_at(0, 0));
    return EXIT_SUCCESS;
}
