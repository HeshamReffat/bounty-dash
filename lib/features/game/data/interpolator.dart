import '../../../../models/entities.dart';

/// Linearly interpolates entity positions between two server snapshots
/// to produce smooth 60fps rendering from 20Hz server ticks.
class Interpolator {
  GameStateEntity? _prev;
  GameStateEntity? _next;
  DateTime _nextReceivedAt = DateTime.now();

  static const double _tickDuration = 50.0; // ms

  void onNewState(GameStateEntity state) {
    _prev = _next;
    _next = state;
    _nextReceivedAt = DateTime.now();
  }

  /// Returns an interpolated snapshot. Call every render frame.
  GameStateEntity? interpolate() {
    if (_next == null) return null;
    if (_prev == null) return _next;

    final elapsed =
        DateTime.now().difference(_nextReceivedAt).inMilliseconds.toDouble();
    final t = (elapsed / _tickDuration).clamp(0.0, 1.0);

    final interpolatedPlayers = <String, PlayerEntity>{};
    for (final entry in _next!.players.entries) {
      final next = entry.value;
      final prev = _prev!.players[entry.key];
      if (prev == null) {
        interpolatedPlayers[entry.key] = next;
      } else {
        interpolatedPlayers[entry.key] = next.copyWith(
          position: prev.position.lerp(next.position, t),
        );
      }
    }

    return GameStateEntity(
      phase: _next!.phase,
      players: interpolatedPlayers,
      artifacts: _next!.artifacts,
      winner: _next!.winner,
      winReason: _next!.winReason,
      tick: _next!.tick,
      secondsRemaining: _next!.secondsRemaining,
    );
  }
}

