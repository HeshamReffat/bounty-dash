import 'dart:math' as math;
import 'entities/entities.dart';
import 'map_data.dart';

/// Pure domain logic — no I/O.
/// Returns a new [PlayerEntity] for the runner with [isVisible] set
/// correctly for the given [guard].
class VisibilityEngine {
  static const double kFlashlightRange = 7.0; // tiles
  static const double kFlashlightAngle = math.pi / 3; // 60°
  static const int kRayCount = 40;
  static const double kFootstepRevealRadius = 2.0; // tiles

  /// Whether the runner is visible to a specific guard.
  static bool isRunnerVisibleToGuard({
    required PlayerEntity guard,
    required PlayerEntity runner,
    required bool runnerIsMoving,
  }) {
    // Footstep reveal — audible radius when moving
    if (runnerIsMoving &&
        guard.position.distanceTo(runner.position) <= kFootstepRevealRadius) {
      return true;
    }
    // Flashlight cone ray-cast
    return _raycastCone(
      origin: guard.position,
      guardAngle: guard.angle,
      target: runner.position,
    );
  }

  static bool _raycastCone({
    required Vec2 origin,
    required double guardAngle,
    required Vec2 target,
  }) {
    final dx = target.x - origin.x;
    final dy = target.y - origin.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist > kFlashlightRange) return false;

    // Angle to target relative to guard facing
    final angleToTarget = math.atan2(dy, dx);
    double diff = (angleToTarget - guardAngle + math.pi * 3) % (math.pi * 2) - math.pi;
    if (diff.abs() > kFlashlightAngle / 2) return false;

    // Cast a single ray toward the target and check for wall occlusion
    return !_isOccluded(origin: origin, target: target);
  }

  static bool _isOccluded({required Vec2 origin, required Vec2 target}) {
    // Bresenham step along the ray
    int x0 = origin.x.floor();
    int y0 = origin.y.floor();
    final int x1 = target.x.floor();
    final int y1 = target.y.floor();

    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (x0 != x1 || y0 != y1) {
      if (_isWall(x0, y0)) return true;
      final int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x0 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y0 += sy;
      }
    }
    return false;
  }

  static bool _isWall(int col, int row) {
    if (row < 0 || row >= kMapData.length) return true;
    if (col < 0 || col >= kMapData[row].length) return true;
    return kMapData[row][col] == tWall;
  }
}

