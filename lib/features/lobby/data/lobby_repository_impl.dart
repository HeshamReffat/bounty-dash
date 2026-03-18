import 'dart:async';
import 'package:bountydash/models/entities.dart';
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

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String? ?? '';
    switch (type) {
      case 'CONNECTED':
        _myPlayerId = msg['playerId'] as String?;
        if (_myPlayerId != null) {
          _eventController.add(LobbyConnected(playerId: _myPlayerId!));
        }
      case 'LOBBY_UPDATE':
        final players = (msg['players'] as List<dynamic>? ?? [])
            .map((p) => LobbyPlayerInfo.fromJson(p as Map<String, dynamic>))
            .toList();
        _eventController.add(LobbyUpdated(
          roomCode: msg['roomCode'] as String? ?? '',
          players: players,
        ));
      case 'GAME_START':
        _eventController.add(LobbyGameStarted());
      case 'PLAYER_LEFT':
        _eventController.add(
            LobbyPlayerLeft(playerId: msg['playerId'] as String? ?? ''));
      case 'ERROR':
        _eventController
            .add(LobbyError(message: msg['message'] as String? ?? 'Unknown error'));
    }
  }

  @override
  Future<String> createRoom() async {
    _ws.send({'type': 'CREATE_ROOM'});
    // roomCode is returned via LOBBY_UPDATE event
    final event = await events
        .where((e) => e is LobbyUpdated)
        .first
        .timeout(const Duration(seconds: 5));
    return (event as LobbyUpdated).roomCode;
  }

  @override
  Future<void> joinRoom(String code) async {
    _ws.send({'type': 'JOIN_ROOM', 'roomCode': code});
  }

  @override
  Future<void> startGame(String code) async {
    _ws.send({'type': 'START_GAME', 'roomCode': code});
  }

  @override
  void disconnect() => _ws.disconnect();

  String? get myPlayerId => _myPlayerId;
}


