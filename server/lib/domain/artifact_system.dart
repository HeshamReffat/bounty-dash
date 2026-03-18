import 'entities/entities.dart';

/// Pure domain rule: artifact collection and exit logic.
class ArtifactSystem {
  static const double kCollectRadius = 0.8;
  static const double kExitRadius = 1.2;

  /// Returns updated artifact if runner is close enough, else null.
  static ArtifactEntity? tryCollect({
    required PlayerEntity runner,
    required ArtifactEntity artifact,
  }) {
    if (artifact.isCollected) return null;
    if (runner.position.distanceTo(artifact.position) > kCollectRadius) return null;
    return artifact.copyWith(isCollected: true, collectedBy: runner.id);
  }

  static bool allCollected(List<ArtifactEntity> artifacts) =>
      artifacts.every((a) => a.isCollected);

  static bool hasReachedExit({
    required PlayerEntity runner,
    required Vec2 exitPosition,
    required List<ArtifactEntity> artifacts,
  }) {
    if (!allCollected(artifacts)) return false;
    return runner.position.distanceTo(exitPosition) <= kExitRadius;
  }
}

