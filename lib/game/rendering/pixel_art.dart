import 'dart:math' as math;
import 'dart:ui';

import '../config/game_config.dart';
import '../core/game_state.dart';

/// Stable art identifiers: a sprite atlas can replace these drawings later.
enum SpriteId {
  rook,
  infantry,
  shield,
  turret,
  engineer,
  vehicle,
  walker,
  barrel,
  crate,
  rapid,
  launcher,
  health,
  grenade,
}

/// Original, grid-aligned pixel artwork. No external images or typefaces.
abstract final class PixelArt {
  static const ink = Color(0xff101e2b);
  static const navy = Color(0xff193947);
  static const deepTeal = Color(0xff245760);
  static const teal = Color(0xff398783);
  static const mint = Color(0xff87d9b1);
  static const pale = Color(0xffd4efca);
  static const cream = Color(0xffffe1a6);
  static const gold = Color(0xffffbc62);
  static const orange = Color(0xfff17b42);
  static const red = Color(0xffca4945);
  static const rust = Color(0xff8d4748);
  static const steel = Color(0xff698e8c);
  static const white = Color(0xfffff5dc);
  static final Paint _paint = Paint()..isAntiAlias = false;

  static void _r(Canvas c, num x, num y, num w, num h, Color color) {
    if (w <= 0 || h <= 0) return;
    _paint.color = color;
    c.drawRect(
      Rect.fromLTWH(
        x.roundToDouble(),
        y.roundToDouble(),
        w.roundToDouble(),
        h.roundToDouble(),
      ),
      _paint,
    );
  }

  static void _line(
    Canvas c,
    int x,
    int y,
    int x2,
    int y2,
    Color color, [
    int thickness = 1,
  ]) {
    final dx = (x2 - x).abs();
    final dy = (y2 - y).abs();
    final steps = math.max(dx, dy);
    for (var i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      _r(c, x + (x2 - x) * t, y + (y2 - y) * t, thickness, thickness, color);
    }
  }

  static void _plate(
    Canvas c,
    num x,
    num y,
    num w,
    num h,
    Color fill, {
    Color edge = ink,
  }) {
    _r(c, x + 2, y, w - 4, h, edge);
    _r(c, x, y + 2, w, h - 4, edge);
    _r(c, x + 2, y + 2, w - 4, h - 4, fill);
  }

  static void _bolt(Canvas c, num x, num y, [Color color = steel]) {
    _r(c, x, y, 2, 2, ink);
    _r(c, x, y, 1, 1, color);
  }

