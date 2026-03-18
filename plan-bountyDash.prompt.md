# Plan: Bounty Dash — Asymmetric PvP Hide-and-Seek Game

A full-stack multiplayer Flutter game where 1 Runner steals artifacts and escapes while 3 Guards use flashlights and line-of-sight to hunt them. The Flutter client handles rendering and input; a Dart `shelf`/`shelf_web_socket` server handles all authoritative game logic including visibility, collisions, and win conditions — preventing any client-side cheating.

The client follows **Clean Architecture** (Data → Domain → Presentation layers) and **MVVM** (ViewModel + View) strictly, using **flutter_bloc** (Cubit/Bloc) as the state management solution. Dependencies always point inward: Presentation depends on Domain, Domain depends on nothing external, Data implements Domain interfaces.

```
lib/
├── core/                        # App-wide utilities, DI setup (get_it), router
├── models/                      # Shared pure Dart entities (PlayerEntity, etc.)
├── features/
│   ├── lobby/
│   │   ├── data/                # LobbyRepositoryImpl, WebSocket data sources
│   │   ├── domain/              # LobbyRepository (abstract), Use Cases
│   │   └── presentation/        # LobbyCubit + LobbyState, Screens, Widgets
│   ├── game/
│   │   ├── data/                # GameRepositoryImpl, interpolation, WS data source
│   │   ├── domain/              # GameRepository (abstract), Use Cases
│   │   └── presentation/        # GameBloc + GameEvent + GameState, Flame components, HUD widgets
│   └── result/
│       ├── domain/              # ResultRepository (abstract), Use Cases
│       └── presentation/        # ResultCubit + ResultState, GameOverScreen
└── network/                     # Raw WebSocket client (infrastructure layer only)
```

Server mirrors the same layered separation: `server/lib/` is split into `domain/` (pure game rules, no I/O), `application/` (use-case orchestrators: game loop, tag validation, etc.), and `infrastructure/` (WebSocket transport, room registry).

---

## Phase 1 — Project Structure & Dependencies

1. Restructure `lib/` following **Clean Architecture + MVVM**: `lib/core/`, `lib/models/`, and `lib/features/<feature>/{data,domain,presentation}/` for each feature (lobby, game, result).
2. Add Flutter client dependencies to `pubspec.yaml`: `flame` (2D game engine), `web_socket_channel` (WebSocket client), `flutter_bloc` + `bloc` (state management), `bloc_concurrency` (event transformer for droppable/restartable input events), `get_it` (service locator / dependency injection), `uuid`, and `go_router`.
3. Create `lib/core/di/injection_container.dart` — registers all repositories, use cases, and **Blocs/Cubits** with `get_it` so no layer instantiates its own dependencies (Dependency Inversion Principle).
4. Create a separate `server/` directory at the project root with its own `pubspec.yaml` as a pure Dart server package, using `shelf`, `shelf_web_socket`, and `dart:math` — no Flutter dependencies. Structure it as `server/lib/{domain,application,infrastructure}/`.

---

## Phase 2 — Shared Data Models (Clean Architecture Layers)

Define models across layers following Clean Architecture:

5. **Domain entities** (`lib/models/` / `server/lib/domain/entities/`) — pure Dart, no JSON, no framework imports:
   - `PlayerEntity` — `id`, `role` (Runner/Guard), `position (x,y)`, `isTagged`, `tagCount`, `isVisible` (server-computed).
   - `ArtifactEntity` — `id`, `position (x,y)`, `isCollected`, `collectedBy`.
   - `GameStateEntity` — `phase` (lobby/playing/ended), `players`, `artifacts`, `winner`, `tick`.
6. **Data-layer DTOs** (`lib/features/<feature>/data/models/`) — mirror entities with `toJson`/`fromJson`; these are the only classes that touch JSON. Use extension methods or factory constructors to convert DTO ↔ Entity.
7. Define all WebSocket message types as a sealed class hierarchy in `lib/models/ws_message.dart`: `JoinMessage`, `MoveMessage`, `RotateMessage`, `TagMessage`, `CollectMessage`, `GameStateUpdateMessage`, `LobbyUpdateMessage`, `GameOverMessage` — each with its own `toJson`/`fromJson` in the data layer.
8. **Repository interfaces** (`lib/features/<feature>/domain/repositories/`) — abstract classes (e.g., `GameRepository`, `LobbyRepository`) defining the contract; data-layer `*Impl` classes fulfill them. No Presentation code ever touches a concrete repository.

---

## Phase 3 — Game Map & Tile System

