import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_state.dart';
import '../core/progress_store.dart';
import '../input/input_router.dart';
import '../rendering/pixel_art.dart';
import '../side_scroller_game.dart';
import 'menu_state.dart';

const ink = Color(0xff102c3a);
const cream = Color(0xffffedbf);
const gold = Color(0xffffc857);
const mint = Color(0xff67ddbd);
const coral = Color(0xfff87754);

class RuckusApp extends StatelessWidget {
  const RuckusApp({super.key, required this.progress});
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operation Ruckus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: mint,
          surface: ink,
          onSurface: cream,
        ),
      ),
      home: RuckusShell(progress: progress),
    );
  }
}

class RuckusShell extends StatefulWidget {
  const RuckusShell({super.key, required this.progress});
  final ProgressStore progress;

  @override
  State<RuckusShell> createState() => RuckusShellState();
}

class RuckusShellState extends State<RuckusShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final menu = MenuState();
  final audio = AudioBus();
  final focus = FocusNode();
  late final AnimationController animation;
  GameState? session;
  SideScrollerGame? game;
  InputRouter? router;
  Widget? _gameWidget;
  bool _recorded = false;
  bool touchVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    animation.addListener(_checkResults);
  }

  void _checkResults() {
    final s = session;
    if (s == null || _recorded) return;
    if (s.status == MissionStatus.victory ||
        s.status == MissionStatus.gameOver) {
      _recorded = true;
      router?.clear();
      unawaited(
        widget.progress.record(
          s.score,
          victory: s.status == MissionStatus.victory,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    focus.dispose();
    router?.clear();
    super.dispose();
  }

  void _select(VoidCallback action) {
    audio.emit(AudioEvent.menuSelection);
    setState(action);
    focus.requestFocus();
  }

  void _start() {
    router?.clear();
    game?.pauseEngine();
    session = GameState(audio: audio);
    game = SideScrollerGame(session: session!);
    router = InputRouter(session!.input);
    _gameWidget = GameWidget<SideScrollerGame>(
      key: ObjectKey(game),
      game: game!,
      autofocus: false,
    );
    _recorded = false;
    menu.screen = AppScreen.mission;
  }

  void _leave(AppScreen screen) {
    router?.clear();
    game?.pauseEngine();
    _gameWidget = null;
    game = null;
    session = null;
    menu.screen = screen;
  }

  void _pause() {
    router?.clear();
    if (session?.status == MissionStatus.playing) {
      setState(() => session!.pause());
    }
  }

  void _back() {
    if (menu.screen == AppScreen.mission) {
      if (session?.status == MissionStatus.playing) {
        _pause();
      } else if (session?.status == MissionStatus.paused) {
        _select(() => session!.resume());
      }
    } else {
      _select(menu.back);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) _back();
      return KeyEventResult.handled;
    }
    if (menu.screen == AppScreen.mission &&
        session?.status == MissionStatus.playing) {
      return router!.key(event)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      switch (menu.screen) {
        case AppScreen.title:
          _select(() => menu.screen = AppScreen.main);
        case AppScreen.main:
          _select(() => menu.screen = AppScreen.characters);
        case AppScreen.characters:
          _select(() => menu.selectCharacter(0));
        case AppScreen.levels:
          _select(() {
            if (menu.selectLevel(0)) _start();
          });
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: _key,
        onFocusChange: (focused) {
          if (!focused) _pause();
        },
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final menuView = Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _HarborPainter(animation.value * 30)),
                Container(color: ink.withValues(alpha: .55)),
                SafeArea(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 960,
                        height: 540,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(40, 28, 40, 20),
                          child: _menuContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (session != null) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  _mission(),
                  if (menu.screen == AppScreen.help) menuView,
                ],
              );
            }
            return menuView;
          },
        ),
      ),
    );
  }

  Widget _menuContent() {
    return switch (menu.screen) {
      AppScreen.title => _title(),
      AppScreen.main => _mainMenu(),
      AppScreen.characters => _characters(),
      AppScreen.levels => _levels(),
      AppScreen.help => _help(),
      AppScreen.credits => _credits(),
      AppScreen.mission => const SizedBox.shrink(),
    };
  }

  Widget _title() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('A POCKET-SIZED REBELLION  /  VOL. 01'),
        const SizedBox(height: 28),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'OPERATION',
                      style: TextStyle(
                        color: cream,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'RUCKUS',
                        maxLines: 1,
                        style: TextStyle(
                          height: 1.1,
                          fontSize: 108,
                          fontWeight: FontWeight.w900,
                          color: gold,
                          letterSpacing: -6,
                          shadows: [Shadow(color: ink, offset: Offset(6, 6))],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SMALL HERO. MASSIVE PROPERTY DAMAGE.',
                      style: TextStyle(
                        color: mint,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OpButton(
                      label: 'TAP TO START  ▶',
                      onPressed:
                          () => _select(() => menu.screen = AppScreen.main),
                      color: animation.value % .04 > .02 ? gold : cream,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'or press ENTER',
                      style: TextStyle(color: cream, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -.07,
                      child: Container(
                        width: 270,
                        height: 290,
                        decoration: BoxDecoration(
                          color: coral,
                          border: Border.all(color: ink, width: 6),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 240,
                      height: 260,
                      child: _Portrait(variant: 0),
                    ),
                    Positioned(
                      bottom: 8,
                      child: _tag('“THIS IS PROBABLY FINE.”', cream),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _footer(
          'ORIGINAL ARCADE MISCHIEF',
          'IRON HARBOR • SINGLE PLAYER • NO QUARTERS REQUIRED',
        ),
      ],
    );
  }

  Widget _mainMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('OPERATION RUCKUS / FIELD OPERATIONS'),
        const SizedBox(height: 24),
        const Text(
          'MAKE SOME\nNOISE.',
          style: TextStyle(
            fontSize: 66,
            height: 1,
            fontWeight: FontWeight.w900,
            color: gold,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 310,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OpButton(
                    label: 'PLAY  ▶',
                    onPressed:
                        () => _select(() => menu.screen = AppScreen.characters),
                  ),
                  const SizedBox(height: 12),
                  OpButton(
                    label: 'HOW TO PLAY',
                    color: mint,
                    onPressed: () => _select(menu.showHelp),
                  ),
                  const SizedBox(height: 12),
                  OpButton(
                    label: 'CREDITS',
                    color: cream,
                    onPressed:
                        () => _select(() => menu.screen = AppScreen.credits),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('DISPATCH / 06:00'),
                    const SizedBox(height: 14),
                    const Text(
                      'The Brass Bureau stole our harbor.\nAnd our lunch breaks.',
                      style: TextStyle(fontSize: 20, color: cream),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Get the crew out.\nMake an unreasonable entrance.',
                      style: TextStyle(fontSize: 16, color: mint),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'BEST ${widget.progress.bestScore.toString().padLeft(6, '0')}'
                      '  /  ${widget.progress.completed ? 'HARBOR LIBERATED' : 'MISSION READY'}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        _footer('ESC / BACK', '100% ORIGINAL • 200% OVERCONFIDENT'),
      ],
    );
  }

  Widget _characters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('PICK YOUR PROBLEM.', '01 / CREW SELECT'),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(MenuState.characters.length, (index) {
              final c = MenuState.characters[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 3 ? 0 : 12),
                  child: Semantics(
                    label:
                        '${c.name}${c.locked ? ', locked, future content' : ''}',
                    child: _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _eyebrow(
                            c.locked
                                ? 'CLASSIFIED / 0${index + 1}'
                                : 'READY / 01',
                          ),
                          Expanded(
                            child: _Portrait(variant: index, locked: c.locked),
                          ),
                          Text(
                            c.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: c.locked ? Colors.blueGrey : gold,
                            ),
                          ),
                          Text(
                            c.role,
                            style: const TextStyle(fontSize: 11, color: mint),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            c.description,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          OpButton(
                            label: c.locked ? '🔒 COMING LATER' : 'SELECT ROOK',
                            compact: true,
                            onPressed:
                                c.locked
                                    ? null
                                    : () => _select(
                                      () => menu.selectCharacter(index),
                                    ),
                          ),
                        ],
                      ),
                      muted: c.locked,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        _footer(
          MenuState.characters[menu.character].attributes,
          'ENTER / SELECT ROOK',
        ),
      ],
    );
  }

  Widget _levels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('WHERE’S THE TROUBLE?', '02 / MISSION SELECT'),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(MenuState.levels.length, (index) {
              final l = MenuState.levels[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 16),
                  child: _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _eyebrow(l.region),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: l.locked ? const Color(0xff263c48) : mint,
                              border: Border.all(color: ink, width: 3),
                            ),
                            child: Center(
                              child: Icon(
                                [
                                  Icons.anchor,
                                  Icons.local_shipping,
                                  Icons.forest,
                                ][index],
                                size: 78,
                                color: l.locked ? Colors.blueGrey : ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: l.locked ? Colors.blueGrey : gold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 56,
                          child: Text(
                            l.description,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        OpButton(
                          label:
                              l.locked
                                  ? 'LOCKED / FUTURE MISSION'
                                  : 'DEPLOY  ▶',
                          compact: true,
                          onPressed:
                              l.locked
                                  ? null
                                  : () => _select(() {
                                    if (menu.selectLevel(index)) _start();
                                  }),
                        ),
                      ],
                    ),
                    muted: l.locked,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 18),
        _footer('ROOK / READY TO RUMBLE', 'ONE HARBOR. ONE VERY BAD PLAN.'),
      ],
    );
  }

  Widget _help() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('THE FIELD MANUAL.', 'READ THIS. WING THE REST.'),
        const SizedBox(height: 22),
        Expanded(
          child: SingleChildScrollView(
            child: _panel(
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'A / D  or  ← / →    MOVE\n'
                      'W / ↑              AIM UP\n'
                      'S / ↓              CROUCH\n'
                      'SPACE              JUMP\n'
                      'J                  FIRE / CLOSE MELEE\n'
                      'K                  GRENADE\n'
                      'E / L              RESCUE / ENTER / EXIT\n'
                      'ESC                PAUSE / BACK',
                      style: TextStyle(fontSize: 15, height: 1.9, color: cream),
                    ),
                  ),
                  SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      'TOUCH: D-pad left. Actions right.\n'
                      'Hold FIRE. Tap JUMP, BOOM, or USE.\n\n'
                      'Shields block frontal bullets: get close,\n'
                      'flank, or use explosives.\n'
                      'Shoot restraints or USE near dock crew.\n'
                      'Grab weapons; empty ones auto-switch.\n'
                      'Walker glowing? Dodge. Venting? Shoot!\n'
                      'Retry restores your latest checkpoint.',
                      style: TextStyle(fontSize: 14, height: 1.65, color: mint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OpButton(
          label: 'GOT IT  ✓',
          onPressed:
              () => _select(() {
                unawaited(widget.progress.acknowledgeHelp());
                menu.back();
              }),
        ),
      ],
    );
  }

  Widget _credits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('SMALL TEAM. BIG RUCKUS.', 'CREDITS / ORIGINAL WORK'),
        const SizedBox(height: 36),
        Expanded(
          child: SingleChildScrollView(
            child: _panel(
              const Text(
                'OPERATION RUCKUS\n\n'
                'An original comic-book arcade adventure.\n'
                'Characters, harbor, vehicles, effects, and pixel artwork\n'
                'are drawn in code for this game. No borrowed game assets.\n\n'
                'Built with Flutter + Flame.\n'
                'Audio is intentionally silent; event hooks are ready\n'
                'for a future original soundtrack and sound effects.\n\n'
                'Dedicated to everyone who has ever pressed J too hard.',
                style: TextStyle(fontSize: 18, height: 1.5, color: cream),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OpButton(label: 'BACK', onPressed: () => _select(menu.back)),
      ],
    );
  }

  Widget _mission() {
    final s = session!;
    return Stack(
      fit: StackFit.expand,
      children: [
        _gameWidget!,
        SafeArea(
          child: Column(
            children: [
              _hud(s),
              if (s.boss.active && s.boss.hp > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 70),
                  child: Column(
                    children: [
                      Text(
                        'IRONJAW SIEGE WALKER / PHASE ${s.boss.phase}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: cream,
                          backgroundColor: ink,
                        ),
                      ),
                      LinearProgressIndicator(
                        value: s.boss.hp / s.boss.maxHp,
                        color: coral,
                        backgroundColor: ink,
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (s.status == MissionStatus.playing && touchVisible)
                _touchControls(),
            ],
          ),
        ),
        if (s.status != MissionStatus.playing) _missionOverlay(s),
      ],
    );
  }

  Widget _hud(GameState s) {
    final p = s.player;
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .94),
        border: Border.all(color: mint.withValues(alpha: .7), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 18,
              runSpacing: 3,
              children: [
                Text(
                  'ROOK  ♥ ${p.health}',
                  style: const TextStyle(
                    color: coral,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${p.weapon.name.toUpperCase()}  ${p.weapon == WeaponType.sidearm ? '∞' : p.ammo}',
                  style: const TextStyle(color: gold),
                ),
                Text('BOMBS ${p.grenades}'),
                Text(
                  'CREW ${s.rescued}/${s.prisoners.length}',
                  style: const TextStyle(color: mint),
                ),
                Text('SCORE ${s.score.toString().padLeft(6, '0')}'),
                if (p.inVehicle)
                  Text(
                    'BULLFROG ♥ ${s.vehicle.hp}',
                    style: const TextStyle(color: mint),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                touchVisible ? 'Hide touch controls' : 'Show touch controls',
            onPressed:
                () => _select(() {
                  router!.clear();
                  touchVisible = !touchVisible;
                }),
            icon: Icon(touchVisible ? Icons.gamepad : Icons.gamepad_outlined),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Pause',
            onPressed: _pause,
            icon: const Icon(Icons.pause),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _touchControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(58.0, math.max(44.0, constraints.maxWidth / 15));
        Widget key(Command command, String label, {Color color = cream}) {
          return _HoldButton(
            label: label,
            color: color,
            size: size,
            onChange: (source, down) => router!.set(command, source, down),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  key(Command.up, '↑'),
                  Row(
                    children: [
                      key(Command.left, '←'),
                      key(Command.down, '↓'),
                      key(Command.right, '→'),
                    ],
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  key(Command.interact, 'USE', color: mint),
                  key(Command.grenade, 'BOOM', color: coral),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      key(Command.jump, 'JUMP'),
                      key(Command.fire, 'FIRE', color: gold),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _missionOverlay(GameState s) {
    final paused = s.status == MissionStatus.paused;
    final won = s.status == MissionStatus.victory;
    return ColoredBox(
      color: ink.withValues(alpha: .83),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _panel(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _eyebrow(
                      paused ? 'TAKE A BREATHER' : 'IRON HARBOR / AFTER ACTION',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      paused
                          ? 'HOLD THAT THOUGHT.'
                          : won
                          ? 'HARBOR LIBERATED!'
                          : 'PLAN B?',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!paused)
                      Text(
                        'SCORE ${s.score}  •  CREW ${s.rescued}/${s.prisoners.length}\n'
                        'TIME ${s.elapsed ~/ 60}:${(s.elapsed.toInt() % 60).toString().padLeft(2, '0')}'
                        '  •  BEST ${widget.progress.bestScore}\n'
                        '${won
                            ? 'The lunch breaks are safe. For now.'
                            : s.checkpointReached
                            ? 'Retry from the latest checkpoint.'
                            : 'Retry from the harbor landing.'}',
                        style: const TextStyle(color: mint, height: 1.6),
                      ),
                    const SizedBox(height: 14),
                    if (paused) ...[
                      OpButton(
                        label: 'RESUME',
                        onPressed: () => _select(() => s.resume()),
                      ),
                      const SizedBox(height: 8),
                      OpButton(
                        label: 'RESTART MISSION',
                        color: coral,
                        onPressed:
                            () => _select(() {
                              router!.clear();
                              s.restart();
                              _recorded = false;
                            }),
                      ),
                      const SizedBox(height: 8),
                      OpButton(
                        label: 'CONTROLS',
                        color: mint,
                        onPressed: () => _select(menu.showHelp),
                      ),
                    ] else ...[
                      OpButton(
                        label: 'RETRY',
                        onPressed:
                            () => _select(() {
                              router!.clear();
                              if (won) {
                                s.restart();
                              } else {
                                s.retryCheckpoint();
                              }
                              _recorded = false;
                            }),
                      ),
                      const SizedBox(height: 8),
                      OpButton(
                        label: 'LEVEL SELECT',
                        color: mint,
                        onPressed:
                            () => _select(() => _leave(AppScreen.levels)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OpButton(
                      label: 'MAIN MENU',
                      color: cream,
                      onPressed: () => _select(() => _leave(AppScreen.main)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _eyebrow(subtitle),
            TextButton(
              onPressed: () => _select(menu.back),
              child: const Text('← BACK / ESC'),
            ),
          ],
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: gold,
          ),
        ),
      ],
    );
  }
}

Widget _eyebrow(String text) => Text(
  text,
  style: const TextStyle(
    color: mint,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  ),
);

Widget _footer(String left, String right) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(left, style: const TextStyle(color: cream, fontSize: 11)),
    Text(right, style: const TextStyle(color: mint, fontSize: 11)),
  ],
);

Widget _panel(Widget child, {bool muted = false}) => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: (muted ? const Color(0xff20333c) : ink).withValues(alpha: .95),
    border: Border.all(color: muted ? Colors.blueGrey : mint, width: 2),
    boxShadow: const [
      BoxShadow(color: Color(0x8007121d), offset: Offset(5, 5)),
    ],
  ),
  child: child,
);

Widget _tag(String text, Color color) => Container(
  color: color,
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: Text(
    text,
    style: const TextStyle(
      color: ink,
      fontWeight: FontWeight.w900,
      fontSize: 13,
    ),
  ),
);

class OpButton extends StatelessWidget {
  const OpButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = gold,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: ink,
        disabledBackgroundColor: const Color(0xff344752),
        disabledForegroundColor: const Color(0xff9aa9aa),
        elevation: 0,
        minimumSize: Size(0, compact ? 42 : 48),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 20,
          vertical: 12,
        ),
        shape: const RoundedRectangleBorder(),
        side: const BorderSide(color: ink, width: 2),
        textStyle: TextStyle(
          fontSize: compact ? 11 : 15,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.variant, this.locked = false});
  final int variant;
  final bool locked;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PortraitPainter(variant, locked),
    child: const SizedBox.expand(),
  );
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.variant, this.locked);
  final int variant;
  final bool locked;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 48, size.height / 58);
    PixelArt.paintPortrait(
      canvas,
      Offset((size.width - 48 * scale) / 2, (size.height - 58 * scale) / 2),
      scale,
      variant: variant,
      locked: locked,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) =>
      variant != oldDelegate.variant || locked != oldDelegate.locked;
}

class _HarborPainter extends CustomPainter {
  _HarborPainter(this.time);
  final double time;
  @override
  void paint(Canvas canvas, Size size) =>
      PixelArt.paintHarbor(canvas, size, time);
  @override
  bool shouldRepaint(_HarborPainter oldDelegate) => time != oldDelegate.time;
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.label,
    required this.color,
    required this.size,
    required this.onChange,
  });
  final String label;
  final Color color;
  final double size;
  final void Function(Object source, bool down) onChange;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  final Set<int> pointers = {};
  void _change(int pointer, bool down) {
    setState(() {
      if (down) {
        pointers.add(pointer);
      } else {
        pointers.remove(pointer);
      }
    });
    widget.onChange(pointer, down);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      child: Listener(
        onPointerDown: (event) => _change(event.pointer, true),
        onPointerUp: (event) => _change(event.pointer, false),
        onPointerCancel: (event) => _change(event.pointer, false),
        child: Container(
          width: widget.size,
          height: widget.size,
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                pointers.isEmpty
                    ? ink.withValues(alpha: .65)
                    : widget.color.withValues(alpha: .8),
            border: Border.all(
              color: widget.color.withValues(alpha: .8),
              width: 2,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: pointers.isEmpty ? widget.color : ink,
              fontSize: widget.label.length > 2 ? 11 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
