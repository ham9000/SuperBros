import 'dart:math' as math;

import '../config/game_config.dart';
import 'enemy_spawn.dart';

export 'enemy_spawn.dart';

enum WeaponType { sidearm, rapid, launcher }

enum EnemyType { infantry, shield, turret }

enum EnemyMode { patrol, alert, attack, hurt, defeated }

enum EnemyStance { standing, lowering, prone }

enum PickupType { rapid, launcher, health, grenades }

class Bounds {
  const Bounds(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
  double get right => left + width;
  double get bottom => top + height;
  bool overlaps(Bounds other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;
}

class Entity {
  Entity(this.x, this.y, this.width, this.height);
  double x, y, width, height;
  double get w => width;
  double get h => height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  Bounds get bounds => Bounds(x, y, width, height);
}

class PlayerState extends Entity {
  PlayerState()
    : super(
        48,
        GameConfig.groundY - GameConfig.playerHeight,
        GameConfig.playerWidth,
        GameConfig.playerHeight,
      );
  double vx = 0, vy = 0, invulnerable = 0, fireCooldown = 0;
  int health = GameConfig.maxHealth;
  int facing = 1;
  bool grounded = true, crouching = false, inVehicle = false;
  WeaponType weapon = WeaponType.sidearm;
  int ammo = 0, grenades = GameConfig.startingGrenades;
}

class Enemy extends Entity {
  Enemy({
    required double x,
    required this.kind,
    double? y,
    this.id = '',
    this.spawn = const EnemySpawnDefinition(),
    this.entrance,
    int aiSeed = GameConfig.encounterSeed,
  }) : hp = switch (kind) {
         EnemyType.infantry => GameConfig.infantryHealth,
         EnemyType.shield => GameConfig.shieldHealth,
         EnemyType.turret => GameConfig.turretHealth,
       },
       originX = x,
       patrolX = x,
       super(x, y ?? GameConfig.groundY - 28, 22, 28) {
    randomState = (aiSeed + x.round() * 31) % 2147483646 + 1;
    startsProne =
        kind != EnemyType.turret &&
        (spawn.startsProne ??
            nextDecision() < GameConfig.enemyInitialProneChance);
  }
  final EnemyType kind;
  final String id;
  final EnemySpawnDefinition spawn;
  EntranceChoice? entrance;
  final double originX;
  double patrolX;
  int hp;
  EnemyMode mode = EnemyMode.patrol;
  int facing = -1;
  double timer = 0, contactCooldown = 0;
  late int randomState;
  late bool startsProne;
  EnemyStance stance = EnemyStance.standing;
  double loweringTime = 0, decisionTimer = GameConfig.enemyDecisionInterval;
  double grenadeCooldown = GameConfig.enemyGrenadeCooldown;
  bool throwingGrenade = false;
  double get muzzleX =>
      centerX + facing * (stance == EnemyStance.standing ? 14 : width / 2);
  double get muzzleY => y + (stance == EnemyStance.prone ? 5 : 7);

  // Explicit integer state is portable to the web and survives checkpoint copies.
  double nextDecision() {
    randomState = randomState * 48271 % 2147483647;
    return randomState / 2147483647;
  }

  void lowerToProne() {
    if (kind == EnemyType.turret || stance != EnemyStance.standing) return;
    stance = EnemyStance.lowering;
    loweringTime = 0;
    throwingGrenade = false;
  }

  void updateStance(double dt) {
    if (stance != EnemyStance.lowering) return;
    loweringTime += dt;
    final t = (loweringTime / GameConfig.enemyLoweringTime).clamp(0.0, 1.0);
    final bottom = y + height;
    width = 22 + (GameConfig.enemyProneWidth - 22) * t;
    height = 28 + (GameConfig.enemyProneHeight - 28) * t;
    y = bottom - height;
    if (t >= 1) {
      stance = EnemyStance.prone;
      mode = EnemyMode.patrol;
    }
  }

  bool get alive => hp > 0;
  EnemyLifecycle lifecycle = EnemyLifecycle.dormant;
  bool entranceSuspended = false;
  bool _damageable = false, _combatEnabled = false, _entranceBlocked = false;
  double entranceTime = 0, recovery = 0;
  double startX = 0, startY = 0, targetX = 0, targetY = 0;
  int entranceFacing = 1;
  bool get visible => alive && lifecycle != EnemyLifecycle.dormant;
  bool get damageable =>
      alive &&
      !entranceSuspended &&
      !_entranceBlocked &&
      _damageable &&
      (lifecycle == EnemyLifecycle.entering ||
          lifecycle == EnemyLifecycle.active);
  bool get combatEnabled =>
      alive &&
      lifecycle == EnemyLifecycle.active &&
      _combatEnabled &&
      recovery <= 0;
  EntranceType get entranceType => entrance?.type ?? EntranceType.screenEdge;
  double get motionProgress =>
      ((entranceTime - GameConfig.entranceWarning) / GameConfig.entranceMotion)
          .clamp(0.0, 1.0);
  bool get warningVisible => lifecycle == EnemyLifecycle.entering;
  bool get spriteVisible =>
      visible &&
      !entranceSuspended &&
      !_entranceBlocked &&
      (lifecycle != EnemyLifecycle.entering ||
          entranceType == EntranceType.screenEdge ||
          entranceType == EntranceType.background ||
          (entranceType == EntranceType.vehicle
              ? motionProgress >= 0.65
              : motionProgress > 0));
  double get transportX =>
      startX -
      16 +
      (targetX + 28 - (startX - 16)) * (motionProgress / 0.65).clamp(0.0, 1.0);
  double get entranceScale =>
      lifecycle == EnemyLifecycle.entering &&
              entranceType == EntranceType.background
          ? 0.35 + motionProgress * 0.65
          : 1;

  void enterDormantState() {
    if (lifecycle == EnemyLifecycle.defeated) return;
    lifecycle = EnemyLifecycle.dormant;
    entranceSuspended = false;
    _entranceBlocked = false;
    _damageable = _combatEnabled = false;
    entranceTime = 0;
  }

  void setDamageable(bool value) => _damageable = value;
  void setCombatEnabled(bool value) => _combatEnabled = value;

  bool shouldActivate(EnemySpawnContext context) {
    if (lifecycle != EnemyLifecycle.dormant ||
        !alive ||
        context.enteringCount >= GameConfig.maxConcurrentEntrances) {
      return false;
    }
    if (entranceType == EntranceType.rearAmbush &&
        context.forwardPressure &&
        !spawn.scripted) {
      return false;
    }
    final triggerX = spawn.triggerX ?? originX;
    // Even wave and prerequisite triggers must wait until their area is reached.
    if (triggerX < context.cameraX - 32 ||
        triggerX > context.cameraX + context.viewportWidth + 32) {
      return false;
    }
    return switch (spawn.trigger) {
      SpawnTrigger.forwardEdge =>
        (triggerX - context.forwardEdge) * context.facing <= 32,
      SpawnTrigger.playerCrossed =>
        (context.playerX - triggerX) * context.facing >= 0,
      SpawnTrigger.entranceComplete => context.completed.contains(
        spawn.prerequisite,
      ),
      SpawnTrigger.encounterWave => context.wave >= spawn.wave,
    };
  }

  /// Returns false if no readable, non-overlapping landing position is available.
  bool beginEntrance(EnemySpawnContext context) {
    if (!alive || lifecycle != EnemyLifecycle.dormant) return false;
    entranceFacing = context.facing;
    final marker = entrance?.marker;
    targetY = marker?.y ?? GameConfig.groundY - height;
    if (marker != null && entranceType != EntranceType.rearAmbush) {
      targetX = marker.x + spawn.landingOffset;
    } else {
      final direction =
          entranceType == EntranceType.rearAmbush
              ? -context.facing
              : context.facing;
      targetX =
          direction > 0
              ? context.cameraX + context.viewportWidth - 64
              : context.cameraX + 42;
      targetX -= direction * spawn.landingOffset;
    }
    if (!_safeTarget(context)) return false;
    startX = targetX;
    startY = targetY;
    switch (entranceType) {
      case EntranceType.screenEdge:
      case EntranceType.rearAmbush:
        final direction =
            entranceType == EntranceType.rearAmbush
                ? -context.facing
                : context.facing;
        startX =
            context.cameraX +
            (direction > 0 ? context.viewportWidth + 4 : -width - 4);
      case EntranceType.doorway:
        startX -= 20;
      case EntranceType.trench:
        startY += height;
      case EntranceType.dropFromAbove:
        startY = context.cameraY - height - 8;
      case EntranceType.background:
        startY -= 40;
      case EntranceType.vehicle:
        entranceFacing = targetX > context.playerX ? 1 : -1;
        startX =
            context.cameraX +
            (entranceFacing > 0 ? context.viewportWidth + 70 : -90);
    }
    x = startX;
    y = startY;
    lifecycle = EnemyLifecycle.entering;
    _entranceBlocked = false;
    entranceTime = 0;
    _damageable = spawn.entranceVulnerable;
    _combatEnabled = false;
    return true;
  }

  bool _safeTarget(EnemySpawnContext context) =>
      targetX >= context.cameraX + 24 &&
      targetX + width <= context.cameraX + context.viewportWidth - 24 &&
      targetX >= 0 &&
      targetX + width <= GameConfig.worldWidth &&
      (targetX + width / 2 - context.playerX).abs() >=
          GameConfig.entranceSafeGap;

  /// Keep an entrance readable if the camera moves quickly. Geometry entrances
  /// wait at their marker; edge arrivals follow the view, never teleport active.
  void updateEntrance(double dt, [EnemySpawnContext? context]) {
    if (lifecycle != EnemyLifecycle.entering || !alive) return;
    if (context != null && !_safeTarget(context)) {
      // Keep the warning, not a visible sprite where the player has moved.
      _entranceBlocked = true;
      entranceTime = math.min(entranceTime, GameConfig.entranceWarning);
      if (entrance?.marker == null) {
        final direction =
            entranceType == EntranceType.rearAmbush
                ? -entranceFacing
                : entranceFacing;
        targetX =
            context.cameraX +
            (direction > 0 ? context.viewportWidth - 64 : 42) -
            direction * spawn.landingOffset;
        startX =
            context.cameraX +
            (direction > 0 ? context.viewportWidth + 4 : -width - 4);
      }
      x = startX;
      y = startY;
      return;
    }
    _entranceBlocked = false;
    if (context != null &&
        entranceTime <= GameConfig.entranceWarning &&
        (entranceType == EntranceType.screenEdge ||
            entranceType == EntranceType.rearAmbush)) {
      final direction =
          entranceType == EntranceType.rearAmbush
              ? -entranceFacing
              : entranceFacing;
      // Camera motion must not reveal the staged sprite before it walks in.
      startX =
          context.cameraX +
          (direction > 0 ? context.viewportWidth + 4 : -width - 4);
    }
    entranceTime += dt;
    final t = motionProgress;
    final movement = entranceType == EntranceType.dropFromAbove ? t * t : t;
    x = startX + (targetX - startX) * movement;
    y = startY + (targetY - startY) * movement;
    if (entranceType == EntranceType.vehicle) {
      x = t < 0.65 ? transportX + 20 : targetX + 48 * (1 - (t - 0.65) / 0.35);
    }
    if (t >= 1) completeEntrance();
  }

  void completeEntrance() {
    if (lifecycle != EnemyLifecycle.entering || motionProgress < 1) return;
    x = targetX;
    y = targetY;
    activateCombat();
    recovery = GameConfig.entranceRecovery;
  }

  void activateCombat() {
    if (!alive) return;
    lifecycle = EnemyLifecycle.active;
    entranceSuspended = false;
    _entranceBlocked = false;
    _damageable = _combatEnabled = true;
    mode = EnemyMode.patrol;
    patrolX = x;
    timer = 0;
    throwingGrenade = false;
    if (startsProne && stance == EnemyStance.standing) {
      lowerToProne();
      updateStance(GameConfig.enemyLoweringTime);
    }
  }

  void defeat() {
    hp = 0;
    lifecycle = EnemyLifecycle.defeated;
    mode = EnemyMode.defeated;
    _damageable = _combatEnabled = false;
    throwingGrenade = false;
  }

  Enemy copy() =>
      Enemy(x: originX, kind: kind, id: id, spawn: spawn, entrance: entrance)
        ..x = x
        ..patrolX = patrolX
        ..y = y
        ..width = width
        ..height = height
        ..startsProne = startsProne
        ..randomState = randomState
        ..stance = stance
        ..loweringTime = loweringTime
        ..decisionTimer = decisionTimer
        ..grenadeCooldown = grenadeCooldown
        ..throwingGrenade = throwingGrenade
        ..hp = hp
        ..mode = mode
        ..facing = facing
        ..timer = timer
        ..contactCooldown = contactCooldown
        ..lifecycle = lifecycle
        ..entranceSuspended = entranceSuspended
        .._damageable = _damageable
        .._combatEnabled = _combatEnabled
        .._entranceBlocked = _entranceBlocked
        ..entranceTime = entranceTime
        ..recovery = recovery
        ..startX = startX
        ..startY = startY
        ..targetX = targetX
        ..targetY = targetY
        ..entranceFacing = entranceFacing;
}

class Projectile extends Entity {
  Projectile({
    required double x,
    required double y,
    required this.vx,
    required this.vy,
    this.hostile = false,
    this.explosive = false,
    this.grenade = false,
    this.life = 2.5,
    this.damage = GameConfig.bulletDamage,
    this.shockwave = false,
    this.allowOffscreen = false,
    this.detonateOnImpact = true,
    double width = 6,
    double height = 3,
  }) : super(x, y, width, height);
  double vx, vy, life;
  final bool hostile, explosive, grenade, shockwave, allowOffscreen;
  final bool detonateOnImpact;
  final int damage;
}

class Pickup extends Entity {
  Pickup({required double x, required this.kind, double? y})
    : super(x, y ?? GameConfig.groundY - 16, 16, 16);
  final PickupType kind;
  bool collected = false;
}

class Prisoner extends Entity {
  Prisoner({required double x}) : super(x, GameConfig.groundY - 27, 18, 27);
  bool rescued = false;
  double rescueTime = 0;
  int restraints = 20;
}

class Prop extends Entity {
  Prop({required double x, this.explosive = true})
    : super(x, GameConfig.groundY - 22, 18, 22);
  final bool explosive;
  int hp = 20;
  bool get alive => hp > 0;
}

class Platform extends Entity {
  Platform(super.x, super.y, super.width, [super.height = 10]);
}

class Vehicle extends Entity {
  Vehicle({double x = 4740}) : super(x, GameConfig.groundY - 35, 64, 35);
  int hp = GameConfig.vehicleHealth;
  bool occupied = false;
  bool get alive => hp > 0;
}

class Boss extends Entity {
  Boss() : super(GameConfig.worldWidth - 140, GameConfig.groundY - 72, 60, 72);
  int hp = GameConfig.bossHealth;
  final int maxHp = GameConfig.bossHealth;
  bool active = false, telegraph = true, vulnerable = false;
  int phase = 1, attack = 0;
  double timer = GameConfig.bossOpeningTelegraph, defeatTime = 0, shotTimer = 0;
  bool attacking = false;
  bool get alive => hp > 0;
}

class Effect {
  Effect(this.x, this.y, this.kind, [this.maxTime = 0.35]) : time = maxTime;
  double x, y, time;
  final double maxTime;
  final String kind;
}
