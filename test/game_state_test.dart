import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/config/game_config.dart';
import 'package:super_bros/game/core/game_state.dart';

void advance(GameState game, double seconds) {
  final frames = (seconds * 120).ceil();
  for (var i = 0; i < frames; i++) {
    game.update(1 / 120);
  }
}

void tap(GameState game, Command command) {
  game.input.press(command);
  game.update(1 / 120);
  game.input.release(command);
}

GameState emptyGame() {
  final game = GameState();
  game.enemies.clear();
  game.pickups.clear();
  game.props.clear();
  game.prisoners.clear();
  game.platforms.clear();
  return game;
}

Projectile bulletAt(
  Entity target, {
  bool explosive = false,
  bool hostile = false,
}) => Projectile(
  x: target.x + 1,
  y: target.y + 1,
  vx: 0,
  vy: 0,
  explosive: explosive,
  hostile: hostile,
);

void main() {
  group('input and lifecycle', () {
    test('edges occur once per press, while held controls persist', () {
      final input = GameInput();
      input.press(Command.jump);
      input.press(Command.jump);
      expect(input.held(Command.jump), isTrue);
      expect(input.consume(Command.jump), isTrue);
      expect(input.consume(Command.jump), isFalse);
      input.release(Command.jump);
      input.press(Command.jump);
      expect(input.consume(Command.jump), isTrue);
      input.clear();
      expect(input.held(Command.jump), isFalse);
    });

    test('mission contains every enemy, reward, captives and traversal', () {
      final game = GameState();
      expect(game.status, MissionStatus.playing);
      expect(game.player.health, GameConfig.maxHealth);
      expect(game.enemies.map((e) => e.kind).toSet(), EnemyType.values.toSet());
      expect(
        game.pickups.map((e) => e.kind).toSet(),
        PickupType.values.toSet(),
      );
      expect(game.prisoners.length, 6);
      expect(game.platforms, isNotEmpty);
      expect(game.boss.active, isFalse);
      expect(game.score, 0);
      expect(GameConfig.worldWidth / GameConfig.playerSpeed, greaterThan(100));
    });

    test('pause freezes time and clears controls; resume is clean', () {
      final game = GameState();
      game.input.press(Command.right);
      game.pause();
      game.update(1);
      expect(game.elapsed, 0);
      expect(game.input.held(Command.right), isFalse);
      game.input.press(Command.fire);
      game.resume();
      game.update(1 / 60);
      expect(game.elapsed, greaterThan(0));
      expect(game.projectiles, isEmpty);
    });

    test('invalid delta is ignored and long frames are clamped', () {
      final game = emptyGame();
      for (final dt in [0.0, -1.0, double.nan, double.infinity]) {
        game.update(dt);
      }
      expect(game.elapsed, 0);
      game.input.press(Command.right);
      game.update(100);
      expect(game.elapsed, closeTo(GameConfig.maxFrameTime, 0.0001));
      expect(game.player.x, closeTo(48 + GameConfig.playerSpeed * 0.1, 0.01));
    });

    test('substeps make movement independent of rendering rate', () {
      final a = emptyGame()..input.press(Command.right);
      final b = emptyGame()..input.press(Command.right);
      for (var i = 0; i < 30; i++) {
        a.update(1 / 30);
      }
      for (var i = 0; i < 120; i++) {
        b.update(1 / 120);
      }
      expect(a.player.x, closeTo(b.player.x, 0.001));
    });
  });

  group('movement and combat', () {
    test('moving sets facing and respects world bounds', () {
      final game = emptyGame();
      game.input.press(Command.left);
      advance(game, 1);
      expect(game.player.x, 0);
      expect(game.player.facing, -1);
      game.input.release(Command.left);
      game.input.press(Command.right);
      advance(game, 1);
      expect(game.player.x, closeTo(GameConfig.playerSpeed, 0.01));
    });

    test('jump requires a new press and lands on continuous ground', () {
      final game = emptyGame();
      game.input.press(Command.jump);
      advance(game, 0.2);
      expect(game.player.y, lessThan(GameConfig.groundY - 30));
      expect(game.player.grounded, isFalse);
      advance(game, 1.5);
      expect(game.player.grounded, isTrue);
      expect(game.player.y + game.player.height, GameConfig.groundY);
      expect(game.player.vy, 0);
    });

    test('one-way raised platforms can be jumped through and landed on', () {
      final game = emptyGame();
      game.platforms.add(Platform(20, 163, 120));
      tap(game, Command.jump);
      advance(game, 0.6);
      expect(game.player.grounded, isTrue);
      expect(game.player.y + game.player.height, 163);
    });

    test('crouching shrinks the hitbox and dodges standing-height fire', () {
      final game = emptyGame();
      game.input.press(Command.down);
      game.update(1 / 60);
      expect(game.player.height, GameConfig.crouchHeight);
      expect(game.player.y + game.player.height, GameConfig.groundY);
      game.projectiles.add(
        Projectile(x: game.player.x, y: 195, vx: 0, vy: 0, hostile: true),
      );
      game.update(1 / 60);
      expect(game.player.health, GameConfig.maxHealth);
      game.input.release(Command.down);
      game.update(1 / 60);
      expect(game.player.height, GameConfig.playerHeight);
      expect(game.player.health, lessThan(GameConfig.maxHealth));
    });

    test('default gun is unlimited and aim-up produces vertical shots', () {
      final game = emptyGame();
      game.input.press(Command.up);
      game.input.press(Command.fire);
      game.update(1 / 60);
      final shot = game.projectiles.single;
      expect(shot.vx, 0);
      expect(shot.vy, lessThan(0));
      advance(game, 2);
      expect(game.player.weapon, WeaponType.sidearm);
      expect(game.player.ammo, 0);
    });

    test('held sidearm fires immediately with bounded shot intervals', () {
      for (final frameTime in [1 / 30, 1 / 60, 1 / 120]) {
        final game = emptyGame();
        final shots = <double>[];
        game.audio.onEvent = (event) {
          if (event == AudioEvent.shot) shots.add(game.elapsed);
        };
        game.input.press(Command.fire);
        game.update(frameTime);
        expect(shots, hasLength(1));
        expect(shots.single, lessThanOrEqualTo(GameConfig.simulationStep));
        for (var i = 1; i < (2 / frameTime).round(); i++) {
          game.update(frameTime);
        }
        expect(shots, hasLength(6));
        for (var i = 1; i < shots.length; i++) {
          expect(shots[i] - shots[i - 1], greaterThanOrEqualTo(0.36));
          expect(
            shots[i] - shots[i - 1],
            lessThanOrEqualTo(0.36 + GameConfig.simulationStep),
          );
        }
        expect(game.player.weapon, WeaponType.sidearm);
        expect(game.player.ammo, 0);
      }
    });

    test('releasing and repressing fire cannot bypass sidearm cooldown', () {
      final game = emptyGame();
      var shots = 0;
      game.audio.onEvent = (event) {
        if (event == AudioEvent.shot) shots++;
      };
      tap(game, Command.fire);
      expect(shots, 1);
      for (var i = 0; i < 40; i++) {
        tap(game, Command.fire);
      }
      expect(shots, 1);
      game.input.press(Command.fire);
      advance(game, 0.05);
      expect(shots, 2);
      game.input.release(Command.fire);
      advance(game, 0.5);
      expect(shots, 2);
      tap(game, Command.fire);
      expect(shots, 3);
    });

    test('held rapid fire spends finite ammo then resumes sidearm cadence', () {
      final game = emptyGame();
      final shots = <double>[];
      game.audio.onEvent = (event) {
        if (event == AudioEvent.shot) shots.add(game.elapsed);
      };
      game.player.weapon = WeaponType.rapid;
      game.player.ammo = GameConfig.rapidAmmo;
      expect(GameConfig.rapidAmmo, 90);
      game.input.press(Command.fire);
      while (game.player.ammo > 0 && game.elapsed < 10) {
        game.update(GameConfig.simulationStep);
      }
      expect(shots, hasLength(90));
      expect(game.player.ammo, 0);
      expect(game.player.weapon, WeaponType.sidearm);
      for (var i = 1; i < shots.length; i++) {
        expect(shots[i] - shots[i - 1], greaterThanOrEqualTo(0.09));
        expect(
          shots[i] - shots[i - 1],
          lessThanOrEqualTo(0.09 + GameConfig.simulationStep),
        );
      }
      advance(game, 1);
      expect(shots, hasLength(93));
      expect(shots[90] - shots[89], greaterThanOrEqualTo(0.09));
      for (var i = 91; i < shots.length; i++) {
        expect(shots[i] - shots[i - 1], greaterThanOrEqualTo(0.36));
        expect(
          shots[i] - shots[i - 1],
          lessThanOrEqualTo(0.36 + GameConfig.simulationStep),
        );
      }
      expect(game.player.ammo, 0);
    });

    test('rapid and launcher ammo deplete and fall back to sidearm', () {
      for (final weapon in [WeaponType.rapid, WeaponType.launcher]) {
        final game = emptyGame();
        game.player.weapon = weapon;
        game.player.ammo = 1;
        tap(game, Command.fire);
        expect(game.player.weapon, WeaponType.sidearm);
        expect(game.player.ammo, 0);
        expect(
          game.projectiles.single.explosive,
          weapon == WeaponType.launcher,
        );
      }
    });

    test('nearby enemies trigger melee without spending special ammo', () {
      final game = emptyGame();
      final enemy = Enemy(x: 78, kind: EnemyType.shield)..activateCombat();
      game.enemies.add(enemy);
      game.player.weapon = WeaponType.rapid;
      game.player.ammo = 5;
      tap(game, Command.fire);
      expect(enemy.hp, GameConfig.shieldHealth - GameConfig.meleeDamage);
      expect(game.player.ammo, 5);
      expect(game.projectiles.where((p) => !p.hostile), isEmpty);
    });

    test('grenades consume one per press, follow gravity, and explode', () {
      final game = emptyGame();
      final events = <AudioEvent>[];
      game.audio.onEvent = events.add;
      game.input.press(Command.grenade);
      game.update(1 / 60);
      final grenade = game.projectiles.single;
      final initialVy = grenade.vy;
      advance(game, 0.4);
      expect(grenade.vy, greaterThan(initialVy));
      expect(game.player.grenades, GameConfig.startingGrenades - 1);
      advance(game, 1.3);
      expect(game.projectiles, isEmpty);
      expect(events.where((e) => e == AudioEvent.explosion).length, 1);
      game.input.release(Command.grenade);
      game.player.grenades = 0;
      tap(game, Command.grenade);
      expect(game.projectiles, isEmpty);
    });

    test('enemy defeats award score once and explosions bypass shields', () {
      final game = emptyGame();
      final enemy = Enemy(x: 150, kind: EnemyType.shield)..activateCombat();
      game.enemies.add(enemy);
      game.projectiles.add(bulletAt(enemy, explosive: true));
      game.update(1 / 60);
      expect(enemy.hp, GameConfig.shieldHealth - GameConfig.explosionDamage);
      game.projectiles.add(bulletAt(enemy, explosive: true));
      game.update(1 / 60);
      expect(enemy.alive, isFalse);
      expect(enemy.mode, EnemyMode.defeated);
      expect(game.score, GameConfig.enemyScore);
      game.projectiles.add(bulletAt(enemy, explosive: true));
      advance(game, 0.1);
      expect(game.score, GameConfig.enemyScore);
    });

    test('shield blocks frontal bullets but opens during an attack', () {
      final game = emptyGame();
      final enemy = Enemy(x: 150, kind: EnemyType.shield)..activateCombat();
      game.enemies.add(enemy);
      game.projectiles.add(bulletAt(enemy));
      game.update(1 / 120);
      expect(enemy.hp, GameConfig.shieldHealth);
      enemy.mode = EnemyMode.attack;
      enemy.timer = 0.2;
      game.projectiles.add(bulletAt(enemy));
      game.update(1 / 120);
      expect(enemy.hp, GameConfig.shieldHealth - GameConfig.bulletDamage);
    });

    test('all enemy types telegraph before firing and recover from hurt', () {
      for (final kind in EnemyType.values) {
        final game = emptyGame();
        final enemy = Enemy(x: 200, kind: kind)..activateCombat();
        game.enemies.add(enemy);
        game.update(1 / 120);
        expect(enemy.mode, EnemyMode.alert);
        expect(game.projectiles, isEmpty);
        advance(game, 1.2);
        expect(game.projectiles.where((p) => p.hostile), isNotEmpty);
        enemy.mode = EnemyMode.hurt;
        enemy.timer = 0.1;
        advance(game, 0.2);
        expect(enemy.mode, isNot(EnemyMode.hurt));
      }
    });

    test('explosive props chain without awarding repeated enemy kills', () {
      final game = emptyGame();
      final first = Prop(x: 150);
      final second = Prop(x: 190);
      game.props.addAll([first, second]);
      final enemy = Enemy(x: 220, kind: EnemyType.infantry)..activateCombat();
      game.enemies.add(enemy);
      game.projectiles.addAll([bulletAt(first), bulletAt(first)]);
      game.update(1 / 120);
      expect(first.alive, isFalse);
      expect(second.alive, isFalse);
      expect(enemy.alive, isFalse);
      expect(game.score, GameConfig.enemyScore);
    });

    test(
      'fast projectiles cannot tunnel through enemies during a long frame',
      () {
        final game = emptyGame();
        final enemy = Enemy(x: 120, kind: EnemyType.infantry)..activateCombat();
        game.enemies.add(enemy);
        game.projectiles.add(
          Projectile(x: 105, y: 198, vx: GameConfig.bulletSpeed, vy: 0),
        );
        game.update(0.1);
        expect(enemy.hp, GameConfig.infantryHealth - GameConfig.bulletDamage);
      },
    );

    test('regular enemies now take more than a couple of sidearm shots', () {
      // Fixed pre-tuning HP values from the issue (not current GameConfig
      // values); kept as plain literals so a future rebalance can't make
      // this regression check drift along with GameConfig.
      const legacyBaselineHp = {
        EnemyType.infantry: 30,
        EnemyType.shield: 50,
        EnemyType.turret: 60,
      };
      for (final kind in EnemyType.values) {
        final game = emptyGame();
        // Keep the player out of aggro range so enemy AI (facing/mode
        // changes) cannot interfere with this pure durability check.
        game.player.x = 5000;
        final enemy = Enemy(x: 120, kind: kind);
        game.enemies.add(enemy);
        final startingHp = enemy.hp;
        final maxShots = (startingHp / GameConfig.bulletDamage).ceil() + 2;
        var shotsToDefeat = 0;
        while (enemy.alive && shotsToDefeat < maxShots) {
          game.projectiles.add(bulletAt(enemy));
          game.update(1 / 120);
          shotsToDefeat++;
        }
        expect(enemy.alive, isFalse);
        expect(shotsToDefeat, greaterThan(2));
        expect(startingHp, greaterThan(legacyBaselineHp[kind]!));
      }
    });

    test(
      'enemies stay alive with their hp and position when far off-screen and '
      'reengage once the player returns',
      () {
        final game = emptyGame();
        final enemy = Enemy(x: 400, kind: EnemyType.infantry);
        game.enemies.add(enemy);
        // Damage the enemy first so we can confirm the remaining hp survives.
        game.projectiles.add(bulletAt(enemy));
        game.update(1 / 120);
        final woundedHp = enemy.hp;
        expect(woundedHp, lessThan(GameConfig.infantryHealth));

        // Move the player far away, well outside the enemy-update window.
        game.player.x = enemy.x + GameConfig.viewportWidth + 500;
        advance(game, 2);

        expect(enemy.alive, isTrue);
        expect(enemy.mode, isNot(EnemyMode.defeated));
        expect(enemy.hp, woundedHp);
        expect(enemy.x, closeTo(400, 1));

        // Bring the player back within range but not overlapping, so a
        // fired shot survives long enough to observe.
        game.player.x = enemy.x - 60;
        advance(game, 1.5);
        expect(enemy.mode, isNot(EnemyMode.patrol));
        expect(game.player.health, lessThan(GameConfig.maxHealth));
      },
    );
  });

  group('rescues, rewards and vehicles', () {
    test(
      'interacting rescues once and grants score, health, and a grenade',
      () {
        final game = emptyGame();
        final prisoner = Prisoner(x: 70);
        game.prisoners.add(prisoner);
        game.player.health = 50;
        tap(game, Command.interact);
        expect(prisoner.rescued, isTrue);
        expect(game.rescued, 1);
        expect(game.score, GameConfig.rescueScore);
        expect(game.player.health, 70);
        expect(game.player.grenades, GameConfig.startingGrenades + 1);
        tap(game, Command.interact);
        expect(game.rescued, 1);
        expect(game.score, GameConfig.rescueScore);
      },
    );

    test('shooting restraints safely frees a captive', () {
      final game = emptyGame();
      final prisoner = Prisoner(x: 150);
      game.prisoners.add(prisoner);
      game.projectiles.addAll([bulletAt(prisoner), bulletAt(prisoner)]);
      game.update(1 / 120);
      expect(prisoner.rescued, isTrue);
      expect(game.rescued, 1);
    });

    test('each pickup applies once and health has a cap', () {
      for (final kind in PickupType.values) {
        final game = emptyGame();
        final pickup = Pickup(x: game.player.x, kind: kind);
        game.pickups.add(pickup);
        game.update(1 / 60);
        expect(pickup.collected, isTrue);
        switch (kind) {
          case PickupType.rapid:
            expect(game.player.weapon, WeaponType.rapid);
            expect(game.player.ammo, GameConfig.rapidAmmo);
          case PickupType.launcher:
            expect(game.player.weapon, WeaponType.launcher);
            expect(game.player.ammo, GameConfig.launcherAmmo);
          case PickupType.health:
            expect(game.player.health, GameConfig.maxHealth);
          case PickupType.grenades:
            expect(game.player.grenades, GameConfig.startingGrenades + 3);
        }
        final grenades = game.player.grenades;
        game.update(1 / 60);
        expect(game.player.grenades, grenades);
      }
    });

    test('vehicle can enter, drive, fire without ammo, and exit', () {
      final game = emptyGame();
      game.vehicle.x = 80;
      tap(game, Command.interact);
      expect(game.player.inVehicle, isTrue);
      expect(game.vehicle.occupied, isTrue);
      final x = game.vehicle.x;
      game.input.press(Command.right);
      advance(game, 0.5);
      expect(game.vehicle.x, greaterThan(x + 50));
      tap(game, Command.fire);
      expect(game.projectiles.single.explosive, isTrue);
      expect(game.player.ammo, 0);
      tap(game, Command.interact);
      expect(game.player.inVehicle, isFalse);
      expect(game.vehicle.occupied, isFalse);
    });

    test(
      'vehicle absorbs damage, ejects on destruction, cannot reenter wreck',
      () {
        final game = emptyGame();
        game.vehicle.x = 80;
        tap(game, Command.interact);
        game.damagePlayer(30);
        expect(game.vehicle.hp, GameConfig.vehicleHealth - 30);
        expect(game.player.health, GameConfig.maxHealth);
        game.player.invulnerable = 0;
        game.damagePlayer(GameConfig.vehicleHealth);
        expect(game.vehicle.alive, isFalse);
        expect(game.player.inVehicle, isFalse);
        expect(game.player.health, GameConfig.maxHealth);
        tap(game, Command.interact);
        expect(game.player.inVehicle, isFalse);
      },
    );
  });

  group('checkpoint and ending', () {
    test(
      'damage has invulnerability, death freezes, restart resets everything',
      () {
        final game = GameState();
        game.damagePlayer(25);
        game.damagePlayer(25);
        expect(game.player.health, 75);
        game.player.invulnerable = 0;
        game.damagePlayer(1000);
        expect(game.status, MissionStatus.gameOver);
        expect(game.player.health, 0);
        final time = game.elapsed;
        game.update(0.1);
        expect(game.elapsed, time);
        game.score = 500;
        game.restart();
        expect(game.status, MissionStatus.playing);
        expect(game.player.health, GameConfig.maxHealth);
        expect(game.score, 0);
        expect(game.checkpointReached, isFalse);
      },
    );

    test('retry without checkpoint starts a new mission', () {
      final game = GameState();
      game.player.x = 1000;
      game.damagePlayer(100);
      game.retryCheckpoint();
      expect(game.player.x, 48);
      expect(game.status, MissionStatus.playing);
    });

    test(
      'checkpoint restores score and world atomically, preventing reward farming',
      () {
        final game = GameState();
        game.enemies.first.hp = 0;
        game.enemies.first.mode = EnemyMode.defeated;
        game.pickups.first.collected = true;
        game.prisoners.first.rescued = true;
        game.prisoners.first.restraints = 0;
        game.score = 600;
        game.rescued = 1;
        game.player.x = GameConfig.checkpointX;
        game.player.health = 10;
        game.update(1 / 120);
        expect(game.checkpointReached, isTrue);
        expect(game.player.health, GameConfig.maxHealth);
        game.score = 900;
        game.rescued = 2;
        game.enemies[20].hp = 0;
        game.pickups[8].collected = true;
        game.prisoners[4].rescued = true;
        game.vehicle.hp = 0;
        game.damagePlayer(100);
        game.retryCheckpoint();
        expect(game.player.x, GameConfig.checkpointX);
        expect(game.score, 600);
        expect(game.rescued, 1);
        expect(game.enemies.first.alive, isFalse);
        expect(game.enemies[20].alive, isTrue);
        expect(game.pickups.first.collected, isTrue);
        expect(game.pickups[8].collected, isFalse);
        expect(game.prisoners.first.rescued, isTrue);
        expect(game.prisoners[4].rescued, isFalse);
        expect(game.vehicle.alive, isTrue);
        game.retryCheckpoint();
        expect(game.score, 600);
      },
    );

    test('preboss refill becomes the newest retry checkpoint', () {
      final game = GameState();
      game.player.x = GameConfig.preBossCheckpointX;
      game.player.health = 5;
      game.player.grenades = 0;
      game.update(1 / 120);
      expect(game.player.health, GameConfig.maxHealth);
      expect(game.player.ammo, GameConfig.rapidAmmo);
      expect(game.player.grenades, 5);
      game.player.invulnerable = 0;
      game.damagePlayer(100);
      game.retryCheckpoint();
      expect(game.player.x, GameConfig.preBossCheckpointX);
      expect(game.boss.active, isFalse);
      expect(game.boss.hp, GameConfig.bossHealth);
    });

    test('boss arena locks the camera and escape never grants victory', () {
      final game = GameState();
      game.player.x = GameConfig.bossArenaStart + 1;
      game.update(1 / 60);
      expect(game.boss.active, isTrue);
      expect(game.cameraX, greaterThanOrEqualTo(GameConfig.bossArenaStart));
      game.input.press(Command.left);
      advance(game, 0.3);
      expect(game.player.x, greaterThanOrEqualTo(GameConfig.bossArenaStart));
      game.player.x = GameConfig.worldWidth - game.player.width;
      game.update(1 / 60);
      expect(game.status, MissionStatus.playing);
      expect(
        game.cameraX,
        lessThanOrEqualTo(GameConfig.worldWidth - GameConfig.viewportWidth),
      );
    });

    test('boss rejects armored hits, has three attacks and phase two', () {
      final game = emptyGame();
      game.boss.active = true;
      game.cameraX = GameConfig.bossArenaStart;
      game.player.x = GameConfig.bossArenaStart + 60;
      game.projectiles.add(bulletAt(game.boss));
      game.update(1 / 120);
      expect(game.boss.hp, GameConfig.bossHealth);
      final seen = <int>{};
      final attacks = <Projectile>[];
      for (var i = 0; i < 1800; i++) {
        game.player.invulnerable = 10;
        game.update(1 / 120);
        seen.add(game.boss.attack);
        attacks.addAll(game.projectiles);
      }
      expect(seen, {0, 1, 2});
      expect(
        attacks.any((p) => p.hostile && !p.grenade && !p.shockwave),
        isTrue,
      );
      expect(attacks.any((p) => p.hostile && p.grenade), isTrue);
      expect(attacks.any((p) => p.shockwave), isTrue);
      game.boss.hp = game.boss.maxHp ~/ 2;
      game.update(1 / 120);
      expect(game.boss.phase, 2);
    });

    test(
      'boss vulnerable window allows damage; defeat alone unlocks victory',
      () {
        final game = emptyGame();
        game.boss.active = true;
        game.cameraX = GameConfig.bossArenaStart;
        game.boss.telegraph = false;
        game.boss.vulnerable = true;
        game.boss.timer = 1;
        game.boss.hp = 10;
        game.player.x = GameConfig.bossArenaStart + 60;
        game.projectiles.add(bulletAt(game.boss));
        game.update(1 / 120);
        expect(game.boss.hp, 0);
        expect(game.score, GameConfig.bossScore);
        expect(game.status, MissionStatus.playing);
        advance(game, 1.7);
        expect(game.status, MissionStatus.victory);
        final score = game.score;
        advance(game, 1);
        expect(game.score, score);
      },
    );

    test('ground shockwaves are avoided by jumping, not by crouching', () {
      final game = emptyGame();
      game.input.press(Command.jump);
      advance(game, 0.2);
      game.projectiles.add(
        Projectile(
          x: game.player.x,
          y: GameConfig.groundY - 13,
          vx: 0,
          vy: 0,
          hostile: true,
          shockwave: true,
          width: 18,
          height: 13,
        ),
      );
      game.update(1 / 120);
      expect(game.player.health, GameConfig.maxHealth);
      game.projectiles.clear();
      advance(game, 1);
      game.input.press(Command.down);
      game.update(1 / 120);
      game.projectiles.add(
        Projectile(
          x: game.player.x,
          y: GameConfig.groundY - 13,
          vx: 0,
          vy: 0,
          hostile: true,
          shockwave: true,
          width: 18,
          height: 13,
        ),
      );
      game.update(1 / 120);
      expect(game.player.health, lessThan(GameConfig.maxHealth));
    });

    test('audio hooks work without platform dependencies and honor mute', () {
      final events = <AudioEvent>[];
      final bus = AudioBus(onEvent: events.add);
      final game = GameState(audio: bus);
      tap(game, Command.jump);
      tap(game, Command.fire);
      game.damagePlayer(10);
      expect(
        events,
        containsAll([AudioEvent.jump, AudioEvent.shot, AudioEvent.hit]),
      );
      bus.muted = true;
      final count = events.length;
      bus.emit(AudioEvent.explosion);
      expect(events.length, count);
    });
  });
}
