import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../config/game_config.dart';
import 'ground.dart';

/// The player character.
///
/// Uses manual AABB physics: gravity pulls the player down each frame and
/// a simple overlap check snaps the player back on top of the ground when
/// they collide.
class Player extends PositionComponent with CollisionCallbacks {
  // ── Physics state ────────────────────────────────────────────────────────
  final Vector2 velocity = Vector2.zero();
  bool _isOnGround = false;

  // ── Input state ──────────────────────────────────────────────────────────
  bool _moveLeft = false;
  bool _moveRight = false;
  bool _jumpRequested = false;

  Player({required Vector2 position})
      : super(
          position: position,
          size: Vector2(GameConfig.playerWidth, GameConfig.playerHeight),
          anchor: Anchor.topLeft,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Draw player as a solid blue rectangle with a lighter top to suggest
    // a head / direction.
    final bodyPaint = Paint()..color = const Color(0xFF1565C0); // dark blue
    final headPaint = Paint()..color = const Color(0xFF42A5F5); // light blue
    final bodyRect = Rect.fromLTWH(0, size.y * 0.35, size.x, size.y * 0.65);
    final headRect =
        Rect.fromLTWH(size.x * 0.15, 0, size.x * 0.7, size.y * 0.4);
    canvas.drawRect(bodyRect, bodyPaint);
    canvas.drawRect(headRect, headPaint);
  }

  /// Called by [SideScrollerGame] each time a keyboard event is received.
  void onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _moveLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    _moveRight = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.keyW ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      _jumpRequested = true;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // ── Jump ────────────────────────────────────────────────────────────────
    // Check jump BEFORE resetting _isOnGround so the flag still reflects
    // last frame's collision result.
    if (_jumpRequested && _isOnGround) {
      velocity.y = GameConfig.playerJumpForce;
      _isOnGround = false;
    }
    _jumpRequested = false;

    // ── Horizontal movement ─────────────────────────────────────────────────
    if (_moveLeft) {
      velocity.x = -GameConfig.playerMoveSpeed;
    } else if (_moveRight) {
      velocity.x = GameConfig.playerMoveSpeed;
    } else {
      velocity.x = 0;
    }

    // ── Gravity ──────────────────────────────────────────────────────────────
    if (!_isOnGround) {
      velocity.y += GameConfig.gravity * dt;
      if (velocity.y > GameConfig.playerMaxFallSpeed) {
        velocity.y = GameConfig.playerMaxFallSpeed;
      }
    }

    // ── Integrate position ───────────────────────────────────────────────────
    position += velocity * dt;

    // Reset ground flag – collision callbacks will restore it if still grounded.
    _isOnGround = false;

    // ── World boundary clamping ─────────────────────────────────────────────
    if (position.x < 0) position.x = 0;
    if (position.x + size.x > GameConfig.worldWidth) {
      position.x = GameConfig.worldWidth - size.x;
    }
  }

  // ── Collision handling ───────────────────────────────────────────────────

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);
    if (other is Ground) {
      _resolveGroundCollision(other);
    }
  }

  /// Snaps the player on top of [ground] when falling onto it.
  void _resolveGroundCollision(Ground ground) {
    final double playerBottom = position.y + size.y;
    final double groundTop = ground.position.y;

    // Only resolve from above (falling down).
    if (playerBottom > groundTop && velocity.y >= 0) {
      position.y = groundTop - size.y;
      velocity.y = 0;
      _isOnGround = true;
    }
  }
}
