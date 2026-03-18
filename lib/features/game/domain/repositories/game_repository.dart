import '../../../../models/entities.dart';

abstract class GameRepository {
  /// Stream of authoritative game state updates from the server.
  Stream<GameStateEntity> get gameStateStream;

  /// Stream of game-over results.
  Stream<GameResultEntity> get gameResultStream;

  void sendMove({required double dx, required double dy, required double angle});
  void sendTag();
  void sendCollect();
  void dispose();
}

