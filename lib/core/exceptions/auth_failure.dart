class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}
