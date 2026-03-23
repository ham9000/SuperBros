import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/side_scroller_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    GameWidget(game: SideScrollerGame()),
  );
}
