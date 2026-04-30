import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/referral_storage_service.dart';
import '../../data/auth_repository.dart';

class ReferralEntryPage extends StatefulWidget {
  const ReferralEntryPage({super.key, required this.username});

  final String username;

  @override
  State<ReferralEntryPage> createState() => _ReferralEntryPageState();
}

class _ReferralEntryPageState extends State<ReferralEntryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleReferral());
  }

  Future<void> _handleReferral() async {
    final username = widget.username.trim().toLowerCase();
    if (username.isEmpty) {
      if (mounted) {
        context.go('/home');
      }
      return;
    }

    final isAuthenticated = context.read<AuthRepository>().currentUser != null;
    if (isAuthenticated) {
      if (mounted) {
        context.go('/users/$username');
      }
      return;
    }

    await ReferralStorageService.saveReferral(username: username);
    if (mounted) {
      context.go('/signup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
