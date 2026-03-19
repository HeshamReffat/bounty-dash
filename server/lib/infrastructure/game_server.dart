import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../application/lobby_manager.dart';
import '../application/game_engine.dart';
import '../domain/entities/entities.dart';
import '../domain/map_data.dart';
import '../domain/visibility_engine.dart';

const _uuid = Uuid();

class GameServer {
  final LobbyManager _lobby = LobbyManager();
  final Map<String, GameEngine> _engines = {};
  final Map<String, Timer> _timers = {};
  final Map<String, WebSocketChannel> _sockets = {};
  final Map<String, List<PlayerInput>> _inputBuffer = {};
  // Track previous runner position per room for movement detection
  final Map<String, Vec2?> _prevRunnerPos = {};

  Handler get handler {
    final router = Router();

    // Health check
    router.get('/health', (Request req) => Response.ok('ok'));

    // Root landing page — elegant game description with visual effects
    router.get('/', (Request req) {
      final host = req.headers['host'] ?? 'localhost';
      final scheme = req.headers['x-forwarded-proto'] ?? 'https';
      final wsScheme = scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = '$wsScheme://$host/ws';
      final html = '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bounty Dash — Asymmetric PvP</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Inter:wght@300;400;600&display=swap');

    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: 'Inter', system-ui, sans-serif;
      background: #0a0a14;
      color: #e0e0e0;
      min-height: 100vh;
      overflow-x: hidden;
    }

    /* ── Animated background particles ─────────────────────────── */
    .bg-particles {
      position: fixed; inset: 0; z-index: 0; overflow: hidden;
    }
    .bg-particles span {
      position: absolute;
      width: 3px; height: 3px;
      background: rgba(0,229,255,0.4);
      border-radius: 50%;
      animation: float linear infinite;
    }
    @keyframes float {
      0%   { transform: translateY(100vh) scale(0); opacity: 0; }
      10%  { opacity: 1; }
      90%  { opacity: 1; }
      100% { transform: translateY(-10vh) scale(1.2); opacity: 0; }
    }

    /* ── Scanning line effect ──────────────────────────────────── */
    .scan-line {
      position: fixed; inset: 0; z-index: 1; pointer-events: none;
      background: repeating-linear-gradient(
        0deg,
        transparent,
        transparent 2px,
        rgba(0,229,255,0.015) 2px,
        rgba(0,229,255,0.015) 4px
      );
    }
    .scan-line::after {
      content: '';
      position: absolute; left: 0; right: 0;
      height: 120px;
      background: linear-gradient(180deg, rgba(0,229,255,0.06), transparent);
      animation: scan 4s ease-in-out infinite;
    }
    @keyframes scan {
      0%, 100% { top: -120px; }
      50%      { top: 100%; }
    }

    /* ── Layout ────────────────────────────────────────────────── */
    .container {
      position: relative; z-index: 2;
      max-width: 900px; margin: 0 auto;
      padding: 60px 24px 80px;
    }

    /* ── Hero ──────────────────────────────────────────────────── */
    .hero { text-align: center; margin-bottom: 64px; }
    .hero-icon {
      font-size: 72px;
      animation: pulse-glow 2s ease-in-out infinite alternate;
    }
    @keyframes pulse-glow {
      0%   { filter: drop-shadow(0 0 8px rgba(0,229,255,0.4)); transform: scale(1); }
      100% { filter: drop-shadow(0 0 24px rgba(0,229,255,0.8)); transform: scale(1.08); }
    }
    .hero h1 {
      font-family: 'Orbitron', monospace;
      font-size: clamp(32px, 6vw, 56px);
      font-weight: 900;
      letter-spacing: 6px;
      margin-top: 16px;
      background: linear-gradient(135deg, #00e5ff, #00ffaa, #00e5ff);
      background-size: 200% 200%;
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      animation: gradient-shift 3s ease-in-out infinite;
    }
    @keyframes gradient-shift {
      0%, 100% { background-position: 0% 50%; }
      50%      { background-position: 100% 50%; }
    }
    .hero .tagline {
      font-size: 18px; color: #888; margin-top: 12px;
      letter-spacing: 3px; text-transform: uppercase;
    }

    /* ── Divider ───────────────────────────────────────────────── */
    .divider {
      height: 1px; margin: 48px 0;
      background: linear-gradient(90deg, transparent, rgba(0,229,255,0.3), transparent);
    }

    /* ── Description ───────────────────────────────────────────── */
    .desc {
      font-size: 17px; line-height: 1.8; color: #aaa;
      text-align: center; max-width: 640px; margin: 0 auto 48px;
    }
    .desc strong { color: #00e5ff; font-weight: 600; }

    /* ── Role cards ────────────────────────────────────────────── */
    .roles {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 24px; margin-bottom: 56px;
    }
    .role-card {
      background: linear-gradient(135deg, rgba(30,30,46,0.9), rgba(18,18,30,0.9));
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 16px;
      padding: 32px 28px;
      transition: transform 0.3s, box-shadow 0.3s, border-color 0.3s;
      position: relative; overflow: hidden;
    }
    .role-card::before {
      content: '';
      position: absolute; top: 0; left: 0; right: 0; height: 3px;
      border-radius: 16px 16px 0 0;
    }
    .role-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 12px 40px rgba(0,0,0,0.4);
    }
    .role-card.runner::before { background: linear-gradient(90deg, #00e5ff, #00ffaa); }
    .role-card.runner:hover   { border-color: rgba(0,229,255,0.3); }
    .role-card.guard::before  { background: linear-gradient(90deg, #ff6b35, #ffe066); }
    .role-card.guard:hover    { border-color: rgba(255,107,53,0.3); }

    .role-card .emoji { font-size: 40px; margin-bottom: 12px; }
    .role-card h3 {
      font-family: 'Orbitron', monospace; font-size: 20px;
      font-weight: 700; margin-bottom: 14px;
    }
    .role-card.runner h3 { color: #00e5ff; }
    .role-card.guard h3  { color: #ff6b35; }
    .role-card ul { list-style: none; }
    .role-card li {
      padding: 6px 0; color: #999; font-size: 15px;
      padding-left: 20px; position: relative;
    }
    .role-card li::before {
      content: '▸'; position: absolute; left: 0; font-weight: bold;
    }
    .role-card.runner li::before { color: #00e5ff; }
    .role-card.guard li::before  { color: #ff6b35; }

    /* ── Features ──────────────────────────────────────────────── */
    .features {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px; margin-bottom: 56px;
    }
    .feat {
      text-align: center;
      padding: 28px 16px;
      border-radius: 12px;
      background: rgba(30,30,46,0.6);
      border: 1px solid rgba(255,255,255,0.04);
      transition: border-color 0.3s;
    }
    .feat:hover { border-color: rgba(0,229,255,0.2); }
    .feat .icon { font-size: 28px; margin-bottom: 10px; }
    .feat h4 { font-size: 14px; color: #00e5ff; margin-bottom: 6px; font-weight: 600; letter-spacing: 1px; text-transform: uppercase; }
    .feat p  { font-size: 13px; color: #777; line-height: 1.5; }

    /* ── Server info ───────────────────────────────────────────── */
    .server-info {
      background: rgba(30,30,46,0.7);
      border: 1px solid rgba(0,229,255,0.15);
      border-radius: 12px;
      padding: 28px 32px;
      margin-bottom: 40px;
    }
    .server-info h4 {
      font-family: 'Orbitron', monospace;
      font-size: 13px; color: #00e5ff;
      letter-spacing: 2px; margin-bottom: 16px;
    }
    .info-row {
      display: flex; align-items: center;
      padding: 10px 0;
      border-bottom: 1px solid rgba(255,255,255,0.04);
    }
    .info-row:last-child { border-bottom: none; }
    .info-row .label { width: 140px; color: #666; font-size: 13px; text-transform: uppercase; letter-spacing: 1px; }
    .info-row .value {
      font-family: 'Courier New', monospace; font-size: 14px; color: #00ffaa;
    }
    .info-row .value a { color: #00ffaa; text-decoration: none; }
    .info-row .value a:hover { text-decoration: underline; }

    .status-dot {
      display: inline-block; width: 8px; height: 8px;
      background: #00ffaa; border-radius: 50%; margin-right: 8px;
      animation: blink 1.5s ease-in-out infinite;
    }
    @keyframes blink {
      0%, 100% { opacity: 1; }
      50%      { opacity: 0.3; }
    }

    /* ── Footer ────────────────────────────────────────────────── */
    .footer {
      text-align: center; padding-top: 20px;
      font-size: 12px; color: #444;
      border-top: 1px solid rgba(255,255,255,0.04);
    }
    .footer span { color: #00e5ff; }
  </style>
</head>
<body>

  <!-- Animated background particles -->
  <div class="bg-particles" id="particles"></div>
  <div class="scan-line"></div>

  <div class="container">

    <!-- Hero -->
    <div class="hero">
      <div class="hero-icon">⚡</div>
      <h1>BOUNTY DASH</h1>
      <p class="tagline">Asymmetric PvP • Hide &amp; Seek</p>
    </div>

    <!-- Description -->
    <p class="desc">
      One player is the <strong>Runner</strong> — fast, invisible when standing still.
      The others are <strong>Guards</strong> — slower, but armed with flashlights that
      reveal the Runner in the dark. Steal the artifacts. Reach the exit. Don't get caught.
    </p>

    <div class="divider"></div>

    <!-- Role cards -->
    <div class="roles">
      <div class="role-card runner">
        <div class="emoji">🏃</div>
        <h3>THE RUNNER</h3>
        <ul>
          <li>Faster movement speed</li>
          <li>Invisible while standing still</li>
          <li>Collect all artifacts to unlock the exit</li>
          <li>Reach the golden exit zone to win</li>
          <li>Survive — you can only be tagged a limited number of times</li>
        </ul>
      </div>
      <div class="role-card guard">
        <div class="emoji">🔦</div>
        <h3>THE GUARDS</h3>
        <ul>
          <li>Flashlight cone reveals the Runner</li>
          <li>Coordinate with teammates to cover exits</li>
          <li>Tag the Runner enough times to win</li>
          <li>Runner is only visible inside your light</li>
          <li>Work together — the Runner is fast</li>
        </ul>
      </div>
    </div>

    <!-- Features -->
    <div class="features">
      <div class="feat">
        <div class="icon">🎮</div>
        <h4>Cross-Platform</h4>
        <p>Play on Mobile, Desktop, macOS, Windows &amp; Linux</p>
      </div>
      <div class="feat">
        <div class="icon">🔒</div>
        <h4>Server Authoritative</h4>
        <p>All visibility &amp; physics computed server-side — no cheating</p>
      </div>
      <div class="feat">
        <div class="icon">⚡</div>
        <h4>Real-Time</h4>
        <p>20Hz tick rate with client-side interpolation for smooth play</p>
      </div>
      <div class="feat">
        <div class="icon">🗺️</div>
        <h4>Dynamic Maps</h4>
        <p>Artifacts spawn in random locations every match</p>
      </div>
    </div>

    <div class="divider"></div>

    <!-- Server info -->
    <div class="server-info">
      <h4>⬡ Server Status</h4>
      <div class="info-row">
        <span class="label">Status</span>
        <span class="value"><span class="status-dot"></span>Online</span>
      </div>
      <div class="info-row">
        <span class="label">Health</span>
        <span class="value"><a href="/health">/health</a></span>
      </div>
      <div class="info-row">
        <span class="label">WebSocket</span>
        <span class="value"><a href="$wsUrl">$wsUrl</a></span>
      </div>
      <div class="info-row">
        <span class="label">Connect</span>
        <span class="value">Enter <em style="color:#ffe066">$host</em> in the app</span>
      </div>
    </div>

    <!-- Footer -->
    <div class="footer">
      Bounty Dash &mdash; built with <span>Dart</span> &amp; <span>Flame</span> &mdash; 2026
    </div>

  </div>

  <script>
    // Generate floating particles
    const container = document.getElementById('particles');
    for (let i = 0; i < 50; i++) {
      const span = document.createElement('span');
      span.style.left = Math.random() * 100 + '%';
      span.style.width = span.style.height = (Math.random() * 3 + 1) + 'px';
      span.style.animationDuration = (Math.random() * 8 + 6) + 's';
      span.style.animationDelay = (Math.random() * 10) + 's';
      span.style.background = Math.random() > 0.5
        ? 'rgba(0,229,255,0.4)'
        : 'rgba(0,255,170,0.3)';
      container.appendChild(span);
    }
  </script>
</body>
</html>
''';
      return Response.ok(html, headers: {'content-type': 'text/html'});
    });

    // WebSocket upgrade
    router.get(
      '/ws',
      webSocketHandler((WebSocketChannel ws) {
        final playerId = _uuid.v4();
        _sockets[playerId] = ws;

        ws.stream.listen(
          (raw) => _handleMessage(playerId, raw as String),
          onDone: () => _handleDisconnect(playerId),
          onError: (_) => _handleDisconnect(playerId),
        );

        _send(playerId, {'type': 'CONNECTED', 'playerId': playerId});
      }),
    );

    return router.call;
  }

  void _handleMessage(String playerId, String raw) {
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      final type = msg['type'] as String;

      switch (type) {
        case 'CREATE_ROOM':
          final code = _lobby.createRoom(playerId);
          _send(playerId, {
            'type': 'LOBBY_UPDATE',
            'roomCode': code,
            'players': _lobby.lobbySnapshot(_lobby.getRoom(code)!),
          });

        case 'JOIN_ROOM':
          final code = msg['roomCode'] as String;
          final room = _lobby.joinRoom(code, playerId);
          if (room == null) {
            _send(playerId, {'type': 'ERROR', 'message': 'Room not found or full'});
            return;
          }
          _broadcastLobby(code);

        case 'START_GAME':
          final code = msg['roomCode'] as String;
          final room = _lobby.getRoom(code);
          if (room == null || room.hostId != playerId) return;
          if (!room.canStart) return;
          _startGame(code);

        case 'INPUT':
          final room = _lobby.getRoomForPlayer(playerId);
          if (room == null || !room.started) return;
          _inputBuffer.putIfAbsent(room.code, () => []).add(
            PlayerInput.fromJson({...msg, 'playerId': playerId}),
          );

        case 'TAG_ATTEMPT':
          final room = _lobby.getRoomForPlayer(playerId);
          if (room == null || !room.started) return;
          _inputBuffer.putIfAbsent(room.code, () => []).add(
            PlayerInput(playerId: playerId, tag: true),
          );

        case 'COLLECT':
          final room = _lobby.getRoomForPlayer(playerId);
          if (room == null || !room.started) return;
          _inputBuffer.putIfAbsent(room.code, () => []).add(
            PlayerInput(playerId: playerId, collect: true),
          );
      }
    } catch (_) {
      // Malformed messages are silently dropped
    }
  }

  void _startGame(String code) {
    final room = _lobby.getRoom(code)!;
    room.started = true;

    final playerCount = room.players.length;

    // Artifact count: 3 for 2 players, 5 for 3+ players
    final artifactCount = playerCount <= 2 ? 3 : 5;
    final artifactSpots = randomArtifactPositions(artifactCount);
    final artifacts = artifactSpots
        .asMap()
        .entries
        .map((e) => ArtifactEntity(
              id: 'artifact_${e.key}',
              position: Vec2(e.value.col + 0.5, e.value.row + 0.5),
            ))
        .toList();

    final initialState = GameStateEntity(
      phase: GamePhase.playing,
      players: room.players,
      artifacts: artifacts,
      maxTags: playerCount,
    );

    // maxTags = number of players (2 players → 2 tags to win, 4 → 4)
    _engines[code] = GameEngine(initialState, maxTags: playerCount);
    _inputBuffer[code] = [];
    _prevRunnerPos[code] = null;

    // Broadcast game start with dynamic maxTags so HUD can display it
    _broadcastToRoom(code, {
      'type': 'GAME_START',
      'maxTags': playerCount,
    });

    // 20 ticks/sec game loop
    _timers[code] = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _tick(code),
    );
  }

  void _tick(String code) {
    final engine = _engines[code];
    if (engine == null) return;

    final inputs = List<PlayerInput>.from(_inputBuffer[code] ?? []);
    _inputBuffer[code] = [];

    final newState = engine.tick(inputs);
    _broadcastState(code, newState);

    if (newState.phase == GamePhase.ended) {
      _timers[code]?.cancel();
      _engines.remove(code);
      _prevRunnerPos.remove(code);

      final runner = newState.players.values
          .where((p) => p.role == PlayerRole.runner)
          .firstOrNull;

      final result = GameResultEntity(
        winner: newState.winner!,
        reason: newState.winReason!,
        secondsSurvived: 600 - newState.secondsRemaining,
        artifactsCollected: newState.artifacts.where((a) => a.isCollected).length,
        totalArtifacts: newState.artifacts.length,
        tagsMade: runner?.tagCount ?? 0,
        maxTags: newState.maxTags,
      );
      _broadcastToRoom(code, {'type': 'GAME_OVER', 'result': result.toJson()});
      _lobby.closeRoom(code);
    }
  }

  /// Sends each player a personalised snapshot — runner position is stripped
  /// from guard packets unless the runner is within the guard's flashlight.
  void _broadcastState(String code, GameStateEntity state) {
    final room = _lobby.getRoom(code);
    if (room == null) return;

    final runner = state.players.values
        .where((p) => p.role == PlayerRole.runner)
        .firstOrNull;

    // Compute runner movement from previous tick
    final prev = _prevRunnerPos[code];
    final runnerIsMoving =
        runner != null && prev != null && prev.distanceTo(runner.position) > 0.01;
    if (runner != null) _prevRunnerPos[code] = runner.position;

    for (final playerId in room.players.keys) {
      final recipient = state.players[playerId];
      if (recipient == null) continue;

      Map<String, dynamic> personalised;

      if (recipient.role == PlayerRole.guard && runner != null) {
        final visible = VisibilityEngine.isRunnerVisibleToGuard(
          guard: recipient,
          runner: runner,
          runnerIsMoving: runnerIsMoving,
        );

        final filteredPlayers = Map<String, dynamic>.from(
          state.players.map((k, v) => MapEntry(k, v.toJson())),
        );

        if (!visible) {
          filteredPlayers.remove(runner.id);
        } else {
          filteredPlayers[runner.id] = runner.copyWith(isVisible: true).toJson();
        }

        personalised = {
          'type': 'GAME_STATE',
          'state': {
            'phase': state.phase.name,
            'players': filteredPlayers,
            'artifacts': state.artifacts.map((a) => a.toJson()).toList(),
            'tick': state.tick,
            'secondsRemaining': state.secondsRemaining,
            'maxTags': state.maxTags,
          },
        };
      } else {
        // Runner receives full state (sees all guards)
        personalised = {'type': 'GAME_STATE', 'state': state.toJson()};
      }

      _send(playerId, personalised);
    }
  }

  void _handleDisconnect(String playerId) {
    // Snapshot room reference BEFORE any removal so it stays valid throughout.
    final room = _lobby.getRoomForPlayer(playerId);

    // Always remove the socket first so we stop trying to write to a dead pipe.
    _sockets.remove(playerId);

    if (room == null) return;
    final code = room.code;

    // Notify remaining players that this player left.
    // Do this before removing from lobby so the room still exists.
    _broadcastToRoom(code, {'type': 'PLAYER_LEFT', 'playerId': playerId});

    // Remove from lobby player list (but NOT from room map yet — room.players
    // is still needed by _broadcastState / _broadcastToRoom below).
    room.players.remove(playerId);

    final engine = _engines[code];
    if (engine != null) {
      // Remove from engine state and check win condition.
      final newState = engine.removePlayer(playerId);

      if (newState.phase == GamePhase.ended) {
        // Cancel tick loop immediately so no more ticks race with cleanup.
        _timers[code]?.cancel();
        _timers.remove(code);
        _engines.remove(code);
        _prevRunnerPos.remove(code);
        _inputBuffer.remove(code);

        final runner = newState.players.values
            .where((p) => p.role == PlayerRole.runner)
            .firstOrNull;

        final result = GameResultEntity(
          winner: newState.winner!,
          reason: newState.winReason!,
          secondsSurvived: 600 - newState.secondsRemaining,
          artifactsCollected:
              newState.artifacts.where((a) => a.isCollected).length,
          totalArtifacts: newState.artifacts.length,
          tagsMade: runner?.tagCount ?? 0,
          maxTags: newState.maxTags,
        );

        // Send GAME_OVER to all REMAINING players (room.players no longer
        // contains the disconnected player, so only survivors receive it).
        // Use _broadcastToPlayers because closeRoom is called right after.
        _broadcastToPlayers(
          room.players.keys,
          {'type': 'GAME_OVER', 'result': result.toJson()},
        );

        // Now safe to close the room.
        _lobby.closeRoom(code);
      } else {
        // Game continues — broadcast the updated state so the ghost disappears.
        _broadcastState(code, newState);

        // Clean up empty room if somehow everyone left without ending the game.
        if (room.players.isEmpty) {
          _timers[code]?.cancel();
          _timers.remove(code);
          _engines.remove(code);
          _prevRunnerPos.remove(code);
          _inputBuffer.remove(code);
          _lobby.closeRoom(code);
        }
      }
    } else {
      // Game not started yet (lobby disconnect).
      if (room.players.isEmpty) {
        _lobby.closeRoom(code);
      }
    }
  }

  void _broadcastLobby(String code) {
    final room = _lobby.getRoom(code);
    if (room == null) return;
    _broadcastToRoom(code, {
      'type': 'LOBBY_UPDATE',
      'roomCode': code,
      'players': _lobby.lobbySnapshot(room),
    });
  }

  void _broadcastToRoom(String code, Map<String, dynamic> msg) {
    final room = _lobby.getRoom(code);
    if (room == null) return;
    // Copy keys so iteration is safe if the map is modified during send.
    for (final id in List<String>.from(room.players.keys)) {
      _send(id, msg);
    }
  }

  /// Broadcast to an explicit list of player IDs (safe to use after closeRoom).
  void _broadcastToPlayers(Iterable<String> playerIds, Map<String, dynamic> msg) {
    for (final id in playerIds) {
      _send(id, msg);
    }
  }

  void _send(String playerId, Map<String, dynamic> msg) {
    try {
      _sockets[playerId]?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }
}

Future<void> startServer({int port = 8080}) async {
  final server = GameServer();
  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(server.handler);

  final httpServer = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
  // ignore: avoid_print
  print('🎮 Bounty Dash server running on ws://0.0.0.0:${httpServer.port}');
}
