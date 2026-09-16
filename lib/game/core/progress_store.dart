import 'package:shared_preferences/shared_preferences.dart';

/// No account, analytics, or remote storage. A failed save never stops play.
class ProgressStore {
  ProgressStore({SharedPreferences? preferences}) : _preferences = preferences;

  final SharedPreferences? _preferences;
  int bestScore = 0;
  bool completed = false;
  bool helpSeen = false;
  bool available = true;

  static Future<ProgressStore> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ProgressStore(preferences: prefs)
        ..bestScore = prefs.getInt('ruckus.best') ?? 0
        ..completed = prefs.getBool('ruckus.completed') ?? false
        ..helpSeen = prefs.getBool('ruckus.help') ?? false;
    } catch (_) {
      return ProgressStore()..available = false;
    }
  }

  Future<void> record(int score, {required bool victory}) async {
    if (score > bestScore) bestScore = score;
    completed |= victory;
    await _save();
  }

  Future<void> acknowledgeHelp() async {
    helpSeen = true;
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = _preferences;
      if (prefs == null) return;
      final results = await Future.wait([
        prefs.setInt('ruckus.best', bestScore),
        prefs.setBool('ruckus.completed', completed),
        prefs.setBool('ruckus.help', helpSeen),
      ]);
      available = results.every((saved) => saved);
    } catch (_) {
      available = false;
    }
  }
}
