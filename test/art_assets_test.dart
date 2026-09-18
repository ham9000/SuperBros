import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/rendering/art_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ArtAssets.load);

  test('every unit has visible artwork for all supported poses', () async {
    expect(ArtAssets.ready, isTrue);
    for (var unit = 0; unit < 5; unit++) {
      for (final state in ['idle','run','jump','crouch','fire','hurt','death','hero','rest','taunt']) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        expect(ArtAssets.character(canvas,unit,state,0,128,224,size:256),isTrue);
        final picture = recorder.endRecording();
        final image = await picture.toImage(256,256);
        final pixels = (await image.toByteData())!.buffer.asUint8List();
        var opaque = 0;
        for(var i=3;i<pixels.length;i+=4) {
          if(pixels[i]>128) opaque++;
        }
        expect(opaque,greaterThan(1200),reason:'Unit $unit $state must not be blank');
        expect(pixels[3],0,reason:'Sprite corners must be transparent');
        expect(pixels[pixels.length-1],0);
        image.dispose();
        picture.dispose();
      }
    }
  });

  test('death holds its final pose and a new action resets its clock', () {
    final actor = Object();
    expect(ArtAssets.poseTime(actor,'run',10),0);
    expect(ArtAssets.poseTime(actor,'run',11),1);
    expect(ArtAssets.poseTime(actor,'death',12),0);
    for(var unit=0;unit<5;unit++) {
      expect(ArtAssets.frameAt(unit,'death',100),ArtAssets.frames(unit,'death').last);
    }
    expect(ArtAssets.poseTime(actor,'idle',0),0);
  });
}
