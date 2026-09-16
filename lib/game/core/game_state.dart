import 'dart:math' as math;

import '../config/game_config.dart';
import 'audio_events.dart';
import 'entities.dart';
import 'game_input.dart';

export 'audio_events.dart';
export 'entities.dart';
export 'game_input.dart';

enum MissionStatus { playing, paused, gameOver, victory }

/// Deterministic mission rules. Rendering, device input, and sound stay outside.
class GameState {
  GameState({GameInput? input, AudioBus? audio})
    : input = input ?? GameInput(),
      audio = audio ?? AudioBus() {
    restart();
  }

  final GameInput input;
  final AudioBus audio;
  MissionStatus status = MissionStatus.playing;
  late PlayerState player;
  final List<Enemy> enemies = [];
  final List<Projectile> projectiles = [];
  final List<Pickup> pickups = [];
  final List<Prisoner> prisoners = [];
  final List<Prop> props = [];
  final List<Platform> platforms = [];
  final List<Effect> effects = [];
  late Vehicle vehicle;
  late Boss boss;
  double elapsed = 0, cameraX = 0, shake = 0;
  int score = 0, rescued = 0;
  String callout = '';
  double calloutTime = 0;
  bool checkpointReached = false;
  _Checkpoint? _checkpoint;
  double _grenadeCooldown = 0;

  void restart() {
    input.clear();
    status = MissionStatus.playing;
    player = PlayerState();
    vehicle = Vehicle();
    boss = Boss();
    elapsed = cameraX = shake = _grenadeCooldown = 0;
    score = rescued = 0;
    checkpointReached = false;
    _checkpoint = null;
    projectiles.clear();
    effects.clear();
    enemies.clear();
    pickups.clear();
    prisoners.clear();
    props.clear();
    platforms.clear();
    for (var i = 0; i < GameConfig.encounterCount; i++) {
      final x = 420.0 + i * GameConfig.encounterSpacing;
      enemies.add(Enemy(x: x, kind: EnemyType.values[i % 3]));
      if (i % 3 == 1) {
        platforms.add(Platform(x - 100, GameConfig.groundY - 56, 90));
      }
      if (i % 4 == 0) props.add(Prop(x: x - 48));
    }
    for (final x in [970.0, 2190.0, 3710.0, 5230.0, 6910.0, 8220.0]) {
      prisoners.add(Prisoner(x: x));
    }
    for (var i = 0; i < 12; i++) {
      pickups.add(Pickup(x: 290.0 + i * 720, kind: PickupType.values[i % 4]));
    }
    _announce('IRON HARBOR • Rescue the captives. Stop the Iron Warden.', 6);
  }

  void pause() {
    if (status != MissionStatus.playing) return;
    status = MissionStatus.paused;
    input.clear();
  }

  void resume() {
    if (status == MissionStatus.paused) {
      input.clear();
      status = MissionStatus.playing;
    }
  }

  void retryCheckpoint() {
    final saved = _checkpoint;
    if (saved == null) {
      restart();
      return;
    }
    restart();
    _checkpoint = saved;
    checkpointReached = true;
    player.x = saved.x;
    player.health = saved.health;
    player.weapon = saved.weapon;
    player.ammo = saved.ammo;
    player.grenades = saved.grenades;
    player.invulnerable = 2;
    score = saved.score;
    rescued = saved.rescued;
    elapsed = saved.elapsed;
    for (var i = 0; i < enemies.length; i++) {
      enemies[i].hp = saved.enemyHp[i];
      enemies[i].x = saved.enemyX[i];
      if (!enemies[i].alive) enemies[i].mode = EnemyMode.defeated;
    }
    for (var i = 0; i < pickups.length; i++) {
      pickups[i].collected = saved.pickups[i];
    }
    for (var i = 0; i < prisoners.length; i++) {
      prisoners[i].rescued = saved.prisoners[i];
      prisoners[i].restraints = saved.restraints[i];
    }
    for (var i = 0; i < props.length; i++) {
      props[i].hp = saved.props[i];
    }
    vehicle.x = saved.vehicleX;
    vehicle.hp = saved.vehicleHp;
    cameraX = (player.x - 150).clamp(
      0.0,
      GameConfig.worldWidth - GameConfig.viewportWidth,
    );
    _announce('CHECKPOINT RESTORED • Back in the fight!', 3);
  }

