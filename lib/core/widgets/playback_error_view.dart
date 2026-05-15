import 'package:flutter/material.dart';

import '../utils/playback_error_utils.dart';

/// Inline error overlay for HLS / Chewie when playback fails.
class PlaybackErrorView extends StatelessWidget {
  const PlaybackErrorView({
    super.key,
    required this.rawErrorMessage,
    required this.onRetry,
  });

  final String? rawErrorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final display = playbackErrorDisplay(rawErrorMessage);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              display.isOffline
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              display.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (display.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                display.subtitle!,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED1C2F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
