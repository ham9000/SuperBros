import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../config/game_config.dart';

/// A static rectangular block that the player can stand on.
///
/// Uses a simple colored rectangle. The [position] marks the
/// top-left corner; [size] defines width and height.
class Ground extends PositionComponent {
  Ground({
    required Vector2 position,
    required Vector2 size,
    this.color = const Color(0xFF4A7A2E), // earthy green
  }) : super(position: position, size: size);

  final Color color;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      size.toRect(),
      Paint()..color = color,
    );

    if (GameConfig.debugMode) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFFFF0000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }
}