  void update(double dt) {
    if (status != MissionStatus.playing || !dt.isFinite || dt <= 0) return;
    var remaining = math.min(dt, GameConfig.maxFrameTime);
    while (remaining > 0.000001 && status == MissionStatus.playing) {
      final step = math.min(remaining, GameConfig.simulationStep);
      _step(step);
      remaining -= step;
    }
    input.clearEdges();
  }

  void _step(double dt) {
    elapsed += dt;
    player.invulnerable = math.max(0, player.invulnerable - dt);
    player.fireCooldown = math.max(0, player.fireCooldown - dt);
    _grenadeCooldown = math.max(0, _grenadeCooldown - dt);
    calloutTime = math.max(0, calloutTime - dt);
    shake = math.max(0, shake - dt * 15);
    for (final effect in effects) {
      effect.time -= dt;
    }
    effects.removeWhere((e) => e.time <= 0);
    _movePlayer(dt);
    if (input.consume(Command.interact)) _interact();
    if (input.held(Command.fire) && player.fireCooldown <= 0) _fire();
    if (input.consume(Command.grenade)) _throwGrenade();
    _updateEnemies(dt);
    _updateBoss(dt);
    _updateProjectiles(dt);
    if (status != MissionStatus.playing) return;
    _collectPickups();
    for (final prisoner in prisoners) {
      if (prisoner.rescued) prisoner.rescueTime += dt;
    }
    _checkMilestones(dt);
    final target = (player.centerX - GameConfig.viewportWidth * 0.38).clamp(
      boss.active ? GameConfig.bossArenaStart : 0.0,
      GameConfig.worldWidth - GameConfig.viewportWidth,
    );
    cameraX +=
        (target - cameraX) * math.min(1, dt * GameConfig.cameraLerpSpeed);
    cameraX = cameraX.clamp(
      boss.active ? GameConfig.bossArenaStart : 0.0,
      GameConfig.worldWidth - GameConfig.viewportWidth,
    );
  }

  void _movePlayer(double dt) {
    final direction =
        (input.held(Command.right) ? 1 : 0) -
        (input.held(Command.left) ? 1 : 0);
    if (direction != 0) player.facing = direction;
    final oldBottom = player.y + player.height;
    player.crouching =
        input.held(Command.down) && player.grounded && !player.inVehicle;
    player.height =
        player.crouching ? GameConfig.crouchHeight : GameConfig.playerHeight;
    player.y = oldBottom - player.height;
    player.vx =
        direction *
        (player.inVehicle
            ? GameConfig.vehicleSpeed
            : player.crouching
            ? GameConfig.crouchSpeed
            : GameConfig.playerSpeed);
    if (input.consume(Command.jump) && player.grounded && !player.inVehicle) {
      player.vy = GameConfig.jumpForce;
      player.grounded = false;
      audio.emit(AudioEvent.jump);
    }
    player.x = (player.x + player.vx * dt).clamp(
      boss.active ? GameConfig.bossArenaStart + 10 : 0.0,
      GameConfig.worldWidth - player.width,
    );
    if (player.inVehicle) {
      vehicle.x = (player.x - 23).clamp(
        boss.active ? GameConfig.bossArenaStart : 0.0,
        GameConfig.worldWidth - vehicle.width,
      );
      player.x = vehicle.x + 23;
      player.y = vehicle.y - 8;
      player.vy = 0;
      return;
    }
    final previousBottom = player.y + player.height;
    player.vy = math.min(
      GameConfig.maxFallSpeed,
      player.vy + GameConfig.gravity * dt,
    );
    player.y += player.vy * dt;
    player.grounded = false;
    var floor = GameConfig.groundY;
    if (player.vy >= 0) {
      for (final platform in platforms) {
        if (player.x + player.width > platform.x &&
            player.x < platform.x + platform.width &&
            previousBottom <= platform.y + 0.01 &&
            player.y + player.height >= platform.y) {
          floor = math.min(floor, platform.y);
        }
      }
      if (player.y + player.height >= floor) {
        player.y = floor - player.height;
        player.vy = 0;
        player.grounded = true;
      }
    }
  }

