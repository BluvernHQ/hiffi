import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connectivity/connectivity_controller.dart';
import '../connectivity/connectivity_phase.dart';
import 'offline_empty_state.dart';

/// Page-level shell: shows offline empty state only when offline with no cache.
class NetworkPageShell extends StatefulWidget {
  const NetworkPageShell({
    super.key,
    required this.hasCachedContent,
    required this.onRetry,
    required this.child,
    this.isLoading = false,
    this.emptyDescription,
    this.autoRefreshOnReconnect = true,
  });

  final bool hasCachedContent;
  final bool isLoading;
  final Future<void> Function() onRetry;
  final Widget child;
  final String? emptyDescription;
  final bool autoRefreshOnReconnect;

  @override
  State<NetworkPageShell> createState() => _NetworkPageShellState();
}

class _NetworkPageShellState extends State<NetworkPageShell> {
  bool _isRetrying = false;
  ConnectivityController? _connectivity;
  late final VoidCallback _reconnectListener = _onReconnect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<ConnectivityController>();
    if (_connectivity != next) {
      _connectivity?.removeReconnectListener(_reconnectListener);
      _connectivity = next;
      _connectivity!.addReconnectListener(_reconnectListener);
    }
  }

  @override
  void dispose() {
    _connectivity?.removeReconnectListener(_reconnectListener);
    super.dispose();
  }

  void _onReconnect() {
    if (!widget.autoRefreshOnReconnect || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    widget.onRetry();
  }

  Future<void> _handleTryAgain() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      await context.read<ConnectivityController>().tryAgainWithRefresh(
        widget.onRetry,
      );
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  bool _shouldShowOfflineEmpty(ConnectivityController connectivity) {
    if (widget.hasCachedContent) return false;
    if (connectivity.phase == ConnectivityPhase.offline) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityController>();
    final showOfflineEmpty = _shouldShowOfflineEmpty(connectivity);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: showOfflineEmpty
          ? OfflineEmptyState(
              key: const ValueKey('offline_empty'),
              description:
                  widget.emptyDescription ??
                  'Connect to the internet to load the latest content.',
              onTryAgain: _handleTryAgain,
              isRetrying: _isRetrying,
            )
          : KeyedSubtree(
              key: const ValueKey('page_content'),
              child: widget.child,
            ),
    );
  }
}
