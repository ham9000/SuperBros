import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/config/game_config.dart';
import 'package:super_bros/game/core/game_state.dart';
import 'package:super_bros/game/core/progress_store.dart';
import 'package:super_bros/game/rendering/pixel_art.dart';
import 'package:super_bros/game/ui/menu_state.dart';
import 'package:super_bros/game/ui/ruckus_app.dart';

Future<RuckusShellState> launch(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(960, 540));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RuckusApp(progress: ProgressStore()));
  await tester.pump();
  return tester.state<RuckusShellState>(find.byType(RuckusShell));
}

Future<void> deploy(WidgetTester tester, RuckusShellState shell) async {
  for (var i = 0; i < 4; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }
  await tester.runAsync(() => shell.game!.loaded);
  await tester.pump();
  shell.game!.pauseEngine();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ElevatedButton, label));
  await tester.pump();
}

Future<void> tapButtonAt(WidgetTester tester, String label, int index) async {
  await tester.tap(find.widgetWithText(ElevatedButton, label).at(index));
  await tester.pump();
}

Future<int> renderDigest(GameState state) async {
  final recorder = ui.PictureRecorder();
  PixelArt.renderScene(ui.Canvas(recorder), state);
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 270);
  final data = await image.toByteData();
  final digest = Object.hashAll(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return digest;
}

void step(RuckusShellState shell, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    shell.game!.update(1 / 60);
  }
}

