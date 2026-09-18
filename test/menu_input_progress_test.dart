import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_bros/game/core/game_input.dart';
import 'package:super_bros/game/core/progress_store.dart';
import 'package:super_bros/game/input/input_router.dart';
import 'package:super_bros/game/ui/menu_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only released characters and levels can advance navigation', () {
    final menu = MenuState()..screen = AppScreen.characters;
    expect(MenuState.characters.map((c) => c.unit), [
      '01',
      '02',
      '03',
      '04',
      '05',
    ]);
    expect(MenuState.characters.where((c) => !c.locked).length, 5);
    expect(MenuState.levels.where((l) => !l.locked).length, 2);
    for (var i = 0; i < MenuState.characters.length; i++) {
      if (!MenuState.characters[i].locked) continue;
      expect(menu.selectCharacter(i), isFalse);
      expect(menu.screen, AppScreen.characters);
    }
    expect(menu.selectCharacter(-1), isFalse);
    expect(menu.selectCharacter(MenuState.characters.length), isFalse);
    expect(menu.selectCharacter(0), isTrue);
    for (var i = 0; i < MenuState.levels.length; i++) {
      if (!MenuState.levels[i].locked) continue;
      expect(menu.selectLevel(i), isFalse);
      expect(menu.screen, AppScreen.levels);
    }
    expect(menu.selectLevel(MenuState.levels.length), isFalse);
    expect(menu.selectLevel(0), isTrue);
    expect(menu.screen, AppScreen.mission);
    menu.screen = AppScreen.characters;
    for (var i = 0; i < MenuState.characters.length; i++) {
      expect(menu.selectCharacter(i), isTrue);
      expect(menu.character, i);
      expect(menu.screen, AppScreen.levels);
      menu.screen = AppScreen.levels;
      for (var level = 0; level < 2; level++) {
        expect(menu.selectLevel(level), isTrue);
        expect(menu.level, level);
        expect(menu.screen, AppScreen.mission);
        menu.screen = AppScreen.levels;
      }
      menu.screen = AppScreen.characters;
    }
  });

  test('help returns to its caller, not always the main menu', () {
    final menu = MenuState()..screen = AppScreen.mission;
    menu.showHelp();
    menu.back();
    expect(menu.screen, AppScreen.mission);
    menu.screen = AppScreen.main;
    menu.showHelp();
    menu.back();
    expect(menu.screen, AppScreen.main);
  });

  test('independent touch and keyboard sources retain held commands', () {
    final input = GameInput();
    final router = InputRouter(input);
    router.set(Command.left, LogicalKeyboardKey.keyA, true);
    router.set(Command.left, 1, true);
    router.set(Command.left, 1, false);
    expect(input.held(Command.left), isTrue);
    router.set(Command.left, LogicalKeyboardKey.keyA, false);
    expect(input.held(Command.left), isFalse);
    router.set(Command.fire, 2, true);
    router.clear();
    expect(input.held(Command.fire), isFalse);
  });

  test('progress persists only best score, completion, and help', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressStore.load();
    await progress.record(1200, victory: true);
    await progress.record(100, victory: false);
    await progress.acknowledgeHelp();
    final restored = await ProgressStore.load();
    expect(restored.bestScore, 1200);
    expect(restored.completed, isTrue);
    expect(restored.helpSeen, isTrue);
    expect(MenuState.characters.where((c) => !c.locked).length, 5);
    expect(MenuState.levels.where((l) => !l.locked).length, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'ruckus.best', 'ruckus.completed', 'ruckus.help'});
  });

  test(
    'memory-only progress remains playable without a storage backend',
    () async {
      final progress = ProgressStore();
      await progress.record(750, victory: false);
      expect(progress.bestScore, 750);
      expect(progress.completed, isFalse);
    },
  );
}
