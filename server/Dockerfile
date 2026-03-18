# ── Build stage ────────────────────────────────────────────────────────────────
FROM dart:stable AS build

WORKDIR /app
COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get

COPY server/ .
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