9. Design a tile-based map (e.g., 30×20 grid) with tile types: `floor`, `wall`, `shadow`, `exitZone`, `artifactSpawn`.
10. Store the map as a 2D integer array constant in `lib/features/game/domain/map_data.dart` (domain layer — pure logic, no UI). Mirror it to `server/lib/domain/map_data.dart`. Walls are the foundation of all LoS blocking.
11. Place 3 artifact spawn points, 1 exit zone, and 4 player spawn points (1 Runner + 3 Guards) in the map definition.

---

## Phase 4 — Server: Authoritative Game Loop (`server/`)

12. Create `server/lib/infrastructure/game_server.dart` using `shelf_web_socket` — manages WebSocket connections, assigns player roles, and runs the game loop at **20 ticks/sec** using a `Timer.periodic`. This is pure infrastructure; it delegates all game logic to the application layer.
13. Create `server/lib/application/lobby_manager.dart` — handles room creation (4-digit code), player joining (max 4), role assignment (first joiner = Runner, rest = Guards or voted), and game start trigger. Depends only on domain entities, not on transport.
14. Create `server/lib/application/game_engine.dart` — the core use-case orchestrator: processes buffered player inputs each tick, updates positions with speed limits (Runner: 4 tiles/sec, Guards: 2.5 tiles/sec), enforces wall collisions, and advances `GameStateEntity`.
15. Create `server/lib/domain/visibility_engine.dart` — pure domain logic, the critical anti-cheat layer:
    - **Runner invisibility**: Runner is invisible to Guards by default unless in flashlight cone OR moving (footstep reveal radius ~2 tiles).
    - **Guard flashlight**: Each Guard has a cone (60° arc, 7-tile range). Compute using **ray-casting**: cast ~30 rays from Guard's position within the cone; a ray is blocked by any `wall` tile.
    - **LoS algorithm**: For each ray, step tile-by-tile using Bresenham's line algorithm. If a wall tile is hit, stop. If the Runner's tile is within any unblocked ray's reach, mark Runner as `isVisible = true` for that Guard.
    - The server sends **each Guard only what they're allowed to see** — the Runner's position is omitted from a Guard's `GAME_STATE_UPDATE` unless `isVisible = true`.
    - The Runner receives all Guard positions always (fair play, they need to avoid them).
16. Create `server/lib/domain/tag_system.dart` — pure domain rule: Guard must be within 1.5 tiles of Runner AND Runner must be visible (in LoS) to prevent blind tagging. Runner gets 2 tags before Guards win.
17. Create `server/lib/domain/artifact_system.dart` — pure domain rule: Runner must be within 0.8 tiles of an artifact. After collecting all 3, `exitZone` becomes active. Runner wins by reaching the exit zone.

---

## Phase 5 — Flutter Client: Network & Data Layer

18. Create `lib/network/ws_client.dart` wrapping `web_socket_channel` — low-level infrastructure that sends/receives raw JSON frames. No business logic lives here.
19. Create `lib/features/game/data/game_repository_impl.dart` implementing the domain's `GameRepository` — translates raw WS frames into domain entities using DTOs, exposes a `Stream<GameStateEntity>`.
20. Create `lib/features/game/domain/use_cases/` — one class per action: `SendMoveUseCase`, `SendRotateUseCase`, `CollectArtifactUseCase`, `AttemptTagUseCase`. Each takes the abstract `GameRepository`; injected via `get_it`.
21. Implement input buffering in the data layer: local player input (move direction, Guard rotation) is sent to the server on every frame but the client **never moves the player locally** — it only renders what the server says. This is the authoritative model.
22. Implement **client-side interpolation** in `lib/features/game/data/interpolator.dart`: smoothly lerp all entity positions between server ticks (50ms apart) to avoid jittery movement at 60fps rendering. The `GameRepositoryImpl` applies interpolation before emitting to the stream.

---

## Phase 6 — Flutter Client: Presentation Layer — GameBloc + Flame (`lib/features/game/presentation/`)

23. Create the Bloc triad in `lib/features/game/presentation/bloc/`:
    - `game_event.dart` — sealed class with events: `GameStarted`, `GameStateReceived(GameStateEntity state)`, `PlayerMoved(Vector2 direction)`, `GuardRotated(double angle)`, `ArtifactCollectRequested`, `TagAttempted`, `GameStopped`.
    - `game_state.dart` — sealed class with states: `GameInitial`, `GameLoading`, `GameRunning(GameStateEntity state)`, `GameOver(GameResultEntity result)`, `GameError(String message)`.
    - `game_bloc.dart` extending `Bloc<GameEvent, GameState>` — subscribes to the `GameStateEntity` stream from `WatchGameStateUseCase` and maps events to states. Uses `bloc_concurrency`'s `droppable()` transformer on high-frequency input events (`PlayerMoved`, `GuardRotated`) to avoid flooding the server.
