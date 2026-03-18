import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../models/entities.dart';
import '../../../game/domain/map_data.dart';

class RunnerComponent extends PositionComponent {
  PlayerEntity entity;
  final bool isLocalPlayer;

  // Pre-allocated paints — never allocate inside render()
  static final _bodyPaint = Paint()..color = const Color(0xFF00E5FF);
  static final _ghostPaint = Paint()..color = const Color(0x2600E5FF);
  static final _taggedPaint = Paint()..color = const Color(0xFFFF4444);
  static final _linePaint = Paint()
    ..color = Colors.white70
    ..strokeWidth = 2;
  static final _dotPaint = Paint()..color = Colors.red;

  RunnerComponent({required this.entity, required this.isLocalPlayer})
      : super(
          position: Vector2(
              entity.position.x * kTileSize, entity.position.y * kTileSize),
          size: Vector2.all(kTileSize * 0.7),
          anchor: Anchor.center,
        );

  /// Called when a new server snapshot arrives — update authoritative state.
  void updateEntity(PlayerEntity updated) {
    entity = updated;
  }

  /// Called every Flame frame with the interpolated position.
  void smoothPosition(Vec2 pos, double dt) {
    position = Vector2(pos.x * kTileSize, pos.y * kTileSize);
  }

  // Keep old name as alias so nothing else breaks during transition
  void update_(PlayerEntity updated) => updateEntity(updated);

  @override
  void render(Canvas canvas) {
    if (!isLocalPlayer && !entity.isVisible) return;

    final paint = entity.tagCount > 0
        ? _taggedPaint
        : (isLocalPlayer && !entity.isVisible)
            ? _ghostPaint
            : _bodyPaint;

    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r, paint);

    final dx = math.cos(entity.angle) * r * 0.8;
    final dy = math.sin(entity.angle) * r * 0.8;
    canvas.drawLine(Offset(r, r), Offset(r + dx, r + dy), _linePaint);

    for (int i = 0; i < entity.tagCount; i++) {
      canvas.drawCircle(Offset(r + (i * 8.0) - 4, -6), 4, _dotPaint);
    }
  }
}
