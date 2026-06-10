import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connectivity_phase.dart';
import '../services/network_connectivity_service.dart';

/// App-wide connectivity state machine driving the banner and auto-refresh.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController({
    required NetworkConnectivityService connectivityService,
  }) : _connectivityService = connectivityService {
    unawaited(_init());
  }

  final NetworkConnectivityService _connectivityService;
  StreamSubscription<bool>? _subscription;
  Timer? _reconnectedTimer;
  Timer? _reconnectNotifyTimer;
  ConnectivityPhase _phase = ConnectivityPhase.checking;
  final List<VoidCallback> _reconnectListeners = [];

  ConnectivityPhase get phase => _phase;

  bool get isOffline => _phase == ConnectivityPhase.offline;

  bool get isOnline =>
      _phase == ConnectivityPhase.online ||
      _phase == ConnectivityPhase.justReconnected;

  bool get showBanner =>
      _phase == ConnectivityPhase.offline ||
      _phase == ConnectivityPhase.justReconnected ||
      _phase == ConnectivityPhase.refreshing;

  bool get isBannerRetrying => _phase == ConnectivityPhase.refreshing;

  /// Height of banner content below the status bar (fixed layout).
  static const double bannerContentHeight = 52;

  void addReconnectListener(VoidCallback listener) {
    if (!_reconnectListeners.contains(listener)) {
      _reconnectListeners.add(listener);
    }
  }

  void removeReconnectListener(VoidCallback listener) {
    _reconnectListeners.remove(listener);
  }

  Future<void> _init() async {
    await _connectivityService.ensureInitialized();
    _setPhase(
      _connectivityService.isConnected
          ? ConnectivityPhase.online
          : ConnectivityPhase.offline,
    );

    _subscription = _connectivityService.connectivityStream.listen(
      _onConnectivityChanged,
    );
  }

  void _onConnectivityChanged(bool connected) {
    if (connected) {
      if (_phase == ConnectivityPhase.offline ||
          _phase == ConnectivityPhase.refreshing) {
        _enterJustReconnected();
      } else if (_phase == ConnectivityPhase.checking) {
        _setPhase(ConnectivityPhase.online);
      }
    } else {
      _reconnectedTimer?.cancel();
      _setPhase(ConnectivityPhase.offline);
    }
  }

  void _enterJustReconnected() {
    _reconnectedTimer?.cancel();
    _reconnectNotifyTimer?.cancel();
    _setPhase(ConnectivityPhase.justReconnected);
    // Brief delay so the network stack is ready before screens refetch.
    _reconnectNotifyTimer = Timer(const Duration(milliseconds: 450), () {
      _notifyReconnectListeners();
    });
    _reconnectedTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_phase == ConnectivityPhase.justReconnected) {
        _setPhase(ConnectivityPhase.online);
      }
    });
  }

  void _notifyReconnectListeners() {
    for (final listener in List<VoidCallback>.from(_reconnectListeners)) {
      listener();
    }
  }

  void _setPhase(ConnectivityPhase next) {
    if (_phase == next) return;
    _phase = next;
    notifyListeners();
  }

  /// Re-checks device connectivity only (banner Retry action).
  Future<void> retryConnectivityCheck() async {
    if (_phase == ConnectivityPhase.refreshing) return;

    final wasOffline = _phase == ConnectivityPhase.offline;
    _setPhase(ConnectivityPhase.refreshing);

    final connected = await _connectivityService.checkConnectivity();

    if (connected) {
      if (wasOffline) {
        _enterJustReconnected();
      } else {
        _setPhase(ConnectivityPhase.online);
      }
    } else {
      _setPhase(ConnectivityPhase.offline);
    }
  }

  /// Re-check connectivity, then reload screen data when back online.
  Future<void> tryAgainWithRefresh(Future<void> Function() onRetry) async {
    await retryConnectivityCheck();
    if (isOnline) {
      await onRetry();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectedTimer?.cancel();
    _reconnectNotifyTimer?.cancel();
    super.dispose();
  }
}
