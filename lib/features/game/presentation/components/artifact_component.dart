import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../../../../models/entities.dart';
import '../../../game/domain/map_data.dart';

class ArtifactComponent extends PositionComponent {
  ArtifactEntity entity;
  late ScaleEffect _pulseEffect;

  static final _paint = Paint()..color = const Color(0xFF00FFAA);
  static final _glowPaint = Paint()
    ..color = const Color(0x4400FFAA)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  ArtifactComponent({required this.entity})
      : super(
          position: Vector2(
              entity.position.x * kTileSize, entity.position.y * kTileSize),
          size: Vector2.all(kTileSize * 0.5),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    _pulseEffect = ScaleEffect.by(
      Vector2.all(1.2),
      EffectController(
        duration: 0.8,
        reverseDuration: 0.8,
        infinite: true,
        curve: Curves.easeInOut,
      ),
    );
    add(_pulseEffect);
  }

  void updateEntity(ArtifactEntity updated) {
    entity = updated;
    if (updated.isCollected) removeFromParent();
  }

  void update_(ArtifactEntity updated) => updateEntity(updated);

  @override
  void render(Canvas canvas) {
    if (entity.isCollected) return;
    final r = size.x / 2;
    // Glow
    canvas.drawCircle(Offset(r, r), r * 1.4, _glowPaint);
    // Diamond shape
    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(size.x, r)
      ..lineTo(r, size.y)
      ..lineTo(0, r)
      ..close();
    canvas.drawPath(path, _paint);
  }
}

