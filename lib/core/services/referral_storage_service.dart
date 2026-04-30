import 'package:shared_preferences/shared_preferences.dart';

class ReferralStorageService {
  static const String _referralCodeKey = 'referral_code';
  static const String _referralRedirectPendingKey = 'referral_redirect_pending';

  static Future<void> saveReferral({
    required String username,
    bool shouldRedirectAfterSignup = true,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_referralCodeKey, normalized);
    await prefs.setBool(
      _referralRedirectPendingKey,
      shouldRedirectAfterSignup,
    );
  }

  static Future<String?> getReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_referralCodeKey)?.trim().toLowerCase();
    if (code == null || code.isEmpty) {
      return null;
    }
    return code;
  }

  static Future<bool> isRedirectPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_referralRedirectPendingKey) ?? false;
  }

  static Future<void> setRedirectPending(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_referralRedirectPendingKey, value);
  }

  static Future<void> clearReferral() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_referralCodeKey);
    await prefs.remove(_referralRedirectPendingKey);
  }
}
