import 'package:flutter_test/flutter_test.dart';
import 'package:super_bros/game/config/game_config.dart';
import 'package:super_bros/game/core/game_state.dart';

void main() {
  test('a new game starts with configured lives and no result', () {
    final state = GameState();

    expect(state.score, 0);
    expect(state.lives, GameConfig.startingLives);
    expect(state.isGameOver, isFalse);
    expect(state.isWin, isFalse);
  });

  test('collectible and stomp scores accumulate', () {
    final state = GameState();
    state.addScore(GameConfig.collectibleScore);
    state.addScore(GameConfig.stompScore);

    expect(state.score, GameConfig.collectibleScore + GameConfig.stompScore);
  });

  test('only the final life ends the game and lives never become negative', () {
    final state = GameState();
    for (var remaining = GameConfig.startingLives - 1;
        remaining >= 0;
        remaining--) {
      state.loseLife();
      expect(state.lives, remaining);
      expect(state.isGameOver, remaining == 0);
    }

    state.loseLife();
    expect(state.lives, 0);
    expect(state.isGameOver, isTrue);
  });

  test('reset clears score, lost lives, and both end states', () {
    final state = GameState();
    state.addScore(GameConfig.collectibleScore);
    for (var i = 0; i < GameConfig.startingLives; i++) {
      state.loseLife();
    }
    state.win();
    expect(state.isWin, isTrue);

    state.reset();

    expect(state.score, 0);
    expect(state.lives, GameConfig.startingLives);
    expect(state.isGameOver, isFalse);
    expect(state.isWin, isFalse);
  });
}
