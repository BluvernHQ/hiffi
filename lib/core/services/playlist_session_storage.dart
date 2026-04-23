import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/playlist/domain/models/playlist_models.dart';

class PlaylistSessionStorage {
  static const String key = 'hiffi_playlist_session';

  Future<void> save(PlaylistSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(session.toJson()));
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<PlaylistSession?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final session = PlaylistSession.fromJson(decoded);
      return session.isValid ? session : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // no-op
    }
  }
}
