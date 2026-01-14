import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Picture-in-Picture mode via Platform Channels.
class PipService {
  static const MethodChannel _channel = MethodChannel('com.example.hiffi/pip');

  /// Updates the player status on the native side.
  /// If [active] is true, the native side will allow entering PiP when user leaves the app.
  static Future<void> updatePlayerStatus(bool active) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('updatePlayerStatus', active);
        debugPrint('PipService: Updated player status to active=$active');
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: Failed to update player status: ${e.message}');
    }
  }

  /// Triggers the native Picture-in-Picture mode.
  static Future<void> enterPiP() async {
    try {
      // Only attempt on Android for now as iOS handles it differently via AVPlayerLayer
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('enterPiP');
        debugPrint('PipService: Successfully requested PiP mode');
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: Failed to enter PiP mode: ${e.message}');
    }
  }
}