  void _interact() {
    for (final prisoner in prisoners) {
      if (!prisoner.rescued &&
          (prisoner.centerX - player.centerX).abs() < 44 &&
          (prisoner.centerY - player.centerY).abs() < 42) {
        _rescue(prisoner);
        return;
      }
    }
    if (player.inVehicle) {
      _exitVehicle();
    } else if (vehicle.alive &&
        (vehicle.centerX - player.centerX).abs() < 66 &&
        (vehicle.centerY - player.centerY).abs() < 50) {
      player.inVehicle = vehicle.occupied = true;
      player.x = vehicle.x + 23;
      player.crouching = false;
      player.height = GameConfig.playerHeight;
      audio.emit(AudioEvent.vehicle);
      _announce('BREAKER APC • Armored cannon online. E to exit.', 4);
    }
  }

  void _exitVehicle() {
    player.inVehicle = vehicle.occupied = false;
    player.x = (vehicle.x - player.width - 4).clamp(
      boss.active ? GameConfig.bossArenaStart + 10 : 0.0,
      GameConfig.worldWidth - player.width,
    );
    player.y = GameConfig.groundY - GameConfig.playerHeight;
    player.height = GameConfig.playerHeight;
    player.vy = 0;
    player.grounded = true;
    player.invulnerable = GameConfig.invulnerability;
    audio.emit(AudioEvent.vehicle);
  }

  void _fire() {
    if (!player.inVehicle && !input.held(Command.up)) {
      for (final enemy in enemies) {
        final dx = enemy.centerX - player.centerX;
        if (enemy.alive &&
            dx * player.facing >= -5 &&
            dx.abs() < GameConfig.meleeRange &&
            (enemy.centerY - player.centerY).abs() < 28) {
          _hitEnemy(enemy, GameConfig.meleeDamage, bypassShield: true);
          player.fireCooldown = GameConfig.meleeCooldown;
          effects.add(Effect(enemy.centerX, enemy.centerY, 'melee'));
          audio.emit(AudioEvent.melee);
          return;
        }
      }
    }
    final cannon = player.inVehicle;
    final weapon = cannon ? WeaponType.launcher : player.weapon;
    final up = input.held(Command.up);
    final explosive = weapon == WeaponType.launcher;
    final x =
        cannon
            ? vehicle.centerX + player.facing * 34
            : player.centerX + (up ? 0 : player.facing * 13);
    final y = cannon ? vehicle.y + 9 : player.y + (up ? 0 : 10);
    projectiles.add(
      Projectile(
        x: x,
        y: y,
        vx: up ? 0 : player.facing * GameConfig.bulletSpeed,
        vy: up ? -GameConfig.bulletSpeed : 0,
        explosive: explosive,
        damage:
            cannon ? GameConfig.vehicleBulletDamage : GameConfig.bulletDamage,
      ),
    );
    player.fireCooldown =
        cannon
            ? GameConfig.vehicleFireCooldown
            : switch (weapon) {
              WeaponType.sidearm => GameConfig.sidearmCooldown,
              WeaponType.rapid => GameConfig.rapidCooldown,
              WeaponType.launcher => GameConfig.launcherCooldown,
            };
    if (!cannon && weapon != WeaponType.sidearm && --player.ammo <= 0) {
      player.ammo = 0;
      player.weapon = WeaponType.sidearm;
      _announce('Ammo depleted • SIDEARM ready', 2);
    }
    effects.add(Effect(x, y, 'muzzle', 0.09));
    audio.emit(AudioEvent.shot);
  }

  void _throwGrenade() {
    if (player.grenades <= 0 || _grenadeCooldown > 0) return;
    player.grenades--;
    _grenadeCooldown = GameConfig.grenadeCooldown;
    projectiles.add(
      Projectile(
        x: player.centerX,
        y: player.y,
        vx: player.facing * GameConfig.grenadeSpeed,
        vy: GameConfig.grenadeLaunchSpeed,
        grenade: true,
        explosive: true,
        life: GameConfig.grenadeFuse,
        width: 6,
        height: 6,
      ),
    );
    audio.emit(AudioEvent.grenade);
  }

