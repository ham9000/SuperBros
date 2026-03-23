/// Centralized tunable constants for the game.
///
/// All physics values, sizes, and speeds live here so they're
/// easy to find and tweak during prototyping.
class GameConfig {
  // ── Player ────────────────────────────────────────────
  static const double playerWidth = 32;
  static const double playerHeight = 48;
  static const double playerSpeed = 200; // px/s
  static const double jumpForce = -400; // negative = upward
  static const double gravity = 1000; // px/s²
  static const double maxFallSpeed = 600;
  static const int startingLives = 3;

  // ── World ─────────────────────────────────────────────
  static const double tileSize = 32;
  static const double groundY = 400; // y-position of the ground surface

  // ── Viewport ──────────────────────────────────────────
  static const double viewportWidth = 800;
  static const double viewportHeight = 600;

  // ── Enemy ─────────────────────────────────────────────
  static const double enemySpeed = 60;
  static const double enemyWidth = 32;
  static const double enemyHeight = 32;

  // ── Collectible ───────────────────────────────────────
  static const double collectibleSize = 20;
  static const int collectibleScore = 100;

  // ── Camera ────────────────────────────────────────────
  static const double cameraLerpSpeed = 4.0;

  // ── Debug ─────────────────────────────────────────────
  static const bool debugMode = false;
}
