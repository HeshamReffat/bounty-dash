import 'dart:math' as math;
import '../domain/entities/entities.dart';
import '../domain/map_data.dart';
import '../domain/visibility_engine.dart';
import '../domain/tag_system.dart';
import '../domain/artifact_system.dart';

const double kRunnerSpeed = 4.0; // tiles/sec
const double kGuardSpeed  = 2.5; // tiles/sec
const double kTickRate    = 1 / 20; // 50 ms per tick

/// Input snapshot received from a client each tick.
class PlayerInput {
  final String playerId;
  final double dx;   // -1..1
  final double dy;   // -1..1
  final double angle; // radians (guard flashlight / runner facing)
  final bool tag;
  final bool collect;

  const PlayerInput({
    required this.playerId,
    this.dx = 0,
    this.dy = 0,
    this.angle = 0,
    this.tag = false,
    this.collect = false,
  });

  factory PlayerInput.fromJson(Map<String, dynamic> j) => PlayerInput(
        playerId: j['playerId'] as String,
        dx: (j['dx'] as num? ?? 0).toDouble(),
        dy: (j['dy'] as num? ?? 0).toDouble(),
        angle: (j['angle'] as num? ?? 0).toDouble(),
        tag: j['tag'] as bool? ?? false,
        collect: j['collect'] as bool? ?? false,
      );
}

/// Core authoritative game engine — pure application logic.
class GameEngine {
  GameStateEntity state;
  // Track previous positions to detect movement
  final Map<String, Vec2> _prevPositions = {};
  int _elapsedTicks = 0;

  GameEngine(this.state);

  /// Process one tick worth of inputs and return the new [GameStateEntity].
  GameStateEntity tick(List<PlayerInput> inputs) {
    if (state.phase != GamePhase.playing) return state;

    _elapsedTicks++;
    final secondsRemaining = math.max(0, 180 - (_elapsedTicks ~/ 20));

    var players = Map<String, PlayerEntity>.from(state.players);
    var artifacts = List<ArtifactEntity>.from(state.artifacts);

    // ── Move players ────────────────────────────────────────────────────────
    for (final input in inputs) {
      final player = players[input.playerId];
      if (player == null) continue;

      final speed = player.role == PlayerRole.runner ? kRunnerSpeed : kGuardSpeed;
      final rawDx = input.dx.clamp(-1.0, 1.0);
      final rawDy = input.dy.clamp(-1.0, 1.0);
      // Normalise diagonal movement
      final len = math.sqrt(rawDx * rawDx + rawDy * rawDy);
      final ndx = len > 0 ? (rawDx / len) * speed * kTickRate : 0.0;
      final ndy = len > 0 ? (rawDy / len) * speed * kTickRate : 0.0;

      final newX = (player.position.x + ndx).clamp(0.5, 29.5);
      final newY = (player.position.y + ndy).clamp(0.5, 19.5);

      final candidate = Vec2(newX, newY);
      final resolved = _resolveCollision(player.position, candidate);

      players[input.playerId] = player.copyWith(
        position: resolved,
        angle: input.angle != 0 ? input.angle : player.angle,
      );
    }

    // ── Compute visibility ───────────────────────────────────────────────────
    final runner = players.values.where((p) => p.role == PlayerRole.runner).firstOrNull;
    if (runner == null) return state;

    final prevRunnerPos = _prevPositions[runner.id];
    final runnerIsMoving = prevRunnerPos != null &&
        prevRunnerPos.distanceTo(runner.position) > 0.01;
    _prevPositions[runner.id] = runner.position;

    // Determine if runner is visible to ANY guard (for tag validation)
    bool runnerVisibleToAnyGuard = false;
    for (final guard in players.values.where((p) => p.role == PlayerRole.guard)) {
      final visible = VisibilityEngine.isRunnerVisibleToGuard(
        guard: guard,
        runner: runner,
        runnerIsMoving: runnerIsMoving,
      );
      if (visible) runnerVisibleToAnyGuard = true;
      _prevPositions[guard.id] = guard.position;
    }

    // ── Process actions ──────────────────────────────────────────────────────
    var updatedRunner = runner;
    for (final input in inputs) {
      final player = players[input.playerId];
      if (player == null) continue;

      // Tag attempt
      if (input.tag && player.role == PlayerRole.guard) {
        final tagged = TagSystem.attemptTag(
          guard: player,
          runner: updatedRunner,
          runnerIsVisible: runnerVisibleToAnyGuard,
        );
        if (tagged != null) updatedRunner = tagged;
      }

      // Artifact collection
      if (input.collect && player.role == PlayerRole.runner) {
        for (int i = 0; i < artifacts.length; i++) {
          final updated = ArtifactSystem.tryCollect(
            runner: player,
            artifact: artifacts[i],
          );
          if (updated != null) artifacts[i] = updated;
        }
      }
    }

    players[updatedRunner.id] = updatedRunner;

    // ── Win conditions ───────────────────────────────────────────────────────
    if (TagSystem.isGuardsWin(updatedRunner)) {
      return state.copyWith(
        players: players,
        artifacts: artifacts,
        phase: GamePhase.ended,
        winner: 'guards',
        winReason: 'Runner tagged twice',
        tick: state.tick + 1,
        secondsRemaining: secondsRemaining,
      );
    }

    final exitPos = Vec2(
      kExitPosition.col.toDouble() + 0.5,
      kExitPosition.row.toDouble() + 0.5,
    );
    if (ArtifactSystem.hasReachedExit(
      runner: updatedRunner,
      exitPosition: exitPos,
      artifacts: artifacts,
    )) {
      return state.copyWith(
        players: players,
        artifacts: artifacts,
        phase: GamePhase.ended,
        winner: 'runner',
        winReason: 'Runner escaped with all artifacts',
        tick: state.tick + 1,
        secondsRemaining: secondsRemaining,
      );
    }

    if (secondsRemaining == 0) {
      return state.copyWith(
        players: players,
        artifacts: artifacts,
        phase: GamePhase.ended,
        winner: 'guards',
        winReason: 'Time ran out',
        tick: state.tick + 1,
        secondsRemaining: 0,
      );
    }

    state = state.copyWith(
      players: players,
      artifacts: artifacts,
      tick: state.tick + 1,
      secondsRemaining: secondsRemaining,
    );
    return state;
  }

  Vec2 _resolveCollision(Vec2 from, Vec2 to) {
    final col = to.x.floor();
    final row = to.y.floor();
    if (_isSolid(col, row)) return from;
    return to;
  }

  bool _isSolid(int col, int row) {
    if (row < 0 || row >= kMapData.length) return true;
    if (col < 0 || col >= kMapData[row].length) return true;
    return kMapData[row][col] == tWall;
  }
}

