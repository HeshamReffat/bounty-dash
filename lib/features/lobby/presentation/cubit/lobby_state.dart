import 'package:equatable/equatable.dart';
import '../../../../models/entities.dart';

sealed class LobbyState extends Equatable {
  const LobbyState();
  @override
  List<Object?> get props => [];
}

class LobbyInitial extends LobbyState {
  const LobbyInitial();
}

class LobbyConnecting extends LobbyState {
  const LobbyConnecting();
}

class LobbyIdle extends LobbyState {
  /// Connected but no room yet. Holds our assigned playerId.
  final String playerId;
  const LobbyIdle({required this.playerId});
  @override
  List<Object?> get props => [playerId];
}

class LobbyWaiting extends LobbyState {
  final String roomCode;
  final String playerId;
  final List<LobbyPlayerInfo> players;
  final bool isHost;

  const LobbyWaiting({
    required this.roomCode,
    required this.playerId,
    required this.players,
    required this.isHost,
  });

  bool get canStart => players.length >= 2;

  @override
  List<Object?> get props => [roomCode, playerId, players, isHost];
}

class LobbyStarting extends LobbyState {
  final String playerId;
  final List<LobbyPlayerInfo> players;

  const LobbyStarting({
    required this.playerId,
    required this.players,
  });

  @override
  List<Object?> get props => [playerId, players];
}

class LobbyFailure extends LobbyState {
  final String message;
  const LobbyFailure(this.message);
  @override
  List<Object?> get props => [message];
}