  void _updateEnemies(double dt) {
    for (final enemy in enemies) {
      if (!enemy.alive) continue;
      final dx = player.centerX - enemy.centerX;
      if (dx.abs() > GameConfig.viewportWidth + 80) continue;
      enemy.timer -= dt;
      enemy.contactCooldown -= dt;
      if (enemy.bounds.overlaps(player.bounds) && enemy.contactCooldown <= 0) {
        damagePlayer(GameConfig.enemyDamage);
        enemy.contactCooldown = 1;
      }
      switch (enemy.mode) {
        case EnemyMode.patrol:
          if (enemy.kind != EnemyType.turret) {
            enemy.x += enemy.facing * GameConfig.enemySpeed * dt;
            if ((enemy.x - enemy.originX).abs() > 45) enemy.facing *= -1;
          }
          if (dx.abs() < GameConfig.enemyAwareness) {
            enemy.facing = dx < 0 ? -1 : 1;
            enemy.mode = EnemyMode.alert;
            enemy.timer =
                enemy.kind == EnemyType.turret
                    ? GameConfig.turretTelegraph
                    : GameConfig.enemyTelegraph;
          }
        case EnemyMode.alert:
          if (enemy.timer <= 0) {
            enemy.mode = EnemyMode.attack;
            enemy.timer = GameConfig.enemyAttackTime;
            _enemyShoot(enemy);
          }
        case EnemyMode.attack:
          if (enemy.timer <= 0) {
            enemy.mode = EnemyMode.patrol;
            // The next patrol step visibly telegraphs the following attack.
          }
        case EnemyMode.hurt:
          if (enemy.timer <= 0) enemy.mode = EnemyMode.patrol;
        case EnemyMode.defeated:
          break;
      }
    }
  }

  void _enemyShoot(Enemy enemy) {
    final count = enemy.kind == EnemyType.turret ? 3 : 1;
    for (var i = 0; i < count; i++) {
      projectiles.add(
        Projectile(
          x: enemy.centerX + enemy.facing * 14,
          y: enemy.y + 7,
          vx: enemy.facing * GameConfig.hostileBulletSpeed,
          vy: count == 3 ? (i - 1) * 26.0 : 0,
          hostile: true,
          damage: GameConfig.enemyDamage,
          life: 3.4,
        ),
      );
    }
    effects.add(Effect(enemy.centerX, enemy.y + 7, 'enemyMuzzle', 0.15));
  }

  void _hitEnemy(Enemy enemy, int damage, {bool bypassShield = false}) {
    if (!enemy.alive) return;
    if (enemy.kind == EnemyType.shield &&
        !bypassShield &&
        enemy.mode != EnemyMode.attack &&
        (player.centerX - enemy.centerX) * enemy.facing > 0) {
      effects.add(Effect(enemy.centerX, enemy.centerY, 'shield'));
      return;
    }
    enemy.hp = math.max(0, enemy.hp - damage);
    enemy.mode = enemy.alive ? EnemyMode.hurt : EnemyMode.defeated;
    enemy.timer = GameConfig.enemyHurtTime;
    effects.add(Effect(enemy.centerX, enemy.centerY, 'hit'));
    if (!enemy.alive) {
      score += GameConfig.enemyScore;
      effects.add(Effect(enemy.centerX, enemy.centerY, 'defeat', 0.5));
    }
  }

