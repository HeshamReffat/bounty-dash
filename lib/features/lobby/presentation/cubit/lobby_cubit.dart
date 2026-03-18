import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/lobby_repository.dart';
import '../../domain/use_cases/lobby_use_cases.dart';
import 'lobby_state.dart';

class LobbyCubit extends Cubit<LobbyState> {
  final ConnectToServerUseCase _connectUseCase;
  final CreateRoomUseCase _createRoom;
  final JoinRoomUseCase _joinRoom;
  final StartGameUseCase _startGame;
  final LobbyRepository _repo;

  StreamSubscription<LobbyEvent>? _sub;
  String? _playerId;
  String? _roomCode;

  LobbyCubit({
    required ConnectToServerUseCase connectUseCase,
    required CreateRoomUseCase createRoom,
    required JoinRoomUseCase joinRoom,
    required StartGameUseCase startGame,
    required LobbyRepository repo,
  })  : _connectUseCase = connectUseCase,
        _createRoom = createRoom,
        _joinRoom = joinRoom,
        _startGame = startGame,
        _repo = repo,
        super(const LobbyInitial()) {
    _sub = _repo.events.listen(_onEvent);
  }

  void _onEvent(LobbyEvent event) {
    switch (event) {
      case LobbyConnected(:final playerId):
        _playerId = playerId;
        emit(LobbyIdle(playerId: playerId));
      case LobbyUpdated(:final roomCode, :final players):
        _roomCode = roomCode;
        emit(LobbyWaiting(
          roomCode: roomCode,
          playerId: _playerId ?? '',
          players: players,
          isHost: players.isNotEmpty && players.first.id == _playerId,
        ));
      case LobbyGameStarted():
        final current = state;
        if (current is LobbyWaiting) {
          emit(LobbyStarting(
            playerId: current.playerId,
            players: current.players,
          ));
        }
      case LobbyPlayerLeft():
        // Re-emit waiting with updated player list handled by next LOBBY_UPDATE
        break;
      case LobbyError(:final message):
        emit(LobbyFailure(message));
    }
  }

  Future<void> connect(String serverUrl) async {
    emit(const LobbyConnecting());
    try {
      await _connectUseCase(serverUrl);
    } catch (e) {
      emit(LobbyFailure(e.toString()));
    }
  }

  Future<void> createRoom() async {
    try {
      await _createRoom();
    } catch (e) {
      emit(LobbyFailure(e.toString()));
    }
  }

  Future<void> joinRoom(String code) async {
    try {
      await _joinRoom(code);
    } catch (e) {
      emit(LobbyFailure(e.toString()));
    }
  }

  Future<void> startGame() async {
    if (_roomCode == null) return;
    try {
      await _startGame(_roomCode!);
    } catch (e) {
      emit(LobbyFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
