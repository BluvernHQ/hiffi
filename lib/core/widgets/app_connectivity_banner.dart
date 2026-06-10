import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connectivity/connectivity_controller.dart';
import '../connectivity/connectivity_phase.dart';

/// Fixed strip below the status bar for offline / reconnected states.
class AppConnectivityBanner extends StatelessWidget {
  const AppConnectivityBanner({super.key});

  static const Color _offlineBg = Color(0xFFFFF4F4);
  static const Color _offlineBorder = Color(0xFFFECACA);
  static const Color _onlineBg = Color(0xFFECFDF3);
  static const Color _onlineBorder = Color(0xFFBBF7D0);
  static const Color _titleColor = Color(0xFF29292E);
  static const Color _subtitleColor = Color(0xFF6B6B6B);
  static const Color _successGreen = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityController>();
    final phase = connectivity.phase;

    if (phase == ConnectivityPhase.checking) {
      return const SizedBox.shrink();
    }

    final isReconnected = phase == ConnectivityPhase.justReconnected;
    final isOffline =
        phase == ConnectivityPhase.offline ||
        phase == ConnectivityPhase.refreshing;
    final isRetrying = phase == ConnectivityPhase.refreshing;

    if (!isOffline && !isReconnected) {
      return const SizedBox.shrink();
    }

    final statusBarTop = MediaQuery.paddingOf(context).top;
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: statusBarTop),
          decoration: BoxDecoration(
            color: isReconnected ? _onlineBg : _offlineBg,
            border: Border(
              bottom: BorderSide(
                color: isReconnected ? _onlineBorder : _offlineBorder,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (isReconnected ? _successGreen : primary)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isReconnected
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    size: 18,
                    color: isReconnected ? _successGreen : primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isReconnected
                            ? 'Back Online'
                            : 'No Internet Connection',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _titleColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isReconnected
                            ? "You're connected again."
                            : 'Some features may be unavailable.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _subtitleColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOffline) ...[
                  const SizedBox(width: 8),
                  _RetryChip(
                    isRetrying: isRetrying,
                    onPressed: isRetrying
                        ? null
                        : connectivity.retryConnectivityCheck,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryChip extends StatelessWidget {
  const _RetryChip({required this.isRetrying, required this.onPressed});

  final bool isRetrying;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: isRetrying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFED1C2F),
                  ),
                ),
        ),
      ),
    );
  }
}
