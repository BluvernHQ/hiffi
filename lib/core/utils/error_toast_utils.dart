import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../exceptions/api_exception.dart';
import 'network_error_utils.dart';

/// Toast for caught exceptions — network vs generic (release-safe).
void showCatchToast(
  BuildContext context,
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final message = _messageForCatch(error, fallback: fallback);
  _showToast(context, message, isOffline: isOfflineError(error));
}

/// Toast for API failures — prefers server message over transport errors.
void showApiFailureMessage(
  BuildContext context, {
  String? apiMessage,
  Object? error,
  String fallback = 'Something went wrong. Please try again.',
}) {
  String message;
  var offline = false;

  if (apiMessage != null && apiMessage.trim().isNotEmpty) {
    message = apiMessage.trim();
  } else if (error != null) {
    message = _messageForCatch(error, fallback: fallback);
    offline = isOfflineError(error);
  } else {
    message = fallback;
  }

  _showToast(context, message, isOffline: offline);
}

String _messageForCatch(Object error, {required String fallback}) {
  final offline = offlineMessageIfApplicable(error);
  if (offline != null) return offline;
  if (error is ApiException && error.message.isNotEmpty) {
    return error.message;
  }
  if (kDebugMode && error.toString().isNotEmpty) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return fallback;
}

void _showToast(
  BuildContext context,
  String message, {
  required bool isOffline,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    ),
  );
}
