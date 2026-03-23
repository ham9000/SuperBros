/// Central place for all gameplay constants.
/// Tweak these values to adjust the feel of the game.
class GameConfig {
  GameConfig._(); // prevent instantiation

  // ── Player ──────────────────────────────────────────────────────────────
  static const double playerWidth = 32.0;
  static const double playerHeight = 48.0;
  static const double playerMoveSpeed = 200.0;
  static const double playerJumpForce = -480.0; // negative = upward
  static const double playerMaxFallSpeed = 600.0;

  // ── Physics ─────────────────────────────────────────────────────────────
  static const double gravity = 980.0; // pixels / s²

  // ── Ground / platforms ─────────────────────────────────────────────────
  static const double groundThickness = 32.0;

  // ── World ───────────────────────────────────────────────────────────────
  /// Logical world width (used for ground length and camera bounds).
  static const double worldWidth = 3200.0;
  static const double worldHeight = 640.0;

  // ── Viewport ────────────────────────────────────────────────────────────
  static const double viewportWidth = 800.0;
  static const double viewportHeight = 450.0;
}
