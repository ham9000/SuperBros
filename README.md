# SuperBros
Test Game Prototype

A Flutter/Flame side-scroller. Move with **A/D** or **Left/Right**, jump with
**W/Up/Space**, and restart with **R**. Native Android/iOS builds have touch
controls; the web build currently requires a keyboard.

## Development and verification

Use Flutter **3.29.3 stable** (the same SDK as CI and Copilot setup).
From the repository root:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --coverage
flutter test --platform chrome test/game_runtime_test.dart
flutter build web --release --base-href /SuperBros/ --no-web-resources-cdn
```

Chrome must be installed for browser tests. Set `CHROME_EXECUTABLE` to its
executable path if Flutter cannot find it. The runtime suite mounts the real app
and checks keyboard movement, jumping, collecting, winning, losing lives, and
restart/overlay wiring. It runs as Flutter widget tests on both the VM and
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
