import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing authentication token storage in SharedPreferences
class TokenStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _tokenTimestampKey = 'auth_token_timestamp';

  /// Save the authentication token (JWT) to SharedPreferences
  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setInt(
        _tokenTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('✅ JWT token saved to SharedPreferences');
    } catch (e) {
      print('❌ Failed to save auth token: $e');
      rethrow;
    }
  }

  /// Get the stored authentication token (JWT) from SharedPreferences
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        print('✅ JWT token retrieved from SharedPreferences');
        return token;
      }
      print('ℹ️ No auth token found in SharedPreferences');
      return null;
    } catch (e) {
      print('❌ Failed to get auth token: $e');
      return null;
    }
  }

  /// Delete the stored Firebase auth token from SharedPreferences
  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenTimestampKey);
      print('✅ Auth token deleted from SharedPreferences');
    } catch (e) {
      print('❌ Failed to delete auth token: $e');
      rethrow;
    }
  }

  /// Check if a token exists in SharedPreferences
  static Future<bool> hasToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_tokenKey) &&
          prefs.getString(_tokenKey) != null &&
          prefs.getString(_tokenKey)!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the timestamp when the token was saved
  static Future<DateTime?> getTokenTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_tokenTimestampKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
