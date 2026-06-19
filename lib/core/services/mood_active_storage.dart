import 'package:shared_preferences/shared_preferences.dart';

class MoodActiveStorage {
  static const String key = 'hiffi_active_mood';

  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String? moodQuery) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (moodQuery == null || moodQuery.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, moodQuery);
      }
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
