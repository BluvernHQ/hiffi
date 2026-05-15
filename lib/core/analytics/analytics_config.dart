class AnalyticsConfig {
  const AnalyticsConfig({
    required this.baseUrl,
    this.ingestKey,
    this.flushIntervalSeconds = 5,
    // Match web tracker default.
    this.maxBatchSize = 25,
    this.maxQueueSize = 1000,
    this.maxEventAgeDays = 7,
    this.persistQueue = true,
  });

  /// Example: `https://api.dev.hiffi.com`
  final String baseUrl;

  /// If required by backend, sent as `X-Analytics-Ingest-Key`.
  final String? ingestKey;

  final int flushIntervalSeconds;
  final int maxBatchSize;

  /// Hard cap to prevent unbounded growth if offline.
  final int maxQueueSize;

  /// Events older than this are dropped.
  final int maxEventAgeDays;

  /// Persists unsent events to local storage.
  final bool persistQueue;
}

