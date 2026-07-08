/// Minimum count before views/likes are shown in the UI (YouTube-style privacy).
const int kMinEngagementCountDisplay = 10000;

bool shouldShowEngagementCount(int count) =>
    count >= kMinEngagementCountDisplay;

/// Formats large integers for compact display (e.g. 12.5K, 2M).
String formatCompactCount(int count) {
  if (count >= 1000000) {
    final value = count / 1000000;
    return value == value.roundToDouble()
        ? '${value.toInt()}M'
        : '${value.toStringAsFixed(1)}M';
  }
  if (count >= 10000) {
    final value = count / 1000;
    return value == value.roundToDouble()
        ? '${value.toInt()}K'
        : '${value.toStringAsFixed(1)}K';
  }
  return count.toString();
}

/// Shorter compact format for video overlay counts (1 decimal always when >= 1K).
String formatCompactCountShort(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}
