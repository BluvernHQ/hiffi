import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../core/analytics/first_party_analytics_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required AuthRepository authRepository,
    required AuthViewModel authViewModel,
    FirstPartyAnalyticsService? firstPartyAnalytics,
  }) : _authRepository = authRepository,
       _authViewModel = authViewModel,
       _firstPartyAnalytics = firstPartyAnalytics;

  final AuthRepository _authRepository;
  final AuthViewModel _authViewModel;
  final FirstPartyAnalyticsService? _firstPartyAnalytics;

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
    await _firstPartyAnalytics?.identify(null);
    // Clear auth state and form fields after sign out
    _authViewModel.reset();
  }
}
