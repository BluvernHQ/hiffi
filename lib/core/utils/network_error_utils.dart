bool isOfflineErrorMessage(String? message) {
  if (message == null || message.isEmpty) return false;
  final lower = message.toLowerCase();
  return lower.contains('no internet') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('no address associated with hostname');
}

