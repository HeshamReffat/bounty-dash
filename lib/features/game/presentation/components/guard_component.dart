import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Path;
import '../../../../models/entities.dart';
import '../../../game/domain/map_data.dart';

class GuardComponent extends PositionComponent {
  PlayerEntity entity;
  final bool isLocalPlayer;

  static const double _flashlightRange = 7.0 * kTileSize;
  static const double _flashlightAngle = math.pi / 3; // 60°

  // Pre-allocated paints
  static final _bodyPaint = Paint()..color = const Color(0xFFFF6B35);
  static final _flashlightPaint = Paint()
    ..color = const Color(0x44FFE066)
    ..style = PaintingStyle.fill;
  static final _flashlightBorderPaint = Paint()
    ..color = const Color(0x88FFE066)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _linePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2.5;

  GuardComponent({required this.entity, required this.isLocalPlayer})
      : super(
          position: Vector2(
              entity.position.x * kTileSize, entity.position.y * kTileSize),
          size: Vector2.all(kTileSize * 0.75),
          anchor: Anchor.center,
        );

  void updateEntity(PlayerEntity updated) {
    entity = updated;
  }

  void smoothPosition(Vec2 pos, double dt) {
    position = Vector2(pos.x * kTileSize, pos.y * kTileSize);
  }

  // Alias
  void update_(PlayerEntity updated) => updateEntity(updated);

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    _drawFlashlightCone(canvas, r);
    canvas.drawCircle(Offset(r, r), r, _bodyPaint);
    final dx = math.cos(entity.angle) * r * 0.8;
    final dy = math.sin(entity.angle) * r * 0.8;
    canvas.drawLine(Offset(r, r), Offset(r + dx, r + dy), _linePaint);
  }

  void _drawFlashlightCone(Canvas canvas, double r) {
    final path = Path();
    path.moveTo(r, r);
    final startAngle = entity.angle - _flashlightAngle / 2;
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      final a = startAngle + (_flashlightAngle / steps) * i;
      path.lineTo(
          r + math.cos(a) * _flashlightRange, r + math.sin(a) * _flashlightRange);
    }
    path.close();
    canvas.drawPath(path, _flashlightPaint);
    canvas.drawPath(path, _flashlightBorderPaint);
  }
}
