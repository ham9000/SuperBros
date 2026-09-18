import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/core/progress_store.dart';
import 'game/ui/ruckus_app.dart';
import 'game/rendering/art_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ArtAssets.load();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(RuckusApp(progress: await ProgressStore.load()));
}
