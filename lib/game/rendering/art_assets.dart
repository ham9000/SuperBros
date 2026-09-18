import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Local artwork, decoded once. Simulation coordinates and hitboxes stay intact.
abstract final class ArtAssets {
  static final Map<String, ui.Image> _images = {};
  static Map<String, dynamic> _characters = {};
  static Future<void>? _loading;
  static final _clocks = Expando<_PoseClock>();
  static bool get ready => _images.length == 12;
  // Measured sprite bounds avoid bleeding from the nonuniform source atlas.
  static const equipmentBounds = <List<double>>[
    [44, 90, 227, 257],
    [358, 88, 223, 259],
    [669, 93, 206, 254],
    [960, 89, 294, 258],
    [44, 457, 284, 203],
    [312, 522, 313, 133],
    [653, 395, 265, 272],
    [1010, 425, 174, 242],
    [36, 779, 262, 204],
    [335, 757, 253, 226],
    [637, 688, 293, 301],
    [979, 834, 231, 148],
    [84, 1025, 135, 201],
    [386, 1070, 176, 140],
    [679, 1075, 191, 136],
    [942, 1080, 286, 131],
  ];
  static final _paint =
      ui.Paint()
        ..isAntiAlias = false
        ..filterQuality = ui.FilterQuality.none;

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    _characters =
        jsonDecode(await rootBundle.loadString('assets/art/characters.json'))
            as Map<String, dynamic>;
    final names = [
      for (var i = 1; i <= 5; i++) ...[
        'unit-${i.toString().padLeft(2, '0')}',
        'unit-${i.toString().padLeft(2, '0')}-portrait',
      ],
      'world',
      'equipment',
    ];
    await Future.wait(
      names.map((name) async {
        final data = await rootBundle.load('assets/art/$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _images[name] = (await codec.getNextFrame()).image;
        codec.dispose();
      }),
    );
  }

  static String unitName(int unit) =>
      'unit-${(unit.clamp(0, 4) + 1).toString().padLeft(2, '0')}';

  static double poseTime(Object owner, String state, double elapsed) {
    var clock = _clocks[owner];
    if (clock == null || clock.state != state || elapsed < clock.started) {
      clock = _PoseClock(state, elapsed);
      _clocks[owner] = clock;
    }
    return elapsed - clock.started;
  }

  static List<int> frames(int unit, String state) => List<int>.from(
    _characters['${unit.clamp(0, 4)}']['states'][state] as List,
  );

  static int frameAt(int unit, String state, double seconds) {
    final sequence = frames(unit, state);
    if (state == 'crouch') return sequence.first;
    final fps = switch (state) {
      'run' => 10.0,
      'fire' => 12.0,
      'idle' => 2.0,
      _ => 6.0,
    };
    final tick = (seconds * fps).floor().clamp(0, 1000000000);
    return sequence[state == 'death' || state == 'hurt'
        ? tick.clamp(0, sequence.length - 1)
        : tick % sequence.length];
  }

  static bool portrait(ui.Canvas canvas, ui.Rect target, int unit) {
    final image = _images['${unitName(unit)}-portrait'];
    if (image == null) return false;
    // Cover within a clipped frame, biased toward the face on the left.
    final ratio = target.width / target.height;
    final sourceWidth = (image.height * ratio).clamp(
      1.0,
      image.width.toDouble(),
    );
    final sourceHeight = sourceWidth / ratio;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(
        (image.width - sourceWidth) * .25,
        0,
        sourceWidth,
        sourceHeight,
      ),
      target,
      _paint,
    );
    return true;
  }

  static bool character(
    ui.Canvas c,
    int unit,
    String state,
    double seconds,
    double center,
    double feet, {
    int facing = 1,
    double size = 56,
  }) {
    final image = _images[unitName(unit)];
    if (image == null) return false;
    final frame = frameAt(unit, state, seconds);
    c.save();
    c.translate(center, feet);
    c.scale(facing.toDouble(), 1);
    c.drawImageRect(
      image,
      ui.Rect.fromLTWH((frame % 8) * 256, (frame ~/ 8) * 256, 256, 256),
      ui.Rect.fromLTWH(-size / 2, -size * 224 / 256, size, size),
      _paint,
    );
    c.restore();
    return true;
  }

  static bool equipment(
    ui.Canvas c,
    int frame,
    ui.Rect target, {
    int facing = 1,
  }) {
    final image = _images['equipment'];
    if (image == null) return false;
    final bounds = equipmentBounds[frame];
    final scale = math.min(target.width / bounds[2], target.height / bounds[3]);
    final w = bounds[2] * scale;
    final h = bounds[3] * scale;
    c.save();
    c.translate(target.center.dx, target.bottom);
    c.scale(facing.toDouble(), 1);
    c.drawImageRect(
      image,
      ui.Rect.fromLTWH(bounds[0], bounds[1], bounds[2], bounds[3]),
      ui.Rect.fromLTWH(-w / 2, -h, w, h),
      _paint,
    );
    c.restore();
    return true;
  }

  static bool backdrop(ui.Canvas c, int mission, double camera) {
    final image = _images['world'];
    if (image == null) return false;
    final sourceHeight = image.height / 2;
    final width = image.width / sourceHeight * 218;
    final scroll = camera * .18;
    final offset = scroll % width;
    final segment = (scroll / width).floor();
    for (var i = 0; i < 2; i++) {
      c.save();
      c.translate(i * width - offset, 0);
      // Alternate mirrored segments so the panorama joins without a hard cut.
      if ((segment + i).isOdd) {
        c.translate(width, 0);
        c.scale(-1, 1);
      }
      c.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          0,
          mission == 1 ? sourceHeight : 0,
          image.width.toDouble(),
          sourceHeight,
        ),
        ui.Rect.fromLTWH(0, 0, width, 218),
        _paint,
      );
      c.restore();
    }
    return true;
  }

  static void missionPreview(ui.Canvas c, ui.Size size, int mission) {
    final image = _images['world'];
    if (image == null || size.isEmpty) return;
    final half = image.height / 2;
    final width = math.min(
      image.width.toDouble(),
      half * size.width / size.height,
    );
    c.drawImageRect(
      image,
      ui.Rect.fromLTWH(
        (image.width - width) / 2,
        mission == 1 ? half : 0,
        width,
        half,
      ),
      ui.Offset.zero & size,
      _paint,
    );
  }

  static bool floor(ui.Canvas c, int mission, double camera) {
    final image = _images['world'];
    if (image == null) return false;
    final half = image.height / 2;
    final startY = mission == 1 ? image.height - 48.0 : half - 48;
    for (var i = -1; i < 5; i++) {
      c.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, startY, 384, 48),
        ui.Rect.fromLTWH(i * 128 - camera % 128, 218, 128, 52),
        _paint,
      );
    }
    return true;
  }
}

class _PoseClock {
  _PoseClock(this.state, this.started);
  final String state;
  final double started;
}
