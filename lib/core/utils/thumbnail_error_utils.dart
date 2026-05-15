import 'dart:io';

/// Detects image-load failures for video thumbnails that are handled in UI
/// (placeholder) and should not be reported as fatal crashes.
bool isExpectedThumbnailLoadError(Object error) {
  final msg = error.toString();
  if (!_mentionsThumbnailUrl(msg)) return false;
  return _isMissingThumbnail(msg) || _isTransientNetworkFailure(msg, error);
}

bool _mentionsThumbnailUrl(String msg) {
  return msg.contains('/thumbnails/') ||
      msg.contains('thumbnails/videos/');
}

bool _isMissingThumbnail(String msg) {
  return msg.contains('HTTP request failed') &&
      (msg.contains('statusCode: 404') || msg.contains('status code: 404'));
}

bool _isTransientNetworkFailure(String msg, Object error) {
  if (error is HttpException) {
    return _mentionsThumbnailUrl(error.uri?.toString() ?? msg);
  }

  final lower = msg.toLowerCase();
  const patterns = [
    'software caused connection abort',
    'connection abort',
    'connection closed',
    'connection reset',
    'connection refused',
    'connection timed out',
    'timed out',
    'network is unreachable',
    'failed host lookup',
    'socketexception',
    'clientexception',
    'handshakeexception',
    'httpexception',
  ];

  return patterns.any(lower.contains);
}