24. Create `lib/features/game/presentation/game_screen.dart` — a `BlocProvider` + `BlocBuilder<GameBloc, GameState>` widget that mounts the `BountyDashGame` Flame widget when state is `GameRunning`, and delegates input gestures/keys to `context.read<GameBloc>().add(...)`.
25. Create `lib/features/game/presentation/components/bounty_dash_game.dart` extending `FlameGame` — receives `GameStateEntity` updates from the Bloc (via a `Stream` or `ValueNotifier` passed in) and re-renders components accordingly.
26. Create Flame components in `lib/features/game/presentation/components/`:
    - `map_component.dart` — renders the tile map; walls dark gray, floors light, exit zone gold, artifact spawns teal.
    - `runner_component.dart` — renders the Runner; opacity ~0.15 when `isVisible = false` on Runner's own screen, fully hidden on Guard screens.
    - `guard_component.dart` — renders Guard sprite + flashlight cone overlay via `Canvas.drawPath` with semi-transparent yellow `Paint`. Cosmetic only — server is authority.
    - `artifact_component.dart` — pulsing animation via `EffectController`; disappears on collection.
    - `hud_component.dart` — tag hearts (×2), artifact icons (×3), role badge, optional minimap.
27. Handle input in the presentation layer: `KeyboardMovementController` (WASD + mouse aim) for desktop, `JoystickComponent` for mobile. Input events are dispatched via `gameBloc.add(PlayerMoved(...))` / `gameBloc.add(GuardRotated(...))` — the Bloc calls the appropriate use case.

---

## Phase 7 — Lobby & Matchmaking (`lib/features/lobby/`)

28. Create `lib/features/lobby/domain/use_cases/` — `CreateRoomUseCase`, `JoinRoomUseCase`, `StartGameUseCase`; each depends on the abstract `LobbyRepository`.
29. Create `lib/features/lobby/data/lobby_repository_impl.dart` implementing `LobbyRepository` — sends `JOIN`/`CREATE` WS messages and maps server responses to `LobbyStateEntity`.
30. Create the Cubit pair in `lib/features/lobby/presentation/cubit/`:
    - `lobby_state.dart` — sealed class: `LobbyInitial`, `LobbyCreating`, `LobbyWaiting(String roomCode, List<PlayerEntity> players, bool canStart)`, `LobbyError(String message)`.
    - `lobby_cubit.dart` extending `Cubit<LobbyState>` — exposes `createRoom()`, `joinRoom(String code)`, `startGame()` methods; calls use cases injected via `get_it`.
31. Create lobby screens in `lib/features/lobby/presentation/`:
    - `lobby_screen.dart` — `BlocProvider` + `BlocBuilder<LobbyCubit, LobbyState>`; "Create Room" / "Join Room" UI.
    - `waiting_room_screen.dart` — connected players list, roles, "Start Game" (host only); uses `BlocListener` to navigate to `/game` on `LobbyWaiting.canStart`.
32. Use `go_router` in `lib/core/router/app_router.dart` for navigation: `/` → `MainMenuScreen`, `/lobby` → `LobbyScreen`, `/waiting` → `WaitingRoomScreen`, `/game` → `GameScreen`.

---

## Phase 8 — Game Flow & Win/Loss Conditions

33. Server emits `GAME_OVER` message with `winner: "runner"` or `winner: "guards"` and the reason (e.g., `"Runner escaped"`, `"Runner tagged twice"`).
34. Create `lib/features/result/domain/use_cases/GetGameResultUseCase.dart` — parses the `GameOverMessage` into a `GameResultEntity` (winner, stats, reason).
35. Create the Cubit pair in `lib/features/result/presentation/cubit/`:
    - `result_state.dart` — sealed class: `ResultInitial`, `ResultLoaded(GameResultEntity result)`.
    - `result_cubit.dart` extending `Cubit<ResultState>` — calls `GetGameResultUseCase`, emits `ResultLoaded`.
36. Create `lib/features/result/presentation/game_over_screen.dart` — `BlocProvider` + `BlocBuilder<ResultCubit, ResultState>`; shows winner, time survived, artifacts stolen, tags made; "Play Again" triggers `CreateRoomUseCase`, "Main Menu" navigates to `/`.
37. Implement a 3-minute game timer on the server; if it expires with Runner not escaping, Guards win by timeout.

---

## Phase 9 — Polish & Game Feel

38. Add sound effects using `flame_audio`: footstep sounds for movement, a heartbeat for Runner when a Guard is nearby (within 5 tiles), and a sting when tagged.
39. Add particle effects using Flame's `ParticleSystemComponent`: dust puffs on movement, a spark burst on artifact collection, a red flash on tag.
40. Add a **"Danger Indicator"** for the Runner: a directional red arc on the HUD showing which direction the nearest Guard is, inspired by Dead by Daylight's terror radius.

