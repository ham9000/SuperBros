import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../core/game_state.dart';

/// Heads-up display showing score and lives.
///
/// This is added to the camera viewport so it stays fixed
/// on screen regardless of camera position.
class Hud extends PositionComponent {
  Hud({required this.gameState})
      : _scorePainter = TextPainter(textDirection: TextDirection.ltr),
        _livesPainter = TextPainter(textDirection: TextDirection.ltr),
        super(position: Vector2(16, 16));

  final GameState gameState;
  final TextPainter _scorePainter;
  final TextPainter _livesPainter;

  static const _scoreStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
  );

  static const _livesStyle = TextStyle(
    color: Color(0xFFFF4444),
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
  );

  int _lastScore = -1;
  int _lastLives = -1;

  @override
  void render(Canvas canvas) {
    // Background box
    canvas.drawRect(
      const Rect.fromLTWH(-4, -4, 220, 56),
      Paint()..color = const Color(0x88000000),
    );

    // Only re-layout when values change
    if (gameState.score != _lastScore) {
      _lastScore = gameState.score;
      _scorePainter.text = TextSpan(
        text: 'SCORE: $_lastScore',
        style: _scoreStyle,
      );
      _scorePainter.layout();
    }
    _scorePainter.paint(canvas, const Offset(0, 0));

    if (gameState.lives != _lastLives) {
      _lastLives = gameState.lives;
      _livesPainter.text = TextSpan(
        text: 'LIVES: ${'♥' * _lastLives}',
        style: _livesStyle,
      );
      _livesPainter.layout();
    }
    _livesPainter.paint(canvas, const Offset(0, 26));
  }
}
