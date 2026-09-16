# Operation Ruckus

An original, playable comic-book run-and-gun built with Flutter and Flame.
Play as **Rook** and liberate **Iron Harbor** from the Brass Bureau: rescue the
dock crew, commandeer the **Bullfrog** scout vehicle, and take down the
**Ironjaw Siege Walker**. All character and world artwork is generated in code;
no assets from existing arcade games are used.

## Play

The title leads through the main menu, crew selection, and mission selection.
Rook and Iron Harbor are playable. Nyx, Bolt, Mae, Desert Convoy, and Jungle
Foundry are clearly locked future content, including after mission completion.

| Input | Action |
| --- | --- |
| A/D or Left/Right | Move |
| W or Up | Aim upward |
| S or Down | Crouch |
| Space | Jump |
| J (hold) | Fire; automatically melee an enemy within reach |
| K | Throw grenade |
| E or L | Rescue nearby crew / enter or exit vehicle |
| Escape | Pause / resume / back |
| Enter | Advance title and default menu selections |

Touch controls are available on **all platforms, including mobile web**. Hold
the D-pad and FIRE; tap JUMP, BOOM, or USE. The gamepad icon toggles touch
controls. Controls respect device safe areas. Native mobile uses landscape;
rotate a browser into landscape for the best experience.

Iron Harbor includes infantry, frontal shields, telegraphing turrets, weapon
and supply pickups, destructible crates and explosive barrels, elevated
platforms, six captives, two checkpoints, a usable vehicle, and a phased boss
with cannon bursts, arcing bombs, and jumpable ground shockwaves. Shields can
be flanked, meleed, or blasted. Special weapons switch back to the unlimited
sidearm when empty. Shoot restraints or interact to rescue crew.

Death opens the results screen. **Retry** restores the latest checkpoint
snapshot (including score and rescue progress); **Restart Mission** in pause
starts fresh. Defeat the walker to reach victory. Its warning lights telegraph
attacks; attack when its vents open. The vehicle is powerful but cannot jump
the boss's shockwaves.

## Architecture

* `lib/game/core/`: deterministic, sub-stepped Dart simulation, entities,
  command input, audio events, and lightweight local progress storage.
* `lib/game/config/game_config.dart`: centralized movement/combat tuning.
* `lib/game/side_scroller_game.dart`: Flame clock and fixed 480×270 viewport.
* `lib/game/rendering/pixel_art.dart`: centralized sprite identifiers, original
  hard-edged pixel artwork, parallax harbor, particles, and comic callouts.
* `lib/game/input/`: source-aware keyboard/touch routing. Releasing one source
  does not cancel another; pause/focus loss clears held commands.
* `lib/game/ui/`: navigation catalogs, selection locking, menus, HUD, touch
  controls, and pause/results flows.

Shared preferences stores only best score, completion, and help acknowledgement.
Unavailable storage falls back to session-only progress. Audio is deliberately
silent, with an event bus ready for original menu, weapon, impact, rescue,
vehicle, boss, and victory sounds; no missing audio asset can crash the game.

The art is a coherent programmatic placeholder set rather than production
sprite sheets. The mission targets a short arcade run; difficulty and the
three-to-six-minute new-player pacing still merit broader playtesting.

## Development and verification

Use Flutter **3.29.3 stable** (the same SDK as CI and Copilot setup).
From the repository root:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter test --platform chrome test/game_runtime_test.dart
flutter build web --release --base-href /SuperBros/ --no-web-resources-cdn
flutter build apk --debug
```

Chrome must be installed for browser tests. Set `CHROME_EXECUTABLE` to its
executable path if Flutter cannot find it. The runtime suite mounts the real app
and checks menu locking/navigation, keyboard and touch input, pause/help,
checkpoint retry, and projectile-driven boss victory/results wiring. The
simulation suite covers combat, weapons, rescues, vehicles, and boss attacks.
Runtime tests use controlled state setup for distant encounters, not a claimed
full-length human playthrough. They run as Flutter widget tests on both the VM and
headless Chrome, not as an end-to-end test of the release bundle.

For interactive testing, run `flutter run -d chrome`. Also test the **release
build** before calling a feature complete: serve `build/web` under `/SuperBros/`
on a local static server, or use the online test site below. Check movement,
jumping, collecting, both end screens, restarting, and the browser console for
errors. Automated checks are a baseline, not proof that every new feature works;
add relevant regression tests and manually exercise the changed behavior.

## Handing work to Copilot

1. Create an issue with the desired behavior, acceptance criteria, and any
   relevant screenshot or reproduction steps; assign it to Copilot. Alternatively,
   start a Copilot task for this repository.
2. Ask Copilot to read this development workflow, implement a focused change,
   add/update behavioral tests, and repeat analysis, tests, and runtime checks
   until they pass. Commit completed, verified work in logical increments.
3. Require a final report with commands/results, runtime observations, and
   remaining limitations. If a tool or dependency is blocked, report that
   explicitly instead of claiming the change is verified.
4. Review the changes and green **Analyze, test, and build** check, then play the
   online build before merging. GitHub may require you to approve Actions runs
   for Copilot or fork pull requests; approve trusted changes only.

The Copilot setup workflow installs Flutter, web tooling, and locked dependencies
before future tasks. It takes effect once merged into the default branch.
If Copilot's firewall blocks SDK/package downloads, allow the required Flutter
services (`storage.googleapis.com` and `pub.dev`) in repository Copilot settings.
Repository files cannot assign issues, approve runs, or enforce agent behavior.
For enforcement, enable a branch ruleset requiring pull requests and the
**Analyze, test, and build** status check before merging to `main`.

## Online verification with GitHub Pages

One-time repository setup (requires an administrator):

1. Merge these workflows into `main`.
2. In **Settings → Pages → Build and deployment**, select **GitHub Actions**.
3. In **Settings → Environments → github-pages**, allow `main` to deploy.
   To test a trusted feature branch before merging, explicitly allow that branch
   too. Keep untrusted branches excluded; consider required reviewers.
4. Run **Actions → Verify and publish web → Run workflow** on `main` with
   **publish** enabled for the initial deployment.

After setup, successful pushes to `main` publish automatically to:

**https://ham9000.github.io/SuperBros/**

To preview a feature before merging, manually run the same workflow, select its
branch, and enable **publish**. It must pass analysis, unit/widget tests, Chrome
runtime tests, and the release build before deployment. The deployment job shows
the playable URL and commit SHA; `/SuperBros/version.txt` identifies the deployed
revision. Only publish branches whose code and workflow you trust.

**This is a single shared test site, not a separate URL per pull request.**
A manual branch deployment replaces the current site; a later deployment from
`main` replaces that preview. Re-run on `main` to restore it. Pull request events
never deploy and have no Pages write permission. Every successful verification
run also keeps a downloadable `web-<commit>` build artifact; downloading it alone
does not host it online.
