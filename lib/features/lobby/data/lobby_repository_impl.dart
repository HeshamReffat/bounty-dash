import 'dart:async';
import 'package:bountydash/models/entities.dart';
import 'package:bountydash/models/ws_message.dart';
import 'package:bountydash/network/ws_client.dart';
import 'package:bountydash/features/lobby/domain/repositories/lobby_repository.dart';

class LobbyRepositoryImpl implements LobbyRepository {
  final WsClient _ws;
  String? _myPlayerId;
  final _eventController = StreamController<LobbyEvent>.broadcast();

  LobbyRepositoryImpl(this._ws);

  @override
  Stream<LobbyEvent> get events => _eventController.stream;

  @override
  Future<void> connect(String serverUrl) async {
    await _ws.connect(serverUrl);
    _ws.messages.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> raw) {
    final msg = WsMessage.fromJson(raw);
    switch (msg) {
      case ConnectedMessage(:final playerId):
        _myPlayerId = playerId;
        _eventController.add(LobbyConnected(playerId: playerId));

      case LobbyUpdateMessage(:final roomCode, :final players):
        final infos = players
            .map((p) => LobbyPlayerInfo.fromJson(p))
            .toList();
        _eventController.add(LobbyUpdated(roomCode: roomCode, players: infos));

      case GameStartMessage():
        _eventController.add(LobbyGameStarted());

      case PlayerLeftMessage(:final playerId):
        _eventController.add(LobbyPlayerLeft(playerId: playerId));

      case ErrorMessage(:final message):
        _eventController.add(LobbyError(message: message));

      default:
        break; // other message types handled by GameRepositoryImpl
    }
  }

  @override
  Future<String> createRoom() async {
    _ws.send(const CreateRoomMessage().toJson());
    final event = await events
        .where((e) => e is LobbyUpdated)
        .first
        .timeout(const Duration(seconds: 5));
    return (event as LobbyUpdated).roomCode;
  }

  @override
  Future<void> joinRoom(String code) async {
    _ws.send(JoinRoomMessage(roomCode: code).toJson());
  }

  @override
  Future<void> startGame(String code) async {
    _ws.send(StartGameMessage(roomCode: code).toJson());
  }

  @override
  void disconnect() => _ws.disconnect();

  String? get myPlayerId => _myPlayerId;
}




