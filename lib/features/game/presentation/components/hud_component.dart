import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../models/entities.dart';

class HudComponent extends PositionComponent {
  GameStateEntity? gameState;
  String localPlayerId;
  PlayerRole localRole;

  double _vpWidth = 900;
  double _vpHeight = 600;

  // Cache TextPainters so we don't re-layout on every frame
  final Map<String, TextPainter> _textCache = {};

  HudComponent({
    required this.localPlayerId,
    required this.localRole,
  }) : super(priority: 10);

  static final _bgPaint = Paint()..color = const Color(0xCC000000);
  static final _heartFull = Paint()..color = const Color(0xFFE53935);
  static final _heartEmpty = Paint()..color = const Color(0xFF444444);
  static final _artifactFull = Paint()..color = const Color(0xFF00FFAA);
  static final _artifactEmpty = Paint()..color = const Color(0xFF444444);
  // Reusable danger arc paint — color mutated per frame but no new allocation
  final _dangerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  void update_(GameStateEntity state) {
    gameState = state;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _vpWidth = size.x;
    _vpHeight = size.y;
  }

  @override
  void render(Canvas canvas) {
    if (gameState == null) return;
    final runner = gameState!.players.values
        .where((p) => p.role == PlayerRole.runner)
        .firstOrNull;

    // Top bar
    canvas.drawRect(Rect.fromLTWH(0, 0, _vpWidth, 48), _bgPaint);

    // Timer — only re-layout when the string changes
    final minutes = gameState!.secondsRemaining ~/ 60;
    final seconds = gameState!.secondsRemaining % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
    _drawCachedText(canvas, timeStr, Offset(_vpWidth / 2 - 16, 14),
        fontSize: 22, key: 'timer');

    // Hearts (tag count — dynamic based on player count)
    final tagCount = runner?.tagCount ?? 0;
    final maxTags = gameState!.maxTags;
    for (int i = 0; i < maxTags; i++) {
      final filled = i < (maxTags - tagCount);
      _drawHeart(canvas, Offset(16 + i * 32.0, 12), filled);
    }

    // Artifact icons
    final collected = gameState!.artifacts.where((a) => a.isCollected).length;
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(820 + i * 22.0, 14, 14, 20),
        i < collected ? _artifactFull : _artifactEmpty,
      );
    }

    // Role badge
    final roleStr = localRole == PlayerRole.runner ? '🏃 RUNNER' : '🔦 GUARD';
    _drawCachedText(canvas, roleStr, const Offset(16, 60),
        fontSize: 13, key: 'role');

    // Danger indicator
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
      if (d < minDist) { minDist = d; nearest = g; }
    }
    if (nearest == null || minDist > 8) return;

    final dx = nearest.position.x - runner.position.x;
    final dy = nearest.position.y - runner.position.y;
    final angle = math.atan2(dy, dx);

    _dangerPaint.color = Color.fromARGB(
      (((8 - minDist) / 8) * 255).clamp(0, 255).toInt(),
      255, 0, 0,
    );

    final cx = _vpWidth / 2 - 20;
    final cy = _vpHeight - 100.0;
    canvas.drawArc(Rect.fromLTWH(cx, cy, 40, 40), angle - 0.4, 0.8, false,
        _dangerPaint);
  }

  /// Paint text only re-lays-out when [text] changes for a given [key].
  void _drawCachedText(Canvas canvas, String text, Offset offset,
      {required double fontSize, required String key}) {
    final cacheKey = '$key:$text:$fontSize';
    var tp = _textCache[cacheKey];
    if (tp == null) {
      // Evict old entry for this slot
      _textCache.removeWhere((k, _) => k.startsWith('$key:'));
      tp = TextPainter(
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
      _textCache[cacheKey] = tp;
    }
    tp.paint(canvas, offset);
  }
}

