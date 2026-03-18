/// Sealed hierarchy of all WebSocket message types exchanged between
/// client and server. The data layer is the only place that constructs
/// and parses these — domain/presentation never touch raw JSON.
library;

sealed class WsMessage {
  const WsMessage();

  /// Deserialise from a raw decoded-JSON map.
  factory WsMessage.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String? ?? '';
    return switch (type) {
      'CONNECTED'    => ConnectedMessage(playerId: j['playerId'] as String),
      'LOBBY_UPDATE' => LobbyUpdateMessage(
          roomCode: j['roomCode'] as String? ?? '',
          players: (j['players'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>(),
        ),
      'GAME_START'   => const GameStartMessage(),
      'GAME_STATE'   => GameStateMessage(
          state: j['state'] as Map<String, dynamic>? ?? {},
        ),
      'GAME_OVER'    => GameOverMessage(
          result: j['result'] as Map<String, dynamic>? ?? {},
        ),
      'PLAYER_LEFT'  => PlayerLeftMessage(
          playerId: j['playerId'] as String? ?? '',
        ),
      'ERROR'        => ErrorMessage(
          message: j['message'] as String? ?? 'Unknown error',
        ),
      _              => UnknownMessage(type: type),
    };
  }
}

// ── Server → Client ──────────────────────────────────────────────────────────

class ConnectedMessage extends WsMessage {
  final String playerId;
  const ConnectedMessage({required this.playerId});
}

class LobbyUpdateMessage extends WsMessage {
  final String roomCode;
  final List<Map<String, dynamic>> players;
  const LobbyUpdateMessage({required this.roomCode, required this.players});
}

class GameStartMessage extends WsMessage {
  const GameStartMessage();
}

class GameStateMessage extends WsMessage {
  final Map<String, dynamic> state;
  const GameStateMessage({required this.state});
}

class GameOverMessage extends WsMessage {
  final Map<String, dynamic> result;
  const GameOverMessage({required this.result});
}

class PlayerLeftMessage extends WsMessage {
  final String playerId;
  const PlayerLeftMessage({required this.playerId});
}

class ErrorMessage extends WsMessage {
  final String message;
  const ErrorMessage({required this.message});
}

class UnknownMessage extends WsMessage {
  final String type;
  const UnknownMessage({required this.type});
}

// ── Client → Server ──────────────────────────────────────────────────────────

class CreateRoomMessage extends WsMessage {
  const CreateRoomMessage();
  Map<String, dynamic> toJson() => {'type': 'CREATE_ROOM'};
}

class JoinRoomMessage extends WsMessage {
  final String roomCode;
  const JoinRoomMessage({required this.roomCode});
  Map<String, dynamic> toJson() => {'type': 'JOIN_ROOM', 'roomCode': roomCode};
}

class StartGameMessage extends WsMessage {
  final String roomCode;
  const StartGameMessage({required this.roomCode});
  Map<String, dynamic> toJson() =>
      {'type': 'START_GAME', 'roomCode': roomCode};
}

class InputMessage extends WsMessage {
  final double dx;
  final double dy;
  final double angle;
  const InputMessage({required this.dx, required this.dy, required this.angle});
  Map<String, dynamic> toJson() =>
      {'type': 'INPUT', 'dx': dx, 'dy': dy, 'angle': angle};
}

class TagAttemptMessage extends WsMessage {
  const TagAttemptMessage();
  Map<String, dynamic> toJson() => {'type': 'TAG_ATTEMPT'};
}

class CollectMessage extends WsMessage {
  const CollectMessage();
  Map<String, dynamic> toJson() => {'type': 'COLLECT'};
}

