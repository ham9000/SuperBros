import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/config/game_config.dart';
import 'package:super_bros/game/core/game_state.dart';

import 'game_state_test.dart' show advance, emptyGame, bulletAt, tap;

const context = EnemySpawnContext(playerX: 160, cameraX: 0);
const marker = EntranceMarker(
  id: 'door-a',
  x: 360,
  allowed: {...EntranceType.values},
);

Enemy arrival(
  EntranceType type, {
  bool vulnerable = false,
  bool scripted = false,
}) {
  final spawn = EnemySpawnDefinition(
    marker: marker,
    forced: type,
    entranceVulnerable: vulnerable,
    scripted: scripted || type == EntranceType.rearAmbush,
  );
  return Enemy(
    x: 360,
    kind: EnemyType.infantry,
    spawn: spawn,
    entrance: EntranceSelector(
      42,
    ).chooseEntrance(EnemyType.infantry, spawn, context),
  );
}

void main() {
  group('encounter lifecycle and fairness', () {
    test(
      'dormant enemies are invisible, inert, and immune to every damage path',
      () {
        final game = emptyGame();
        final enemy = Enemy(
          x: 76,
          kind: EnemyType.infantry,
          spawn: const EnemySpawnDefinition(
            trigger: SpawnTrigger.encounterWave,
            wave: 3,
          ),
        );
        game.enemies.add(enemy);
        final x = enemy.x;
        tap(game, Command.fire);
        expect(game.projectiles.where((p) => !p.hostile), isNotEmpty);
        game.projectiles.add(bulletAt(enemy));
        game.projectiles.add(bulletAt(enemy, explosive: true)..life = 0);
        final prop = Prop(x: 80);
        game.props.add(prop);
        game.projectiles.addAll([bulletAt(prop), bulletAt(prop)]);
        advance(game, 0.3);
        expect(enemy.hp, GameConfig.infantryHealth);
        expect(enemy.x, x);
        expect(enemy.visible, isFalse);
        expect(enemy.combatEnabled, isFalse);
        expect(game.player.health, GameConfig.maxHealth);
        expect(game.projectiles.where((p) => p.hostile), isEmpty);
        expect(prop.alive, isFalse);
      },
    );

    test('dormant overlap neither contacts nor consumes friendly bullets', () {
      final game = emptyGame();
      final enemy = Enemy(
        x: game.player.x,
        kind: EnemyType.infantry,
        spawn: const EnemySpawnDefinition(
          trigger: SpawnTrigger.encounterWave,
          wave: 2,
        ),
      );
      game.enemies.add(enemy);
      final shot = bulletAt(enemy);
      game.projectiles.add(shot);
      advance(game, 0.1);
      expect(game.projectiles, contains(shot));
      expect(game.player.health, GameConfig.maxHealth);
    });

    for (final type in EntranceType.values) {
      test('${type.name} warns, animates, lands safely, and delays combat', () {
        final enemy = arrival(type);
        expect(enemy.entranceType, type);
        expect(enemy.beginEntrance(context), isTrue);
        expect(enemy.visible, isTrue);
        expect(enemy.warningVisible, isTrue);
        expect(enemy.damageable, isFalse);
        expect(enemy.combatEnabled, isFalse);
        final start = (enemy.x, enemy.y, enemy.entranceScale);
        enemy.updateEntrance(GameConfig.entranceWarning + 0.4, context);
        expect((enemy.x, enemy.y, enemy.entranceScale), isNot(start));
        expect(enemy.motionProgress, closeTo(0.5, 0.001));
        expect(
          (enemy.targetX + enemy.width / 2 - context.playerX).abs(),
          greaterThanOrEqualTo(GameConfig.entranceSafeGap),
        );
        enemy.updateEntrance(0.41, context);
        expect(enemy.lifecycle, EnemyLifecycle.active);
        expect(enemy.x, enemy.targetX);
        expect(enemy.y, enemy.targetY);
        expect(enemy.damageable, isTrue);
        expect(enemy.combatEnabled, isFalse);
        expect(enemy.recovery, GameConfig.entranceRecovery);
        expect(enemy.shouldActivate(context), isFalse);
      });
    }

    test(
      'door and trench open/warn before exposing a sprite; vehicle disembarks',
      () {
        for (final type in [
          EntranceType.doorway,
          EntranceType.trench,
          EntranceType.dropFromAbove,
          EntranceType.rearAmbush,
          EntranceType.vehicle,
        ]) {
          final enemy = arrival(type)..beginEntrance(context);
          expect(enemy.spriteVisible, isFalse);
          enemy.updateEntrance(GameConfig.entranceWarning / 2, context);
          expect(enemy.warningVisible, isTrue);
          expect(enemy.spriteVisible, isFalse);
          enemy.updateEntrance(GameConfig.entranceWarning / 2 + 0.6, context);
          expect(enemy.spriteVisible, isTrue);
        }
        final background = arrival(EntranceType.background)
          ..beginEntrance(context);
        expect(background.entranceScale, 0.35);
        final edge = arrival(EntranceType.screenEdge)..beginEntrance(context);
        expect(edge.x, greaterThan(GameConfig.viewportWidth));
        final rear = arrival(EntranceType.rearAmbush)..beginEntrance(context);
        expect(rear.x + rear.width, lessThan(0));
      },
    );

    test(
      'doorway and vehicle sprites stay clear throughout their visible path',
      () {
        for (final type in [EntranceType.doorway, EntranceType.vehicle]) {
          for (final playerX in [283.0, 459.0]) {
            final nearby = EnemySpawnContext(playerX: playerX, cameraX: 0);
            final enemy = arrival(type);
            expect(enemy.beginEntrance(nearby), isTrue);
            final playerBounds = Bounds(
              playerX - GameConfig.playerWidth / 2,
              GameConfig.groundY - GameConfig.playerHeight,
              GameConfig.playerWidth,
              GameConfig.playerHeight,
            );
            for (var frame = 0; frame < 180; frame++) {
              if (enemy.spriteVisible) {
                expect(enemy.bounds.overlaps(playerBounds), isFalse);
              }
              enemy.updateEntrance(GameConfig.simulationStep, nearby);
            }
            expect(enemy.lifecycle, EnemyLifecycle.active);
          }
        }
      },
    );

    test(
      'left-facing edge entrances start fully offscreen at world boundaries',
      () {
        for (final cameraX in [
          0.0,
          40.0,
          GameConfig.worldWidth - GameConfig.viewportWidth,
        ]) {
          final leftward = EnemySpawnContext(
            playerX: cameraX + 320,
            cameraX: cameraX,
            facing: -1,
          );
          final enemy = arrival(EntranceType.screenEdge);
          expect(enemy.beginEntrance(leftward), isTrue);
          expect(enemy.x + enemy.width, lessThan(cameraX));
          expect(enemy.targetX, greaterThanOrEqualTo(0));
          expect(
            enemy.targetX + enemy.width,
            lessThanOrEqualTo(GameConfig.worldWidth),
          );
          enemy.updateEntrance(2, leftward);
          expect(enemy.lifecycle, EnemyLifecycle.active);
          expect(enemy.x, greaterThan(cameraX));
        }
        final blocked = arrival(EntranceType.screenEdge);
        expect(
          blocked.beginEntrance(
            const EnemySpawnContext(playerX: 9, cameraX: 0, facing: -1),
          ),
          isFalse,
        );
        expect(blocked.visible, isFalse);
      },
    );

    test(
      'unsafe background reset never exposes a sprite over a jumping player',
      () {
        final enemy = arrival(EntranceType.background, vulnerable: true)
          ..beginEntrance(context);
        enemy.updateEntrance(1, context);
        final player =
            PlayerState()
              ..x = enemy.startX
              ..y = enemy.startY;
        enemy.updateEntrance(
          GameConfig.simulationStep,
          EnemySpawnContext(playerX: player.centerX, cameraX: 0),
        );
        expect(enemy.bounds.overlaps(player.bounds), isTrue);
        expect(enemy.spriteVisible, isFalse);
        expect(enemy.damageable, isFalse);
        expect(enemy.copy().spriteVisible, isFalse);
        expect(enemy.copy().damageable, isFalse);
        expect(enemy.warningVisible, isTrue);
        expect(enemy.combatEnabled, isFalse);
        enemy.updateEntrance(GameConfig.simulationStep, context);
        expect(enemy.spriteVisible, isTrue);
        expect(enemy.damageable, isTrue);
        expect(enemy.motionProgress, lessThan(0.02));
      },
    );

    test(
      'left-moving camera keeps edge arrivals offscreen during the warning',
      () {
        for (final cameraX in [
          40.0,
          GameConfig.worldWidth - GameConfig.viewportWidth,
        ]) {
          final enemy = arrival(EntranceType.screenEdge);
          expect(
            enemy.beginEntrance(
              EnemySpawnContext(
                playerX: cameraX + 320,
                cameraX: cameraX,
                facing: -1,
              ),
            ),
            isTrue,
          );
          for (var frame = 1; frame <= 40; frame++) {
            final moving = EnemySpawnContext(
              playerX: cameraX + 320 - frame,
              cameraX: cameraX - frame,
              facing: -1,
            );
            enemy.updateEntrance(GameConfig.simulationStep, moving);
            expect(enemy.motionProgress, 0);
            expect(enemy.x + enemy.width, lessThan(moving.cameraX));
          }
        }
      },
    );

    test(
      'entering is immune by default; vulnerability opt-in does not enable AI',
      () {
        for (final vulnerable in [false, true]) {
          final game = emptyGame();
          game.player.x = 151;
          final enemy = arrival(EntranceType.doorway, vulnerable: vulnerable)
            ..beginEntrance(context);
          game.enemies.add(enemy);
          game.projectiles.add(bulletAt(enemy));
          game.update(1 / 120);
          expect(enemy.hp, GameConfig.infantryHealth - (vulnerable ? 10 : 0));
          expect(enemy.combatEnabled, isFalse);
          expect(game.projectiles.where((p) => p.hostile), isEmpty);
          enemy.setDamageable(true);
          enemy.setCombatEnabled(true);
          expect(enemy.combatEnabled, isFalse);
          game.projectiles.add(bulletAt(enemy, explosive: true));
          game.update(1 / 120);
          expect(enemy.lifecycle, EnemyLifecycle.defeated);
          expect(enemy.visible, isFalse);
          expect(game.score, GameConfig.enemyScore);
        }
      },
    );

    test('active setters gate hits and combat independently', () {
      final game = emptyGame();
      final enemy = Enemy(x: 150, kind: EnemyType.infantry)..activateCombat();
      game.enemies.add(enemy);
      enemy.setDamageable(false);
      enemy.setCombatEnabled(false);
      game.projectiles.add(bulletAt(enemy));
      advance(game, 0.1);
      expect(enemy.hp, GameConfig.infantryHealth);
      expect(enemy.mode, EnemyMode.patrol);
      game.projectiles.clear();
      enemy.setDamageable(true);
      game.projectiles.add(bulletAt(enemy));
      game.update(1 / 120);
      expect(enemy.hp, GameConfig.infantryHealth - 10);
    });

    test(
      'entering immunity covers melee, explosions, prop chains and contact',
      () {
        final game = emptyGame();
        game.player.x = 151;
        final enemy = arrival(EntranceType.doorway)..beginEntrance(context);
        game.enemies.add(enemy);
        game.projectiles.add(bulletAt(enemy, explosive: true)..life = 0);
        final prop = Prop(x: enemy.x);
        game.props.add(prop);
        game.projectiles.addAll([bulletAt(prop), bulletAt(prop)]);
        game.update(1 / 120);
        expect(enemy.hp, GameConfig.infantryHealth);
        expect(prop.alive, isFalse);
        game.player.x = enemy.x - 15;
        tap(game, Command.fire);
        expect(enemy.hp, GameConfig.infantryHealth);
        game.player.x = enemy.x;
        game.update(1 / 120);
        expect(game.player.health, GameConfig.maxHealth);
        expect(game.projectiles.where((p) => p.hostile), isEmpty);
      },
    );

    test(
      'post-entrance recovery blocks contact and attacks, then normal AI resumes',
      () {
        final game = emptyGame();
        final enemy = arrival(EntranceType.doorway)..beginEntrance(context);
        enemy.updateEntrance(2, context);
        game.enemies.add(enemy);
        game.player.x = enemy.x;
        advance(game, GameConfig.entranceRecovery - 0.05);
        expect(game.player.health, GameConfig.maxHealth);
        expect(game.projectiles.where((p) => p.hostile), isEmpty);
        advance(game, 0.1);
        expect(game.player.health, lessThan(GameConfig.maxHealth));
        expect(enemy.mode, EnemyMode.alert);
        advance(game, GameConfig.enemyTelegraph + 0.1);
        expect(game.effects.any((e) => e.kind == 'enemyMuzzle'), isTrue);
      },
    );

    test(
      'skipped marker entrances release budget and safely resume without reroll',
      () {
        final game = emptyGame();
        game.player.x = 151;
        final first = arrival(EntranceType.doorway);
        final second = arrival(EntranceType.trench);
        game.enemies.addAll([first, second]);
        advance(game, 0.8);
        final selected = first.entrance;
        final time = first.entranceTime;
        game.player.x = 1151;
        game.cameraX = 1000;
        final next = Enemy(x: 1400, kind: EnemyType.infantry);
        game.enemies.add(next);
        game.update(1 / 120);
        expect(first.entranceSuspended, isTrue);
        expect(second.entranceSuspended, isTrue);
        expect(first.entranceTime, time);
        expect(first.spriteVisible, isFalse);
        expect(next.lifecycle, EnemyLifecycle.entering);
        expect(game.spawnContext.enteringCount, 1);
        next.defeat();
        game.player.x = 151;
        game.cameraX = 0;
        game.update(1 / 120);
        expect(first.entranceSuspended, isFalse);
        expect(first.entrance, same(selected));
        expect(first.lifecycle, EnemyLifecycle.entering);
        expect(first.motionProgress, lessThan(0.1));
        expect(game.spawnContext.enteringCount, 2);
      },
    );

    test(
      'unsafe targets defer, moving camera cannot complete an unseen entrance',
      () {
        final enemy = arrival(EntranceType.dropFromAbove)
          ..beginEntrance(context);
        enemy.updateEntrance(1, context);
        enemy.updateEntrance(
          2,
          const EnemySpawnContext(playerX: 900, cameraX: 700),
        );
        expect(enemy.lifecycle, EnemyLifecycle.entering);
        expect(enemy.entranceTime, GameConfig.entranceWarning);
        enemy.updateEntrance(0.1, context);
        expect(enemy.lifecycle, EnemyLifecycle.entering);
        final blocked = arrival(EntranceType.doorway);
        expect(
          blocked.beginEntrance(
            const EnemySpawnContext(playerX: 360, cameraX: 0),
          ),
          isFalse,
        );
        expect(blocked.lifecycle, EnemyLifecycle.dormant);
        final edge = arrival(EntranceType.screenEdge)..beginEntrance(context);
        edge.updateEntrance(
          3,
          const EnemySpawnContext(playerX: 860, cameraX: 700),
        );
        expect(edge.lifecycle, EnemyLifecycle.entering);
        edge.updateEntrance(
          0.2,
          const EnemySpawnContext(playerX: 860, cameraX: 700),
        );
        expect(edge.motionProgress, lessThan(1));
        expect(edge.targetX, greaterThan(700));
      },
    );

    test(
      'simulation caps concurrent entrances and delays rear under forward fire',
      () {
        final game = emptyGame();
        game.player.x = 151;
        game.enemies.addAll(
          List.generate(4, (_) => arrival(EntranceType.doorway)),
        );
        game.update(1 / 120);
        expect(
          game.enemies
              .where((e) => e.lifecycle == EnemyLifecycle.entering)
              .length,
          2,
        );
        final rear = Enemy(
          x: 360,
          kind: EnemyType.infantry,
          entrance: const EntranceChoice(EntranceType.rearAmbush, 1, {}),
        );
        game.enemies
          ..clear()
          ..add(rear);
        game.projectiles.addAll(
          List.generate(
            3,
            (i) =>
                Projectile(x: 300 + i * 10, y: 40, vx: 0, vy: 0, hostile: true),
          ),
        );
        game.update(1 / 120);
        expect(rear.lifecycle, EnemyLifecycle.dormant);
        game.projectiles.clear();
        game.update(1 / 120);
        expect(rear.lifecycle, EnemyLifecycle.entering);
      },
    );

    test('all triggers obey readiness and dormant enemies do not reroll', () {
      for (final trigger in SpawnTrigger.values) {
        final enemy = Enemy(
          x: 300,
          kind: EnemyType.infantry,
          spawn: EnemySpawnDefinition(
            trigger: trigger,
            prerequisite: 'a',
            wave: 2,
          ),
        );
        final ready = EnemySpawnContext(
          playerX: 310,
          cameraX: 0,
          completed: const {'a'},
          wave: 2,
        );
        expect(enemy.shouldActivate(ready), isTrue);
        if (trigger != SpawnTrigger.forwardEdge) {
          expect(enemy.shouldActivate(context), isFalse);
        }
        expect(
          enemy.shouldActivate(
            const EnemySpawnContext(playerX: 900, cameraX: 700),
          ),
          isFalse,
        );
      }
      final a = GameState(encounterSeed: 123);
      final b = GameState(encounterSeed: 123);
      final choices = a.enemies.map((e) => e.entranceType).toList();
      expect(b.enemies.map((e) => e.entranceType), choices);
      a.input.press(Command.right);
      a.player.invulnerable = 100;
      advance(a, 5);
      a.input.release(Command.right);
      a.input.press(Command.left);
      advance(a, 3);
      expect(a.enemies.map((e) => e.entranceType), choices);
      expect(a.enemies.first.lifecycle, isNot(EnemyLifecycle.dormant));
      a.retryCheckpoint();
      expect(a.enemies.map((e) => e.entranceType), choices);
    });

    test(
      'entry completion triggers dependent encounter and waves are usable',
      () {
        final game = emptyGame();
        game.player.x = 151;
        final first = Enemy(x: 360, kind: EnemyType.infantry, id: 'first');
        final second = Enemy(
          x: 350,
          kind: EnemyType.infantry,
          spawn: const EnemySpawnDefinition(
            trigger: SpawnTrigger.entranceComplete,
            prerequisite: 'first',
          ),
        );
        game.enemies.addAll([first, second]);
        advance(game, 1.6);
        expect(game.completedEntrances, contains('first'));
        expect(second.lifecycle, EnemyLifecycle.entering);
        final wave = Enemy(
          x: 350,
          kind: EnemyType.infantry,
          spawn: const EnemySpawnDefinition(
            trigger: SpawnTrigger.encounterWave,
            wave: 2,
          ),
        );
        game.enemies.add(wave);
        game.update(1 / 120);
        expect(wave.lifecycle, EnemyLifecycle.dormant);
        game.encounterWave = 2;
        game.update(1 / 120);
        expect(wave.lifecycle, EnemyLifecycle.entering);
      },
    );

    test(
      'checkpoint deeply preserves choice, progress, positions, flags and triggers',
      () {
        final game = GameState(encounterSeed: 505);
        final enemy = game.enemies[15];
        enemy.beginEntrance(
          EnemySpawnContext(
            playerX: enemy.originX - 220,
            cameraX: enemy.originX - 350,
          ),
        );
        enemy.updateEntrance(0.9);
        enemy.setDamageable(true);
        game.completedEntrances.add('saved');
        game.encounterWave = 3;
        game.player.x = GameConfig.checkpointX;
        game.cameraX = GameConfig.checkpointX - 160;
        game.update(1 / 120);
        final saved = enemy.copy();
        final choices = game.enemies.map((e) => e.entranceType).toList();
        enemy.defeat();
        game.completedEntrances.clear();
        game.encounterWave = 8;
        game.retryCheckpoint();
        final restored = game.enemies[15];
        expect(restored.entrance, same(saved.entrance));
        expect(restored.lifecycle, saved.lifecycle);
        expect(restored.entranceTime, saved.entranceTime);
        expect(restored.x, saved.x);
        expect(restored.y, saved.y);
        expect(restored.targetX, saved.targetX);
        expect(restored.startY, saved.startY);
        expect(restored.damageable, saved.damageable);
        expect(restored.combatEnabled, saved.combatEnabled);
        expect(game.completedEntrances, contains('saved'));
        expect(game.encounterWave, 3);
        game.enemies[15].updateEntrance(0.2);
        game.retryCheckpoint();
        expect(game.enemies[15].entranceTime, saved.entranceTime);
        expect(game.enemies.map((e) => e.entranceType), choices);
      },
    );
  });

  group('seeded weighted selection', () {
    test(
      'default weights and seed are reproducible, unusual repeats discouraged',
      () {
        expect(EntranceSelector.weights.values, [35, 18, 15, 14, 10, 5, 3]);
        List<EntranceType> select(int seed) {
          final selector = EntranceSelector(seed);
          return List.generate(
            500,
            (_) =>
                selector
                    .chooseEntrance(
                      EnemyType.infantry,
                      const EnemySpawnDefinition(marker: marker),
                      context,
                    )
                    .type,
          );
        }

        final a = select(555);
        expect(a, select(555));
        expect(a, isNot(select(556)));
        expect(a.toSet(), EntranceType.values.toSet());
        final repeated =
            List.generate(
              a.length - 1,
              (i) => a[i] != EntranceType.screenEdge && a[i] == a[i + 1],
            ).where((r) => r).length;
        expect(repeated, lessThan(50));
        expect(
          a.where((t) => t == EntranceType.rearAmbush).length,
          lessThanOrEqualTo(15),
        );
      },
    );

    test(
      'geometry, kind, definition and marker exclusions precede random roll',
      () {
        final selector = EntranceSelector(1);
        for (var i = 0; i < 50; i++) {
          final choice = selector.chooseEntrance(
            EnemyType.turret,
            const EnemySpawnDefinition(marker: marker),
            context,
          );
          expect(
            choice.type,
            isIn([EntranceType.screenEdge, EntranceType.doorway]),
          );
          expect(
            choice.exclusions[EntranceType.dropFromAbove],
            'stationary turret',
          );
        }
        for (final spawn in [
          const EnemySpawnDefinition(forced: EntranceType.doorway),
          const EnemySpawnDefinition(
            marker: EntranceMarker(
              id: 'bad',
              x: 360,
              clearance: 20,
              allowed: {...EntranceType.values},
            ),
            allowed: {EntranceType.screenEdge, EntranceType.doorway},
          ),
          const EnemySpawnDefinition(allowed: {}),
          const EnemySpawnDefinition(
            marker: marker,
            weights: {
              EntranceType.screenEdge: 0,
              EntranceType.doorway: 0,
              EntranceType.trench: 0,
              EntranceType.dropFromAbove: 0,
              EntranceType.background: 0,
              EntranceType.vehicle: 0,
              EntranceType.rearAmbush: 0,
            },
          ),
        ]) {
          expect(
            selector.chooseEntrance(EnemyType.infantry, spawn, context).type,
            EntranceType.screenEdge,
          );
        }
        final restricted = selector.chooseEntrance(
          EnemyType.infantry,
          const EnemySpawnDefinition(
            marker: EntranceMarker(
              id: 'only',
              x: 360,
              allowed: {EntranceType.doorway},
              weights: {EntranceType.doorway: 100},
            ),
          ),
          context,
        );
        expect(restricted.type, EntranceType.doorway);
        expect(restricted.exclusions[EntranceType.trench], 'marker');
      },
    );

    test(
      'forced and scripted/boss/tutorial behavior has safe explicit opt-in',
      () {
        final selector = EntranceSelector(2);
        for (final spawn in [
          const EnemySpawnDefinition(marker: marker, scripted: true),
          const EnemySpawnDefinition(marker: marker, boss: true),
          const EnemySpawnDefinition(marker: marker, tutorial: true),
        ]) {
          expect(
            selector.chooseEntrance(EnemyType.infantry, spawn, context).type,
            EntranceType.screenEdge,
          );
        }
        final forced = selector.chooseEntrance(
          EnemyType.infantry,
          const EnemySpawnDefinition(
            marker: marker,
            forced: EntranceType.trench,
          ),
          context,
        );
        expect(forced.type, EntranceType.trench);
        final invalid = selector.chooseEntrance(
          EnemyType.turret,
          const EnemySpawnDefinition(
            marker: marker,
            forced: EntranceType.trench,
          ),
          context,
        );
        expect(invalid.type, EntranceType.screenEdge);
        final optIn = selector.chooseEntrance(
          EnemyType.infantry,
          const EnemySpawnDefinition(
            marker: marker,
            boss: true,
            randomizeSpecial: true,
            allowed: {EntranceType.doorway},
          ),
          context,
        );
        expect(optIn.type, EntranceType.doorway);
        final protected = selector.chooseEntrance(
          EnemyType.infantry,
          const EnemySpawnDefinition(
            scripted: true,
            forced: EntranceType.rearAmbush,
          ),
          const EnemySpawnContext(
            playerX: 160,
            cameraX: 0,
            firstEncounter: true,
          ),
        );
        expect(protected.type, EntranceType.screenEdge);
      },
    );

    test(
      'group shares choice and doorway; intersection and conflicting forces fall back',
      () {
        final selector = EntranceSelector(8);
        const spawn = EnemySpawnDefinition(
          marker: marker,
          forced: EntranceType.doorway,
        );
        final choice = selector.chooseGroupEntrance([
          (EnemyType.infantry, spawn),
          (EnemyType.turret, spawn),
        ], context);
        expect(choice.type, EntranceType.doorway);
        expect(choice.marker, same(marker));
        final a = Enemy(
          x: 360,
          kind: EnemyType.infantry,
          spawn: spawn,
          entrance: choice,
        );
        final b = Enemy(
          x: 360,
          kind: EnemyType.shield,
          entrance: choice,
          spawn: const EnemySpawnDefinition(marker: marker, landingOffset: 28),
        );
        a.beginEntrance(context);
        b.beginEntrance(context);
        expect(b.targetX - a.targetX, 28);
        final mixed = selector.chooseGroupEntrance([
          (EnemyType.infantry, spawn),
          (
            EnemyType.infantry,
            const EnemySpawnDefinition(
              marker: marker,
              forced: EntranceType.trench,
            ),
          ),
        ], context);
        expect(mixed.type, EntranceType.screenEdge);
        expect(
          () => selector.chooseGroupEntrance([], context),
          throwsArgumentError,
        );
        final actual =
            GameState().enemies
                .where((e) => e.id.startsWith('encounter-4-'))
                .toList();
        expect(actual.length, 2);
        expect(actual.first.entrance, same(actual.last.entrance));
      },
    );

    test(
      'rear cap is enforced at every prefix; pressure excludes unless scripted',
      () {
        final selector = EntranceSelector(4);
        var rear = 0;
        for (var i = 1; i <= 200; i++) {
          final choice = selector.chooseEntrance(
            EnemyType.infantry,
            const EnemySpawnDefinition(forced: EntranceType.rearAmbush),
            context,
          );
          if (choice.type == EntranceType.rearAmbush) rear++;
          expect(rear / i, lessThanOrEqualTo(GameConfig.rearEntranceCap));
        }
        expect(rear, greaterThan(0));
        const pressure = EnemySpawnContext(
          playerX: 160,
          cameraX: 0,
          forwardPressure: true,
        );
        final ordinary = selector.chooseEntrance(
          EnemyType.infantry,
          const EnemySpawnDefinition(forced: EntranceType.rearAmbush),
          pressure,
        );
        expect(ordinary.type, EntranceType.screenEdge);
        expect(
          ordinary.exclusions[EntranceType.rearAmbush],
          'forward projectile pressure',
        );
        final scripted = selector.chooseEntrance(
          EnemyType.infantry,
          const EnemySpawnDefinition(
            scripted: true,
            forced: EntranceType.rearAmbush,
          ),
          pressure,
        );
        expect(scripted.type, EntranceType.rearAmbush);
      },
    );
  });

  group('viewport projectiles, held fire and camera', () {
    test(
      'friendly bullets cull at all padded edges before any impact/explosion',
      () {
        for (final position in [
          (497.0, 198.0),
          (-23.0, 198.0),
          (200.0, -20.0),
          (200.0, 287.0),
        ]) {
          final game = emptyGame();
          final enemy =
              Enemy(x: position.$1, y: position.$2, kind: EnemyType.infantry)
                ..activateCombat()
                ..setCombatEnabled(false);
          final prop = Prop(x: position.$1)..y = position.$2;
          game.enemies.add(enemy);
          game.props.add(prop);
          game.projectiles.add(
            Projectile(
              x: position.$1,
              y: position.$2,
              vx: 0,
              vy: 0,
              explosive: true,
              life: 0,
            ),
          );
          game.update(1 / 120);
          expect(enemy.hp, GameConfig.infantryHealth);
          expect(prop.hp, 20);
          expect(game.projectiles, isEmpty);
          expect(game.effects.where((e) => e.kind == 'explosion'), isEmpty);
        }
      },
    );

    test(
      'edge-inside hits work; movement beyond edge is culled before collision',
      () {
        final game = emptyGame();
        final enemy =
            Enemy(x: 475, kind: EnemyType.infantry)
              ..activateCombat()
              ..setCombatEnabled(false);
        game.enemies.add(enemy);
        game.projectiles.add(Projectile(x: 477, y: 195, vx: 0, vy: 0));
        game.update(1 / 120);
        expect(enemy.hp, 20);
        enemy.x = 496;
        game.projectiles.add(
          Projectile(x: 495, y: 195, vx: 390, vy: 0, explosive: true),
        );
        game.update(1 / 120);
        expect(enemy.hp, 20);
        expect(game.projectiles, isEmpty);
      },
    );

    test(
      'explicit offscreen shots, hostile bullets and grenade arcs are exceptions',
      () {
        final game = emptyGame();
        final enemy =
            Enemy(x: 700, kind: EnemyType.infantry)
              ..activateCombat()
              ..setCombatEnabled(false);
        game.enemies.add(enemy);
        game.projectiles.add(
          Projectile(x: 700, y: 195, vx: 0, vy: 0, allowOffscreen: true),
        );
        game.update(1 / 120);
        expect(enemy.hp, 20);
        final grenade = Projectile(
          x: 600,
          y: -40,
          vx: 0,
          vy: -20,
          grenade: true,
        );
        final hostile = Projectile(x: 650, y: 100, vx: 0, vy: 0, hostile: true);
        game.projectiles.addAll([grenade, hostile]);
        game.update(1 / 120);
        expect(game.projectiles, containsAll([grenade, hostile]));
        expect(grenade.vy, greaterThan(-20));
      },
    );

    test('walking with held pistol cannot clear unseen dormant encounters', () {
      final game = GameState();
      game.pickups.clear();
      final far = game.enemies.last;
      game.input.press(Command.fire);
      game.input.press(Command.right);
      game.player.invulnerable = 100;
      advance(game, 8);
      expect(far.lifecycle, EnemyLifecycle.dormant);
      expect(far.hp, GameConfig.turretHealth);
      expect(game.player.weapon, WeaponType.sidearm);
      expect(game.player.ammo, 0);
      expect(
        game.projectiles
            .where((p) => !p.hostile && !p.grenade)
            .every((p) => p.x < game.cameraX + GameConfig.viewportWidth + 16),
        isTrue,
      );
    });

    test(
      'held pistol cadence is controlled and rapid remains ammo-limited',
      () {
        final game = emptyGame();
        var shots = 0;
        game.audio.onEvent = (event) {
          if (event == AudioEvent.shot) shots++;
        };
        game.input.press(Command.fire);
        advance(game, 1);
        expect(shots, 3);
        game.input.release(Command.fire);
        advance(game, 0.5);
        expect(shots, 3);
        game.player.weapon = WeaponType.rapid;
        game.player.ammo = 3;
        game.input.press(Command.fire);
        advance(game, 0.2);
        expect(game.player.ammo, 0);
        expect(game.player.weapon, WeaponType.sidearm);
        expect(shots, 6);
      },
    );

    test('camera mirrors smooth lookahead with world bounds and boss lock', () {
      final game = emptyGame();
      game.player.x = 2000;
      game.cameraX = 1700;
      game.update(1 / 120);
      expect(game.cameraX, greaterThan(1700));
      expect(game.cameraX, lessThan(2009 - 160));
      advance(game, 2);
      expect(game.player.centerX - game.cameraX, closeTo(160, 0.1));
      final before = game.cameraX;
      game.player.facing = -1;
      game.update(1 / 120);
      expect(game.cameraX, lessThan(before));
      expect(game.cameraX, greaterThan(2009 - 320));
      advance(game, 2);
      expect(game.player.centerX - game.cameraX, closeTo(320, 0.1));
      game.player.x = 0;
      advance(game, 2);
      expect(game.cameraX, closeTo(0, 0.01));
      game.player.x = GameConfig.worldWidth - game.player.width;
      advance(game, 2);
      expect(game.cameraX, lessThanOrEqualTo(GameConfig.worldWidth - 480));
      expect(game.cameraX, greaterThanOrEqualTo(GameConfig.bossArenaStart));
      final custom = GameState(cameraFacingFraction: 0.4);
      custom.player.x = 2000;
      advance(custom, 2);
      expect(custom.player.centerX - custom.cameraX, closeTo(192, 0.1));
    });

    test(
      'inspection is opt-in and contains state, type, trigger, seed, exclusions',
      () {
        expect(GameState().encounterInspection, isEmpty);
        final game = GameState(inspectEncounters: true);
        final line = game.encounterInspection.first;
        expect(line, contains('dormant'));
        expect(line, contains('screenEdge'));
        expect(line, contains('forwardEdge'));
        expect(line, contains('seed=7319'));
        expect(line, contains('excluded='));
      },
    );
  });
}
