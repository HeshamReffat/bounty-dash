import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../models/entities.dart';
import '../../../game/domain/map_data.dart';

class RunnerComponent extends PositionComponent {
  PlayerEntity entity;
  final bool isLocalPlayer;

  static final _bodyPaint = Paint()..color = const Color(0xFF00E5FF);
  static final _ghostPaint = Paint()
    ..color = const Color(0x2600E5FF); // barely visible when hidden
  static final _taggedPaint = Paint()..color = const Color(0xFFFF4444);

  RunnerComponent({required this.entity, required this.isLocalPlayer})
      : super(
          position: Vector2(
              entity.position.x * kTileSize, entity.position.y * kTileSize),
          size: Vector2.all(kTileSize * 0.7),
          anchor: Anchor.center,
        );

  void update_(PlayerEntity updated) {
    entity = updated;
    position = Vector2(
        updated.position.x * kTileSize, updated.position.y * kTileSize);
  }

  @override
  void render(Canvas canvas) {
    // On guard screen, runner is invisible unless visible flag set
    if (!isLocalPlayer && !entity.isVisible) return;

    final paint = entity.tagCount > 0
        ? _taggedPaint
        : (isLocalPlayer && !entity.isVisible)
            ? _ghostPaint
            : _bodyPaint;

    final r = size.x / 2;
    // Body circle
    canvas.drawCircle(Offset(r, r), r, paint);
    // Direction indicator
    final dx = math.cos(entity.angle) * r * 0.8;
    final dy = math.sin(entity.angle) * r * 0.8;
    canvas.drawLine(
      Offset(r, r),
      Offset(r + dx, r + dy),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 2,
    );
    // Tag count dots
    for (int i = 0; i < entity.tagCount; i++) {
      canvas.drawCircle(
        Offset(r + (i * 8.0) - 4, -6),
        4,
        Paint()..color = Colors.red,
      );
    }
  }
}