  void _updateProjectiles(double dt) {
    final expired = <Projectile>{};
    // Explosions can chain through props but do not mutate this collection.
    for (final shot in projectiles) {
      shot.life -= dt;
      if (shot.grenade) shot.vy += GameConfig.gravity * dt * 0.65;
      shot.x += shot.vx * dt;
      shot.y += shot.vy * dt;
      if (shot.grenade && shot.y + shot.height >= GameConfig.groundY) {
        shot.y = GameConfig.groundY - shot.height;
        shot.vy = -shot.vy.abs() * 0.35;
        shot.vx *= 0.65;
      }
      var hit = false;
      if (shot.hostile) {
        final target = player.inVehicle ? vehicle.bounds : player.bounds;
        if (shot.bounds.overlaps(target)) {
          if (!shot.explosive) damagePlayer(shot.damage);
          hit = true;
        }
      } else {
        for (final enemy in enemies) {
          if (enemy.alive && shot.bounds.overlaps(enemy.bounds)) {
            if (!shot.explosive) _hitEnemy(enemy, shot.damage);
            hit = true;
            break;
          }
        }
        if (!hit &&
            boss.active &&
            boss.alive &&
            shot.bounds.overlaps(boss.bounds)) {
          if (!shot.explosive) _hitBoss(shot.damage);
          hit = true;
        }
        if (!hit) {
          for (final prisoner in prisoners) {
            if (!prisoner.rescued && shot.bounds.overlaps(prisoner.bounds)) {
              prisoner.restraints -= shot.damage;
              if (prisoner.restraints <= 0) _rescue(prisoner);
              hit = true;
              break;
            }
          }
        }
        if (!hit) {
          for (final prop in props) {
            if (prop.alive && shot.bounds.overlaps(prop.bounds)) {
              if (!shot.explosive) _hitProp(prop, shot.damage);
              hit = true;
              break;
            }
          }
        }
      }
      if (hit || shot.life <= 0) {
        if (shot.explosive) {
          _explode(shot.centerX, shot.centerY, hostile: shot.hostile);
        }
        expired.add(shot);
      } else if (shot.x < -100 ||
          shot.x > GameConfig.worldWidth + 100 ||
          shot.y < -180 ||
          shot.y > GameConfig.groundY + 100) {
        expired.add(shot);
      }
    }
    projectiles.removeWhere(expired.contains);
  }

  void _explode(double x, double y, {bool hostile = false}) {
    effects.add(Effect(x, y, 'explosion', 0.55));
    shake = 4;
    audio.emit(AudioEvent.explosion);
    bool near(Entity entity) {
      final nearestX = x.clamp(entity.x, entity.x + entity.width);
      final nearestY = y.clamp(entity.y, entity.y + entity.height);
      return math.pow(x - nearestX, 2) + math.pow(y - nearestY, 2) <
          GameConfig.explosionRadius * GameConfig.explosionRadius;
    }

    if (hostile) {
      if (near(player.inVehicle ? vehicle : player)) damagePlayer(22);
      return;
    }
    for (final enemy in enemies) {
      if (enemy.alive && near(enemy)) {
        _hitEnemy(enemy, GameConfig.explosionDamage, bypassShield: true);
      }
    }
    if (boss.active && boss.alive && near(boss)) {
      _hitBoss(GameConfig.explosionDamage);
    }
    for (final prisoner in prisoners) {
      if (!prisoner.rescued && near(prisoner)) _rescue(prisoner);
    }
    for (final prop in props) {
      if (prop.alive && near(prop)) _hitProp(prop, GameConfig.explosionDamage);
    }
  }

  void _hitProp(Prop prop, int damage) {
    prop.hp = math.max(0, prop.hp - damage);
    if (!prop.alive && prop.explosive) _explode(prop.centerX, prop.centerY);
  }

  void damagePlayer(int amount) {
    if (status != MissionStatus.playing ||
        player.invulnerable > 0 ||
        amount <= 0) {
      return;
    }
    player.invulnerable = GameConfig.invulnerability;
    shake = 3;
    audio.emit(AudioEvent.hit);
    if (player.inVehicle && vehicle.alive) {
      vehicle.hp = math.max(0, vehicle.hp - amount);
      if (!vehicle.alive) {
        _exitVehicle();
        effects.add(Effect(vehicle.centerX, vehicle.centerY, 'explosion', 0.8));
        audio.emit(AudioEvent.explosion);
        _announce('APC destroyed • Keep moving!', 3);
      }
      return;
    }
    player.health = math.max(0, player.health - amount);
    if (player.health == 0) {
      status = MissionStatus.gameOver;
      input.clear();
      audio.emit(AudioEvent.gameOver);
      _announce('MISSION FAILED', 99);
    }
  }

