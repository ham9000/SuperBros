import '../config/game_config.dart';

/// Tracks score, lives, and game-over/win state.
///
/// This is a plain Dart object — not a Flame component.
/// The game class owns one instance and passes it around.
class GameState {
  int score = 0;
  int lives = GameConfig.startingLives;
  bool isGameOver = false;
  bool isWin = false;

  void addScore(int points) {
    score += points;
  }

  void loseLife() {
    lives--;
    if (lives <= 0) {
      lives = 0;
      isGameOver = true;
    }
  }

  void win() {
    isWin = true;
  }

  void reset() {
    score = 0;
    lives = GameConfig.startingLives;
    isGameOver = false;
    isWin = false;
  }
}
