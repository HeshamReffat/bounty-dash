# Bounty Dash ⚡

Asymmetric PvP hide-and-seek multiplayer game built with Flutter + Flame.  
1 Runner steals 3 artifacts and escapes. 3 Guards use flashlights to hunt them.

## Architecture

- **Clean Architecture** — Data → Domain → Presentation
- **MVVM** with `flutter_bloc` (Cubit/Bloc) for state management
- **Flame** game engine for rendering
- **Dart shelf** authoritative server — all game logic (LoS, tags, collisions) runs server-side

## Running Locally (LAN Play)

### 1. Start the server

```bash
cd server
dart pub get
dart run bin/server.dart
```

The server binds to `0.0.0.0:8080` and broadcasts its presence on UDP port `41234`.  
Find your machine's local IP: `ifconfig | grep "inet "` (macOS/Linux) or `ipconfig` (Windows).

### 2. Run the Flutter app

```bash
flutter pub get
flutter run -d macos               # macOS desktop
flutter run -d windows             # Windows desktop
flutter run -d <android-device-id> # Android
flutter run -d <ios-device-id>     # iOS
```

On the **Lobby screen**, enter the server machine's local IP (e.g. `192.168.1.42`).  
The app will auto-populate the IP field if it detects a LAN broadcast.

## Deploy the Server (Docker / Fly.io)

```bash
cd server
docker build -t bountydash-server .
docker run -p 8080:8080 -p 41234:41234/udp bountydash-server

# Or with Fly.io:
fly launch --dockerfile Dockerfile && fly deploy
```

Update `AppConfig.serverUrl` in `lib/core/config/app_config.dart` to your deployed URL.

## Controls

| Platform | Move | Aim Flashlight | Action (Tag / Collect) |
|---|---|---|---|
| Desktop | WASD / Arrows | Mouse | Space |
| Mobile | Left joystick | — | Right half of screen |

## Project Structure

```
lib/
├── core/           # DI (get_it), router (go_router), config, window
├── models/         # Pure Dart entities
├── network/        # WsClient, LanDiscovery
└── features/
    ├── lobby/      # LobbyCubit — Create/Join room
    ├── game/       # GameBloc + Flame components
    └── result/     # ResultCubit — Game over screen

server/
├── bin/server.dart
└── lib/
    ├── domain/         # VisibilityEngine, TagSystem, ArtifactSystem (pure logic)
    ├── application/    # GameEngine, LobbyManager (orchestrators)
    └── infrastructure/ # WebSocket transport, LAN broadcaster
```
