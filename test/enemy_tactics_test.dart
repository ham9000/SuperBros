import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/config/game_config.dart';
import 'package:super_bros/game/core/game_state.dart';

import 'game_state_test.dart' show advance, emptyGame, bulletAt;

Enemy soldier({bool prone = false, EnemyType kind = EnemyType.infantry}) =>
    Enemy(x: 210, kind: kind, spawn: EnemySpawnDefinition(startsProne: prone))
      ..activateCombat()
      ..decisionTimer = 100;

void main() {
  for (final kind in [EnemyType.infantry, EnemyType.shield]) {
    test('${kind.name} prone bounds, low shots and stationary pose', () {
      final game = emptyGame();
      final enemy = soldier(prone: true, kind: kind);
      game.enemies.add(enemy);
      final x = enemy.x;
      expect(enemy.height, GameConfig.enemyProneHeight);
      expect(enemy.width, GameConfig.enemyProneWidth);
      expect(enemy.y + enemy.height, GameConfig.groundY);
      final highShot = bulletAt(enemy)..y = GameConfig.groundY - 23;
      game.projectiles.add(highShot);
      advance(game, GameConfig.enemyTelegraph + 0.05);
      expect(enemy.hp, kind == EnemyType.shield ? 50 : 30);
      expect(enemy.x, x);
      final shot = game.projectiles.firstWhere((p) => p.hostile);
      expect(shot.y, enemy.muzzleY);
      expect(shot.y, greaterThan(GameConfig.groundY - 10));
      enemy.facing = 1;
      game.projectiles.add(bulletAt(enemy));
      advance(game, 0.01);
      expect(enemy.hp, kind == EnemyType.shield ? 40 : 20);
    });
  }

  test('lowering is anchored, stationary and delays attacks', () {
    final game = emptyGame();
    final enemy =
        soldier()
          ..decisionTimer = 0
          ..randomState = 1;
    game.enemies.add(enemy);
    advance(game, 0.01);
    expect(enemy.stance, EnemyStance.lowering);
    final x = enemy.x;
    advance(game, GameConfig.enemyLoweringTime / 2);
    expect(enemy.height, inExclusiveRange(12, 28));
    expect(enemy.y + enemy.height, closeTo(GameConfig.groundY, 0.00001));
    expect(enemy.x, x);
    expect(game.projectiles, isEmpty);
    advance(game, GameConfig.enemyLoweringTime / 2 + 0.02);
    expect(enemy.stance, EnemyStance.prone);
    expect(game.projectiles, isEmpty);
    advance(game, GameConfig.enemyTelegraph + 0.02);
    expect(game.projectiles.where((p) => p.hostile), isNotEmpty);
  });

  test('decisions are interval based and copies preserve random state', () {
    final game = emptyGame();
    final enemy = soldier()..decisionTimer = 0.4;
    game.enemies.add(enemy);
    final state = enemy.randomState;
    advance(game, 0.2);
    expect(enemy.randomState, state);
    final copy = enemy.copy();
    expect(copy.decisionTimer, enemy.decisionTimer);
    expect(copy.grenadeCooldown, enemy.grenadeCooldown);
    expect(
      List.generate(20, (_) => copy.nextDecision()),
      List.generate(20, (_) => enemy.nextDecision()),
    );
    final outcomes = <EnemyStance>{};
    for (var seed = 1; seed <= 20; seed++) {
      final trial = emptyGame();
      final e =
          soldier()
            ..decisionTimer = 0
            ..randomState = seed * 3000;
      trial.enemies.add(e);
      advance(trial, 0.01);
      outcomes.add(e.stance);
    }
    expect(outcomes, containsAll([EnemyStance.standing, EnemyStance.lowering]));
  });

  for (final prone in [false, true]) {
    test('grenade telegraph and cooldown in prone=$prone', () {
      final game = emptyGame();
      game.player.invulnerable = 100;
      final enemy =
          soldier(prone: prone)
            ..randomState = 1
            ..grenadeCooldown = 0;
      game.enemies.add(enemy);
      advance(game, 0.01);
      expect(enemy.throwingGrenade, isTrue);
      advance(game, GameConfig.enemyGrenadeTelegraph - 0.05);
      expect(game.projectiles, isEmpty);
      advance(game, 0.06);
      final grenade = game.projectiles.single;
      expect(grenade.hostile && grenade.grenade && grenade.explosive, isTrue);
      expect(grenade.detonateOnImpact, isFalse);
      expect(grenade.vy, lessThan(0));
      expect(enemy.grenadeCooldown, greaterThan(5.9));
      advance(game, 1.1);
      expect(game.projectiles.where((p) => p.grenade).length, 1);
      expect(game.projectiles.where((p) => !p.grenade), isNotEmpty);
    });
  }

  test('hostile grenades bounce and only explode at fuse expiry', () {
    final game = emptyGame();
    final grenade = Projectile(
      x: game.player.x,
      y: GameConfig.groundY - 4,
      vx: 0,
      vy: 80,
      hostile: true,
      grenade: true,
      explosive: true,
      life: 0.3,
      detonateOnImpact: false,
    );
    game.projectiles.add(grenade);
    advance(game, 0.03);
    expect(grenade.vy, lessThan(0));
    expect(game.player.health, GameConfig.maxHealth);
    expect(game.projectiles, contains(grenade));
    advance(game, 0.3);
    expect(game.projectiles, isEmpty);
    expect(game.player.health, GameConfig.maxHealth - 22);
  });

  test(
    'inactive states cannot throw and interruptions cancel queued throws',
    () {
      for (final state in [
        'dormant',
        'entering',
        'recovery',
        'offscreen',
        'dead',
        'hurt',
      ]) {
        final game = emptyGame();
        final enemy =
            soldier()
              ..mode = EnemyMode.alert
              ..timer = 0
              ..throwingGrenade = true;
        switch (state) {
          case 'dormant':
            enemy.enterDormantState();
            enemy.x = 1000;
          case 'entering':
            enemy.enterDormantState();
            enemy.beginEntrance(
              const EnemySpawnContext(playerX: 57, cameraX: 0),
            );
          case 'recovery':
            enemy.recovery = 1;
          case 'offscreen':
            enemy.x = 1000;
          case 'dead':
            enemy.defeat();
          case 'hurt':
            game.projectiles.add(bulletAt(enemy));
            enemy.timer = 1;
        }
        game.enemies.add(enemy);
        advance(game, 0.2);
        expect(
          game.projectiles.where((p) => p.hostile),
          isEmpty,
          reason: state,
        );
        if (state == 'hurt' || state == 'offscreen' || state == 'dead') {
          expect(enemy.throwingGrenade, isFalse);
        }
      }
    },
  );

  test('actual authored pairs enter together and land separately', () {
    for (final index in [4, 6, 9, 16, 21]) {
      final game = GameState();
      game.enemies.removeWhere((e) => !e.id.startsWith('encounter-$index-'));
      game.player.x = game.enemies.first.originX - 169;
      game.cameraX = game.player.centerX - 160;
      advance(game, 0.01);
      expect(game.enemies.length, 2);
      expect(
        game.enemies.every((e) => e.lifecycle == EnemyLifecycle.entering),
        isTrue,
      );
      expect(game.enemies.first.entranceTime, game.enemies.last.entranceTime);
      expect(game.enemies.first.entrance, same(game.enemies.last.entrance));
      advance(game, GameConfig.entranceWarning + GameConfig.entranceMotion);
      expect(
        game.enemies.every((e) => e.lifecycle == EnemyLifecycle.active),
        isTrue,
      );
      expect(
        game.enemies.first.bounds.overlaps(game.enemies.last.bounds),
        isFalse,
      );
    }
  });

  test('pair waits for both landing positions', () {
    final game = GameState();
    game.enemies.removeWhere((e) => !e.id.startsWith('encounter-4-'));
    final x = game.enemies.first.originX;
    game.player.x = x - 259;
    game.cameraX = game.player.centerX - 160;
    advance(game, 0.01);
    expect(
      game.enemies.every((e) => e.lifecycle == EnemyLifecycle.dormant),
      isTrue,
    );
    game.player.x += 60;
    game.cameraX += 60;
    advance(game, 0.01);
    expect(
      game.enemies.every((e) => e.lifecycle == EnemyLifecycle.entering),
      isTrue,
    );
  });

  test('mission seed, restart and checkpoint preserve tactics', () {
    final game = GameState();
    final initial =
        game.enemies.map((e) => (e.startsProne, e.randomState)).toList();
    expect(game.enemies.where((e) => e.startsProne), isNotEmpty);
    expect(
      game.enemies
          .where((e) => e.kind == EnemyType.turret)
          .every((e) => !e.startsProne),
      isTrue,
    );
    game.restart();
    expect(game.enemies.map((e) => (e.startsProne, e.randomState)), initial);
    expect(
      GameState(
        encounterSeed: 55,
      ).enemies.map((e) => (e.startsProne, e.randomState)),
      isNot(initial),
    );
    game.player.x = GameConfig.checkpointX;
    game.cameraX = game.player.centerX - 160;
    final enemy =
        game.enemies.first
          ..x = game.player.x + 140
          ..activateCombat()
          ..lowerToProne()
          ..updateStance(0.2)
          ..grenadeCooldown = 2.5;
    advance(game, 0.01);
    game.retryCheckpoint();
    final saved = game.enemies.first.copy();
    advance(game, 4);
    final future = game.enemies.first.copy();
    game.retryCheckpoint();
    final restored = game.enemies.first;
    expect(restored.randomState, saved.randomState);
    expect(restored.stance, saved.stance);
    expect(restored.height, saved.height);
    expect(restored.loweringTime, saved.loweringTime);
    expect(restored.grenadeCooldown, saved.grenadeCooldown);
    expect(restored.decisionTimer, saved.decisionTimer);
    advance(game, 4);
    expect(game.enemies.first.randomState, future.randomState);
    expect(game.enemies.first.stance, future.stance);
    expect(enemy, isNot(same(restored)));
  });
}
