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

void videoUploadCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final notificationService = NotificationService();
    await notificationService.initialize();

    final payload = VideoUploadPayload.fromMap(inputData);
    if (payload == null) {
      await notificationService.showCompletion(
        taskId: 'unknown',
        title: 'Video upload failed',
        body: 'Payload was missing',
        success: false,
      );
      return Future.value(false);
    }

    final apiClient = ApiClient(firebaseAuth: FirebaseAuth.instance);
    final service = VideoUploadService(apiClient: apiClient);

    int progress = 0;
    const totalStages = 4;

    await notificationService.showProgress(
      taskId: payload.taskId,
      title: 'Uploading video',
      body: 'Preparing upload...',
      progress: progress,
      maxProgress: totalStages,
    );

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

        await notificationService.showProgress(
          taskId: payload.taskId,
          title: 'Uploading video',
          body: statusText,
          progress: progress,
          maxProgress: totalStages,
        );
      },
    );

    await notificationService.showCompletion(
      taskId: payload.taskId,
      title: result.success ? 'Video uploaded' : 'Video upload failed',
      body: result.message,
      success: result.success,
    );

    final sendPort = ui.IsolateNameServer.lookupPortByName(videoUploadPortName);
    sendPort?.send({
      'taskId': payload.taskId,
      'success': result.success,
      'message': result.message,
    });

    return result.success;
  });
}
