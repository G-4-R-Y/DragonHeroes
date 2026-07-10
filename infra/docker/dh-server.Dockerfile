# dh-server — headless zone/match server (M0: benchmark harness; M2: ENet + Agones)
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ cmake make ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY sim/ sim/
RUN cmake -S sim -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j"$(nproc)" && \
    ctest --test-dir build --output-on-failure

FROM debian:bookworm-slim
COPY --from=build /src/build/libs/dh-server/dh-server /usr/local/bin/dh-server
USER 1000:1000
ENTRYPOINT ["dh-server"]
