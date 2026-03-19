import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../game/domain/map_data.dart';

class MapComponent extends Component with HasGameReference {
  static final _wallPaint = Paint()..color = const Color(0xFF2C2C3A);
  static final _wallInnerPaint = Paint()..color = const Color(0xFF1A1A26);
  static final _floorPaint = Paint()..color = const Color(0xFF3E3E52);
  static final _exitPaint = Paint()..color = const Color(0xFFFFD700);
  static final _exitInnerPaint = Paint()..color = const Color(0xFFFFEA00);
  static final _artifactFloorPaint = Paint()..color = const Color(0xFF1A6B6B);

  @override
  void render(Canvas canvas) {
    for (int row = 0; row < kMapRows; row++) {
      for (int col = 0; col < kMapCols; col++) {
        final tile = kMapData[row][col];
        final rect = Rect.fromLTWH(
          col * kTileSize,
          row * kTileSize,
          kTileSize,
          kTileSize,
        );
        switch (tile) {
          case tWall:
            canvas.drawRect(rect, _wallPaint);
            canvas.drawRect(rect.deflate(2), _wallInnerPaint);
          case tExit:
            canvas.drawRect(rect, _exitPaint);
            canvas.drawRect(rect.deflate(3), _exitInnerPaint);
          case tArtifact:
            canvas.drawRect(rect, _artifactFloorPaint);
          default:
            canvas.drawRect(rect, _floorPaint);
        }
      }
    }
    // Grid lines (subtle)
    final gridPaint = Paint()
      ..color = const Color(0x11FFFFFF)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (int row = 0; row <= kMapRows; row++) {
      canvas.drawLine(
        Offset(0, row * kTileSize),
        Offset(kMapCols * kTileSize, row * kTileSize),
        gridPaint,
      );
    }
    for (int col = 0; col <= kMapCols; col++) {
      canvas.drawLine(
        Offset(col * kTileSize, 0),
        Offset(col * kTileSize, kMapRows * kTileSize),
        gridPaint,
      );
    }
  }
}

