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

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    Firebase.app();
  }
}

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
      await _ensureFirebaseInitialized();
      print('✅ Firebase initialized in worker');

      // Initialize notification service - this may fail in background workers
      NotificationService? notificationService;
      try {
        notificationService = NotificationService();
        await notificationService.initialize(skipPermissionRequest: true);
        print('✅ Notification service initialized');
      } catch (e) {
        print('⚠️ Notification service initialization failed: $e');
      }

      final payload = VideoUploadPayload.fromMap(inputData);
      if (payload == null) {
        print('❌ Payload is null or invalid');
        return Future.value(false);
      }

      print('✅ Payload parsed successfully');
      print('   Task ID: ${payload.taskId}');
      print('   Video: ${payload.videoPath}');

      // Check if video file still exists
      final videoFile = File(payload.videoPath);
      if (!await videoFile.exists()) {
        print('❌ Video file no longer exists');
        return Future.value(false);
      }

      // Check network connectivity
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResults.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn,
      );

      if (!hasConnection) {
        print('❌ No internet connection detected');
        return Future.value(false);
      }

      final apiClient = ApiClient();
      final service = VideoUploadService(apiClient: apiClient);

      await notificationService?.showUploadStarted(
        taskId: payload.taskId,
        title: 'Upload started',
        body: 'Preparing to upload video...',
      );

      // Track if video upload stage was reached (indicates successful upload)
      bool videoUploadStageReached = false;

      final result = await service.uploadVideo(
        payload,
        onStage: (stage) async {
          final statusText = switch (stage) {
            VideoUploadStage.preparing => 'Preparing upload...',
            VideoUploadStage.uploadingVideo => 'Uploading video file...',
            VideoUploadStage.uploadingThumbnail => 'Uploading thumbnail...',
            VideoUploadStage.acknowledging => 'Finalizing upload...',
          };

          if (stage == VideoUploadStage.uploadingVideo) {
            videoUploadStageReached = true;
          }

          print('📊 Stage update: $stage - $statusText');

          // Notify main isolate
          final sendPort = ui.IsolateNameServer.lookupPortByName(
            videoUploadPortName,
          );
          if (sendPort != null) {
            sendPort.send({
              'taskId': payload.taskId,
              'stage': stage.toString(),
              'message': statusText,
            });
          }
        },
        onVideoProgress: (sent, total) async {
          final percent = total > 0 ? ((sent / total) * 100).toInt() : 0;

          // Update notification
          await notificationService?.showProgress(
            taskId: payload.taskId,
            title: 'Uploading video',
            body: 'Uploading video file... $percent%',
            progress: percent,
            maxProgress: 100,
          );

          // Notify main isolate
          final sendPort = ui.IsolateNameServer.lookupPortByName(
            videoUploadPortName,
          );
          if (sendPort != null) {
            sendPort.send({
              'taskId': payload.taskId,
              'progress': sent,
              'total': total,
            });
          }
        },
      );

      // Prevent duplicate uploads by treating success if video was uploaded but ack failed
      final acknowledgeFailed =
          result.message.contains('acknowledge') && !result.success;
      final shouldReturnSuccess =
          result.success || (videoUploadStageReached && acknowledgeFailed);

      print('✅ Upload service completed: success=${result.success}');

      await notificationService?.showCompletion(
        taskId: payload.taskId,
        title: shouldReturnSuccess ? 'Video uploaded' : 'Video upload failed',
        body: shouldReturnSuccess && !result.success
            ? 'Video uploaded but server acknowledgment pending. Please check your videos.'
            : result.message,
        success: shouldReturnSuccess,
      );

      // Send final result to main isolate
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
      }

      return shouldReturnSuccess;
    } catch (e, stackTrace) {
      print('❌ WORKMANAGER TASK ERROR: $e');
      print(stackTrace);
      return Future.value(false);
    }
  });
}