---

## Phase 10 — Deployment

41. Deploy the Dart server to **Fly.io** or **Railway** (both support Docker + Dart natively). Add a `Dockerfile` in `server/` based on `dart:stable`.
42. Make the server WebSocket URL configurable via a `const` in `lib/core/config/app_config.dart` so it can switch between `ws://localhost:8080` (dev) and `wss://bountydash.fly.dev` (prod). Register the config in `injection_container.dart` so all layers consume it via DI.

---

## Locked-In Decisions

### Rendering Engine — Flame ✅
Flame is the chosen renderer across all phases. No `CustomPainter` fallback. Rationale:
- `FlameGame` provides a built-in game loop (`update` + `render`) decoupled from Flutter's widget tree, which is essential for 60fps rendering independent of Bloc state rebuilds.
- `Component` + `HasGameRef` mixin pattern maps cleanly to the Clean Architecture presentation layer.
- `flame_audio`, `ParticleSystemComponent`, `EffectController`, and `JoystickComponent` are all first-party — no extra packages needed for Phase 9 polish.
- `Camera2D` with `CameraComponent` handles viewport, zoom, and world-space scrolling for the 30×20 tile map out of the box.

### Local Network (LAN) Play — Included as Phase 1 Milestone ✅
The server must be discoverable on a LAN before cloud deployment is required. Add the following to Phase 1:
- The server binary (`server/bin/server.dart`) binds to `0.0.0.0:8080` so it is reachable from any device on the same Wi-Fi/LAN.
- Add `lib/core/config/app_config.dart` with a `serverUrl` field that defaults to `ws://localhost:8080` but can be overridden at runtime.
- Add a **"Connect to LAN Server"** text field on `LobbyScreen` (below "Create Room" / "Join Room") where players manually enter the host's local IP (e.g., `192.168.1.42`). This is stored in `LobbyCubit` state.
- Optionally, add **UDP broadcast discovery** (`dart:io` `RawDatagramSocket`) so the server announces itself on the LAN every 2 seconds and clients auto-populate the IP field — implemented in `lib/network/lan_discovery.dart` and `server/lib/infrastructure/lan_broadcaster.dart`.
- Document the LAN setup in `README.md`: "Run `dart run server/bin/server.dart` on one machine, then enter that machine's IP in the app on other devices."

### Platform Targets — Mobile (iOS + Android) + Desktop (macOS + Windows + Linux) ✅
The game must run on all five platforms simultaneously from a single codebase. Platform-specific considerations per layer:

**Input (Presentation layer — `lib/features/game/presentation/`):**
- Detect platform at runtime using `defaultTargetPlatform` or `kIsWeb` in an `InputControllerFactory` in `lib/core/input/`.
- **Mobile** (iOS, Android): `JoystickComponent` (left side = move, right side = rotate flashlight / aim). Semi-transparent overlay joystick, always visible.
- **Desktop** (macOS, Windows, Linux): `KeyboardMovementController` (WASD to move) + raw mouse position mapped to world-space angle for Guard flashlight rotation. `HardwareKeyboard` listener registered in `BountyDashGame.onLoad`.
- Both input modes dispatch the same `PlayerMoved(Vector2)` and `GuardRotated(double)` events to `GameBloc` — the Bloc is input-agnostic.

**Window & Viewport:**
- On desktop, set a minimum window size of `800×600` via `window_manager` package (`lib/core/window/window_setup.dart` called from `main.dart`).
- On mobile, force landscape orientation via `SystemChrome.setPreferredOrientations` in `main.dart`.
- `CameraComponent` uses a fixed logical resolution of `900×600` with `FixedResolutionViewport` so tiles scale correctly on all screen sizes.

**Platform-specific build notes:**
- **macOS**: Add `com.apple.security.network.client` entitlement to `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` to allow outbound WebSocket connections.
- **Android**: Add `<uses-permission android:name="android.permission.INTERNET" />` to `AndroidManifest.xml`. For LAN UDP discovery, also add `CHANGE_WIFI_MULTICAST_STATE`.
- **iOS**: Add `NSLocalNetworkUsageDescription` key to `ios/Runner/Info.plist` for LAN discovery.
- **Windows / Linux**: No extra permissions needed; `dart:io` sockets work out of the box.

**flame_audio on all platforms:**
- `flame_audio` uses `audioplayers` under the hood. Ensure audio assets are listed under `flutter: assets:` in `pubspec.yaml` and that `AVAudioSession` (iOS) and `AudioManager` (Android) are not conflicting with system audio. On desktop, no additional setup is required.

