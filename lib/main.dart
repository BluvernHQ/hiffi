import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
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
import 'firebase_options.dart';
import 'package:clarity_flutter/clarity_flutter.dart';

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
