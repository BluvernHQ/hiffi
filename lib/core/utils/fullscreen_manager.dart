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

  /// Exits fullscreen mode: restores system UI and forces portrait orientation initially.
  static Future<void> exitFullscreen() async {
    // 1. Restore system overlays immediately
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    // 2. Force portrait orientation to ensure we exit landscape mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 3. After a short delay, allow all orientations again
    await Future.delayed(const Duration(milliseconds: 500));
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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

  /// Locks orientation to portrait (standard app state).
  static Future<void> lockToPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
