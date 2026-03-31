import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity status
class NetworkConnectivityService {
  NetworkConnectivityService() {
    _connectivity = Connectivity();
    _initFuture = _init();
  }

  Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectivityController;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = false;
  bool _isInitialized = false;
  late final Future<void> _initFuture;

  /// Wait until the first platform connectivity check has finished.
  /// Call this before reading [isConnected] on cold start to avoid a false
  /// "offline" while [_init] is still in flight.
  Future<void> ensureInitialized() => _initFuture;

  /// Stream of connectivity status changes
  Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    return _connectivityController!.stream;
  }

  /// Current connectivity status
  bool get isConnected => _isConnected;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  Future<void> _init() async {
    try {
      // Get initial connectivity status
      final results = await _connectivity.checkConnectivity();
      _isConnected = _hasInternetConnection(results);
      _isInitialized = true;

      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasConnected = _isConnected;
          _isConnected = _hasInternetConnection(results);

          debugPrint(
            '🌐 Connectivity changed: ${_isConnected ? "Connected" : "Disconnected"}',
          );

          // Only notify if status actually changed
          if (wasConnected != _isConnected) {
            _connectivityController?.add(_isConnected);
          }
        },
        onError: (error) {
          debugPrint('❌ Connectivity stream error: $error');
        },
      );

      debugPrint('✅ NetworkConnectivityService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize NetworkConnectivityService: $e');
      _isInitialized = false;
    }
  }

  /// Check if any of the connectivity results indicate internet connection
  bool _hasInternetConnection(List<ConnectivityResult> results) {
    // Consider connected if we have mobile, wifi, ethernet, or vpn
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn,
    );
  }

  /// Check current connectivity status (synchronous)
  bool checkConnectivitySync() {
    return _isConnected;
  }

  /// Check current connectivity status (async, with actual network check)
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final connected = _hasInternetConnection(results);
      _isConnected = connected;
      return connected;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController?.close();
    _connectivityController = null;
  }
}
