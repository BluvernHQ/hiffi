/// Slug helper for mood-mix analytics tags (mirrors web `moodAnalyticsSlug`).
String moodAnalyticsSlug(String label) {
  return label
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
