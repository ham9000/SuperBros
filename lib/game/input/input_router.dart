import 'package:flutter/services.dart';

import '../core/game_input.dart';

/// Each physical source owns its press: lifting a finger cannot release a key.
class InputRouter {
  InputRouter(this.input);
  final GameInput input;
  final Map<Command, Set<Object>> _sources = {};

  static final keys = {
    LogicalKeyboardKey.keyA: Command.left,
    LogicalKeyboardKey.arrowLeft: Command.left,
    LogicalKeyboardKey.keyD: Command.right,
    LogicalKeyboardKey.arrowRight: Command.right,
    LogicalKeyboardKey.keyW: Command.up,
    LogicalKeyboardKey.arrowUp: Command.up,
    LogicalKeyboardKey.keyS: Command.down,
    LogicalKeyboardKey.arrowDown: Command.down,
    LogicalKeyboardKey.space: Command.jump,
    LogicalKeyboardKey.keyJ: Command.fire,
    LogicalKeyboardKey.keyK: Command.grenade,
    LogicalKeyboardKey.keyL: Command.interact,
    LogicalKeyboardKey.keyE: Command.interact,
  };

  void set(Command command, Object source, bool pressed) {
    final sources = _sources.putIfAbsent(command, () => {});
    if (pressed) {
      if (sources.add(source) && sources.length == 1) input.press(command);
    } else {
      sources.remove(source);
      if (sources.isEmpty) input.release(command);
    }
  }

  bool key(KeyEvent event) {
    final command = keys[event.logicalKey];
    if (command == null) return false;
    set(command, event.logicalKey, event is! KeyUpEvent);
    return true;
  }

  void clear() {
    _sources.clear();
    input.clear();
  }
}
