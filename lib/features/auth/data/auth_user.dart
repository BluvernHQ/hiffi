/// Simple auth user model for backend authentication
class AuthUser {
  final String uid;
  final String? email;
  final String? username;
  final String? name;

  AuthUser({required this.uid, this.email, this.username, this.name});
}
