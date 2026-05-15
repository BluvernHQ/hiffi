import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_config.dart';
import 'analytics_ids.dart';
import 'first_party_event.dart';

/// First-party activity logs / batch analytics matching web tracker behavior.
class FirstPartyAnalyticsService {
  FirstPartyAnalyticsService({
    required AnalyticsConfig config,
    http.Client? httpClient,
  }) : _config = config,
       _http = httpClient ?? http.Client(),
       sessionId = generateHexId(bytes: 16);

  final AnalyticsConfig _config;
  final http.Client _http;

  /// Stable during the app process lifetime.
  final String sessionId;

  // Distinct IDs:
  // - logged out: persisted anonymous id
  // - logged in: user uid (via identify)
  String? _userDistinctId;
  late String _anonDistinctId = generateHexId(bytes: 16);

  // Cached metadata
  String? _appVersion;
  String? _deviceModel;
  String? _osName;
  String? _deviceType;

  // Queue & flushing
  final List<FirstPartyEvent> _queue = <FirstPartyEvent>[];
  Timer? _flushTimer;
  Timer? _persistDebounce;
  bool _flushInFlight = false;
  int _consecutiveFailures = 0;
  DateTime? _nextAllowedFlushAt;

  SharedPreferences? _prefs;

  static const _kAnonIdKey = 'fp_analytics_distinct_id';
  static const _kQueueKey = 'fp_analytics_queue_v1';

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadOrCreateAnonId();
    await _loadQueueFromDisk();
    await _loadAppAndDeviceInfo();
    _startFlushTimer();
  }

  void dispose() {
    _flushTimer?.cancel();
    _persistDebounce?.cancel();
    _http.close();
  }

  /// Switch between anonymous and logged-in tracking.
  ///
  /// Pass `null` to revert to anonymous.
  Future<void> identify(String? distinctIdOrNull) async {
    _userDistinctId = (distinctIdOrNull == null || distinctIdOrNull.isEmpty)
        ? null
        : distinctIdOrNull;
  }

  String get distinctId => _userDistinctId ?? _anonDistinctId;

  Future<void> capture(
    String eventName, {
    String? elementUiName,
    String? screenName,
    String? videoId,
    String? videoTitle,
    Map<String, Object?>? properties,
    Map<String, Object?>? topLevel,
  }) async {
    // Ensure ids + persisted queue exist as early as possible.
    unawaited(init());

    final payload = <String, Object?>{
      'event': eventName,
      'distinct_id': distinctId,
      'session_id': sessionId,
      // Backend expects platform + device_type (do not send "unknown").
      'platform': _osName ?? _computeOsName(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (_appVersion != null) 'app_version': _appVersion,
      if (screenName != null) 'screen_name': screenName,
      if (elementUiName != null) 'element_ui_name': elementUiName,
      if (videoId != null) 'video_id': videoId,
      if (videoTitle != null) 'video_title': videoTitle,
      if (_deviceType != null) 'device_type': _deviceType,
      if (_deviceModel != null) 'device_model': _deviceModel,
      if (_osName != null) 'os_name': _osName,
    };

    if (topLevel != null && topLevel.isNotEmpty) {
      for (final entry in topLevel.entries) {
        payload[entry.key] = entry.value;
      }
    }

    final sanitized = _sanitizeProperties(properties);
    if (sanitized != null && sanitized.isNotEmpty) {
      payload['properties'] = sanitized;
    }

    final ev = FirstPartyEvent(payload);
    _enqueue(ev);

    // Requirement: on every button press, call `/analytics/events`.
    // We treat `$click` as "button press" (mirrors web autocapture).
    if (eventName == r'$click') {
      unawaited(_sendClickImmediately(ev));
    }
  }

  Future<void> _sendClickImmediately(FirstPartyEvent ev) async {
    // Avoid duplicate sends if a flush is currently active.
    if (_flushInFlight) return;
    final ok = await _sendSingle(ev);
    if (ok) {
      // Remove the first matching instance from the queue (best-effort).
      final idx = _queue.indexWhere((e) => identical(e, ev));
      if (idx >= 0) {
        _queue.removeAt(idx);
        _persistSoon();
      }
      return;
    }
    // Keep queued for retry via timer/threshold.
    _recordFailure();
  }

  void _enqueue(FirstPartyEvent event) {
    _dropExpiredInMemory();

    _queue.add(event);
    if (_queue.length > _config.maxQueueSize) {
      // Drop oldest to keep memory bounded.
      _queue.removeRange(0, _queue.length - _config.maxQueueSize);
    }

    _persistSoon();

    if (_queue.length >= _config.maxBatchSize) {
      unawaited(flush(reason: 'queue_full'));
    }
  }

  Future<void> flush({String reason = 'timer', bool bestEffort = false}) async {
    if (_flushInFlight) return;
    if (_queue.isEmpty) return;

    final now = DateTime.now();
    final next = _nextAllowedFlushAt;
    if (next != null && now.isBefore(next)) return;

    _flushInFlight = true;
    try {
      _dropExpiredInMemory();
      if (_queue.isEmpty) return;

      final batchSize = _config.maxBatchSize;
      final batch = _queue.take(batchSize).toList(growable: false);
      final ok = await _sendBatch(batch);

      if (ok) {
        _queue.removeRange(0, batch.length);
        _consecutiveFailures = 0;
        _nextAllowedFlushAt = null;
        _persistSoon();
        return;
      }

      // Fallback to single-event ingest if batch fails.
      // If single-event succeeds for all, dequeue them.
      var allSinglesOk = true;
      for (final e in batch) {
        final singleOk = await _sendSingle(e);
        if (!singleOk) {
          allSinglesOk = false;
          break;
        }
      }

      if (allSinglesOk) {
        _queue.removeRange(0, batch.length);
        _consecutiveFailures = 0;
        _nextAllowedFlushAt = null;
        _persistSoon();
      } else {
        _recordFailure();
        if (!bestEffort) {
          // Keep queued for retry later.
        }
      }
    } catch (_) {
      _recordFailure();
    } finally {
      _flushInFlight = false;
    }
  }

  void _recordFailure() {
    _consecutiveFailures = (_consecutiveFailures + 1).clamp(1, 10);
    final backoffSeconds = (1 << (_consecutiveFailures - 1)).clamp(1, 60);
    final jitterMs = DateTime.now().microsecondsSinceEpoch % 750;
    _nextAllowedFlushAt = DateTime.now().add(
      Duration(seconds: backoffSeconds, milliseconds: jitterMs),
    );
  }

  Future<bool> _sendBatch(List<FirstPartyEvent> events) async {
    final uri = Uri.parse('${_config.baseUrl}/analytics/events/batch');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_config.ingestKey != null && _config.ingestKey!.isNotEmpty)
        'X-Analytics-Ingest-Key': _config.ingestKey!,
    };

    try {
      if (kDebugMode) {
        debugPrint(
          '📦 analytics(batch) → POST $uri  events=${events.length}',
        );
      }
      final res = await _http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'events': events.map((e) => e.toJson()).toList()}),
          )
          .timeout(const Duration(seconds: 12));
      if (kDebugMode) {
        debugPrint('📦 analytics(batch) ← ${res.statusCode}');
      }
      return res.statusCode >= 200 && res.statusCode < 300;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('📦 analytics(batch) timeout');
      }
      return false;
    } on SocketException {
      if (kDebugMode) {
        debugPrint('📦 analytics(batch) socket error');
      }
      return false;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('📦 analytics(batch) unexpected error');
      }
      return false;
    }
  }

  Future<bool> _sendSingle(FirstPartyEvent event) async {
    final uri = Uri.parse('${_config.baseUrl}/analytics/events');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_config.ingestKey != null && _config.ingestKey!.isNotEmpty)
        'X-Analytics-Ingest-Key': _config.ingestKey!,
    };

    try {
      if (kDebugMode) {
        debugPrint('📦 analytics(single) → POST $uri');
      }
      final res = await _http
          .post(uri, headers: headers, body: jsonEncode(event.toJson()))
          .timeout(const Duration(seconds: 12));
      if (kDebugMode) {
        debugPrint('📦 analytics(single) ← ${res.statusCode}');
      }
      return res.statusCode >= 200 && res.statusCode < 300;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('📦 analytics(single) timeout');
      }
      return false;
    } on SocketException {
      if (kDebugMode) {
        debugPrint('📦 analytics(single) socket error');
      }
      return false;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('📦 analytics(single) unexpected error');
      }
      return false;
    }
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      Duration(seconds: _config.flushIntervalSeconds),
      (_) => unawaited(flush(reason: 'timer')),
    );
  }

  Future<void> _loadOrCreateAnonId() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final saved = prefs.getString(_kAnonIdKey);
    if (saved != null && saved.isNotEmpty) {
      _anonDistinctId = saved;
      return;
    }
    await prefs.setString(_kAnonIdKey, _anonDistinctId);
  }

  Future<void> _loadQueueFromDisk() async {
    if (!_config.persistQueue) return;
    final prefs = _prefs;
    if (prefs == null) return;
    final raw = prefs.getString(_kQueueKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <FirstPartyEvent>[];
      for (final item in decoded) {
        final ev = FirstPartyEvent.fromJson(item);
        if (ev == null) continue;
        loaded.add(ev);
      }
      _queue
        ..clear()
        ..addAll(loaded);
      _dropExpiredInMemory();
      if (_queue.length > _config.maxQueueSize) {
        _queue.removeRange(0, _queue.length - _config.maxQueueSize);
      }
    } catch (_) {
      // Ignore corrupted queue.
    }
  }

  void _persistSoon() {
    if (!_config.persistQueue) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_persistQueueNow());
    });
  }

  Future<void> _persistQueueNow() async {
    if (!_config.persistQueue) return;
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final jsonList = _queue.map((e) => e.toJson()).toList();
      await prefs.setString(_kQueueKey, jsonEncode(jsonList));
    } catch (_) {
      // Best-effort persistence only.
    }
  }

  void _dropExpiredInMemory() {
    final ttl = Duration(days: _config.maxEventAgeDays);
    final now = DateTime.now().toUtc();
    _queue.removeWhere((e) {
      final ts = e.timestamp?.toUtc();
      if (ts == null) return false;
      return now.difference(ts) > ttl;
    });
  }

  Future<void> _loadAppAndDeviceInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // ignore
    }
    _osName = _computeOsName();
    _deviceType = _computeDeviceType();
    _deviceModel = _computeDeviceModelBestEffort();
  }

  String _computeOsName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  String _computeDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS || Platform.isAndroid) return 'mobile';
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'desktop';
    }
    return 'mobile';
  }

  String? _computeDeviceModelBestEffort() {
    // No device_info_plus dependency currently; keep best-effort and lightweight.
    if (kIsWeb) return null;
    // Platform.operatingSystemVersion can contain verbose strings; omit by default.
    return null;
  }

  Map<String, Object?>? _sanitizeProperties(Map<String, Object?>? properties) {
    if (properties == null) return null;
    if (properties.isEmpty) return null;

    // PII guardrails: do not allow these keys through.
    const bannedKeys = <String>{
      'password',
      'pass',
      'pwd',
      'email',
      'phone',
      'token',
      'id_token',
      'access_token',
      'refresh_token',
      'authorization',
      'auth',
      'name',
      'full_name',
      'first_name',
      'last_name',
      'username',
      'address',
    };

    final out = <String, Object?>{};
    for (final entry in properties.entries) {
      final key = entry.key;
      final lower = key.toLowerCase();
      if (bannedKeys.contains(lower)) continue;
      if (lower.contains('password') ||
          lower.contains('token') ||
          lower.contains('email')) {
        continue;
      }
      out[key] = entry.value;
    }
    return out;
  }
}

