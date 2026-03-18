import '../../../../models/entities.dart';

abstract class LobbyRepository {
  Future<void> connect(String serverUrl);
  Future<String> createRoom();
  Future<void> joinRoom(String code);
  Future<void> startGame(String code);
  Stream<LobbyEvent> get events;
  void disconnect();
}

// ─── Lobby events (domain) ────────────────────────────────────────────────────
sealed class LobbyEvent {}

class LobbyUpdated extends LobbyEvent {
  final String roomCode;
  final List<LobbyPlayerInfo> players;
  LobbyUpdated({required this.roomCode, required this.players});
}

class LobbyGameStarted extends LobbyEvent {}

class LobbyPlayerLeft extends LobbyEvent {
  final String playerId;
  LobbyPlayerLeft({required this.playerId});
}

class LobbyError extends LobbyEvent {
  final String message;
  LobbyError({required this.message});
}

class LobbyConnected extends LobbyEvent {
  final String playerId;
  LobbyConnected({required this.playerId});
}

