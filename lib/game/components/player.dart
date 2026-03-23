import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import '../config/game_config.dart';
import 'ground.dart';

/// The player character — a colored rectangle with manual
/// platformer physics (gravity, jump, ground collision).
class Player extends PositionComponent {
  Player({required Vector2 position})
      : velocity = Vector2.zero(),
        _isOnGround = false,
        super(
          position: position,
          size: Vector2(GameConfig.playerWidth, GameConfig.playerHeight),
        );

  final Vector2 velocity;
  bool _isOnGround;

  // Track which movement keys are currently held
  bool _moveLeft = false;
  bool _moveRight = false;
  bool _jumpRequested = false;

  // ── Keyboard handling ───────────────────────────────────

  void onKeyEvent(KeyEvent event) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _moveLeft = isDown;
        break;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _moveRight = isDown;
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
      case LogicalKeyboardKey.space:
        if (isDown && _isOnGround) {
          _jumpRequested = true;
        }
        break;
    }
  }

  // ── Touch input methods ─────────────────────────────────

  void startMoveLeft() => _moveLeft = true;
  void stopMoveLeft() => _moveLeft = false;
  void startMoveRight() => _moveRight = true;
  void stopMoveRight() => _moveRight = false;
  void startJump() {
    if (_isOnGround) _jumpRequested = true;
  }
  void stopJump() {} // jump is impulse-based, no-op on release

  // ── Update loop ─────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // Horizontal movement
    velocity.x = 0;
    if (_moveLeft) velocity.x -= GameConfig.playerSpeed;
    if (_moveRight) velocity.x += GameConfig.playerSpeed;

    // Jump
    if (_jumpRequested && _isOnGround) {
      velocity.y = GameConfig.jumpForce;
      _isOnGround = false;
      _jumpRequested = false;
    }

    // Gravity
    velocity.y += GameConfig.gravity * dt;
    if (velocity.y > GameConfig.maxFallSpeed) {
      velocity.y = GameConfig.maxFallSpeed;
    }

    // Apply velocity
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    // Collision with ground blocks
    _resolveGroundCollisions();
  }

  /// Simple AABB collision resolution against all Ground components.
  void _resolveGroundCollisions() {
    _isOnGround = false;

    final grounds = parent?.children.whereType<Ground>() ?? [];
    for (final ground in grounds) {
      if (_overlaps(ground)) {
        _resolveCollision(ground);
      }
    }
  }

  bool _overlaps(Ground ground) {
    return position.x < ground.position.x + ground.size.x &&
        position.x + size.x > ground.position.x &&
        position.y < ground.position.y + ground.size.y &&
        position.y + size.y > ground.position.y;
  }

  void _resolveCollision(Ground ground) {
    final playerBottom = position.y + size.y;
    final playerTop = position.y;
    final playerLeft = position.x;
    final playerRight = position.x + size.x;

    final groundTop = ground.position.y;
    final groundBottom = ground.position.y + ground.size.y;
    final groundLeft = ground.position.x;
    final groundRight = ground.position.x + ground.size.x;

    // Calculate overlap on each axis
    final overlapBottom = playerBottom - groundTop;
    final overlapTop = groundBottom - playerTop;
    final overlapRight = playerRight - groundLeft;
    final overlapLeft = groundRight - playerLeft;

    // Find the smallest overlap to determine push direction
    final minOverlap = [overlapBottom, overlapTop, overlapRight, overlapLeft]
        .reduce((a, b) => a < b ? a : b);

    if (minOverlap == overlapBottom && velocity.y >= 0) {
      // Landing on top
      position.y = groundTop - size.y;
      velocity.y = 0;
      _isOnGround = true;
    } else if (minOverlap == overlapTop && velocity.y < 0) {
      // Hitting head on bottom of block
      position.y = groundBottom;
      velocity.y = 0;
    } else if (minOverlap == overlapRight) {
      // Hitting right side
      position.x = groundLeft - size.x;
      velocity.x = 0;
    } else if (minOverlap == overlapLeft) {
      // Hitting left side
      position.x = groundRight;
      velocity.x = 0;
    }
  }

  // ── Render ──────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Body
    canvas.drawRect(
      size.toRect(),
      Paint()..color = const Color(0xFFE04040), // red player
    );

    if (GameConfig.debugMode) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFFFFFF00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  // ── Public state for external systems ───────────────────

  bool get isOnGround => _isOnGround;
}
