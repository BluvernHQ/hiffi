import 'network_error_utils.dart';

/// User-facing playback error (video player / ExoPlayer).
class PlaybackErrorDisplay {
  const PlaybackErrorDisplay({
    required this.title,
    this.subtitle,
    required this.isOffline,
  });

  final String title;
  final String? subtitle;
  final bool isOffline;
}

/// True when [message] likely indicates network/CDN failure during playback.
bool isLikelyPlaybackNetworkFailure(String? message) {
  if (message == null || message.isEmpty) return false;
  if (isOfflineErrorMessage(message)) return true;

  final lower = message.toLowerCase();
  if (lower.contains('exoplaybackexception') ||
      lower.contains('exoplayer') ||
      lower.contains('video player had error')) {
    return lower.contains('source error') ||
        lower.contains('sourceerr') ||
        lower.contains('unable to resolve') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('http') ||
        lower.contains('socket');
  }

  return lower.contains('source error') && lower.contains('playback');
}

/// Maps raw player errors (e.g. ExoPlaybackException) to friendly copy.
PlaybackErrorDisplay playbackErrorDisplay(String? rawMessage) {
  if (isLikelyPlaybackNetworkFailure(rawMessage)) {
    return const PlaybackErrorDisplay(
      title: 'No internet connection',
      subtitle: 'Please check your network and try again.',
      isOffline: true,
    );
  }

  return const PlaybackErrorDisplay(
    title: 'Unable to play video',
    subtitle: 'Please try again.',
    isOffline: false,
  );
}
