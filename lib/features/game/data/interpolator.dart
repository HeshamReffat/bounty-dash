import '../../../../models/entities.dart';

/// Linearly interpolates entity positions between two server snapshots
/// to produce smooth 60fps rendering from 20Hz server ticks (50 ms apart).
///
/// Usage:
///   - Call [onNewState] each time a server packet arrives.
///   - Call [interpolate] every Flame frame (no DateTime.now() — uses
///     accumulated dt from the game loop to avoid syscall overhead).
class Interpolator {
  GameStateEntity? _prev;
  GameStateEntity? _next;

  // Accumulated time since the last snapshot arrived, in seconds.
  double _elapsed = 0;
  static const double _tickDuration = 0.05; // 50 ms in seconds

  void onNewState(GameStateEntity state) {
    _prev = _next;
    _next = state;
    // Carry forward any overshoot rather than snapping back to 0.
    // If we've already consumed more than one tick's worth of time,
    // clamp to 0 so we don't start the next window already "behind".
    _elapsed = (_elapsed - _tickDuration).clamp(0.0, _tickDuration);
  }

  /// Advance the interpolation clock by [dt] seconds and return the
  /// smoothed snapshot. Call this from Flame's update(dt).
  GameStateEntity? tick(double dt) {
    if (_next == null) return null;
    _elapsed += dt;
    return _buildInterpolated();
  }

  /// Return the current interpolated snapshot without advancing time.
  /// Used when you need to read the state without a dt (e.g. camera snap).
  GameStateEntity? interpolate() => _buildInterpolated();

  GameStateEntity? _buildInterpolated() {
    if (_next == null) return null;
    if (_prev == null) return _next;

    final t = (_elapsed / _tickDuration).clamp(0.0, 1.0);

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
      maxTags: _next!.maxTags,
    );
  }
}

