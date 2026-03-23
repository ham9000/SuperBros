import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../config/game_config.dart';

/// A collectible item that the player can pick up for score.
///
/// Rendered as a yellow spinning diamond shape.
class Collectible extends PositionComponent {
  Collectible({required Vector2 position})
      : isCollected = false,
        _animTimer = 0,
        _initialY = position.y,
        super(
          position: position,
          size: Vector2(GameConfig.collectibleSize, GameConfig.collectibleSize),
        );

  bool isCollected;
  double _animTimer;
  final double _initialY;

  @override
  void update(double dt) {
    super.update(dt);
    if (isCollected) return;

    // Absolute bob — no drift
    _animTimer += dt * 3;
    position.y = _initialY + 3 * math.sin(_animTimer);
  }

  @override
  void render(Canvas canvas) {
    if (isCollected) return;

    final cx = size.x / 2;
    final cy = size.y / 2;

    // Draw a diamond/coin shape
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(size.x, cy)
      ..lineTo(cx, size.y)
      ..lineTo(0, cy)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFFFD700), // gold
    );

    // Outline
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFDAA520)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (GameConfig.debugMode) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFF00FFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }
}
