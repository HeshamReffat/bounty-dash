import 'dart:async';
import '../../../../models/entities.dart';
import '../../../../models/ws_message.dart';
import '../../../../network/ws_client.dart';
import '../domain/repositories/game_repository.dart';
import 'interpolator.dart';

class GameRepositoryImpl implements GameRepository {
  final WsClient _ws;
  final Interpolator _interpolator = Interpolator();

  final _stateController =
      StreamController<GameStateEntity>.broadcast();
  final _resultController =
      StreamController<GameResultEntity>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _sub;

  GameRepositoryImpl(this._ws) {
    _sub = _ws.messages.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> raw) {
    final msg = WsMessage.fromJson(raw);
    switch (msg) {
      case GameStateMessage(:final state):
        final entity = GameStateEntity.fromJson(state);
        _interpolator.onNewState(entity);
        final interpolated = _interpolator.interpolate();
        if (interpolated != null) _stateController.add(interpolated);

      case GameOverMessage(:final result):
        _resultController.add(GameResultEntity.fromJson(result));

      default:
        break; // lobby messages handled by LobbyRepositoryImpl
    }
  }

  @override
  Stream<GameStateEntity> get gameStateStream => _stateController.stream;

  @override
  Stream<GameResultEntity> get gameResultStream => _resultController.stream;

  @override
  void sendMove({
    required double dx,
    required double dy,
    required double angle,
  }) {
    _ws.send(InputMessage(dx: dx, dy: dy, angle: angle).toJson());
  }

  @override
  void sendTag() => _ws.send(const TagAttemptMessage().toJson());

  @override
  void sendCollect() => _ws.send(const CollectMessage().toJson());

  @override
  void dispose() {
    _sub?.cancel();
    _stateController.close();
    _resultController.close();
  }
}



