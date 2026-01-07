import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'package:flutter/services.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/workers/video_upload_worker.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait by default
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();
  await Workmanager().initialize(callbackDispatcher);

  // Note: We don't cancel WorkManager tasks on app start
  // This allows in-progress uploads to continue even if the app was closed
  // The worker will gracefully handle stale tasks by checking if video files exist

  runApp(const HiffiApp());
}
