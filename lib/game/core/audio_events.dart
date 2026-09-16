enum AudioEvent {
  menuSelection,
  jump,
  shot,
  melee,
  grenade,
  explosion,
  hit,
  pickup,
  rescue,
  vehicle,
  boss,
  victory,
  gameOver,
  checkpoint,
}

/// Optional presentation hook; the simulation remains silent and platform-free.
class AudioBus {
  AudioBus({this.onEvent});

  void Function(AudioEvent event)? onEvent;
  bool muted = false;

  void emit(AudioEvent event) {
    if (!muted) onEvent?.call(event);
  }
}
