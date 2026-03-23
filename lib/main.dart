import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'game/side_scroller_game.dart';
import 'game/input/touch_controls.dart';
import 'game/ui/game_over_overlay.dart';
import 'game/ui/win_overlay.dart';

void main() {
  final game = SideScrollerGame();

  // Show touch controls on mobile platforms
  final showTouch = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(
              game: game,
              overlayBuilderMap: {
                SideScrollerGame.gameOverOverlay: (context, game) =>
                    GameOverOverlay(game: game as SideScrollerGame),
                SideScrollerGame.winOverlay: (context, game) =>
                    WinOverlay(game: game as SideScrollerGame),
              },
            ),
            if (showTouch)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TouchControls(
                  onLeftPressed: () => game.player.startMoveLeft(),
                  onLeftReleased: () => game.player.stopMoveLeft(),
                  onRightPressed: () => game.player.startMoveRight(),
                  onRightReleased: () => game.player.stopMoveRight(),
                  onJumpPressed: () => game.player.startJump(),
                  onJumpReleased: () => game.player.stopJump(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
