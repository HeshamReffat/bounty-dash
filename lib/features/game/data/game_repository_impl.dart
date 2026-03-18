import 'dart:async';
import '../../../../models/entities.dart';
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

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String? ?? '';
    switch (type) {
      case 'GAME_STATE':
        final raw = msg['state'] as Map<String, dynamic>?;
        if (raw == null) return;
        final state = GameStateEntity.fromJson(raw);
        _interpolator.onNewState(state);
        final interpolated = _interpolator.interpolate();
        if (interpolated != null) _stateController.add(interpolated);

      case 'GAME_OVER':
        final raw = msg['result'] as Map<String, dynamic>?;
        if (raw == null) return;
        _resultController.add(GameResultEntity.fromJson(raw));
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
    _ws.send({'type': 'INPUT', 'dx': dx, 'dy': dy, 'angle': angle});
  }

  @override
  void sendTag() => _ws.send({'type': 'TAG_ATTEMPT'});

  @override
  void sendCollect() => _ws.send({'type': 'COLLECT'});

  @override
  void dispose() {
    _sub?.cancel();
    _stateController.close();
    _resultController.close();
  }
}

