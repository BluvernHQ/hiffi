import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'package:flutter/services.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/workmanager_service.dart';
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

  // Cancel any pending video upload tasks from previous sessions
  // This prevents automatic uploads when the app restarts
  // Users should explicitly start new uploads
  try {
    await WorkManagerService.cancelAllVideoUploadTasks();
    print('📋 Cancelled any pending video upload tasks from previous session');
  } catch (e) {
    print('⚠️ Failed to cancel pending tasks (non-critical): $e');
  }

  runApp(const HiffiApp());
}
