import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/data/auth_repository.dart';
import 'app_sidebar.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;

  const MainScaffold({super.key, required this.child, this.appBar});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final authRepository = context.watch<AuthRepository>();
    final isAuthenticated = authRepository.currentUser != null;

    // Only show sidebar if user is authenticated
    if (isAuthenticated) {
      return AppSidebar(
        currentRoute: currentRoute,
        child: Scaffold(
          appBar: appBar,
          body: SafeArea(child: child),
        ),
      );
    }

    // If not authenticated, show scaffold without sidebar
    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: child),
    );
  }
}
