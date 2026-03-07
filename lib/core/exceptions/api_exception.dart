class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException([this.message = 'No internet connection']);

  @override
  String toString() => 'NoInternetException: $message';
}
