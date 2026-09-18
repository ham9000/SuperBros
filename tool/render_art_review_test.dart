// Run: flutter test tool/render_art_review_test.dart
// Staged scenes use the real renderer, not a full-playthrough claim.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/core/game_state.dart';
import 'package:super_bros/game/rendering/art_assets.dart';
import 'package:super_bros/game/rendering/pixel_art.dart';

Future<void> capture(String name, GameState state) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(3);
  PixelArt.renderScene(canvas,state);
  final picture = recorder.endRecording();
  final image = await picture.toImage(1440,810);
  final data = await image.toByteData(format:ui.ImageByteFormat.png);
  final file=File('build/art-review/$name.png');
  await file.parent.create(recursive:true);
  await file.writeAsBytes(data!.buffer.asUint8List());
  image.dispose(); picture.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('capture both missions, all units, and a staged boss encounter', () async {
    await ArtAssets.load();
    for(var mission=0;mission<2;mission++) {
      for(var unit=0;unit<5;unit++) {
        final s=GameState(characterIndex:unit,missionIndex:mission)
          ..cameraX=220 ..calloutTime=0;
        s.player.x=320;
        for(final enemy in s.enemies.take(2)) {
          enemy.lifecycle=EnemyLifecycle.active;
          enemy.stance=EnemyStance.standing;
        }
        await capture('mission-$mission-unit-$unit',s);
      }
    }
    final s=GameState(characterIndex:1,missionIndex:1)..calloutTime=0;
    s.cameraX=s.boss.x-290;
    s.player.x=s.cameraX+80;
    s.boss.active=true;
    s.boss.vulnerable=true;
    s.boss.telegraph=false;
    await capture('boss-exposed',s);
    s.boss.vulnerable=false;
    s.boss.telegraph=true;
    await capture('boss-warning',s);
  });
}
