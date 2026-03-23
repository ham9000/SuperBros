import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../config/game_config.dart';

/// A static, collidable ground platform drawn as a green rectangle.
class Ground extends PositionComponent with CollisionCallbacks {
  Ground({required Vector2 position, required double width})
      : super(
          position: position,
          size: Vector2(width, GameConfig.groundThickness),
          anchor: Anchor.topLeft,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Top stripe is a lighter green; the rest is darker to give a ground feel.
    final topPaint = Paint()..color = const Color(0xFF66BB6A); // light green
    final bodyPaint = Paint()..color = const Color(0xFF388E3C); // dark green

    const double topHeight = 8.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, topHeight), topPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, topHeight, size.x, size.y - topHeight),
      bodyPaint,
    );
  }
}
