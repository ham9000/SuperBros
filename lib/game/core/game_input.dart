enum Command { left, right, up, down, jump, fire, grenade, interact }

/// Holds continuous controls separately from single-press actions.
class GameInput {
  final Set<Command> _held = {};
  final Set<Command> _pressed = {};

  bool held(Command command) => _held.contains(command);

  void press(Command command) {
    if (_held.add(command)) _pressed.add(command);
  }

  void release(Command command) => _held.remove(command);

  bool consume(Command command) => _pressed.remove(command);

  void clearEdges() => _pressed.clear();

  void clear() {
    _held.clear();
    _pressed.clear();
  }
}
