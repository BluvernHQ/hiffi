import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'package:flutter/services.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/media/media_sync_service.dart';
import 'core/services/hls_proxy_service.dart';
import 'core/services/pip_service.dart';
import 'core/workers/video_upload_worker.dart';
import 'core/utils/http_overrides.dart';
import 'core/utils/auth_error_utils.dart';
import 'core/utils/thumbnail_error_utils.dart';
import 'firebase_options.dart';
import 'package:clarity_flutter/clarity_flutter.dart';

bool _isExpectedUmamiOfflineError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('analytics.superlabs.co') &&
      (msg.contains('failed host lookup') ||
          msg.contains('socketexception') ||
          msg.contains('no address associated with hostname') ||
          msg.contains('network is unreachable'));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }

  // Lock orientation to portrait by default
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (errorDetails) {
    if (_isExpectedUmamiOfflineError(errorDetails.exception)) {
      if (kDebugMode) {
        debugPrint('Skipping expected Umami offline exception.');
      }
      return;
    }
    if (isExpectedThumbnailLoadError(errorDetails.exception)) {
      return;
    }
    if (isAuthRequiredError(errorDetails.exception)) {
      return;
    }
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    originalOnError?.call(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isExpectedUmamiOfflineError(error)) {
      if (kDebugMode) {
        debugPrint('Skipping expected Umami offline exception.');
      }
      return true;
    }
    if (isExpectedThumbnailLoadError(error)) {
      return true;
    }
    if (isAuthRequiredError(error)) {
      return true;
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await NotificationService().initialize();
  await MediaSyncService().initialize();
  await HlsProxyService().start();
  PipService.initialize();
  await Workmanager().initialize(callbackDispatcher);

  // Note: We don't cancel WorkManager tasks on app start
  // This allows in-progress uploads to continue even if the app was closed
  // The worker will gracefully handle stale tasks by checking if video files exist

  runApp(
    ClarityWidget(
      app: const HiffiApp(),
      clarityConfig: ClarityConfig(
        projectId: 'vni1e2qwaz',
        logLevel: LogLevel.None,
      ),
    ),
  );
}
