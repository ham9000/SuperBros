# SuperBros

A minimal 2D side-scrolling platformer prototype built with **Flutter + Flame**.

> **Status:** Milestone 1 complete – player movement, gravity, jump, and ground collision.

---

## 🎮 Controls

| Key | Action |
|-----|--------|
| `←` / `A` | Move left |
| `→` / `D` | Move right |
| `↑` / `W` / `Space` | Jump |

---

## 🚀 How to Run

### Prerequisites

- [Flutter SDK ≥ 3.3.0](https://docs.flutter.dev/get-started/install)
- `flutter doctor` should report no critical errors for your target platform.

### Steps

```bash
# 1. Clone / navigate to the repo
cd SuperBros

# 2. Generate platform-specific files (only needed once)
#    This preserves existing lib/ source files and adds platform boilerplate.
flutter create --project-name super_bros --org com.example .

# 3. Fetch dependencies
flutter pub get

# 4. Run on your platform of choice
flutter run -d chrome     # Web (recommended for quick testing)
flutter run -d linux      # Linux desktop
flutter run               # Any connected device / emulator
```

> **Tip:** Web is the easiest target because it needs no additional SDKs.

---

## 📂 Project Structure

```
lib/
├── main.dart                  # App entry point
└── game/
    ├── side_scroller_game.dart  # Root FlameGame class
    ├── config/
    │   └── game_config.dart   # Centralized gameplay constants
    ├── core/                  # (future: shared utilities)
    ├── components/
    │   ├── player.dart        # Player component (movement + physics)
    │   └── ground.dart        # Static ground platform
    ├── levels/                # (future: level layouts)
    ├── ui/                    # (future: HUD, menus)
    └── input/                 # (future: touch controls)
```

---

## 🗺️ Milestone Roadmap

- [x] **Milestone 1** – Player movement, gravity, jump, flat ground
- [ ] **Milestone 2** – Platform collision, camera follow, level layout
- [ ] **Milestone 3** – Enemy patrol, collectible, score tracking
- [ ] **Milestone 4** – Goal / win condition, fall / lose condition, restart
- [ ] **Milestone 5** – HUD (score + lives), touch controls for mobile
Test Game Prototype
