import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required AuthRepository authRepository,
    required AuthViewModel authViewModel,
  }) : _authRepository = authRepository,
       _authViewModel = authViewModel;

  final AuthRepository _authRepository;
  final AuthViewModel _authViewModel;

  String? get currentDisplayName {
    final user = _authRepository.currentUser;
    if (user == null) {
      return null;
    }
    if (user.name != null && user.name!.isNotEmpty) {
      return user.name;
    }
    return user.username;
  }

  String? get currentUsername => _authViewModel.currentUsername;

  Future<void> signOut() async {
    await _authRepository.signOut();
    // Clear username after sign out
    _authViewModel.setCurrentUsername(null);
  }
}