void main() {
  testWidgets(
    'title, back, locking, and keyboard deployment use actual menus',
    (tester) async {
      final shell = await launch(tester);
      expect(shell.menu.screen, AppScreen.title);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(shell.menu.screen, AppScreen.main);
      await tapButton(tester, 'HOW TO PLAY');
      expect(shell.menu.screen, AppScreen.help);
      await tapButton(tester, 'GOT IT  ✓');
      expect(shell.menu.screen, AppScreen.main);
      await tapButton(tester, 'PLAY  ▶');
      expect(shell.menu.screen, AppScreen.characters);
      final lockedCharacters = tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .where((button) => button.onPressed == null);
      expect(
        lockedCharacters.length,
        MenuState.characters.where((c) => c.locked).length,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(shell.menu.screen, AppScreen.levels);
      expect(
        tester
            .widgetList<ElevatedButton>(find.byType(ElevatedButton))
            .where((button) => button.onPressed == null)
            .length,
        MenuState.levels.where((level) => level.locked).length,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(shell.menu.screen, AppScreen.characters);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all Juggernauts and both active missions deploy through menus', (
    tester,
  ) async {
    final shell = await launch(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tapButton(tester, 'PLAY  ▶');
    for (
      var character = 0;
      character < MenuState.characters.length;
      character++
    ) {
      expect(MenuState.characters[character].locked, isFalse);
      await tapButton(tester, 'SELECT ${MenuState.characters[character].unit}');
      for (var level = 0; level < 2; level++) {
        expect(MenuState.levels[level].locked, isFalse);
        await tapButtonAt(tester, 'DEPLOY  ▶', level);
        expect(shell.session!.characterIndex, character);
        expect(shell.session!.missionIndex, level);
        shell.game!.pauseEngine();
        shell.session!.status = MissionStatus.gameOver;
        await tester.pump();
        await tapButton(tester, 'LEVEL SELECT');
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard and touch move, jump, fire, and release safely', (
    tester,
  ) async {
    final shell = await launch(tester);
    await deploy(tester, shell);
    final s = shell.session!;
    final initialX = s.player.x;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    step(shell, .3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    expect(s.player.x, greaterThan(initialX));
    final stoppedX = s.player.x;
    step(shell, .1);
    expect(s.player.x, stoppedX);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    step(shell, .1);
    expect(s.player.y, lessThan(GameConfig.groundY - s.player.height));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    step(shell, .1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
    expect(s.projectiles.where((shot) => !shot.hostile), isNotEmpty);

    final finger = await tester.startGesture(tester.getCenter(find.text('→')));
    step(shell, .2);
    expect(s.player.x, greaterThan(stoppedX));
    await finger.cancel();
    expect(s.input.held(Command.right), isFalse);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding touch FIRE uses pistol cadence while walking', (
    tester,
  ) async {
    final shell = await launch(tester);
    await deploy(tester, shell);
    final s = shell.session!;
    s.pickups.clear();
    var shots = 0;
    s.audio.onEvent = (event) {
      if (event == AudioEvent.shot) shots++;
    };
    final fire = await tester.startGesture(
      tester.getCenter(find.text('FIRE')),
      pointer: 1,
    );
    final walk = await tester.startGesture(
      tester.getCenter(find.text('→')),
      pointer: 2,
    );
    step(shell, 1);
    expect(shots, 3);
    expect(s.player.x, greaterThan(100));
    expect(s.player.ammo, 0);
    expect(s.enemies.last.lifecycle, EnemyLifecycle.dormant);
    await fire.up();
    await walk.cancel();
    step(shell, 0.5);
    expect(shots, 3);
    expect(s.input.held(Command.fire), isFalse);
    expect(s.input.held(Command.right), isFalse);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'procedural entrances render warnings before sprites and animate all seven',
    (tester) async {
      await tester.runAsync(() async {
        final state = GameState()..calloutTime = 0;
        state.enemies.clear();
        final empty = await renderDigest(state);
        state.enemies.add(Enemy(x: 360, kind: EnemyType.infantry));
        expect(
          await renderDigest(state),
          empty,
          reason: 'Dormant enemies must be invisible',
        );
        const context = EnemySpawnContext(playerX: 160, cameraX: 0);
        for (final type in EntranceType.values) {
          final spawn = EnemySpawnDefinition(
            marker: const EntranceMarker(
              id: 'test',
              x: 360,
              allowed: {...EntranceType.values},
            ),
            forced: type,
            scripted: type == EntranceType.rearAmbush,
          );
          final enemy = Enemy(
            x: 360,
            kind: EnemyType.infantry,
            spawn: spawn,
            entrance: EntranceSelector(
              4,
            ).chooseEntrance(EnemyType.infantry, spawn, context),
          );
          state.enemies
            ..clear()
            ..add(enemy);
          final dormant = await renderDigest(state);
          expect(enemy.beginEntrance(context), isTrue);
          final warning = await renderDigest(state);
          expect(
            warning,
            isNot(dormant),
            reason: '${type.name} needs a pre-arrival warning',
          );
          enemy.updateEntrance(1.25, context);
          final moving = await renderDigest(state);
          expect(
            moving,
            isNot(warning),
            reason: '${type.name} must animate, not just wait',
          );
          enemy.updateEntrance(0.21, context);
          expect(await renderDigest(state), isNot(moving));
        }
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rendering varies each Juggernaut and Airport mission art', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final characterDigests = <int>{};
      for (
        var character = 0;
        character < MenuState.characters.length;
        character++
      ) {
        final state = GameState(characterIndex: character)..calloutTime = 0;
        characterDigests.add(await renderDigest(state));
      }
      expect(characterDigests.length, MenuState.characters.length);
      final harbor = GameState()..calloutTime = 0;
      final airport = GameState(missionIndex: 1)..calloutTime = 0;
      expect(await renderDigest(airport), isNot(await renderDigest(harbor)));
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause freezes, help preserves game, resume and restart work', (
    tester,
  ) async {
    final shell = await launch(tester);
    await deploy(tester, shell);
    final s = shell.session!;
    final game = shell.game;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    step(shell, .2);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(s.status, MissionStatus.paused);
    final x = s.player.x;
    step(shell, 1);
    expect(s.player.x, x);
    expect(s.input.held(Command.right), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tapButton(tester, 'CONTROLS');
    expect(shell.menu.screen, AppScreen.help);
    await tapButton(tester, 'GOT IT  ✓');
    expect(shell.game, same(game));
    expect(s.status, MissionStatus.paused);
    await tapButton(tester, 'RESUME');
    expect(s.status, MissionStatus.playing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tapButton(tester, 'RESTART MISSION');
    expect(s.player.x, lessThan(x));
    expect(s.score, 0);
    expect(s.status, MissionStatus.playing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('death, checkpoint retry, boss victory and menu exit are wired', (
    tester,
  ) async {
    final shell = await launch(tester);
    await deploy(tester, shell);
    final s = shell.session!;
    s.player.x = GameConfig.preBossCheckpointX + 1;
    step(shell, .1);
    expect(s.checkpointReached, isTrue);
    s.player.invulnerable = 0;
    s.damagePlayer(GameConfig.maxHealth);
    await tester.pump();
    expect(s.status, MissionStatus.gameOver);
    await tapButton(tester, 'RETRY');
    expect(s.status, MissionStatus.playing);
    expect(s.player.x, greaterThan(GameConfig.checkpointX));
    expect(s.player.health, GameConfig.maxHealth);

    s.player.x = GameConfig.bossArenaStart + 20;
    step(shell, .1);
    expect(s.boss.active, isTrue);
    // Use the normal projectile collision/vulnerability path, not a win flag.
    s.boss.hp = GameConfig.bulletDamage;
    s.boss.vulnerable = true;
    s.boss.telegraph = false;
    s.boss.timer = 1;
    s.projectiles.add(
      Projectile(
        x: s.boss.x,
        y: s.boss.y + 10,
        vx: 0,
        vy: 0,
        damage: GameConfig.bulletDamage,
      ),
    );
    step(shell, 4);
    await tester.pump();
    expect(s.status, MissionStatus.victory);
    await tapButton(tester, 'LEVEL SELECT');
    expect(shell.menu.screen, AppScreen.levels);
    expect(shell.session, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(shell.menu.screen, AppScreen.main);
    expect(tester.takeException(), isNull);
  });

  testWidgets('common landscape phone layout keeps menus and touch usable', (
    tester,
  ) async {
    final shell = await launch(tester);
    await tester.binding.setSurfaceSize(const Size(740, 360));
    await tester.pump();
    await deploy(tester, shell);
    await tester.pump();
    for (final label in ['FIRE', 'JUMP', 'BOOM', 'USE']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(740));
      expect(rect.bottom, lessThanOrEqualTo(360));
    }
    expect(tester.takeException(), isNull);
  });
}
