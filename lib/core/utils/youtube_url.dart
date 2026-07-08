/// Parsed YouTube channel / playlist target (mirrors web `lib/youtube-url.ts`).
enum YoutubeTargetKind { channelId, handle, username, playlistId }

class YoutubeTarget {
  const YoutubeTarget({required this.kind, required this.value});

  final YoutubeTargetKind kind;
  final String value;
}

String _normalizeYoutubeHost(String host) {
  var h = host.toLowerCase();
  if (h.startsWith('www.')) h = h.substring(4);
  if (h.startsWith('m.')) h = h.substring(2);
  return h;
}

/// Returns a parsed target, or `null` for unsupported URLs (including youtu.be).
YoutubeTarget? parseYoutubeTargetUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  Uri uri;
  try {
    uri = Uri.parse(
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'https://$trimmed',
    );
  } catch (_) {
    return null;
  }

  final host = _normalizeYoutubeHost(uri.host);
  if (host != 'youtube.com') {
    return null;
  }

  final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final listParam = uri.queryParameters['list']?.trim();

  if (pathSegments.isNotEmpty && pathSegments.first == 'playlist') {
    if (listParam != null && listParam.isNotEmpty) {
      return YoutubeTarget(kind: YoutubeTargetKind.playlistId, value: listParam);
    }
    return null;
  }

  if (pathSegments.isNotEmpty && pathSegments.first == 'watch') {
    if (listParam == null || listParam.isEmpty) return null;
    return YoutubeTarget(kind: YoutubeTargetKind.playlistId, value: listParam);
  }

  if (pathSegments.isEmpty) return null;

  switch (pathSegments.first) {
    case 'channel':
      if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        return YoutubeTarget(
          kind: YoutubeTargetKind.channelId,
          value: pathSegments[1],
        );
      }
      return null;
    case 'user':
      if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        return YoutubeTarget(
          kind: YoutubeTargetKind.username,
          value: pathSegments[1],
        );
      }
      return null;
    case 'c':
      if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        return YoutubeTarget(
          kind: YoutubeTargetKind.handle,
          value: pathSegments[1],
        );
      }
      return null;
    default:
      if (pathSegments.first.startsWith('@')) {
        return YoutubeTarget(
          kind: YoutubeTargetKind.handle,
          value: pathSegments.first,
        );
      }
      return null;
  }
}

bool isValidYoutubeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;

  try {
    final uri = Uri.parse(
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'https://$trimmed',
    );
    final host = _normalizeYoutubeHost(uri.host);
    if (host != 'youtube.com') return false;
  } catch (_) {
    return false;
  }

  return parseYoutubeTargetUrl(trimmed) != null;
}
