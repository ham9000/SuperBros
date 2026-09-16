import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/components/collectible.dart';
import 'package:super_bros/game/components/player.dart';
import 'package:super_bros/game/config/game_config.dart';
import 'package:super_bros/game/side_scroller_game.dart';
import 'package:super_bros/game/ui/game_over_overlay.dart';
import 'package:super_bros/game/ui/hud.dart';
import 'package:super_bros/game/ui/win_overlay.dart';
import 'package:super_bros/main.dart' as app;

Future<SideScrollerGame> startGame(WidgetTester tester) async {
  app.main();
  await tester.pump();
  final widget = tester.widget<GameWidget>(
    find.byWidgetPredicate((widget) => widget is GameWidget),
  );
  final game = widget.game as SideScrollerGame;
  await tester.runAsync(() => game.loaded.timeout(const Duration(seconds: 15)));
  await tester.pump();
  game.pauseEngine();
  await tester.runAsync(() => game.ready().timeout(const Duration(seconds: 15)));
  game.update(1 / 60);
  return game;
}

void main() {
  testWidgets('game loads, renders, and responds to movement and jump keys',
      (tester) async {
    final game = await startGame(tester);
    expect(game.player.isMounted, isTrue);
    expect(game.player.isOnGround, isTrue);
    expect(game.camera.viewport.children.whereType<Hud>(), hasLength(1));
    final startX = game.player.x;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var frame = 0; frame < 10; frame++) {
      game.update(1 / 60);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(game.player.x, greaterThan(startX));

    final stoppedX = game.player.x;
    game.update(1 / 60);
    expect(game.player.x, stoppedX);
    final groundY = game.player.y;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    game.update(1 / 60);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(game.player.y, lessThan(groundY));
    expect(game.player.velocity.y, isNegative);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('collecting, winning, and replaying use the real app overlays',
      (tester) async {
    final game = await startGame(tester);
    final initialComponents = game.world.children.length;
    final collectible = game.world.children.whereType<Collectible>().first;

    game.player.position.setFrom(collectible.position);
    game.player.velocity.setZero();
    game.update(0);
    expect(game.gameState.score, GameConfig.collectibleScore);
    expect(collectible.isCollected, isTrue);
    game.update(0);
    expect(game.gameState.score, GameConfig.collectibleScore);

    game.player.position.setFrom(game.levelData.goalPosition!);
    game.player.velocity.setZero();
    game.update(0);
    await tester.pump();
    expect(game.gameState.isWin, isTrue);
    expect(game.paused, isTrue);
    expect(find.byType(WinOverlay), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(WinOverlay),
      matching: find.byType(ElevatedButton),
    ));
    await tester.pump();
    await tester.runAsync(() => game.ready().timeout(const Duration(seconds: 15)));
    expect(game.paused, isFalse);
    game.pauseEngine();
    expect(game.gameState.score, 0);
    expect(game.gameState.isWin, isFalse);
    expect(find.byType(WinOverlay), findsNothing);
    expect(game.world.children.whereType<Player>(), hasLength(1));
    expect(game.world.children, hasLength(initialComponents));
    expect(game.camera.viewport.children.whereType<Hud>(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('falling exhausts lives and R restarts after game over',
      (tester) async {
    final game = await startGame(tester);
    for (var remaining = GameConfig.startingLives - 1;
        remaining >= 0;
        remaining--) {
      game.player.y =
          game.levelData.worldHeight + GameConfig.fallDeathBuffer + 1;
      game.player.velocity.setZero();
      game.update(0);
      expect(game.gameState.lives, remaining);
      if (remaining > 0) {
        expect(game.player.position, game.levelData.playerSpawn);
        expect(game.gameState.isGameOver, isFalse);
      }
    }
    await tester.pump();
    expect(game.gameState.isGameOver, isTrue);
    expect(find.byType(GameOverOverlay), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    await tester.runAsync(() => game.ready().timeout(const Duration(seconds: 15)));
    expect(game.paused, isFalse);
    game.pauseEngine();
    expect(game.gameState.isGameOver, isFalse);
    expect(game.gameState.lives, GameConfig.startingLives);
    expect(find.byType(GameOverOverlay), findsNothing);
    expect(game.world.children.whereType<Player>(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
