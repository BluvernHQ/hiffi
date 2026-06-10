/// Global device connectivity phases for app-wide banner and recovery flows.
enum ConnectivityPhase {
  /// Initial probe — no banner yet.
  checking,

  /// No network interface available.
  offline,

  /// Connected — normal operation.
  online,

  /// Brief transition after offline → online (green banner).
  justReconnected,

  /// User tapped Retry on the offline banner.
  refreshing,
}
