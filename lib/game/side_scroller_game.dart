import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';

import 'config/game_config.dart';
import 'core/game_state.dart';
import 'rendering/pixel_art.dart';

/// Flame owns the clock; the session owns simulation, and the renderer owns ink.
class SideScrollerGame extends FlameGame {
  SideScrollerGame({required this.session});

  final GameState session;

  @override
  Color backgroundColor() => PixelArt.ink;

  @override
  void update(double dt) {
    super.update(dt);
    session.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    const width = GameConfig.viewportWidth;
    const height = GameConfig.viewportHeight;
    final scale = math.min(size.x / width, size.y / height);
    canvas.save();
    canvas.translate(
      ((size.x - width * scale) / 2).floorToDouble(),
      ((size.y - height * scale) / 2).floorToDouble(),
    );
    canvas.scale(scale);
    canvas.clipRect(
      const Rect.fromLTWH(0, 0, width, height),
      doAntiAlias: false,
    );
    PixelArt.renderScene(canvas, session);
    canvas.restore();
  }
}
