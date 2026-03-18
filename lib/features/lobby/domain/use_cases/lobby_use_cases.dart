import '../repositories/lobby_repository.dart';

class CreateRoomUseCase {
  final LobbyRepository _repo;
  CreateRoomUseCase(this._repo);
  Future<String> call() => _repo.createRoom();
}

class JoinRoomUseCase {
  final LobbyRepository _repo;
  JoinRoomUseCase(this._repo);
  Future<void> call(String code) => _repo.joinRoom(code);
}

class StartGameUseCase {
  final LobbyRepository _repo;
  StartGameUseCase(this._repo);
  Future<void> call(String code) => _repo.startGame(code);
}

class ConnectToServerUseCase {
  final LobbyRepository _repo;
  ConnectToServerUseCase(this._repo);
  Future<void> call(String serverUrl) => _repo.connect(serverUrl);
}

