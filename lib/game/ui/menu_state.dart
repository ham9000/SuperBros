enum AppScreen { title, main, characters, levels, help, credits, mission }

class CharacterInfo {
  const CharacterInfo(
    this.name,
    this.role,
    this.description,
    this.attributes, {
    this.locked = true,
  });

  final String name;
  final String role;
  final String description;
  final String attributes;
  final bool locked;
}

class MissionInfo {
  const MissionInfo(
    this.name,
    this.region,
    this.description, {
    this.locked = true,
  });

  final String name;
  final String region;
  final String description;
  final bool locked;
}

class MenuState {
  static const characters = [
    CharacterInfo(
      'Rook',
      'THE IMPROVISER',
      'Big scarf. Bigger bad ideas.',
      'SPEED  ★★★★    ARMOR  ★★★    GRIT  ★★★★★',
      locked: false,
    ),
    CharacterInfo(
      'Nyx',
      'THE NIGHT SHIFT',
      'Currently on a very long lunch.',
      'STEALTH  ★★★★★    GRIT  ★★★',
    ),
    CharacterInfo(
      'Bolt',
      'THE LIVE WIRE',
      'Still looking for the off switch.',
      'SPEED  ★★★★★    GRIT  ★★★',
    ),
    CharacterInfo(
      'Mae',
      'THE FIXER',
      'Can repair anything. Except the plan.',
      'ARMOR  ★★★★★    GRIT  ★★★★',
    ),
  ];

  static const levels = [
    MissionInfo(
      'Iron Harbor',
      '01 / THE RUST COAST',
      'Free the dock crew. Borrow a tank. Cancel a very large robot.',
      locked: false,
    ),
    MissionInfo(
      'Desert Convoy',
      '02 / THE DUST BELT',
      'A road trip with extremely poor reviews.',
    ),
    MissionInfo(
      'Jungle Foundry',
      '03 / THE GREEN MACHINE',
      'Heavy industry. Heavier foliage.',
    ),
  ];

  AppScreen screen = AppScreen.title;
  AppScreen helpReturn = AppScreen.main;
  int character = 0;
  int level = 0;

  bool selectCharacter(int index) {
    if (index < 0 || index >= characters.length || characters[index].locked) {
      return false;
    }
    character = index;
    screen = AppScreen.levels;
    return true;
  }

  bool selectLevel(int index) {
    if (index < 0 || index >= levels.length || levels[index].locked) {
      return false;
    }
    level = index;
    screen = AppScreen.mission;
    return true;
  }

  void showHelp() {
    helpReturn = screen;
    screen = AppScreen.help;
  }

  void back() {
    screen = switch (screen) {
      AppScreen.title => AppScreen.title,
      AppScreen.main => AppScreen.title,
      AppScreen.characters => AppScreen.main,
      AppScreen.levels => AppScreen.characters,
      AppScreen.help => helpReturn,
      AppScreen.credits => AppScreen.main,
      AppScreen.mission => AppScreen.main,
    };
  }
}
