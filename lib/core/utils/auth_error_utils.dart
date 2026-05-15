/// Client-side auth guard failures and similar messages that should be handled in UI.
bool isAuthRequiredError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('authentication required') ||
      msg.contains('no jwt token') ||
      msg.contains('sign in required');
}

String authRequiredUserMessage() => 'Sign in to use playlists';
