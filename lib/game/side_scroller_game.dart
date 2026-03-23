import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Rect;
import 'components/collectible.dart';
import 'components/enemy.dart';
import 'components/goal.dart';
import 'components/player.dart';
import 'config/game_config.dart';
import 'core/game_state.dart';
import 'levels/level_loader.dart';
import 'ui/hud.dart';

/// The main game class. Owns the game state, spawns all components,
/// handles keyboard input, and checks entity collisions each frame.
class SideScrollerGame extends FlameGame with KeyboardEvents {
  @override
  Color backgroundColor() => const Color(0xFF5C94FC); // sky blue

  Player? _player;
  late LevelData levelData;
  final GameState gameState = GameState();
  final List<Enemy> _enemies = [];
  final List<Collectible> _collectibles = [];
  Goal? _goal;
  bool _resetting = false;

  /// Null-safe accessor for touch controls and other external callers.
  Player? get playerOrNull => _player;

  /// Non-null accessor used internally after onLoad.
  Player get player => _player!;

  // ── Overlay names ──────────────────────────────────────
  static const String gameOverOverlay = 'GameOver';
  static const String winOverlay = 'Win';

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _loadLevel();
  }

  void _loadLevel() {
    // Load level data
    levelData = LevelLoader.load(LevelLoader.level1);

    // Add ground blocks
    for (final component in levelData.components) {
      add(component);
    }

    // Spawn enemies
    for (final pos in levelData.enemySpawns) {
      final enemy = Enemy(position: pos.clone());
      _enemies.add(enemy);
      add(enemy);
    }

    // Spawn collectibles
    for (final pos in levelData.collectiblePositions) {
      final collectible = Collectible(position: pos.clone());
      _collectibles.add(collectible);
      add(collectible);
    }

    // Spawn goal
    if (levelData.goalPosition != null) {
      _goal = Goal(position: levelData.goalPosition!.clone());
      add(_goal!);
    }

    // Spawn the player
    _player = Player(position: levelData.playerSpawn.clone());
    add(player);

    // HUD (added to viewport so it stays fixed on screen)
    camera.viewport.add(Hud(gameState: gameState));

    // Camera follows the player
    camera.follow(player, maxSpeed: 300, snap: true);
    camera.setBounds(
      Rectangle.fromRect(
        Rect.fromLTWH(0, 0, levelData.worldWidth, levelData.worldHeight),
      ),
    );
  }

  // ── Update ─────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    if (_player == null || gameState.isGameOver || gameState.isWin) return;

    _checkCollectibleCollisions();
    _checkEnemyCollisions();
    _checkGoalCollision();
    _checkFallOffMap();
  }

  void _checkCollectibleCollisions() {
    for (final c in _collectibles) {
      if (!c.isCollected && _playerOverlaps(c)) {
        c.isCollected = true;
        gameState.addScore(GameConfig.collectibleScore);
      }
    }
  }

  void _checkEnemyCollisions() {
    for (final enemy in _enemies) {
      if (!enemy.isActive) continue;
      if (!_playerOverlaps(enemy)) continue;

      final playerBottom = player.position.y + player.size.y;
      final enemyTop = enemy.position.y;

      // Stomping: player is falling and feet are near enemy top
      if (player.velocity.y > 0 &&
          playerBottom - enemyTop < GameConfig.stompThreshold) {
        enemy.isActive = false;
        player.velocity.y = GameConfig.jumpForce * GameConfig.stompBounce;
        gameState.addScore(GameConfig.stompScore);
      } else {
        _onPlayerHit();
      }
    }
  }

  void _checkGoalCollision() {
    if (_goal != null && _playerOverlaps(_goal!)) {
      gameState.win();
      overlays.add(winOverlay);
      pauseEngine();
    }
  }

  void _checkFallOffMap() {
    if (player.position.y > levelData.worldHeight + GameConfig.fallDeathBuffer) {
      _onPlayerHit();
    }
  }

  void _onPlayerHit() {
    gameState.loseLife();
    if (gameState.isGameOver) {
      overlays.add(gameOverOverlay);
      pauseEngine();
    } else {
      // Respawn at start
      player.position.setFrom(levelData.playerSpawn);
      player.velocity.setZero();
    }
  }

  bool _playerOverlaps(PositionComponent other) {
    return player.position.x < other.position.x + other.size.x &&
        player.position.x + player.size.x > other.position.x &&
        player.position.y < other.position.y + other.size.y &&
        player.position.y + player.size.y > other.position.y;
  }

  // ── Restart ────────────────────────────────────────────

  void restart() {
    if (_resetting) return;
    _resetting = true;

    // Pause first to prevent update() running on stale state
    pauseEngine();
    overlays.remove(gameOverOverlay);
    overlays.remove(winOverlay);

    // Clear all game components
    removeAll(children);
    camera.viewport.removeAll(camera.viewport.children);
    _enemies.clear();
    _collectibles.clear();
    _goal = null;
    _player = null;
    gameState.reset();

    // Reload after removals are processed
    Future.microtask(() {
      _loadLevel();
      resumeEngine();
      _resetting = false;
    });
  }

  // ── Keyboard ───────────────────────────────────────────

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // R to restart anytime
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyR) {
      restart();
      return KeyEventResult.handled;
    }

    _player?.onKeyEvent(event);
    return KeyEventResult.handled;
  }
}
