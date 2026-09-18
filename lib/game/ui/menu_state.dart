enum AppScreen { title, main, characters, levels, help, credits, mission }

class CharacterInfo {
  const CharacterInfo(
    this.unit,
    this.name,
    this.role,
    this.description,
    this.attributes, {
    this.locked = true,
  });

  final String unit;
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
      '01',
      'Unit 01',
      'RESILIENT POINT MAN',
      'White-blue armor, spiky hair, and enough coffee to keep moving.',
      'UNIT 01  ★★★★ SPEED    ★★★ ARMOR    ★★★★★ GRIT',
      locked: false,
    ),
    CharacterInfo(
      '02',
      'Unit 02',
      'ARMORED ASSAULT',
      'Helmet sealed. Armor tagged. Same mission, heavier answers.',
      'UNIT 02  ★★ SPEED    ★★★★★ ARMOR    ★★★★★ FIREPOWER',
      locked: false,
    ),
    CharacterInfo(
      '03',
      'Unit 03',
      'QUICK STRIKE',
      'Ponytail, cheek bandage, and a comeback for every firefight.',
      'UNIT 03  ★★★★★ SPEED    ★★★ ARMOR    ★★★★ STYLE',
      locked: false,
    ),
    CharacterInfo(
      '04',
      'Unit 04',
      'GROUND ANCHOR',
      'Calm under fire in blue-black armor with orange shoulders.',
      'UNIT 04  ★★★ SPEED    ★★★★ ARMOR    ★★★★★ FOCUS',
      locked: false,
    ),
    CharacterInfo(
      '05',
      'Unit 05',
      'REDLINE RAIDER',
      'Red hair, red-white armor, and a grin that outruns the alarms.',
      'UNIT 05  ★★★★★ SPEED    ★★★ ARMOR    ★★★★★ ENERGY',
      locked: false,
    ),
  ];

  static const levels = [
    MissionInfo(
      'Shipping Yard / Iron Harbor',
      '01 / RUST COAST',
      'Free the dock crew through cranes, containers, and a walker blockade.',
      locked: false,
    ),
    MissionInfo(
      'Airport / Transit Hub',
      '02 / SKYLINE TERMINAL',
      'Push through arrivals, concourses, baggage belts, gates, and apron robots.',
      locked: false,
    ),
    MissionInfo(
      'Desert Convoy',
      '03 / THE DUST BELT',
      'A road trip with extremely poor reviews.',
    ),
    MissionInfo(
      'Jungle Foundry',
      '04 / THE GREEN MACHINE',
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
