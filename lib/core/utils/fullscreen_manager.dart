import 'package:flutter/services.dart';

/// Manages System UI and Orientation for Fullscreen video across the app.
class FullscreenManager {
  /// Enters true fullscreen mode: landscape orientation and hidden system UI.
  static Future<void> enterFullscreen() async {
    await Future.wait([
      // Hide status bar and navigation bar
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      ),
      // Lock to landscape
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    ]);
  }

  /// Exits fullscreen mode: restores portrait orientation and system UI.
  static Future<void> exitFullscreen() async {
    await Future.wait([
      // Restore system overlays (status bar, navigation bar)
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      ),
      // Restore portrait orientation
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    ]);
  }

  /// Resets orientation to allow all rotations (default state).
  static Future<void> resetOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
