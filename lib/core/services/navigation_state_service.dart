import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last in-app route so we can restore after the OS kills the process.
class NavigationStateService {
  NavigationStateService._();

  static const _routeKey = 'last_navigation_route';

  static Future<void> saveRoute(String route) async {
    final trimmed = route.trim();
    if (trimmed.isEmpty || trimmed == '/') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, trimmed);
  }

  static Future<String?> getSavedRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString(_routeKey);
    if (route == null || route.isEmpty) return null;
    return route;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_routeKey);
  }
}
