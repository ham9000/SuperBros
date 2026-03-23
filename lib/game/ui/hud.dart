import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../core/game_state.dart';

/// Heads-up display showing score and lives.
///
/// This is added to the camera viewport so it stays fixed
/// on screen regardless of camera position.
class Hud extends PositionComponent {
  Hud({required this.gameState})
      : super(position: Vector2(16, 16));

  final GameState gameState;

  @override
  void render(Canvas canvas) {
    // Background box for readability
    canvas.drawRect(
      const Rect.fromLTWH(-4, -4, 220, 56),
      Paint()..color = const Color(0x88000000),
    );

    final textPaint = TextPainter(textDirection: TextDirection.ltr);

    // Score
    textPaint.text = TextSpan(
      text: 'SCORE: ${gameState.score}',
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    textPaint.layout();
    textPaint.paint(canvas, const Offset(0, 0));

    // Lives
    textPaint.text = TextSpan(
      text: 'LIVES: ${'♥' * gameState.lives}',
      style: const TextStyle(
        color: Color(0xFFFF4444),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    textPaint.layout();
    textPaint.paint(canvas, const Offset(0, 26));
  }
}
