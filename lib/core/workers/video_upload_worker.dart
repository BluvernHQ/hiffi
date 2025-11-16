import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../firebase_options.dart';
import '../../features/upload/data/models/video_upload_payload.dart';
import '../../features/upload/domain/services/video_upload_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

const String videoUploadTaskName = 'video_upload_task';
const String videoUploadPortName = 'video_upload_port';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('');
    print('🔄 ============================================');
    print('🔄 WORKMANAGER TASK STARTED');
    print('🔄 Task: $task');
    print('🔄 Input data keys: ${inputData?.keys.toList()}');
    print('🔄 ============================================');
    print('');

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized in worker');

      final notificationService = NotificationService();
      await notificationService.initialize();
      print('✅ Notification service initialized');

      final payload = VideoUploadPayload.fromMap(inputData);
      if (payload == null) {
        print('❌ Payload is null or invalid');
        await notificationService.showCompletion(
          taskId: 'unknown',
          title: 'Video upload failed',
          body: 'Payload was missing',
          success: false,
        );
        return Future.value(false);
      }

      print('✅ Payload parsed successfully');
      print('   Task ID: ${payload.taskId}');
      print('   Video: ${payload.videoPath}');
      print('   Title: ${payload.title}');

      final apiClient = ApiClient(firebaseAuth: FirebaseAuth.instance);
      final service = VideoUploadService(apiClient: apiClient);
      print('✅ ApiClient and VideoUploadService created');

      int progress = 0;
      const totalStages = 4;

      print('📢 Showing initial notification...');
      await notificationService.showProgress(
        taskId: payload.taskId,
        title: 'Uploading video',
        body: 'Preparing upload...',
        progress: progress,
        maxProgress: totalStages,
      );
      print('✅ Initial notification shown');

      print('🚀 Starting video upload service...');
      final result = await service.uploadVideo(
        payload,
        onStage: (stage) async {
          progress += 1;
          final statusText = switch (stage) {
            VideoUploadStage.preparing => 'Preparing upload...',
            VideoUploadStage.uploadingVideo => 'Uploading video file...',
            VideoUploadStage.uploadingThumbnail => 'Uploading thumbnail...',
            VideoUploadStage.acknowledging => 'Finalizing upload...',
          };

          print('📊 Stage update: $stage - $statusText');
          await notificationService.showProgress(
            taskId: payload.taskId,
            title: 'Uploading video',
            body: statusText,
            progress: progress,
            maxProgress: totalStages,
          );
        },
        onVideoProgress: (sent, total) async {
          // Map byte progress to a 0-100 scale for smoother notification updates
          final percent = total > 0
              ? ((sent / total) * 100).clamp(0, 100).toInt()
              : 0;
          await notificationService.showProgress(
            taskId: payload.taskId,
            title: 'Uploading video',
            body: 'Uploading video file... $percent%',
            progress: percent,
            maxProgress: 100,
          );
        },
      );

      print('✅ Upload service completed: success=${result.success}');
      print('📢 Showing completion notification...');
      await notificationService.showCompletion(
        taskId: payload.taskId,
        title: result.success ? 'Video uploaded' : 'Video upload failed',
        body: result.message,
        success: result.success,
      );
      print('✅ Completion notification shown');

      print('📤 Sending result to main isolate...');
      final sendPort = ui.IsolateNameServer.lookupPortByName(
        videoUploadPortName,
      );
      if (sendPort != null) {
        sendPort.send({
          'taskId': payload.taskId,
          'success': result.success,
          'message': result.message,
        });
        print('✅ Result sent to main isolate');
      } else {
        print('⚠️ Main isolate port not found (app may be terminated)');
      }

      print('');
      print('🎉 ============================================');
      print('🎉 WORKMANAGER TASK COMPLETED');
      print('🎉 Success: ${result.success}');
      print('🎉 Message: ${result.message}');
      print('🎉 ============================================');
      print('');

      return result.success;
    } catch (e, stackTrace) {
      print('');
      print('❌ ============================================');
      print('❌ WORKMANAGER TASK ERROR');
      print('❌ Error: $e');
      print('❌ StackTrace: $stackTrace');
      print('❌ ============================================');
      print('');

      try {
        final notificationService = NotificationService();
        await notificationService.initialize();
        final taskId = inputData?['taskId'] as String? ?? 'unknown';
        await notificationService.showCompletion(
          taskId: taskId,
          title: 'Video upload failed',
          body: 'Error: $e',
          success: false,
        );
      } catch (_) {
        // Ignore notification errors
      }

      return Future.value(false);
    }
  });
}
