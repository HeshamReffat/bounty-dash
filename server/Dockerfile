# ── Build stage ────────────────────────────────────────────────────────────────
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files and resolve dependencies
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

# Copy source code and compile
COPY bin/ bin/
COPY lib/ lib/
RUN dart compile exe bin/server.dart -o bin/server

# ── Runtime stage ───────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/bin/server /app/bin/server

EXPOSE 8080
# UDP broadcast port
EXPOSE 41234/udp

CMD ["/app/bin/server"]
