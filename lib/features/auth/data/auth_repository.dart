import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/exceptions/auth_failure.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({required FirebaseAuth auth}) : _auth = auth;

  final FirebaseAuth _auth;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw const AuthFailure('Please enter your credentials.');
    }

    final trimmedEmail = email.trim();

    if (!trimmedEmail.contains('@')) {
      throw const AuthFailure('Please enter a valid email address.');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageForFirebaseAuthCode(error.code));
    }
  }

  @override
  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageForFirebaseAuthCode(error.code));
    }

    final user = credential.user;
    if (user == null) {
      throw const AuthFailure('Account creation failed. Please retry.');
    }

    // Update display name in Firebase Auth
    await user.updateDisplayName(name);

    // Note: User profile creation is now handled by backend API in AuthViewModel
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }

  String _messageForFirebaseAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with those credentials.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'email-already-in-use':
        return 'That email is already associated with an account.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Authentication failed. ($code)';
    }
  }
}
