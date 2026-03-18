import '../repositories/game_repository.dart';
import '../../../../models/entities.dart';

class WatchGameStateUseCase {
  final GameRepository _repo;
  WatchGameStateUseCase(this._repo);
  Stream<GameStateEntity> call() => _repo.gameStateStream;
}

class WatchGameResultUseCase {
  final GameRepository _repo;
  WatchGameResultUseCase(this._repo);
  Stream<GameResultEntity> call() => _repo.gameResultStream;
}

class SendMoveUseCase {
  final GameRepository _repo;
  SendMoveUseCase(this._repo);
  void call({required double dx, required double dy, required double angle}) =>
      _repo.sendMove(dx: dx, dy: dy, angle: angle);
}

class SendRotateUseCase {
  final GameRepository _repo;
  SendRotateUseCase(this._repo);
  void call(double angle) => _repo.sendMove(dx: 0, dy: 0, angle: angle);
}

class AttemptTagUseCase {
  final GameRepository _repo;
  AttemptTagUseCase(this._repo);
  void call() => _repo.sendTag();
}

class CollectArtifactUseCase {
  final GameRepository _repo;
  CollectArtifactUseCase(this._repo);
  void call() => _repo.sendCollect();
}

