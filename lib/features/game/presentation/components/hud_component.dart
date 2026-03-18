import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../models/entities.dart';

class HudComponent extends PositionComponent {
  GameStateEntity? gameState;
  String localPlayerId;
  PlayerRole localRole;

  HudComponent({
    required this.localPlayerId,
    required this.localRole,
  }) : super(priority: 10);

  static final _bgPaint = Paint()..color = const Color(0xCC000000);
  static final _heartFull = Paint()..color = const Color(0xFFE53935);
  static final _heartEmpty = Paint()..color = const Color(0xFF444444);
  static final _artifactFull = Paint()..color = const Color(0xFF00FFAA);
  static final _artifactEmpty = Paint()..color = const Color(0xFF444444);

  void update_(GameStateEntity state) {
    gameState = state;
  }

  @override
  void render(Canvas canvas) {
    if (gameState == null) return;
    final runner = gameState!.players.values
        .where((p) => p.role == PlayerRole.runner)
        .firstOrNull;

    // ── Top bar background ────────────────────────────────────────────────
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 900, 48),
      _bgPaint,
    );

    // ── Timer ─────────────────────────────────────────────────────────────
    final minutes = gameState!.secondsRemaining ~/ 60;
    final seconds = gameState!.secondsRemaining % 60;
    final timeStr =
        '$minutes:${seconds.toString().padLeft(2, '0')}';
    _drawText(canvas, timeStr, const Offset(430, 14), fontSize: 22);

    // ── Hearts (tag count — 2 max) ────────────────────────────────────────
    for (int i = 0; i < 2; i++) {
      final filled = runner != null && i < (2 - runner.tagCount);
      _drawHeart(canvas, Offset(16 + i * 32.0, 12), filled);
    }

    // ── Artifact icons ────────────────────────────────────────────────────
    final collected =
        gameState!.artifacts.where((a) => a.isCollected).length;
    for (int i = 0; i < 3; i++) {
      final paint = i < collected ? _artifactFull : _artifactEmpty;
      canvas.drawRect(
        Rect.fromLTWH(820 + i * 22.0, 14, 14, 20),
        paint,
      );
    }

    // ── Role badge ───────────────────────────────────────────────────────
    _drawText(
      canvas,
      localRole == PlayerRole.runner ? '🏃 RUNNER' : '🔦 GUARD',
      const Offset(16, 60),
      fontSize: 13,
    );

    // ── Danger indicator for runner ───────────────────────────────────────
    if (localRole == PlayerRole.runner && runner != null) {
      _drawDangerIndicator(canvas, runner);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, bool filled) {
    canvas.drawCircle(center, 9, filled ? _heartFull : _heartEmpty);
  }

  void _drawDangerIndicator(Canvas canvas, PlayerEntity runner) {
    final guards = gameState!.players.values
        .where((p) => p.role == PlayerRole.guard)
        .toList();
    if (guards.isEmpty) return;

    PlayerEntity? nearest;
    double minDist = double.infinity;
    for (final g in guards) {
      final d = runner.position.distanceTo(g.position);
      if (d < minDist) {
        minDist = d;
        nearest = g;
      }
    }
    if (nearest == null || minDist > 8) return;

    // Draw a red arc at bottom-center pointing toward nearest guard
    final dx = nearest.position.x - runner.position.x;
    final dy = nearest.position.y - runner.position.y;
    final angle = math.atan2(dy, dx);

    final paint = Paint()
      ..color = Color.fromARGB(
        (((8 - minDist) / 8) * 255).clamp(0, 255).toInt(),
        255,
        0,
        0,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawArc(
      const Rect.fromLTWH(430, 500, 40, 40),
      angle - 0.4,
      0.8,
      false,
      paint,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset,
      {double fontSize = 16}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }
}

