import '../config/game_config.dart';

enum WeaponType { sidearm, rapid, launcher }

enum EnemyType { infantry, shield, turret }

enum EnemyMode { patrol, alert, attack, hurt, defeated }

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
  Enemy({required double x, required this.kind, double? y})
    : hp = switch (kind) {
        EnemyType.infantry => GameConfig.infantryHealth,
        EnemyType.shield => GameConfig.shieldHealth,
        EnemyType.turret => GameConfig.turretHealth,
      },
      originX = x,
      super(x, y ?? GameConfig.groundY - 28, 22, 28);
  final EnemyType kind;
  final double originX;
  int hp;
  EnemyMode mode = EnemyMode.patrol;
  int facing = -1;
  double timer = 0, contactCooldown = 0;
  bool get alive => hp > 0;
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
    double width = 6,
    double height = 3,
  }) : super(x, y, width, height);
  double vx, vy, life;
  final bool hostile, explosive, grenade, shockwave;
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
