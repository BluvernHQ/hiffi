import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'core/di/app_providers.dart';
import 'core/routes/app_router.dart';
import 'core/services/in_app_notification_service.dart';

class HiffiApp extends StatelessWidget {
  const HiffiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: Builder(
        builder: (context) {
          final appRouter = context.read<AppRouter>();
          return ScreenUtilInit(
            designSize: const Size(375, 812), // iPhone X design size
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              // Set navigator key for in-app notifications from router
              InAppNotificationService.setNavigatorKey(appRouter.navigatorKey);

              return MaterialApp.router(
                title: 'hiffi',
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: const ColorScheme(
                    brightness: Brightness.light,
                    primary: Color(0xFFFF6B35), // orange
                    onPrimary: Colors.white,
                    secondary: Color(0xFFFF8A5B),
                    onSecondary: Colors.white,
                    error: Color(0xFFB00020),
                    onError: Colors.white,
                    background: Colors.white,
                    onBackground: Color(0xFF1A1A1A),
                    surface: Color(0xFFFAFAFA),
                    onSurface: Color(0xFF1A1A1A),
                  ),
                  scaffoldBackgroundColor: Colors.white,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF1A1A1A),
                    elevation: 0,
                    centerTitle: false,
                  ),
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B35),
                    ),
                  ),
                  dividerColor: const Color(0xFFE0E0E0),
                ),
                routerConfig: appRouter.router,
              );
            },
          );
        },
      ),
    );
  }
}