  void _collectPickups() {
    for (final pickup in pickups) {
      if (pickup.collected ||
          !pickup.bounds.overlaps(
            player.inVehicle ? vehicle.bounds : player.bounds,
          )) {
        continue;
      }
      pickup.collected = true;
      switch (pickup.kind) {
        case PickupType.rapid:
          player.weapon = WeaponType.rapid;
          player.ammo = GameConfig.rapidAmmo;
          _announce('RAPID FIRE • ${player.ammo} rounds', 2);
        case PickupType.launcher:
          player.weapon = WeaponType.launcher;
          player.ammo = GameConfig.launcherAmmo;
          _announce('BLAST LAUNCHER • ${player.ammo} rounds', 2);
        case PickupType.health:
          player.health = math.min(
            GameConfig.maxHealth,
            player.health + GameConfig.medkitHealth,
          );
          _announce('FIELD MEDKIT • Health restored', 2);
        case PickupType.grenades:
          player.grenades = math.min(
            GameConfig.maxGrenades,
            player.grenades + GameConfig.grenadePickupCount,
          );
          _announce('GRENADES +3', 2);
      }
      audio.emit(AudioEvent.pickup);
    }
  }

  void _rescue(Prisoner prisoner) {
    if (prisoner.rescued) return;
    prisoner.rescued = true;
    prisoner.restraints = 0;
    rescued++;
    score += GameConfig.rescueScore;
    player.health = math.min(
      GameConfig.maxHealth,
      player.health + GameConfig.rescueHealth,
    );
    player.grenades = math.min(GameConfig.maxGrenades, player.grenades + 1);
    audio.emit(AudioEvent.rescue);
    effects.add(Effect(prisoner.centerX, prisoner.y, 'rescue', 1.2));
    _announce('CAPTIVE FREED • +500 • Medkit & grenade', 3);
  }

  void _checkMilestones(double dt) {
    if (player.x >= GameConfig.preBossCheckpointX &&
        (_checkpoint?.x ?? 0) < GameConfig.preBossCheckpointX) {
      _saveCheckpoint(GameConfig.preBossCheckpointX, preBoss: true);
    } else if (!checkpointReached && player.x >= GameConfig.checkpointX) {
      _saveCheckpoint(GameConfig.checkpointX);
    }
    if (!boss.active && boss.alive && player.x >= GameConfig.bossArenaStart) {
      boss.active = true;
      boss.timer = GameConfig.bossOpeningTelegraph;
      _announce(
        'IRON WARDEN • Dodge the warning. Strike when the core opens!',
        5,
      );
      audio.emit(AudioEvent.boss);
    }
    if (boss.active && !boss.alive) {
      boss.defeatTime += dt;
      if (boss.defeatTime > GameConfig.bossVictoryDelay) {
        status = MissionStatus.victory;
        input.clear();
        _announce('IRON HARBOR LIBERATED', 99);
        audio.emit(AudioEvent.victory);
      }
    }
  }

  void _saveCheckpoint(double x, {bool preBoss = false}) {
    player.health = GameConfig.maxHealth;
    player.grenades = math.max(player.grenades, preBoss ? 5 : 3);
    if (preBoss) {
      player.weapon = WeaponType.rapid;
      player.ammo = GameConfig.rapidAmmo;
    }
    checkpointReached = true;
    _checkpoint = _Checkpoint(this, x);
    _announce(
      preBoss
          ? 'FINAL CHECKPOINT • Health, rapid ammo & grenades refilled'
          : 'CHECKPOINT • Health & grenades replenished',
      4,
    );
    audio.emit(AudioEvent.checkpoint);
  }

