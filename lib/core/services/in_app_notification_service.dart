import 'package:flutter/material.dart';

/// Service for showing in-app notifications (SnackBars) when app is in foreground
class InAppNotificationService {
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Set the navigator key (should be called from app initialization)
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  /// Show a snackbar notification in the app
  static void showNotification({
    required String message,
    String? title,
    bool isSuccess = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    final context = navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('⚠️ Cannot show in-app notification: No context available');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(message),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF4CAF50) // Green for success
            : const Color(0xFFB00020), // Red for error
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show upload progress notification
  static void showProgress({
    required String message,
    String? title,
    int? progress,
    int? maxProgress,
  }) {
    final context = navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('⚠️ Cannot show in-app notification: No context available');
      return;
    }

    final progressText = progress != null && maxProgress != null
        ? '${((progress / maxProgress) * 100).toInt()}%'
        : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(message),
            if (progressText.isNotEmpty) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress != null && maxProgress != null
                    ? progress / maxProgress
                    : null,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                progressText,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFFED1C2F), // Red theme color
        behavior: SnackBarBehavior.floating,
        duration: const Duration(
          seconds: 2,
        ), // Shorter duration for progress updates
      ),
    );
  }

  /// Hide current notification
  static void hideCurrent() {
    final context = navigatorKey?.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }
}
