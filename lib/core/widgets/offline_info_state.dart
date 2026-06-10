import 'package:flutter/material.dart';

import 'offline_empty_state.dart';

/// Backward-compatible wrapper around [OfflineEmptyState].
class OfflineInfoState extends StatelessWidget {
  const OfflineInfoState({
    super.key,
    this.title = "You're Offline",
    this.message = 'Connect to the internet and try again.',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return OfflineEmptyState(
      title: title,
      description: message,
      actionLabel: actionLabel ?? 'Try Again',
      onTryAgain: onAction,
    );
  }
}

