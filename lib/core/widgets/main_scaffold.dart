import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/data/auth_repository.dart';
import 'app_sidebar.dart';
import '../utils/responsive.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;

  const MainScaffold({super.key, required this.child, this.appBar});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final authRepository = context.watch<AuthRepository>();
    final isAuthenticated = authRepository.currentUser != null;

      return AppSidebar(
        currentRoute: currentRoute,
      isAuthenticated: isAuthenticated,
        child: Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: ResponsiveMaxWidth(child: child),
          ),
        ),
    );
  }
}
