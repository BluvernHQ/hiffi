import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'core/di/app_providers.dart';
import 'core/routes/app_router.dart';
import 'core/services/in_app_notification_service.dart';
import 'core/widgets/global_upload_overlay.dart';

class HiffiApp extends StatefulWidget {
  const HiffiApp({super.key});

  @override
  State<HiffiApp> createState() => _HiffiAppState();
}

class _HiffiAppState extends State<HiffiApp> {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSub;
  bool _deepLinksInitialized = false;

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks(AppRouter appRouter) async {
    if (_deepLinksInitialized) return;
    _deepLinksInitialized = true;

    _appLinks = AppLinks();

    try {
      // Handle initial deep link (app launched from URL).
      final initialUri = await _appLinks!.getInitialAppLink();
      if (initialUri != null) {
        _handleIncomingUri(initialUri, appRouter);
      }

      // Handle deep links while the app is already running.
      _linkSub = _appLinks!.uriLinkStream.listen(
        (uri) => _handleIncomingUri(uri, appRouter),
        onError: (Object err) {
          debugPrint('AppLinks error: $err');
        },
      );
    } on PlatformException catch (e) {
      debugPrint('Failed to initialize AppLinks: $e');
    }
  }

  /// Extracts the video ID from URLs like https://www.hiffi.com/watch/{videoId}.
  String? _extractVideoId(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'www.hiffi.com' && host != 'hiffi.com') return null;

    final segments = uri.pathSegments;
    if (segments.length != 2) return null;
    if (segments.first != 'watch') return null;

    final id = segments[1].trim();
    if (id.isEmpty) return null;

    return id;
  }

  void _handleIncomingUri(Uri uri, AppRouter appRouter) {
    final videoId = _extractVideoId(uri);

    // If the link is not a valid watch URL, send the user to home.
    if (videoId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        appRouter.router.go('/home');
      });
      return;
    }

    // Navigate to the internal /watch/:videoId route via GoRouter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      appRouter.router.go('/watch/$videoId');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: Builder(
        builder: (context) {
          final appRouter = context.read<AppRouter>();

          if (!_deepLinksInitialized) {
            _initDeepLinks(appRouter);
          }

          return ScreenUtilInit(
            designSize: const Size(375, 812), // iPhone X design size
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              // Set navigator key for in-app notifications from router
              InAppNotificationService.setNavigatorKey(appRouter.navigatorKey);

              return MaterialApp.router(
                title: 'Hiffi',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: const ColorScheme(
                    brightness: Brightness.light,
                    primary: Color(0xFFED1C2F), // red
                    onPrimary: Colors.white,
                    secondary: Color(0xFFF14D5D),
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
                      backgroundColor: const Color(0xFFED1C2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFED1C2F),
                    ),
                  ),
                  dividerColor: const Color(0xFFE0E0E0),
                ),
                routerConfig: appRouter.router,
                builder: (context, child) {
                  return Stack(
                    children: [
                      if (child != null) child,
                      const GlobalUploadOverlay(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
