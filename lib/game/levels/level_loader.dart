import 'package:flame/components.dart';
import '../components/ground.dart';
import '../config/game_config.dart';

/// Builds a level from a simple tile-map grid.
///
/// Each character in the grid maps to a component:
///   'G' = ground block
///   'P' = player spawn point (stored, not a component)
///   'E' = enemy spawn point
///   'C' = collectible
///   'W' = win goal
///   '.' = empty space
///
/// The grid is read top-to-bottom, left-to-right.
class LevelLoader {
  /// The level grid — each string is one row of tiles.
  static const List<String> level1 = [
    //  0         1         2         3         4         5         6         7         8
    //  0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567
    '..................................................................................',
    '..................................................................................',
    '..................................................................................',
    '..................................................................................',
    '..................................................................................',
    '..................................CCC..........................................W...',
    '...........................GGGGGGGGGGG.........................................G...',
    '..................................................................................',
    '..............C..........................................................C........',
    '..........GGGGGGGG...................GGGG...........GGGGG.....GGGGGGGGGGGGGG.......',
    '.....C..............E.........................................................E...',
    '..P..GGGGG...GGGGGGGGGGG..GGG....GGGGGGGGGGG..GGG.......GGG.GGGGGGGGGGGGGGGGGGGG',
    'GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG',
  ];

  static const double _tile = GameConfig.tileSize;

  /// Parse the level grid and return all components + metadata.
  static LevelData load(List<String> grid) {
    final components = <Component>[];
    Vector2 playerSpawn = Vector2(100, 300);
    final enemySpawns = <Vector2>[];
    final collectiblePositions = <Vector2>[];
    Vector2? goalPosition;

    for (int row = 0; row < grid.length; row++) {
      for (int col = 0; col < grid[row].length; col++) {
        final char = grid[row][col];
        final pos = Vector2(col * _tile, row * _tile);

        switch (char) {
          case 'G':
            components.add(Ground(
              position: pos,
              size: Vector2(_tile, _tile),
            ));
            break;
          case 'P':
            // Place player feet at bottom of this tile cell
            playerSpawn = Vector2(
              pos.x,
              pos.y + _tile - GameConfig.playerHeight,
            );
            break;
          case 'E':
            // Place enemy feet at bottom of this tile cell
            enemySpawns.add(Vector2(
              pos.x,
              pos.y + _tile - GameConfig.enemyHeight,
            ));
            break;
          case 'C':
            collectiblePositions.add(Vector2(
              pos.x + (_tile - GameConfig.collectibleSize) / 2,
              pos.y + (_tile - GameConfig.collectibleSize) / 2,
            ));
            break;
          case 'W':
            // Goal extends upward from tile bottom
            goalPosition = Vector2(pos.x, pos.y + _tile - GameConfig.tileSize * 2);
            break;
        }
      }
    }

    return LevelData(
      components: components,
      playerSpawn: playerSpawn,
      enemySpawns: enemySpawns,
      collectiblePositions: collectiblePositions,
      goalPosition: goalPosition,
      worldWidth: (grid.isNotEmpty ? grid[0].length : 0) * _tile,
      worldHeight: grid.length * _tile,
    );
  }
}

/// Holds all parsed data from a level grid.
class LevelData {
  final List<Component> components;
  final Vector2 playerSpawn;
  final List<Vector2> enemySpawns;
  final List<Vector2> collectiblePositions;
  final Vector2? goalPosition;
  final double worldWidth;
  final double worldHeight;

  const LevelData({
    required this.components,
    required this.playerSpawn,
    required this.enemySpawns,
    required this.collectiblePositions,
    this.goalPosition,
    required this.worldWidth,
    required this.worldHeight,
  });
}
