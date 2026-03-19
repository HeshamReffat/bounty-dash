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

    // Root landing page - simple helpful HTML so visiting the app URL doesn't 404
    router.get('/', (Request req) {
      final host = req.headers['host'] ?? 'localhost';
      final scheme = req.headers['x-forwarded-proto'] ?? 'https';
      final wsScheme = scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = '$wsScheme://$host/ws';
      final html = '''
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>Bounty Dash Server</title></head>
  <body style="font-family:system-ui, sans-serif; padding:24px;">
    <h1>Bounty Dash — Server</h1>
    <p>Status: <a href="/health">/health</a></p>
    <p>WebSocket endpoint: <a href="$wsUrl">$wsUrl</a></p>
    <p>Note: WebSocket clients should connect to the <code>/ws</code> path using <code>${wsScheme}://${host}/ws</code>.</p>
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
