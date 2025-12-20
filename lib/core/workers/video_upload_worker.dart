import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
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

      // Initialize notification service - this may fail in background workers
      // but we continue anyway as notifications are optional
      NotificationService? notificationService;
      try {
        notificationService = NotificationService();
        // Skip permission request in background worker (no Activity context)
        await notificationService.initialize(skipPermissionRequest: true);
        print('✅ Notification service initialized');
      } catch (e) {
        // Notification initialization failed, but we continue with upload
        print(
          '⚠️ Notification service initialization failed (non-critical): $e',
        );
        print('   Continuing with upload anyway...');
      }

      final payload = VideoUploadPayload.fromMap(inputData);
      if (payload == null) {
        print('❌ Payload is null or invalid');
        await notificationService?.showCompletion(
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

      // Check if video file still exists (prevents executing stale tasks)
      final videoFile = File(payload.videoPath);
      if (!await videoFile.exists()) {
        print('❌ Video file no longer exists: ${payload.videoPath}');
        print('   This task is likely stale from a previous session');
        print('   Canceling task gracefully...');

        await notificationService?.showCompletion(
          taskId: payload.taskId,
          title: 'Upload canceled',
          body: 'Video file no longer available',
          success: false,
        );

        print('   ✅ Task canceled (file not found)');
        return Future.value(false);
      }

      // Check network connectivity before starting upload
      print('🌐 Checking network connectivity...');
      final connectivity = Connectivity();
      final connectivityResults = await connectivity.checkConnectivity();
      final hasConnection = connectivityResults.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn,
      );

      if (!hasConnection) {
        print('❌ No internet connection detected');
        print('   Canceling upload task gracefully...');

        await notificationService?.showNetworkError(
          taskId: payload.taskId,
          title: 'Upload canceled',
          body: 'No internet connection. Please try again later.',
        );

        // Cancel the task - don't retry automatically
        print('   ✅ Task canceled (no retry scheduled)');
        return Future.value(false);
      }

      print('✅ Internet connection verified');

      final apiClient = ApiClient();
      final service = VideoUploadService(apiClient: apiClient);
      print('✅ ApiClient and VideoUploadService created');

      int progress = 0;
      const totalStages = 4;

      print('📢 Showing upload started notification...');
      await notificationService?.showUploadStarted(
        taskId: payload.taskId,
        title: 'Upload started',
        body: 'Preparing to upload video...',
      );
      print('✅ Upload started notification shown');

      print('📢 Showing initial progress notification...');
      await notificationService?.showProgress(
        taskId: payload.taskId,
        title: 'Uploading video',
        body: 'Preparing upload...',
        progress: progress,
        maxProgress: totalStages,
      );
      print('✅ Initial progress notification shown');

      print('🚀 Starting video upload service...');

      // Track if video upload stage was reached (indicates successful upload)
      bool videoUploadStageReached = false;

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

          // Track if we reached the video upload stage (means upload succeeded)
          if (stage == VideoUploadStage.uploadingVideo) {
            videoUploadStageReached = true;
          }

          print('📊 Stage update: $stage - $statusText');
          await notificationService?.showProgress(
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
          await notificationService?.showProgress(
            taskId: payload.taskId,
            title: 'Uploading video',
            body: 'Uploading video file... $percent%',
            progress: percent,
            maxProgress: 100,
          );
        },
      );

      // Check if acknowledge failed but video was uploaded
      // If video was uploaded successfully, we should not retry to avoid duplicates
      final acknowledgeFailed =
          result.message.contains('acknowledge') && !result.success;

      // If video was uploaded but acknowledge failed, treat as success
      // to prevent WorkManager from retrying (which would cause duplicate uploads)
      final shouldReturnSuccess =
          result.success || (videoUploadStageReached && acknowledgeFailed);

      print('✅ Upload service completed: success=${result.success}');
      print('   Video upload stage reached: $videoUploadStageReached');
      print('   Acknowledge failed: $acknowledgeFailed');
      print('   Should return success (prevent retry): $shouldReturnSuccess');

      print('📢 Showing completion notification...');
      await notificationService?.showCompletion(
        taskId: payload.taskId,
        title: shouldReturnSuccess ? 'Video uploaded' : 'Video upload failed',
        body: shouldReturnSuccess && !result.success
            ? 'Video uploaded but server acknowledgment pending. Please check your videos.'
            : result.message,
        success: shouldReturnSuccess,
      );
      print('✅ Completion notification shown');

      print('📤 Sending result to main isolate...');
      final sendPort = ui.IsolateNameServer.lookupPortByName(
        videoUploadPortName,
      );
      if (sendPort != null) {
        sendPort.send({
          'taskId': payload.taskId,
          'success': shouldReturnSuccess,
          'message': shouldReturnSuccess && !result.success
              ? 'Video uploaded but server acknowledgment pending'
              : result.message,
        });
        print('✅ Result sent to main isolate');
      } else {
        print('⚠️ Main isolate port not found (app may be terminated)');
      }

      print('');
      print('🎉 ============================================');
      print('🎉 WORKMANAGER TASK COMPLETED');
      print('🎉 Success: $shouldReturnSuccess');
      print('🎉 Original result: ${result.success}');
      print('🎉 Message: ${result.message}');
      print('🎉 ============================================');
      print('');

      // Return success if video was uploaded, even if acknowledge failed
      // This prevents WorkManager from retrying and causing duplicate uploads
      return shouldReturnSuccess;
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
        // Skip permission request in background worker (no Activity context)
        await notificationService.initialize(skipPermissionRequest: true);
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
