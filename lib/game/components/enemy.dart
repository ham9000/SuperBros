import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../config/game_config.dart';
import 'ground.dart';

/// A simple enemy that patrols back and forth on a platform.
///
/// Reverses direction when it hits a wall or reaches a ledge.
class Enemy extends PositionComponent {
  Enemy({required Vector2 position})
      : _direction = 1,
        _speed = GameConfig.enemySpeed,
        super(
          position: position,
          size: Vector2(GameConfig.enemyWidth, GameConfig.enemyHeight),
        );

  double _direction; // 1 = right, -1 = left
  final double _speed;

  /// Whether this enemy is still active (not stomped).
  bool isActive = true;

  @override
  void update(double dt) {
    super.update(dt);
    if (!isActive) return;

    position.x += _speed * _direction * dt;

    if (_shouldReverse()) {
      _direction *= -1;
      // Nudge back so we don't re-trigger next frame
      position.x += _speed * _direction * dt;
    }
  }

  /// Check if the enemy should reverse: either it hit a wall
  /// or there's no ground ahead (ledge detection).
  bool _shouldReverse() {
    final grounds = parent?.children.whereType<Ground>() ?? [];
    final probeX = _direction > 0
        ? position.x + size.x + 2
        : position.x - 2;
    final feetY = position.y + size.y;

    bool hasGroundAhead = false;
    bool wallAhead = false;

    for (final g in grounds) {
      // Ledge check: is there ground below our leading foot?
      if (probeX >= g.position.x &&
          probeX <= g.position.x + g.size.x &&
          feetY >= g.position.y &&
          feetY <= g.position.y + g.size.y + 4) {
        hasGroundAhead = true;
      }

      // Wall check: is there a block at our body height ahead?
      if (_overlapsRect(probeX, position.y + 2, 2, size.y - 4, g)) {
        wallAhead = true;
      }
    }

    return wallAhead || !hasGroundAhead;
  }

  bool _overlapsRect(
      double x, double y, double w, double h, Ground ground) {
    return x < ground.position.x + ground.size.x &&
        x + w > ground.position.x &&
        y < ground.position.y + ground.size.y &&
        y + h > ground.position.y;
  }

  @override
  void render(Canvas canvas) {
    if (!isActive) return;

    // Purple enemy rectangle
    canvas.drawRect(
      size.toRect(),
      Paint()..color = const Color(0xFF8B30B0),
    );

    // Small eyes to show direction
    final eyeY = size.y * 0.3;
    final eyeSize = 4.0;
    final leftEyeX = _direction > 0 ? size.x * 0.55 : size.x * 0.2;
    final rightEyeX = _direction > 0 ? size.x * 0.75 : size.x * 0.4;
    final eyePaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(leftEyeX, eyeY, eyeSize, eyeSize),
      eyePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rightEyeX, eyeY, eyeSize, eyeSize),
      eyePaint,
    );

    if (GameConfig.debugMode) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFFFF00FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }
}
