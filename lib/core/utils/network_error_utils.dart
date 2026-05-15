import '../exceptions/api_exception.dart';
import '../exceptions/auth_failure.dart';
import '../services/network_connectivity_service.dart';

/// User-facing copy for connectivity failures (sign-in, feeds, uploads, etc.).
const String offlineUserMessage =
    'No internet connection. Please check your network and try again.';

bool isOfflineErrorMessage(String? message) {
  if (message == null || message.isEmpty) return false;
  final lower = message.toLowerCase();
  return lower.contains('no internet') ||
      lower.contains('nointernetexception') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('connection abort') ||
      lower.contains('connection refused') ||
      lower.contains('connection timed out');
}

bool isOfflineError(Object error) {
  if (error is NoInternetException) return true;
  return isOfflineErrorMessage(error.toString());
}

/// True when the device reports no connectivity ([NetworkConnectivityService]).
Future<bool> isDeviceOffline(NetworkConnectivityService? connectivity) async {
  if (connectivity == null) return false;
  await connectivity.ensureInitialized();
  return !connectivity.isConnected;
}

/// Returns [offlineUserMessage] when [error] is a connectivity failure.
String? offlineMessageIfApplicable(Object error) {
  return isOfflineError(error) ? offlineUserMessage : null;
}

/// Maps exceptions to short UI copy; avoids leaking type names like NoInternetException.
String userFriendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final offline = offlineMessageIfApplicable(error);
  if (offline != null) return offline;
  if (error is AuthFailure) return error.message;
  return fallback;
}

