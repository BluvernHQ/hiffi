class FirstPartyEvent {
  FirstPartyEvent(this.payload);

  /// Full event payload to send to backend.
  final Map<String, Object?> payload;

  DateTime? get timestamp {
    final ts = payload['timestamp'];
    if (ts is String) {
      return DateTime.tryParse(ts);
    }
    return null;
  }

  Map<String, Object?> toJson() => payload;

  static FirstPartyEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = <String, Object?>{};
    for (final entry in json.entries) {
      final k = entry.key;
      if (k is! String) continue;
      map[k] = entry.value;
    }
    if (map['event'] is! String) return null;
    if (map['distinct_id'] is! String) return null;
    if (map['session_id'] is! String) return null;
    if (map['platform'] is! String) return null;
    return FirstPartyEvent(map);
  }
}