  void _updateBoss(double dt) {
    if (!boss.active || !boss.alive) return;
    if (boss.bounds.overlaps(
      player.inVehicle ? vehicle.bounds : player.bounds,
    )) {
      damagePlayer(18);
    }
    boss.phase = boss.hp <= boss.maxHp ~/ 2 ? 2 : 1;
    boss.timer -= dt;
    if (boss.telegraph) {
      if (boss.timer <= 0) {
        boss.telegraph = false;
        boss.attacking = true;
        boss.timer =
            boss.attack == 0
                ? GameConfig.bossBurstTime
                : GameConfig.bossAttackTime;
        boss.shotTimer = 0;
        if (boss.attack == 1) _bossBombs();
        if (boss.attack == 2) _bossWaves();
      }
    } else if (boss.attacking) {
      if (boss.attack == 0) {
        boss.shotTimer -= dt;
        if (boss.shotTimer <= 0) {
          boss.shotTimer =
              boss.phase == 2
                  ? GameConfig.bossPhaseTwoShotInterval
                  : GameConfig.bossShotInterval;
          projectiles.add(
            Projectile(
              x: boss.x - 8,
              y: GameConfig.groundY - 24,
              vx: -190,
              vy: 0,
              hostile: true,
              damage: 14,
              life: 4,
            ),
          );
        }
      }
      if (boss.timer <= 0) {
        boss.attacking = false;
        boss.vulnerable = true;
        boss.timer =
            boss.phase == 2
                ? GameConfig.bossPhaseTwoVulnerableTime
                : GameConfig.bossVulnerableTime;
      }
    } else if (boss.vulnerable && boss.timer <= 0) {
      boss.vulnerable = false;
      boss.telegraph = true;
      boss.attack = (boss.attack + 1) % 3;
      boss.timer =
          boss.phase == 2
              ? GameConfig.bossPhaseTwoTelegraph
              : GameConfig.bossTelegraph;
    }
  }

  void _bossBombs() {
    final count = boss.phase == 2 ? 5 : 3;
    for (var i = 0; i < count; i++) {
      final target = (player.centerX + (i - count ~/ 2) * 65).clamp(
        GameConfig.bossArenaStart + 30,
        GameConfig.worldWidth - 30,
      );
      projectiles.add(
        Projectile(
          x: boss.centerX,
          y: boss.y,
          vx: (target - boss.centerX) / 1.15,
          vy: -235,
          hostile: true,
          grenade: true,
          explosive: true,
          life: 1.3,
          width: 8,
          height: 8,
        ),
      );
      effects.add(Effect(target, GameConfig.groundY, 'warning', 1.3));
    }
  }

  void _bossWaves() {
    final count = boss.phase == 2 ? 2 : 1;
    for (var i = 0; i < count; i++) {
      projectiles.add(
        Projectile(
          x: boss.x + i * 100,
          y: GameConfig.groundY - 13,
          vx: -180,
          vy: 0,
          hostile: true,
          shockwave: true,
          width: 18,
          height: 13,
          damage: 18,
          life: 4,
        ),
      );
    }
    shake = 4;
  }

  void _hitBoss(int damage) {
    if (!boss.vulnerable || !boss.alive) {
      effects.add(Effect(boss.centerX, boss.centerY, 'shield'));
      return;
    }
    boss.hp = math.max(0, boss.hp - damage);
    effects.add(Effect(boss.centerX, boss.centerY, 'hit'));
    if (!boss.alive) {
      boss.vulnerable = boss.telegraph = boss.attacking = false;
      score += GameConfig.bossScore;
      // Clear hostile hazards before the victory animation, not its iterator.
      for (final projectile in projectiles) {
        if (projectile.hostile) projectile.x = -1000;
      }
      effects.add(Effect(boss.centerX, boss.centerY, 'explosion', 2));
      player.invulnerable = 3;
      shake = 8;
      audio.emit(AudioEvent.explosion);
    }
  }

  void _announce(String message, double duration) {
    callout = message;
    calloutTime = duration;
  }
}

class _Checkpoint {
  _Checkpoint(GameState game, this.x)
    : health = game.player.health,
      weapon = game.player.weapon,
      ammo = game.player.ammo,
      grenades = game.player.grenades,
      score = game.score,
      rescued = game.rescued,
      elapsed = game.elapsed,
      enemyHp = game.enemies.map((e) => e.hp).toList(),
      enemyX = game.enemies.map((e) => e.x).toList(),
      pickups = game.pickups.map((e) => e.collected).toList(),
      prisoners = game.prisoners.map((e) => e.rescued).toList(),
      restraints = game.prisoners.map((e) => e.restraints).toList(),
      props = game.props.map((e) => e.hp).toList(),
      vehicleX = game.vehicle.x,
      vehicleHp = game.vehicle.hp;
  final double x, elapsed, vehicleX;
  final int health, ammo, grenades, score, rescued, vehicleHp;
  final WeaponType weapon;
  final List<int> enemyHp, props, restraints;
  final List<double> enemyX;
  final List<bool> pickups, prisoners;
}
