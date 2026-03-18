import 'entities/entities.dart';

/// Pure domain rule: validates tagging.
class TagSystem {
  static const double kTagRadius = 1.5;
  static const int kMaxTags = 2;

  /// Returns updated runner entity if tag is valid, null otherwise.
  static PlayerEntity? attemptTag({
    required PlayerEntity guard,
    required PlayerEntity runner,
    required bool runnerIsVisible,
  }) {
    if (!runnerIsVisible) return null;
    if (guard.position.distanceTo(runner.position) > kTagRadius) return null;
    final newTagCount = runner.tagCount + 1;
    return runner.copyWith(tagCount: newTagCount);
  }

  static bool isGuardsWin(PlayerEntity runner) => runner.tagCount >= kMaxTags;
}

