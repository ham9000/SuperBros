import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import 'components/ground.dart';
import 'components/player.dart';
import 'config/game_config.dart';

/// Root game class.
///
/// Milestone 1: Player movement, jump, gravity, and a flat ground platform.
class SideScrollerGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents {
  late Player _player;

  @override
  Color backgroundColor() => const Color(0xFF87CEEB); // sky blue

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Fix the viewport size so the game has a consistent coordinate space
    // regardless of the host window / browser size.
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(GameConfig.viewportWidth, GameConfig.viewportHeight),
    );

    // Ground stretches across the full world width.
    final ground = Ground(
      position: Vector2(0, GameConfig.worldHeight - GameConfig.groundThickness),
      width: GameConfig.worldWidth,
    );
    world.add(ground);

    // Player starts near the left edge, sitting on top of the ground.
    _player = Player(
      position: Vector2(
        120,
        GameConfig.worldHeight -
            GameConfig.groundThickness -
            GameConfig.playerHeight,
      ),
    );
    world.add(_player);

    // Camera follows the player; default anchor is Anchor.center so the
    // player stays centered on screen.
    camera.follow(_player);

    // Clamp the camera so it doesn't scroll beyond the world bounds.
    camera.setBounds(
      Rectangle.fromLTWH(
        0,
        0,
        GameConfig.worldWidth,
        GameConfig.worldHeight,
      ),
    );
  }

  // Forward keyboard events to the player component.
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _player.onKeyEvent(event, keysPressed);
    return KeyEventResult.handled;
  }
}
