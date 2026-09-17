import 'dart:math' as math;

import '../config/game_config.dart';
import 'entities.dart';

enum EnemyLifecycle { dormant, entering, active, defeated }

enum EntranceType {
  screenEdge,
  doorway,
  trench,
  dropFromAbove,
  background,
  vehicle,
  rearAmbush,
}

enum SpawnTrigger {
  forwardEdge,
  playerCrossed,
  entranceComplete,
  encounterWave,
}

/// Authored world geometry, shared by every member of an entrance group.
class EntranceMarker {
  const EntranceMarker({
    required this.id,
    required this.x,
    required this.allowed,
    this.y = GameConfig.groundY - 28,
    this.weights = const {},
    this.clearance = 100,
  });
  final String id;
  final double x, y, clearance;
  final Set<EntranceType> allowed;
  final Map<EntranceType, int> weights;
}

class EnemySpawnDefinition {
  const EnemySpawnDefinition({
    this.allowed = const {...EntranceType.values},
    this.weights = const {},
    this.forced,
    this.marker,
    this.trigger = SpawnTrigger.forwardEdge,
    this.triggerX,
    this.prerequisite,
    this.wave = 0,
    this.scripted = false,
    this.boss = false,
    this.tutorial = false,
    this.randomizeSpecial = false,
    this.entranceVulnerable = false,
    this.landingOffset = 0,
  });
  final Set<EntranceType> allowed;
  final Map<EntranceType, int> weights;
  final EntranceType? forced;
  final EntranceMarker? marker;
  final SpawnTrigger trigger;
  final double? triggerX;
  final double landingOffset;
  final String? prerequisite;
  final int wave;
  final bool scripted, boss, tutorial, randomizeSpecial, entranceVulnerable;
}

/// A pure simulation snapshot. No renderer or platform dependency is needed.
class EnemySpawnContext {
  const EnemySpawnContext({
    required this.playerX,
    required this.cameraX,
    this.facing = 1,
    this.cameraY = 0,
    this.viewportWidth = GameConfig.viewportWidth,
    this.viewportHeight = GameConfig.viewportHeight,
    this.firstEncounter = false,
    this.forwardPressure = false,
    this.enteringCount = 0,
    this.wave = 0,
    this.completed = const {},
  });
  final double playerX, cameraX, cameraY, viewportWidth, viewportHeight;
  final int facing, enteringCount, wave;
  final bool firstEncounter, forwardPressure;
  final Set<String> completed;
  double get forwardEdge => cameraX + (facing > 0 ? viewportWidth : 0);
}

class EntranceChoice {
  const EntranceChoice(this.type, this.seed, this.exclusions, {this.marker});
  final EntranceType type;
  final int seed;
  final EntranceMarker? marker;
  final Map<EntranceType, String> exclusions;
}

/// Seed once per mission; choices are made at initialization, never on entry.
/// Pass the entire group to [chooseGroupEntrance] to intersect compatibility.
class EntranceSelector {
  EntranceSelector(this.seed) : _random = math.Random(seed);
  final int seed;
  final math.Random _random;
  int _choices = 0, _rear = 0;
  EntranceType? _previous;
  static const weights = {
    EntranceType.screenEdge: 35,
    EntranceType.doorway: 18,
    EntranceType.trench: 15,
    EntranceType.dropFromAbove: 14,
    EntranceType.background: 10,
    EntranceType.vehicle: 5,
    EntranceType.rearAmbush: 3,
  };

  EntranceChoice chooseEntrance(
    EnemyType kind,
    EnemySpawnDefinition definition,
    EnemySpawnContext context,
  ) => chooseGroupEntrance([(kind, definition)], context);

  EntranceChoice chooseGroupEntrance(
    List<(EnemyType, EnemySpawnDefinition)> members,
    EnemySpawnContext context,
  ) {
    if (members.isEmpty) {
      throw ArgumentError('An entrance group cannot be empty');
    }
    final excluded = <EntranceType, String>{};
    final first = members.first.$2;
    for (final type in EntranceType.values) {
      for (final (kind, definition) in members) {
        String? reason;
        final marker = definition.marker;
        if (!definition.allowed.contains(type)) reason = 'definition';
        if (marker != null && !marker.allowed.contains(type)) reason = 'marker';
        if (kind == EnemyType.turret &&
            type != EntranceType.screenEdge &&
            type != EntranceType.doorway) {
          reason = 'stationary turret';
        }
        if (type != EntranceType.screenEdge &&
            type != EntranceType.rearAmbush &&
            (marker == null ||
                marker.clearance < 64 ||
                marker.x < 32 ||
                marker.x > GameConfig.worldWidth - 64 ||
                marker.y < 80 ||
                marker.y > GameConfig.groundY - 28)) {
          reason = 'missing or unsafe geometry';
        }
        if (type != EntranceType.screenEdge &&
            members.any((m) => m.$2.marker?.id != first.marker?.id)) {
          reason = 'group needs shared marker';
        }
        if (type == EntranceType.rearAmbush) {
          if (definition.tutorial ||
              context.firstEncounter ||
              definition.boss) {
            reason = 'protected encounter';
          } else if (context.forwardPressure && !definition.scripted) {
            reason = 'forward projectile pressure';
          } else if (!definition.scripted &&
              (_rear + 1) / (_choices + 1) > GameConfig.rearEntranceCap) {
            reason = 'rear encounter cap';
          }
        }
        if (reason != null) excluded[type] = reason;
      }
    }
    var selected = EntranceType.screenEdge;
    final forced = members.map((m) => m.$2.forced).toSet();
    if (forced.any((f) => f != null)) {
      if (forced.length == 1 && !excluded.containsKey(forced.single)) {
        selected = forced.single!;
      }
    } else if (!members.any(
      (m) =>
          (m.$2.boss || m.$2.scripted || m.$2.tutorial) &&
          !m.$2.randomizeSpecial,
    )) {
      final candidates = <EntranceType, double>{};
      for (final type in EntranceType.values) {
        if (excluded.containsKey(type)) continue;
        final weight =
            first.weights[type] ??
            first.marker?.weights[type] ??
            weights[type]!;
        if (weight <= 0) continue;
        candidates[type] =
            weight *
            (type == _previous && type != EntranceType.screenEdge ? 0.25 : 1);
      }
      final total = candidates.values.fold(0.0, (a, b) => a + b);
      var roll = _random.nextDouble() * total;
      for (final entry in candidates.entries) {
        roll -= entry.value;
        if (roll < 0) {
          selected = entry.key;
          break;
        }
      }
    }
    _choices++;
    if (selected == EntranceType.rearAmbush) _rear++;
    _previous = selected;
    return EntranceChoice(
      selected,
      seed,
      Map.unmodifiable(excluded),
      marker:
          selected == EntranceType.screenEdge ||
                  selected == EntranceType.rearAmbush
              ? null
              : first.marker,
    );
  }
}
