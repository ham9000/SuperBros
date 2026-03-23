import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../config/game_config.dart';

/// The level goal — reaching this triggers a win.
/// Rendered as a tall flag/pole shape.
class Goal extends PositionComponent {
  Goal({required Vector2 position})
      : super(
          position: position,
          size: Vector2(GameConfig.tileSize, GameConfig.tileSize * 2),
        );

  @override
  void render(Canvas canvas) {
    // Pole
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 2, 0, 4, size.y),
      Paint()..color = const Color(0xFF8B8B8B),
    );

    // Flag triangle
    final flagPath = Path()
      ..moveTo(size.x / 2 + 2, 2)
      ..lineTo(size.x, 10)
      ..lineTo(size.x / 2 + 2, 18)
      ..close();
    canvas.drawPath(
      flagPath,
      Paint()..color = const Color(0xFF00CC00),
    );

    if (GameConfig.debugMode) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFF00FF00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }
}
