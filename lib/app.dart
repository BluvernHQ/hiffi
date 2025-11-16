import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/di/app_providers.dart';
import 'core/routes/app_router.dart';

class HiffiApp extends StatelessWidget {
  const HiffiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: Builder(
        builder: (context) {
          final appRouter = context.read<AppRouter>();
          return MaterialApp.router(
            title: 'hiffi',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}