  /// Draw a 64 x 72 portrait at [offset], with pixel size [scale].
  static void paintPortrait(
    Canvas canvas,
    Offset offset,
    double scale, {
    int variant = 0,
    bool locked = false,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final vest = locked ? deepTeal : (variant == 1 ? orange : teal);
    final hair = locked ? steel : (variant == 1 ? rust : cream);
    _r(canvas, 0, 0, 64, 72, navy);
    for (var y = 0; y < 72; y += 8) {
      _line(canvas, 0, y, 64, y - 32, deepTeal);
    }
    _r(canvas, 7, 7, 3, 19, mint);
    _r(canvas, 10, 7, 15, 3, mint);
    _r(canvas, 53, 48, 3, 17, mint);
    _r(canvas, 42, 62, 14, 3, mint);
    _plate(canvas, 7, 48, 52, 29, ink);
    _plate(canvas, 12, 47, 43, 27, vest);
    _r(canvas, 17, 52, 7, 20, locked ? steel : mint);
    _r(canvas, 38, 52, 8, 20, locked ? steel : mint);
    _r(canvas, 26, 58, 10, 14, navy);
    _r(canvas, 18, 64, 5, 4, cream);
    _plate(canvas, 19, 15, 30, 37, ink);
    _r(canvas, 22, 23, 24, 23, locked ? steel : gold);
    _r(canvas, 26, 26, 20, 17, locked ? steel : cream);
    _r(canvas, 20, 17, 28, 9, hair);
    _r(canvas, 24, 13, 21, 8, hair);
    _r(canvas, 18, 22, 7, 12, hair);
    _r(canvas, 42, 20, 7, 7, hair);
    _r(canvas, 27, 30, 7, 2, ink);
    _r(canvas, 39, 30, 7, 2, ink);
    _r(canvas, 30, 31, 3, 4, ink);
    _r(canvas, 40, 31, 3, 4, ink);
    _r(canvas, 35, 35, 3, 5, orange);
    _r(canvas, 33, 43, 9, 2, ink);
    _r(canvas, 22, 46, 24, 8, locked ? navy : orange);
    _r(canvas, 24, 47, 20, 2, locked ? steel : gold);
    _r(canvas, 12, 50, 12, 5, locked ? steel : red);
    _r(canvas, 7, 54, 12, 4, locked ? steel : orange);
    _r(canvas, 3, 57, 9, 3, locked ? steel : orange);
    if (variant == 1) {
      _r(canvas, 23, 27, 23, 7, navy);
      _r(canvas, 25, 28, 8, 3, mint);
      _r(canvas, 37, 28, 7, 3, mint);
    }
    if (locked) {
      _plate(canvas, 24, 49, 17, 16, ink);
      _r(canvas, 28, 44, 9, 3, cream);
      _r(canvas, 26, 47, 3, 7, cream);
      _r(canvas, 35, 47, 3, 7, cream);
      _r(canvas, 27, 54, 11, 8, gold);
      _r(canvas, 31, 56, 3, 4, ink);
    }
    canvas.restore();
  }

  /// Cover-fills any menu canvas with an animated, 480 x 270 harbor.
  static void paintHarbor(Canvas canvas, Size size, double time) {
    if (size.isEmpty) return;
    final scale = math.max(size.width / 480, size.height / 270);
    canvas.save();
    canvas.clipRect(Offset.zero & size, doAntiAlias: false);
    canvas.translate(
      (size.width - 480 * scale) / 2,
      (size.height - 270 * scale) / 2,
    );
    canvas.scale(scale);
    _harbor(canvas, time, time * 2);
    _dock(canvas, 0, time);
    canvas.restore();
  }

  static void _harbor(Canvas c, double time, double camera) {
    _r(c, 0, 0, 480, 270, const Color(0xff477f83));
    _r(c, 0, 34, 480, 34, const Color(0xff73978c));
    _r(c, 0, 68, 480, 32, const Color(0xffb6b798));
    _r(c, 0, 100, 480, 54, const Color(0xffeac591));
    _r(c, 0, 126, 480, 29, const Color(0xffe9a773));
    final sunX = 352 - (camera * .025 % 28).round();
    _r(c, sunX + 8, 52, 36, 4, cream);
    _r(c, sunX + 3, 56, 46, 6, cream);
    _r(c, sunX, 62, 52, 22, cream);
    _r(c, sunX + 3, 87, 46, 5, cream);
    _r(c, sunX + 8, 96, 36, 3, cream);
    _r(c, sunX + 14, 102, 24, 2, cream);
    for (var i = 0; i < 8; i++) {
      final x = ((i * 83 - camera * .07 + time * 1.8) % 590 - 65).round();
      final y = 22 + (i * 19 % 67);
      _r(c, x + 9, y, 32, 3, const Color(0xffc8c9a5));
      _r(c, x, y + 3, 58, 3, const Color(0xffc8c9a5));
      _r(c, x + 14, y + 6, 65, 2, const Color(0xff9cad99));
    }
    for (var i = -1; i < 9; i++) {
      final x = (i * 77 - camera * .13 % 77).round();
      final h = 13 + ((i + 9) * 17 % 37);
      _r(c, x, 149 - h, 49, h, const Color(0xff83968b));
      _r(c, x + 8, 144 - h, 14, 7, const Color(0xff83968b));
      _r(c, x + 32, 133 - h, 4, 18, const Color(0xff83968b));
      for (var w = 0; w < 5; w++) {
        _r(c, x + 5 + w * 8, 154 - h, 3, 2, const Color(0xffb4b49a));
      }
    }
    for (var i = -1; i < 5; i++) {
      final x = (i * 180 - camera * .24 % 180).round();
      _crane(c, x + 26, 74 + (i.isEven ? 0 : 17), deepTeal);
      _ship(c, x - 20, 145, i);
    }
    _r(c, 0, 157, 480, 61, deepTeal);
    _r(c, 0, 157, 480, 2, gold);
    _r(c, 0, 168, 480, 2, teal);
    for (var i = 0; i < 70; i++) {
      final x =
          ((i * 73 - camera * .32 + time * (i.isEven ? 5 : -3)) % 510 - 15);
      final y = 160 + (i * 17 % 54);
      _r(c, x, y, 4 + i % 19, i % 3 == 0 ? 2 : 1, i % 5 == 0 ? gold : teal);
    }
    for (var i = 0; i < 8; i++) {
      final x = sunX - 6 + (i * 17 % 45);
      _r(c, x, 162 + i * 5, 26 - i * 2, 1, const Color(0xffb0aa7d));
    }
    for (var i = 0; i < 6; i++) {
      final x = ((i * 97 + time * 8 - camera * .1) % 500).round();
      final y = 28 + i * 9;
      _r(c, x, y, 3, 1, deepTeal);
      _r(c, x + 3, y + 1, 2, 1, deepTeal);
      _r(c, x + 5, y, 3, 1, deepTeal);
    }
  }

  static void _crane(Canvas c, int x, int y, Color color) {
    _r(c, x, y + 13, 5, 87, color);
    _r(c, x - 7, y + 93, 20, 5, color);
    _r(c, x - 12, y + 14, 71, 4, color);
    _r(c, x - 8, y + 5, 14, 13, color);
    _line(c, x + 1, y + 1, x + 58, y + 14, color, 2);
    _line(c, x - 11, y + 14, x, y + 1, color, 2);
    _line(c, x + 2, y + 28, x + 34, y + 17, color, 2);
    _r(c, x + 49, y + 18, 1, 38, color);
    _r(c, x + 46, y + 55, 5, 3, color);
    _r(c, x + 45, y + 51, 2, 6, color);
    _r(c, x - 5, y + 8, 7, 5, gold);
    for (var j = 0; j < 5; j++) {
      _r(c, x, y + 29 + j * 12, 5, 2, teal);
    }
  }

  static void _ship(Canvas c, int x, int y, int variant) {
    _r(c, x, y, 112, 7, navy);
    _r(c, x + 5, y + 7, 100, 5, navy);
    _r(c, x + 12, y + 12, 84, 3, navy);
    _r(c, x + 6, y - 3, 98, 3, rust);
    _r(c, x + 10, y - 24, 28, 21, deepTeal);
    _r(c, x + 14, y - 29, 19, 5, navy);
    _r(c, x + 31, y - 45, 2, 22, navy);
    _r(c, x + 25, y - 38, 15, 1, navy);
    for (var j = 0; j < 3; j++) {
      _r(c, x + 14 + j * 7, y - 20, 4, 4, gold);
    }
    for (var j = 0; j < 3; j++) {
      _r(c, x + 43 + j * 20, y - 14, 18, 11, j == 1 ? rust : teal);
      for (var k = 0; k < 4; k++) {
        _r(c, x + 45 + j * 20 + k * 4, y - 12, 1, 7, deepTeal);
      }
    }
    _r(c, x + 11, y + 3, 15, 2, steel);
    _r(c, x + 47, y - 28, 5, 14, navy);
    for (var j = 0; j < 4; j++) {
      _r(c, x + 44 + j * 5, y - 32 - j * 5, 8 + j * 2, 4, steel);
    }
  }

  static void _dock(Canvas c, double camera, double time) {
    final ground = GameConfig.groundY;
    _r(c, 0, ground, 480, 52, ink);
    _r(c, 0, ground, 480, 4, pale);
    _r(c, 0, ground + 4, 480, 5, steel);
    _r(c, 0, ground + 9, 480, 3, deepTeal);
    _r(c, 0, ground + 12, 480, 31, navy);
    _r(c, 0, ground + 43, 480, 9, deepTeal);
    for (var i = -1; i < 17; i++) {
      final x = (i * 32 - camera % 32).round();
      _r(c, x, ground, 2, 9, deepTeal);
      _r(c, x + 4, ground + 1, 21, 1, cream);
      _r(c, x + 8, ground + 6, 6, 1, teal);
      _r(c, x + 3, ground + 13, 27, 26, deepTeal);
      _r(c, x + 5, ground + 15, 23, 22, navy);
      _line(
        c,
        x + 5,
        ground.toInt() + 15,
        x + 26,
        ground.toInt() + 36,
        deepTeal,
        2,
      );
      _bolt(c, x + 5, ground + 15);
      _bolt(c, x + 26, ground + 35);
      _r(c, x + 7, ground + 45, 12, 2, teal);
    }
    for (var i = -1; i < 7; i++) {
      final x = (i * 103 - camera * 1.08 % 103).round();
      _r(c, x, 263, 68, 7, ink);
      _r(c, x + 5, 259, 8, 11, ink);
      _r(c, x + 55, 259, 8, 11, ink);
      _r(c, x + 1, 263, 67, 2, steel);
      _r(c, x + 6, 259, 6, 2, teal);
    }
  }

  static void _container(Canvas c, int x, int y, int w, int h, Color color) {
    _plate(c, x, y, w, h, color);
    _r(c, x + 3, y + 3, w - 6, 2, steel);
    for (var xx = x + 7; xx < x + w - 4; xx += 7) {
      _r(c, xx, y + 7, 2, h - 12, ink);
      _r(c, xx + 2, y + 7, 1, h - 12, steel);
    }
    _r(c, x + w - 15, y + 11, 11, 10, cream);
    _r(c, x + w - 13, y + 13, 7, 1, rust);
    _r(c, x + w - 13, y + 16, 4, 1, rust);
    _bolt(c, x + 3, y + h - 5);
    _bolt(c, x + w - 5, y + h - 5);
  }

  static void _worldScenery(Canvas c, GameState s) {
    final camera = s.cameraX;
    for (var i = -1; i < 6; i++) {
      final worldX = ((camera / 156).floor() + i) * 156;
      final x = worldX - camera;
      if (worldX % 468 == 0) {
        _container(c, x.round(), 164, 80, 54, deepTeal);
        pixelText(c, 'RUCKUS', x + 10, 192, steel);
      } else {
        _r(c, x + 10, 196, 4, 22, navy);
        _r(c, x + 60, 196, 4, 22, navy);
        _r(c, x + 10, 196, 54, 3, steel);
        _r(c, x + 10, 207, 54, 2, deepTeal);
      }
      if (worldX % 624 == 0) {
        _r(c, x + 106, 121, 4, 97, ink);
        _r(c, x + 100, 121, 17, 6, ink);
        _r(c, x + 102, 123, 13, 3, gold);
        _r(c, x + 108, 126, 1, 88, steel);
        _r(c, x + 103, 211, 12, 7, navy);
      }
    }
  }

  static void renderScene(Canvas c, GameState s) {
    c.save();
    if (s.shake > 0) {
      c.translate(
        (math.sin(s.elapsed * 91) * s.shake).roundToDouble(),
        (math.cos(s.elapsed * 117) * s.shake * .55).roundToDouble(),
      );
    }
    _harbor(c, s.elapsed, s.cameraX);
    _worldScenery(c, s);
    _dock(c, s.cameraX, s.elapsed);
    c.save();
    c.translate(-s.cameraX.roundToDouble(), 0);
    for (final platform in s.platforms) {
      if (!_visible(platform.x, platform.width, s)) continue;
      _plate(
        c,
        platform.x,
        platform.y,
        platform.width,
        platform.height,
        deepTeal,
      );
      _r(c, platform.x, platform.y, platform.width, 3, pale);
      for (
        var x = platform.x + 4;
        x < platform.x + platform.width - 3;
        x += 12
      ) {
        _r(c, x, platform.y + 4, 5, 2, gold);
        _bolt(c, x, platform.y + 8);
      }
    }
    _signs(c, s);
    for (final prop in s.props) {
      if (!prop.alive || !_visible(prop.x, prop.width, s)) continue;
      _entitySprite(
        c,
        prop.explosive ? SpriteId.barrel : SpriteId.crate,
        prop.x,
        prop.y,
        prop.width,
        prop.height,
        s.elapsed,
      );
    }
    for (final pickup in s.pickups) {
      if (pickup.collected || !_visible(pickup.x, pickup.width, s)) continue;
      final icon = switch (pickup.kind) {
        PickupType.rapid => SpriteId.rapid,
        PickupType.launcher => SpriteId.launcher,
        PickupType.health => SpriteId.health,
        PickupType.grenades => SpriteId.grenade,
      };
      final bob = (math.sin(s.elapsed * 4 + pickup.x) * 2).round();
      _entitySprite(
        c,
        icon,
        pickup.x,
        pickup.y + bob,
        pickup.width,
        pickup.height,
        s.elapsed,
      );
      _spark(c, pickup.x + 3, pickup.y - 4 + bob, s.elapsed + pickup.x, cream);
    }
    for (final prisoner in s.prisoners) {
      if (prisoner.rescued || !_visible(prisoner.x, prisoner.width, s)) {
        continue;
      }
      _entitySprite(
        c,
        SpriteId.engineer,
        prisoner.x,
        prisoner.y,
        prisoner.width,
        prisoner.height,
        s.elapsed,
      );
      _label(
        c,
        'HELP!',
        prisoner.x + prisoner.width / 2,
        prisoner.y - 14,
        mint,
        centered: true,
      );
    }
    final vehicle = s.vehicle;
    if (vehicle.alive && _visible(vehicle.x, vehicle.width, s)) {
      _entitySprite(
        c,
        SpriteId.vehicle,
        vehicle.x,
        vehicle.y,
        vehicle.width,
        vehicle.height,
        s.elapsed,
        moving: vehicle.occupied && s.player.vx.abs() > 1,
        facing: s.player.inVehicle ? s.player.facing : 1,
        firing: vehicle.occupied && s.player.fireCooldown > .2,
      );
      if (!vehicle.occupied) {
        _label(
          c,
          'PILOT ME',
          vehicle.x + vehicle.width / 2,
          vehicle.y - 14,
          mint,
          centered: true,
        );
        _arrowDown(
          c,
          vehicle.x + vehicle.width / 2,
          vehicle.y - 4 + math.sin(s.elapsed * 4).round(),
          mint,
        );
      }
    }
    for (final enemy in s.enemies) {
      _entranceScenery(c, enemy, s);
      if (!enemy.spriteVisible || !_visible(enemy.x, enemy.width, s)) continue;
      final id = switch (enemy.kind) {
        EnemyType.infantry => SpriteId.infantry,
        EnemyType.shield => SpriteId.shield,
        EnemyType.turret => SpriteId.turret,
      };
      c.save();
      if (enemy.lifecycle == EnemyLifecycle.entering &&
          enemy.entranceType == EntranceType.trench) {
        c.clipRect(
          Rect.fromLTWH(enemy.x - 4, 0, enemy.width + 8, GameConfig.groundY),
        );
      }
      final scale = enemy.entranceScale;
      if (enemy.stance != EnemyStance.standing) {
        _proneSoldier(c, enemy, s.elapsed);
      } else {
        _entitySprite(
          c,
          id,
          enemy.x,
          enemy.y,
          enemy.width * scale,
          enemy.height * scale,
          s.elapsed,
          facing: enemy.facing,
          moving:
              enemy.lifecycle == EnemyLifecycle.entering ||
              enemy.mode == EnemyMode.patrol,
          firing: enemy.combatEnabled && enemy.mode == EnemyMode.attack,
          airborne:
              enemy.lifecycle == EnemyLifecycle.entering &&
              enemy.entranceType == EntranceType.dropFromAbove,
        );
      }
      c.restore();
      if (enemy.combatEnabled && enemy.mode == EnemyMode.alert) {
        _label(
          c,
          enemy.throwingGrenade ? 'GRENADE!' : '!',
          enemy.x + enemy.width / 2,
          enemy.y - 12,
          gold,
          centered: true,
        );
      }
    }
    final boss = s.boss;
    if (_visible(boss.x, boss.width, s) &&
        (boss.hp > 0 || boss.defeatTime > 0)) {
      _entitySprite(
        c,
        SpriteId.walker,
        boss.x,
        boss.y,
        boss.width,
        boss.height,
        s.elapsed,
        moving: boss.active,
        firing: boss.telegraph,
        variant: boss.vulnerable ? 1 : 0,
      );
      if (boss.active && boss.hp > 0) {
        _label(
          c,
          boss.vulnerable ? 'CORE EXPOSED!' : 'IRON WARDEN',
          boss.x + boss.width / 2,
          boss.y - 20,
          boss.vulnerable ? mint : orange,
          centered: true,
        );
        _r(c, boss.x + 8, boss.y - 8, boss.width - 16, 4, ink);
        _r(
          c,
          boss.x + 9,
          boss.y - 7,
          (boss.width - 18) * (boss.hp / boss.maxHp).clamp(0, 1),
          2,
          orange,
        );
        if (boss.telegraph) {
          final warning = switch (boss.attack) {
            0 => 'DUCK!',
            1 => 'BOMBS! MOVE!',
            _ => 'JUMP!',
          };
          _label(
            c,
            warning,
            boss.x - 35,
            GameConfig.groundY - 25,
            gold,
            centered: true,
          );
          for (var i = 0; i < 5; i++) {
            _r(
              c,
              boss.x - 130 + i * 25,
              GameConfig.groundY - 2,
              15,
              2,
              (s.elapsed * 10).floor().isEven ? orange : gold,
            );
          }
        }
      }
    }
    final player = s.player;
    if (!player.inVehicle &&
        !(player.invulnerable > 0 && (s.elapsed * 18).floor().isEven)) {
      _entitySprite(
        c,
        SpriteId.rook,
        player.x,
        player.y,
        player.width,
        player.height,
        s.elapsed,
        facing: player.facing,
        moving: player.vx.abs() > 1,
        crouching: player.crouching,
        firing: player.fireCooldown > .06,
        airborne: !player.grounded,
        variant: player.weapon.index,
      );
    }
    for (final shot in s.projectiles) {
      if (!_visible(shot.x, shot.width + 12, s)) continue;
      if (shot.shockwave) {
        final x = shot.x.round();
        final y = shot.y.round();
        _r(c, x, y + 4, shot.width, shot.height - 4, orange);
        _r(c, x + 3, y, shot.width - 6, shot.height, gold);
        _r(
          c,
          x + 5,
          y + 3,
          math.max(2, shot.width - 10),
          shot.height - 3,
          cream,
        );
        _spark(c, x - 3, y + 4, s.elapsed * 3, cream);
      } else if (shot.grenade) {
        _plate(c, shot.x, shot.y, 6, 7, mint);
        _r(c, shot.x + 2, shot.y - 2, 3, 2, cream);
        _spark(c, shot.x + 5, shot.y - 4, s.elapsed * 3, orange);
      } else if (shot.explosive) {
        final dir = shot.vx < 0 ? -1 : 1;
        _r(c, shot.x - dir * 7, shot.y + 1, 9, 3, orange);
        _plate(c, shot.x, shot.y, 10, 5, cream);
        _r(c, shot.x + 3, shot.y + 1, 4, 3, red);
      } else {
        _r(
          c,
          shot.x - (shot.vx > 0 ? 5 : 0),
          shot.y,
          shot.width + 6,
          math.max(shot.height, 3),
          ink,
        );
        _r(
          c,
          shot.x,
          shot.y,
          math.max(shot.width, 5),
          math.max(shot.height, 2),
          shot.hostile ? orange : cream,
        );
        _r(c, shot.x + 1, shot.y, 3, 1, white);
      }
    }
    for (final effect in s.effects) {
      if (_visible(effect.x - 70, 140, s)) _effect(c, effect, s.elapsed);
    }
    c.restore();
    final inspection = s.encounterInspection;
    for (var i = 0; i < math.min(3, inspection.length); i++) {
      final line = inspection[i].toUpperCase();
      _r(c, 4, 82 + i * 10, 472, 9, ink);
      pixelText(
        c,
        line.substring(0, math.min(92, line.length)),
        6,
        83 + i * 10,
        mint,
      );
    }
    if (s.calloutTime > 0 && s.callout.isNotEmpty) {
      final caption = s.callout.toUpperCase().replaceAll('•', '/');
      _label(c, caption, 240, 68, cream, centered: true);
    }
    c.restore();
  }

  static bool _visible(double x, double width, GameState s) =>
      x + width > s.cameraX - 30 && x < s.cameraX + 510;

  static void _entranceScenery(Canvas c, Enemy enemy, GameState s) {
    final marker = enemy.entrance?.marker;
    final entering = enemy.lifecycle == EnemyLifecycle.entering;
    final x = marker?.x ?? enemy.targetX;
    final y = marker?.y ?? enemy.targetY;
    final type = enemy.entranceType;
    final open =
        entering
            ? (enemy.entranceTime / GameConfig.entranceWarning).clamp(0.0, 1.0)
            : enemy.lifecycle == EnemyLifecycle.dormant
            ? 0.0
            : 1.0;
    if (marker != null && _visible(x - 28, 94, s)) {
      switch (type) {
        case EntranceType.doorway:
          _plate(c, x - 25, y - 12, 42, 42, steel);
          _r(c, x - 21, y - 8, 34, 36, ink);
          _r(c, x - 21, y - 8, 34 * (1 - open), 36, deepTeal);
          _r(c, x - 23, y - 11, 38, 3, open > 0 ? orange : rust);
        case EntranceType.trench:
          _r(c, x - 10, GameConfig.groundY - 2, 46, 7, ink);
          _r(c, x - 13, GameConfig.groundY - 4, 16, 4, steel);
          _r(c, x + 27, GameConfig.groundY - 4, 14, 4, steel);
          for (var i = 0; i < 3; i++) {
            _r(c, x + 5, GameConfig.groundY + i * 3, 18, 1, gold);
          }
        case EntranceType.background:
          _plate(c, x - 18, y - 47, 48, 32, navy);
          _r(c, x - 10, y - 42, 30, 27, ink);
          for (var i = 0; i < 4; i++) {
            _r(c, x - 4 - i * 2, y - 12 + i * 9, 17 + i * 4, 2, steel);
          }
        case EntranceType.vehicle:
        case EntranceType.dropFromAbove:
        case EntranceType.screenEdge:
        case EntranceType.rearAmbush:
          break;
      }
    }
    if (!entering || enemy.entranceSuspended) return;
    // The warning is camera-clamped independently of the hidden/offscreen sprite.
    final warningX = (enemy.targetX + enemy.width / 2).clamp(
      s.cameraX + 30,
      s.cameraX + 450,
    );
    final pulse = (s.elapsed * 8).floor().isEven ? gold : orange;
    _label(
      c,
      switch (type) {
        EntranceType.screenEdge => 'INCOMING',
        EntranceType.doorway => 'DOOR!',
        EntranceType.trench => 'BELOW!',
        EntranceType.dropFromAbove => 'ABOVE!',
        EntranceType.background => 'APPROACH!',
        EntranceType.vehicle => 'TRANSPORT!',
        EntranceType.rearAmbush => 'BEHIND!',
      },
      warningX,
      151,
      pulse,
      centered: true,
    );
    _arrowDown(c, warningX, 166 + math.sin(s.elapsed * 10) * 2, pulse);
    _r(c, warningX - 15, GameConfig.groundY - 2, 30, 2, pulse);
    if (type == EntranceType.dropFromAbove) {
      final width = 10 + enemy.motionProgress * 20;
      _r(c, warningX - width / 2, GameConfig.groundY - 4, width, 4, ink);
    }
    if (type == EntranceType.trench) {
      _spark(c, x + 10, GameConfig.groundY - 7, s.elapsed * 3, gold);
    }
    if (type == EntranceType.vehicle) {
      _entitySprite(
        c,
        SpriteId.vehicle,
        enemy.transportX,
        GameConfig.groundY - 35,
        64,
        35,
        s.elapsed,
        facing: -1,
        moving: enemy.motionProgress < 0.65,
      );
    }
  }

  static void _signs(Canvas c, GameState s) {
    const signs = <(double, String, String)>[
      (160, 'PORT RUCKUS', '01 // LANDING'),
      (1420, 'KEEP MOVING', '02 // FREIGHT'),
      (2950, 'RESCUE ROUTE', '03 // FREIGHT'),
      (4550, 'ARMOR DEPOT', '04 // MOTOR POOL'),
      (6200, 'NO TURNING BACK', '05 // FOUNDRY'),
      (8250, 'DANGER AHEAD', '06 // IRON GATE'),
      (GameConfig.bossArenaStart, 'IRON WARDEN', '07 // SHOWDOWN'),
    ];
    for (final (x, title, subtitle) in signs) {
      if (!_visible(x, 110, s)) continue;
      _r(c, x + 8, 168, 4, 50, ink);
      _r(c, x + 87, 168, 4, 50, ink);
      _plate(c, x, 133, 100, 37, navy);
      _r(c, x + 3, 136, 94, 2, orange);
      pixelText(c, title, x + 7, 143, cream);
      pixelText(c, subtitle, x + 7, 155, steel);
      _bolt(c, x + 3, 164);
      _bolt(c, x + 94, 164);
    }
    for (final x in [GameConfig.checkpointX, GameConfig.preBossCheckpointX]) {
      if (!_visible(x, 50, s)) continue;
      final lit = s.checkpointReached && s.player.x >= x - 50;
      _r(c, x, 168, 3, 50, ink);
      _r(c, x + 1, 168, 1, 48, steel);
      _plate(c, x + 3, 169, 23, 14, lit ? teal : navy);
      _r(c, x + 5, 171, 18, 2, lit ? mint : gold);
      pixelText(c, 'CP', x + 9, 176, lit ? mint : cream);
      _spark(c, x + 1, 165, s.elapsed, lit ? mint : gold);
      _label(c, 'CHECKPOINT', x - 14, 148, lit ? mint : cream);
    }
  }

  static void _disc(Canvas c, num x, num y, int radius, Color color) {
    for (var row = -radius; row <= radius; row += 3) {
      final half = math.sqrt(math.max(0, radius * radius - row * row)).floor();
      _r(c, x - half, y + row, half * 2, 3, color);
    }
  }

  static void _effect(Canvas c, Effect effect, double time) {
    final age = (1 - effect.time / effect.maxTime).clamp(0.0, 1.0);
    final x = effect.x;
    final y = effect.y;
    switch (effect.kind) {
      case 'explosion':
      case 'defeat':
        final big = effect.kind == 'explosion';
        final radius = ((big ? 30 : 15) * math.sin(age * math.pi)).round() + 3;
        for (var i = 0; i < 7; i++) {
          final angle = i * .897 + effect.x;
          final distance = age * (big ? 52 : 24);
          final xx = x + math.cos(angle) * distance;
          final yy = y + math.sin(angle) * distance - age * 12;
          final puff = (8 * (1 - age)).round() + 2;
          _disc(c, xx, yy, puff, age > .6 ? deepTeal : rust);
          if (age < .65) {
            _r(c, xx, yy, 3, 3, i.isEven ? gold : cream);
          }
          _r(c, xx + i % 3, yy + age * age * 25, 2, 2, steel);
        }
        if (age < .8) {
          _disc(c, x, y, radius, red);
          _disc(c, x - 2, y - 2, (radius * .78).round(), orange);
          _disc(c, x - 3, y - 3, (radius * .55).round(), gold);
          _disc(c, x - 2, y - 4, (radius * .3).round(), cream);
        }
        if (big && age > .15 && age < .6) {
          pixelText(c, 'KRAK!', x - 9, y - radius - 9, cream);
        }
      case 'rescue':
        for (var i = 0; i < 8; i++) {
          _spark(
            c,
            x - 17 + i * 5,
            y - age * 30 + i % 3 * 4,
            time + i,
            i.isEven ? mint : cream,
          );
        }
        _label(c, '+500  FREED!', x, y - 15 - age * 22, mint, centered: true);
      case 'warning':
        final flash = (time * 9).floor().isEven;
        _r(c, x - 20, y - 2, 40, 2, flash ? red : gold);
        _r(c, x - 16, y - 4, 32, 1, orange);
        _arrowDown(c, x, y - 9, flash ? cream : orange);
        _label(c, '!', x, y - 26, orange, centered: true);
      case 'muzzle':
      case 'enemyMuzzle':
        _r(c, x - 4, y - 1, 8, 3, cream);
        _r(c, x - 1, y - 4, 3, 9, gold);
        _r(c, x - 2, y - 2, 5, 5, white);
      case 'melee':
        _line(
          c,
          x.round() - 9,
          y.round() + 6,
          x.round() + 12,
          y.round() - 9,
          cream,
          2,
        );
        _line(
          c,
          x.round() - 8,
          y.round() + 9,
          x.round() + 10,
          y.round() - 4,
          mint,
        );
        _spark(c, x, y, time * 2, white);
      default:
        final color = effect.kind == 'shield' ? mint : gold;
        for (var i = 0; i < 5; i++) {
          final angle = i * 1.256;
          final distance = 3 + age * 13;
          _r(
            c,
            x + math.cos(angle) * distance,
            y + math.sin(angle) * distance,
            2,
            2,
            color,
          );
        }
        if (age < .3) _r(c, x - 2, y - 2, 4, 4, white);
    }
  }

  static void _arrowDown(Canvas c, num x, num y, Color color) {
    _r(c, x - 1, y - 4, 3, 5, ink);
    _r(c, x - 3, y - 1, 7, 3, ink);
    _r(c, x, y - 4, 1, 5, color);
    _r(c, x - 2, y, 5, 1, color);
    _r(c, x - 1, y + 1, 3, 1, color);
    _r(c, x, y + 2, 1, 1, color);
  }

  static void _spark(Canvas c, num x, num y, double time, Color color) {
    final frame = (time * 5).floor() % 4;
    if (frame == 0) return;
    final extent = frame == 2 ? 3 : 2;
    _r(c, x - extent, y, extent * 2 + 1, 1, color);
    _r(c, x, y - extent, 1, extent * 2 + 1, color);
    _r(c, x, y, 1, 1, white);
  }

  static void _entitySprite(
    Canvas c,
    SpriteId id,
    double x,
    double y,
    double width,
    double height,
    double time, {
    int facing = 1,
    bool moving = false,
    bool firing = false,
    bool crouching = false,
    bool airborne = false,
    int variant = 0,
  }) {
    final (w, h) = switch (id) {
      SpriteId.rook => (18.0, 30.0),
      SpriteId.infantry => (23.0, 28.0),
      SpriteId.shield => (27.0, 31.0),
      SpriteId.turret => (26.0, 24.0),
      SpriteId.engineer => (18.0, 27.0),
      SpriteId.vehicle => (65.0, 37.0),
      SpriteId.walker => (116.0, 91.0),
      SpriteId.barrel => (17.0, 24.0),
      SpriteId.crate => (25.0, 25.0),
      _ => (16.0, 16.0),
    };
    c.save();
    c.translate(x.roundToDouble(), y.roundToDouble());
    c.scale(width / w, height / h);
    if (facing < 0) {
      c.translate(w, 0);
      c.scale(-1, 1);
    }
    switch (id) {
      case SpriteId.rook:
        _rook(c, time, moving, firing, crouching, airborne, variant);
      case SpriteId.infantry:
      case SpriteId.shield:
        _soldier(c, time, moving, firing, id == SpriteId.shield);
      case SpriteId.turret:
        _turret(c, time, firing);
      case SpriteId.engineer:
        _engineer(c, time);
      case SpriteId.vehicle:
        _vehicle(c, time, moving, firing);
      case SpriteId.walker:
        _walker(c, time, moving, firing, variant == 1);
      case SpriteId.barrel:
        _barrel(c);
      case SpriteId.crate:
        _crate(c);
      default:
        _pickup(c, id, time);
    }
    c.restore();
  }

  static void _rook(
    Canvas c,
    double time,
    bool moving,
    bool firing,
    bool crouching,
    bool airborne,
    int weapon,
  ) {
    final step = moving ? (math.sin(time * 17) * 3).round() : 0;
    final bob = moving && step > 0 ? 1 : 0;
    _r(c, 1, 29, 17, 2, deepTeal);
    c.save();
    c.translate(0, crouching ? 7 : bob.toDouble());
    _plate(c, 2 - step, 23 - (airborne ? 3 : 0), 7, crouching ? 1 : 6, ink);
    _r(c, 3 - step, 23 - (airborne ? 3 : 0), 4, crouching ? 1 : 4, teal);
    _r(c, 1 - step, crouching ? 20 : 28 - (airborne ? 3 : 0), 8, 2, ink);
    _r(c, 10 + step, 22, 5, crouching ? 1 : 7, navy);
    _r(c, 10 + step, crouching ? 20 : 27, 8, 3, ink);
    _plate(c, 2, 12, 14, 13, teal);
    _r(c, 3, 14, 4, 6, mint);
    _r(c, 10, 14, 4, 6, mint);
    _r(c, 7, 14, 2, 9, deepTeal);
    _r(c, 2, 23, 13, 2, ink);
    _r(c, 8, 23, 3, 2, gold);
    _plate(c, 4, 2, 13, 12, gold);
    _r(c, 7, 4, 9, 7, cream);
    _r(c, 13, 6, 3, 2, ink);
    _r(c, 15, 8, 3, 2, cream);
    _r(c, 12, 11, 4, 1, rust);
    _r(c, 3, 2, 4, 7, cream);
    _r(c, 4, 0, 11, 4, cream);
    _r(c, 7, 0, 6, 1, white);
    _r(c, 2, 4, 4, 3, cream);
    _r(c, 3, 11, 12, 3, orange);
    _r(c, 2, 12, 6, 2, gold);
    final flutter = (math.sin(time * 13) * 2).round();
    _r(c, -3, 12 + flutter, 7, 3, red);
    _r(c, -7, 11 + flutter, 5, 2, orange);
    _plate(c, 9, 15, 10, 5, cream);
    _r(c, 14, 15, 12, 4, ink);
    _r(c, 16, 15, 8, 1, steel);
    _r(c, 14, 19, 3, 4, ink);
    _r(c, 23, 16, 5, 2, navy);
    if (weapon == 1) {
      _r(c, 15, 14, 11, 2, mint);
      _r(c, 20, 19, 3, 4, steel);
      _r(c, 25, 15, 5, 3, ink);
    } else if (weapon == 2) {
      _plate(c, 12, 13, 17, 7, teal);
      _r(c, 14, 14, 11, 2, mint);
      _r(c, 26, 12, 4, 9, ink);
      _r(c, 27, 14, 2, 5, gold);
    }
    if (firing) _muzzle(c, 29, 17, time);
    c.restore();
  }

  static void _proneSoldier(Canvas c, Enemy enemy, double time) {
    c.save();
    c.translate(enemy.facing > 0 ? enemy.x : enemy.x + enemy.width, enemy.y);
    c.scale(enemy.facing.toDouble(), 1);
    final t =
        enemy.stance == EnemyStance.prone
            ? 1.0
            : (enemy.loweringTime / GameConfig.enemyLoweringTime).clamp(
              0.0,
              1.0,
            );
    final headX = 6 + 15 * t;
    final h = enemy.height;
    _r(c, 0, h - 4, 10 + 5 * t, 4, ink);
    _r(c, 3, h - 5, 8 + 5 * t, 3, rust);
    _plate(c, 8, 7, headX - 1, h - 7, rust);
    _r(c, 10, 8, headX - 5, 2, orange);
    _plate(c, headX, 1, 9, 8, gold);
    _r(c, headX - 1, 0, 11, 4, red);
    _r(c, headX + 5, 4, 4, 2, mint);
    _r(c, headX - 1, 8, 9, 3, orange);
    _r(c, headX + 4, 5, enemy.width - headX - 4, 3, ink);
    _r(c, headX + 5, 5, enemy.width - headX - 5, 1, steel);
    if (enemy.kind == EnemyType.shield) {
      _plate(c, enemy.width - 9, h - 6, 8, 6, navy);
      _r(c, enemy.width - 7, h - 5, 4, 2, mint);
    }
    if (enemy.throwingGrenade) {
      _r(c, headX - 3, 0, 4, 4, gold);
    } else if (enemy.mode == EnemyMode.attack && enemy.combatEnabled) {
      _muzzle(c, enemy.width.round(), 5, time);
    }
    c.restore();
  }

  static void _soldier(
    Canvas c,
    double time,
    bool moving,
    bool firing,
    bool shield,
  ) {
    final step = moving ? (math.sin(time * 12) * 2).round() : 0;
    _r(c, 2, 27, shield ? 26 : 22, 2, deepTeal);
    _r(c, 4 - step, 23, 7, 5, ink);
    _r(c, 14 + step, 23, 8, 5, ink);
    _r(c, 5 - step, 23, 4, 2, rust);
    _plate(c, 2, 11, 20, 15, rust);
    _r(c, 4, 13, 16, 3, orange);
    _r(c, 8, 16, 12, 5, red);
    _r(c, 4, 22, 16, 3, ink);
    _r(c, 12, 23, 3, 2, gold);
    _plate(c, 5, 2, 15, 12, gold);
    _r(c, 4, 1, 16, 6, ink);
    _r(c, 5, 2, 13, 4, red);
    _r(c, 7, 2, 8, 1, orange);
    _r(c, 4, 6, 18, 3, ink);
    _r(c, 14, 7, 6, 2, mint);
    _r(c, 17, 11, 4, 2, rust);
    _plate(c, 14, 16, 10, 6, orange);
    _r(c, 20, 16, 10, 4, ink);
    _r(c, 21, 16, 7, 1, steel);
    if (shield) {
      _plate(c, 18, 10, 12, 21, navy);
      _r(c, 20, 12, 8, 2, steel);
      _r(c, 20, 14, 8, 4, mint);
      _r(c, 20, 21, 8, 7, rust);
      _line(c, 20, 28, 27, 21, gold, 2);
      _bolt(c, 20, 18);
      _bolt(c, 26, 18);
    }
    if (firing) _muzzle(c, 31, 17, time);
  }

  static void _turret(Canvas c, double time, bool firing) {
    _r(c, 1, 21, 25, 3, ink);
    _r(c, 4, 18, 5, 5, steel);
    _r(c, 19, 18, 5, 5, steel);
    _plate(c, 7, 12, 14, 8, deepTeal);
    _plate(c, 2, 3, 24, 13, rust);
    _r(c, 4, 5, 19, 3, orange);
    _r(c, 5, 10, 8, 3, ink);
    _r(c, 7, 10, 3, 2, firing ? cream : mint);
    _r(c, 22, 8, 12, 5, ink);
    _r(c, 23, 8, 9, 2, steel);
    _r(c, 8, 0, 2, 4, ink);
    _r(c, 7, 0, 4, 2, (time * 4).floor().isEven ? red : gold);
    _bolt(c, 17, 11);
    _bolt(c, 21, 11);
    if (firing) _muzzle(c, 35, 10, time);
  }

  static void _engineer(Canvas c, double time) {
    final bounce = (time * 3).floor().isEven ? 0 : 1;
    c.save();
    c.translate(0, bounce.toDouble());
    _r(c, 1, 25, 16, 2, deepTeal);
    _r(c, 3, 21, 5, 5, ink);
    _r(c, 11, 21, 5, 5, ink);
    _plate(c, 2, 11, 14, 13, cream);
    _r(c, 4, 14, 10, 2, deepTeal);
    _r(c, 4, 18, 10, 2, deepTeal);
    _r(c, 5, 21, 8, 2, teal);
    _plate(c, 3, 2, 13, 11, cream);
    _r(c, 6, 6, 2, 2, ink);
    _r(c, 12, 6, 2, 2, ink);
    _r(c, 9, 10, 3, 1, rust);
    _r(c, 3, 2, 12, 3, gold);
    _r(c, 5, 0, 8, 3, gold);
    _r(c, 1, 4, 16, 2, orange);
    _r(c, 7, 0, 3, 4, cream);
    _r(c, 0, 15, 4, 7, cream);
    _r(c, 15, 11, 3, 8, cream);
    _r(c, 16, 7, 2, 8, ink);
    _r(c, 16, 4, 2, 3, mint);
    _spark(c, 16, 2, time * 2, mint);
    c.restore();
  }

  static void _vehicle(Canvas c, double time, bool moving, bool firing) {
    _r(c, 1, 35, 64, 3, deepTeal);
    _plate(c, 1, 23, 63, 14, ink);
    _plate(c, 4, 25, 57, 10, steel);
    _plate(c, 6, 27, 53, 6, navy);
    final tread = moving ? (time * 24).floor() % 7 : 0;
    for (var x = 8; x < 59; x += 7) {
      _r(c, x, 28, 4, 4, ink);
      _r(c, x + 1, 29, 2, 2, steel);
      _r(c, x + tread - 3, 25, 3, 1, cream);
      _r(c, x - tread + 3, 34, 3, 1, cream);
    }
    _plate(c, 0, 14, 65, 15, teal);
    _r(c, 4, 16, 55, 4, mint);
    _r(c, 7, 20, 47, 5, deepTeal);
    _plate(c, 14, 5, 34, 15, mint);
    _r(c, 18, 7, 25, 2, pale);
    _plate(c, 23, 8, 17, 8, navy);
    _r(c, 25, 10, 12, 3, mint);
    _r(c, 26, 10, 5, 1, pale);
    _r(c, 14, 2, 24, 4, ink);
    _r(c, 17, 2, 18, 2, steel);
    _r(c, 10, -5, 1, 18, ink);
    _r(c, 9, -5, 3, 2, orange);
    _plate(c, 42, 10, 26, 7, steel);
    _r(c, 45, 11, 19, 2, mint);
    _r(c, 63, 9, 5, 9, ink);
    _r(c, 56, 18, 5, 4, cream);
    _r(c, 3, 20, 4, 4, red);
    _r(c, 16, 20, 9, 5, cream);
    pixelText(c, '7', 19, 20, deepTeal);
    for (var i = 0; i < 4; i++) {
      _r(c, 34 + i * 4, 21, 2, 4, ink);
    }
    _bolt(c, 9, 17, pale);
    _bolt(c, 49, 18, pale);
    if (moving) {
      _r(c, -6, 31, 5, 3, steel);
      _r(c, -11, 28, 4, 3, steel);
    }
    if (firing) _muzzle(c, 70, 13, time);
  }

  static void _walker(
    Canvas c,
    double time,
    bool moving,
    bool charging,
    bool exposed,
  ) {
    final stride = moving ? (math.sin(time * 5) * 4).round() : 0;
    _r(c, 0, 89, 117, 4, deepTeal);
    for (var i = 0; i < 4; i++) {
      final x = 15 + i * 25;
      final step = i.isEven ? stride : -stride;
      _line(c, x, 50, x + step - 8, 69, ink, 9);
      _line(c, x + step - 8, 69, x + step - 2, 85, ink, 7);
      _line(c, x + 2, 52, x + step - 5, 69, rust, 4);
      _line(c, x + step - 5, 70, x + step, 85, steel, 3);
      _plate(c, x + step - 10, 64, 12, 12, orange);
      _bolt(c, x + step - 6, 68, cream);
      _plate(c, x + step - 6, 82, 19, 9, ink);
      _r(c, x + step - 4, 83, 14, 3, rust);
      _r(c, x + step - 3, 88, 4, 2, gold);
      _r(c, x + step + 4, 88, 4, 2, gold);
    }
    _plate(c, 8, 13, 104, 47, ink);
    _plate(c, 14, 10, 89, 43, red);
    _r(c, 20, 8, 65, 7, ink);
    _r(c, 23, 10, 58, 3, orange);
    _r(c, 18, 16, 80, 7, orange);
    _r(c, 23, 17, 69, 2, gold);
    _plate(c, 58, 24, 37, 23, rust);
    for (var i = 0; i < 5; i++) {
      _r(c, 63 + i * 6, 28, 3, 14, ink);
      _r(c, 63 + i * 6, 28, 1, 10, orange);
    }
    _plate(c, 14, 26, 34, 25, navy);
    _r(c, 18, 29, 25, 6, ink);
    _r(c, 20, 30, 21, 3, charging ? white : gold);
    _r(c, 20, 31, 5, 2, charging ? red : cream);
    _r(c, 16, 39, 31, 14, ink);
    for (var i = 0; i < 5; i++) {
      _r(c, 18 + i * 6, 39, 4, 4 + i % 2, cream);
      _r(c, 21 + i * 5, 49, 3, 4, cream);
    }
    _plate(c, 0, 23, 16, 27, rust);
    _r(c, 1, 26, 12, 4, orange);
    _r(c, -7, 31, 10, 10, ink);
    _r(c, -7, 33, 8, 5, steel);
    _plate(c, 98, 18, 18, 34, rust);
    _r(c, 101, 22, 12, 3, orange);
    _r(c, 104, 31, 8, 15, ink);
    for (var y = 34; y < 46; y += 4) {
      _r(c, 105, y, 6, 2, steel);
    }
    _r(c, 73, -4, 8, 14, ink);
    _r(c, 75, -3, 4, 12, steel);
    _r(c, 87, 0, 7, 11, ink);
    _r(c, 89, 2, 3, 7, steel);
    final puff = (time * 9).floor() % 4;
    _r(c, 70 - puff, -11 - puff * 2, 11, 5, steel);
    _r(c, 75, -19 - puff * 3, 14, 5, deepTeal);
    _plate(c, 48, 42, 20, 19, ink);
    _plate(c, 51, 44, 14, 14, exposed ? mint : orange);
    _r(c, 55, 47, 6, 8, exposed ? white : gold);
    _r(c, 54, 50, 8, 2, exposed ? pale : red);
    _bolt(c, 19, 20, cream);
    _bolt(c, 92, 20, cream);
    _bolt(c, 72, 48, cream);
    _bolt(c, 93, 48, cream);
    if (charging) {
      _spark(c, -12, 35, time * 3, gold);
      _r(c, 31, 2, 4, 5, (time * 10).floor().isEven ? red : white);
      _r(c, 27, 6, 12, 2, ink);
    }
    if (exposed) {
      _spark(c, 47, 47, time * 2, mint);
      _spark(c, 68, 55, time * 2 + 1, cream);
    }
  }

  static void _barrel(Canvas c) {
    _plate(c, 0, 0, 17, 24, red);
    _r(c, 3, 2, 4, 20, orange);
    _r(c, 1, 4, 15, 3, ink);
    _r(c, 2, 4, 13, 1, steel);
    _r(c, 1, 18, 15, 3, ink);
    _r(c, 2, 18, 13, 1, steel);
    _r(c, 5, 9, 8, 7, gold);
    _r(c, 8, 10, 2, 3, red);
    _r(c, 7, 13, 4, 2, red);
    _r(c, 5, 1, 7, 1, cream);
  }

  static void _crate(Canvas c) {
    _plate(c, 0, 0, 25, 25, rust);
    _r(c, 3, 3, 19, 19, gold);
    _r(c, 6, 5, 13, 15, orange);
    _line(c, 4, 4, 19, 19, rust, 3);
    _line(c, 19, 4, 4, 19, rust, 3);
    _r(c, 10, 8, 6, 9, cream);
    _r(c, 12, 10, 2, 5, rust);
    _bolt(c, 3, 3, cream);
    _bolt(c, 20, 3, cream);
    _bolt(c, 3, 20, cream);
    _bolt(c, 20, 20, cream);
  }

  static void _pickup(Canvas c, SpriteId id, double time) {
    _plate(c, 0, 0, 16, 16, navy);
    _r(c, 2, 2, 12, 1, cream);
    _r(c, 2, 13, 12, 1, gold);
    switch (id) {
      case SpriteId.health:
        _r(c, 6, 4, 4, 8, mint);
        _r(c, 4, 6, 8, 4, mint);
        _r(c, 7, 5, 1, 6, pale);
      case SpriteId.grenade:
        _plate(c, 4, 6, 9, 7, mint);
        _r(c, 7, 3, 4, 3, steel);
        _r(c, 10, 4, 3, 1, cream);
        _r(c, 6, 8, 5, 1, teal);
        _r(c, 8, 6, 1, 6, teal);
      case SpriteId.launcher:
        _r(c, 3, 6, 11, 4, orange);
        _r(c, 5, 10, 3, 3, cream);
        _r(c, 12, 4, 2, 8, gold);
        _r(c, 2, 7, 3, 2, cream);
      default:
        _r(c, 3, 6, 11, 3, mint);
        _r(c, 4, 9, 3, 4, cream);
        _r(c, 9, 9, 2, 3, mint);
        _r(c, 4, 5, 6, 1, cream);
    }
  }

  static void _muzzle(Canvas c, int x, int y, double time) {
    if ((time * 24).floor().isEven) {
      _r(c, x, y - 2, 7, 5, orange);
      _r(c, x + 2, y - 4, 3, 9, gold);
      _r(c, x - 1, y - 1, 9, 3, cream);
      _r(c, x + 2, y, 8, 1, white);
    }
  }

  static void _label(
    Canvas c,
    String text,
    num x,
    num y,
    Color color, {
    bool centered = false,
  }) {
    final width = text.length * 4 + 8;
    final left = centered ? x - width / 2 : x;
    _plate(c, left, y, width, 13, ink);
    _r(c, left + 3, y + 11, width - 6, 1, color);
    pixelText(c, text, left + 4, y + 3, color);
  }

  /// Tiny grid font suitable for signs and diegetic cues, not the Flutter HUD.
  static void pixelText(
    Canvas c,
    String text,
    num x,
    num y,
    Color color, {
    int scale = 1,
  }) {
    var xx = x.toDouble();
    for (final rune in text.toUpperCase().runes) {
      final rows = _font[String.fromCharCode(rune)] ?? _font['?']!;
      for (var row = 0; row < 5; row++) {
        for (var col = 0; col < 3; col++) {
          if (rows[row] & (1 << (2 - col)) != 0) {
            _r(c, xx + col * scale, y + row * scale, scale, scale, color);
          }
        }
      }
      xx += 4 * scale;
    }
  }

  static const _font = <String, List<int>>{
    'A': [2, 5, 7, 5, 5],
    'B': [6, 5, 6, 5, 6],
    'C': [3, 4, 4, 4, 3],
    'D': [6, 5, 5, 5, 6],
    'E': [7, 4, 6, 4, 7],
    'F': [7, 4, 6, 4, 4],
    'G': [3, 4, 5, 5, 3],
    'H': [5, 5, 7, 5, 5],
    'I': [7, 2, 2, 2, 7],
    'J': [1, 1, 1, 5, 2],
    'K': [5, 5, 6, 5, 5],
    'L': [4, 4, 4, 4, 7],
    'M': [5, 7, 7, 5, 5],
    'N': [5, 7, 7, 7, 5],
    'O': [2, 5, 5, 5, 2],
    'P': [6, 5, 6, 4, 4],
    'Q': [2, 5, 5, 3, 1],
    'R': [6, 5, 6, 5, 5],
    'S': [3, 4, 2, 1, 6],
    'T': [7, 2, 2, 2, 2],
    'U': [5, 5, 5, 5, 7],
    'V': [5, 5, 5, 5, 2],
    'W': [5, 5, 7, 7, 5],
    'X': [5, 5, 2, 5, 5],
    'Y': [5, 5, 2, 2, 2],
    'Z': [7, 1, 2, 4, 7],
    '0': [7, 5, 5, 5, 7],
    '1': [2, 6, 2, 2, 7],
    '2': [6, 1, 7, 4, 7],
    '3': [6, 1, 3, 1, 6],
    '4': [5, 5, 7, 1, 1],
    '5': [7, 4, 6, 1, 6],
    '6': [3, 4, 7, 5, 7],
    '7': [7, 1, 2, 2, 2],
    '8': [7, 5, 7, 5, 7],
    '9': [7, 5, 7, 1, 6],
    '!': [2, 2, 2, 0, 2],
    '?': [6, 1, 2, 0, 2],
    '/': [1, 1, 2, 4, 4],
    '-': [0, 0, 7, 0, 0],
    '.': [0, 0, 0, 0, 2],
    ':': [0, 2, 0, 2, 0],
    ' ': [0, 0, 0, 0, 0],
    '+': [0, 2, 7, 2, 0],
  };
}
