import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/workers/video_upload_worker.dart';
import '../../data/models/video_upload_payload.dart';
import '../../domain/services/video_upload_service.dart';

enum UploadStatus { idle, uploading, success, error, canceled }

class VideoUploadViewModel extends ChangeNotifier with WidgetsBindingObserver {
  VideoUploadViewModel({
    required ApiClient apiClient,
    required NotificationService notificationService,
  }) : _apiClient = apiClient,
       _notificationService = notificationService {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiClient _apiClient;
  final NotificationService _notificationService;

  bool _isAppInForeground = true;
  ReceivePort? _receivePort;

  // Form fields
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController tagInputController = TextEditingController();

  // File selections
  File? _selectedVideo;
  File? _selectedThumbnail;
  File? _videoThumbnail; // Auto-generated thumbnail from video

  // State
  bool _isUploading = false;
  bool _isGeneratingThumbnail = false;
  bool _isQueued = false;
  UploadStatus _uploadStatus = UploadStatus.idle;
  String? _errorMessage;
  String? _successMessage;
  final List<String> _tags = <String>[];
  String? _currentTaskId;
  bool _shouldPopAfterSuccess = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  // Getters
  File? get selectedVideo => _selectedVideo;
  File? get selectedThumbnail => _selectedThumbnail;
  File? get videoThumbnail => _videoThumbnail;
  bool get isGeneratingThumbnail => _isGeneratingThumbnail;
  bool get isUploading => _isUploading;
  bool get isQueued => _isQueued;
  UploadStatus get uploadStatus => _uploadStatus;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  List<String> get tags => List.unmodifiable(_tags);
  bool get shouldPopAfterSuccess => _shouldPopAfterSuccess;
  int get uploadProgress => _uploadProgress;
  int get uploadTotal => _uploadTotal;
  double get uploadProgressPercent =>
      _uploadTotal > 0 ? (_uploadProgress / _uploadTotal).clamp(0.0, 1.0) : 0.0;

  // Get the current thumbnail to display (custom if selected, otherwise auto-generated)
  File? get currentThumbnail => _selectedThumbnail ?? _videoThumbnail;
  bool get isAppInForeground => _isAppInForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final wasInForeground = _isAppInForeground;
    _isAppInForeground = state == AppLifecycleState.resumed;

    developer.log(
      'App lifecycle changed: $state (foreground: $_isAppInForeground)',
      name: 'hiffi.video_upload',
    );

    // If app just went to background and upload is in progress, show notification
    if (wasInForeground &&
        !_isAppInForeground &&
        _isQueued &&
        _currentTaskId != null) {
      _notificationService.showProgress(
        taskId: _currentTaskId!,
        title: 'Uploading video',
        body: 'Upload in progress...',
        progress: _uploadTotal > 0
            ? ((_uploadProgress / _uploadTotal) * 100).clamp(0, 100).toInt()
            : 0,
        maxProgress: 100,
      );
    }
  }

  bool get canUpload =>
      titleController.text.trim().isNotEmpty &&
      descriptionController.text.trim().isNotEmpty &&
      _tags.isNotEmpty &&
      _selectedVideo != null &&
      !_isUploading;

  // Tag APIs
  void addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) return;
    _tags.add(tag);
    tagInputController.clear();
    notifyListeners();
  }

  void removeTag(String tag) {
    _tags.remove(tag);
    notifyListeners();
  }

  void clearTags() {
    _tags.clear();
    tagInputController.clear();
    notifyListeners();
  }

  Future<void> pickVideo() async {
    _setError(null);
    _setSuccess(null);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        _selectedVideo = File(result.files.single.path!);
        _selectedThumbnail =
            null; // Reset custom thumbnail when new video is selected
        _videoThumbnail = null; // Clear old thumbnail
        notifyListeners();

        // Generate thumbnail from video
        await _generateVideoThumbnail();
      }
    } catch (error) {
      _setError('Failed to pick video: $error');
    }
  }

  void consumePopRequest() {
    _shouldPopAfterSuccess = false;
  }

  Future<void> _generateVideoThumbnail() async {
    if (_selectedVideo == null) return;

    _isGeneratingThumbnail = true;
    notifyListeners();

    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: _selectedVideo!.path,
        thumbnailPath: Directory.systemTemp.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1280,
        quality: 75,
        timeMs: 2000, // Get frame at 2 second
      );

      if (thumbnailPath != null) {
        _videoThumbnail = File(thumbnailPath);
        developer.log(
          'Video thumbnail generated: $thumbnailPath',
          name: 'hiffi.video_upload',
        );
      }
    } catch (error) {
      developer.log(
        'Failed to generate thumbnail: $error',
        name: 'hiffi.video_upload',
        error: error,
      );
      // Don't show error to user - thumbnail generation failure is not critical
    } finally {
      _isGeneratingThumbnail = false;
      notifyListeners();
    }
  }

  Future<void> pickThumbnail() async {
    _setError(null);
    _setSuccess(null);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        _selectedThumbnail = File(result.files.single.path!);
        notifyListeners();
      }
    } catch (error) {
      _setError('Failed to pick thumbnail: $error');
    }
  }

  void removeCustomThumbnail() {
    _selectedThumbnail = null;
    notifyListeners();
  }

  Future<bool> startUpload() async {
    if (!canUpload || _selectedVideo == null) {
      _setError('Please fill all required fields before uploading.');
      return false;
    }

    _setError(null);
    _setSuccess(null);
    _setUploading(true);
    _uploadStatus = UploadStatus.uploading;
    _shouldPopAfterSuccess = false;
    _uploadProgress = 0;
    _uploadTotal = 0;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null || token.isEmpty) {
        _setUploading(false);
        _setError('Authentication required to upload.');
        return false;
      }

      // Generate thumbnail if not already done
      if (_videoThumbnail == null && _selectedThumbnail == null) {
        await _generateVideoThumbnail();
      }

      final taskId =
          'video_upload_${DateTime.now().microsecondsSinceEpoch.toString()}';
      _currentTaskId = taskId;

      final payload = VideoUploadPayload(
        taskId: taskId,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        tags: List<String>.from(_tags),
        videoPath: _selectedVideo!.path,
        customThumbnailPath: _selectedThumbnail?.path,
        autoThumbnailPath: _selectedThumbnail == null
            ? _videoThumbnail?.path
            : null,
        idToken: token,
      );

      // Get file size for progress tracking
      final videoFile = File(payload.videoPath);
      _uploadTotal = await videoFile.length();

      // Initialize notification service
      await _notificationService.initialize();

      // Set up listener for background worker updates (for WorkManager fallback)
      _ensureReceivePort();

      // Register with WorkManager as backup (in case app terminates)
      try {
        await Workmanager().registerOneOffTask(
          taskId,
          videoUploadTaskName,
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(networkType: NetworkType.connected),
          inputData: payload.toMap(),
        );
        developer.log(
          'WorkManager backup registered: $taskId',
          name: 'hiffi.video_upload',
        );
        print('📋 WorkManager backup registered: $taskId');
      } catch (e) {
        developer.log(
          'Failed to register WorkManager backup (non-critical)',
          name: 'hiffi.video_upload',
          error: e,
        );
        print('⚠️ WorkManager registration failed (non-critical): $e');
      }

      // Start upload immediately in foreground
      _setUploading(true);
      _isQueued = false;

      developer.log(
        'Starting immediate foreground upload: $taskId',
        name: 'hiffi.video_upload',
      );
      print('🚀 Starting immediate foreground upload: $taskId');

      final service = VideoUploadService(apiClient: _apiClient);
      final result = await service.uploadVideo(
        payload,
        onStage: (stage) async {
          final statusText = switch (stage) {
            VideoUploadStage.preparing => 'Preparing upload...',
            VideoUploadStage.uploadingVideo => 'Uploading video file...',
            VideoUploadStage.uploadingThumbnail => 'Uploading thumbnail...',
            VideoUploadStage.acknowledging => 'Finalizing upload...',
          };

          developer.log('Upload stage: $stage', name: 'hiffi.video_upload');
          print('📊 Upload stage: $stage - $statusText');

          // Show notification only if app is backgrounded
          if (!_isAppInForeground) {
            final progress = stage == VideoUploadStage.acknowledging
                ? 100
                : (_uploadTotal > 0
                      ? ((_uploadProgress / _uploadTotal) * 100)
                            .clamp(0, 100)
                            .toInt()
                      : 0);

            await _notificationService.showProgress(
              taskId: taskId,
              title: 'Uploading video',
              body: statusText,
              progress: progress,
              maxProgress: 100,
            );
          }
        },
        onVideoProgress: (sent, total) async {
          _uploadProgress = sent;
          _uploadTotal = total;
          final percent = total > 0
              ? ((sent / total) * 100).clamp(0, 100).toInt()
              : 0;

          // Show notification only if app is backgrounded
          if (!_isAppInForeground) {
            await _notificationService.showProgress(
              taskId: taskId,
              title: 'Uploading video',
              body: 'Uploading video file... $percent%',
              progress: percent,
              maxProgress: 100,
            );
          }
          notifyListeners();
        },
      );

      _setUploading(false);

      developer.log(
        'Upload completed: success=${result.success}, message=${result.message}',
        name: 'hiffi.video_upload',
      );
      print(
        '✅ Upload result: success=${result.success}, message=${result.message}',
      );

      if (result.success) {
        // Cancel WorkManager task since we completed successfully in foreground
        try {
          await Workmanager().cancelByUniqueName(taskId);
          print('📋 Cancelled WorkManager backup task (upload completed)');
        } catch (e) {
          // Ignore cancellation errors
        }

        // Show completion notification only if app is backgrounded
        if (!_isAppInForeground) {
          await _notificationService.showCompletion(
            taskId: taskId,
            title: 'Video uploaded',
            body: result.message,
            success: true,
          );
        }

        _setSuccess(result.message);
        _uploadStatus = UploadStatus.success;
        _shouldPopAfterSuccess = true;
        _resetFormFields();
        print('🎉 Video upload completed successfully!');
      } else {
        // Don't cancel WorkManager if foreground upload failed - let it retry in background
        print(
          '⚠️ Foreground upload failed, WorkManager backup will handle retry',
        );

        // Show error notification only if app is backgrounded
        if (!_isAppInForeground) {
          await _notificationService.showCompletion(
            taskId: taskId,
            title: 'Video upload failed',
            body: result.message,
            success: false,
          );
        }

        _setError(result.message);
        _uploadStatus = UploadStatus.error;
        print('❌ Video upload failed: ${result.message}');
      }

      notifyListeners();
      return result.success;
    } catch (error) {
      developer.log(
        'Failed to start upload',
        name: 'hiffi.video_upload',
        error: error,
      );
      print('❌ Upload exception: $error');
      _setUploading(false);
      _isQueued = false;
      _setError('Failed to start upload: $error');

      // Don't cancel WorkManager - let it handle the upload as fallback
      print(
        '⚠️ Foreground upload exception, WorkManager backup will handle upload',
      );

      // Only show notification if app is backgrounded
      if (_currentTaskId != null && !_isAppInForeground) {
        await _notificationService.showCompletion(
          taskId: _currentTaskId!,
          title: 'Video upload failed',
          body: error.toString(),
          success: false,
        );
      }
      notifyListeners();
      return false;
    }
  }

  void _ensureReceivePort() {
    if (_receivePort != null) return;

    final existingPort = ui.IsolateNameServer.lookupPortByName(
      videoUploadPortName,
    );
    if (existingPort != null) {
      ui.IsolateNameServer.removePortNameMapping(videoUploadPortName);
    }

    _receivePort = ReceivePort();
    ui.IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      videoUploadPortName,
    );
    _receivePort!.listen(_handleBackgroundMessage);
  }

  void _handleBackgroundMessage(dynamic data) async {
    if (data is! Map) return;
    final taskId = data['taskId'] as String?;
    if (taskId == null || taskId != _currentTaskId) return;

    final success = data['success'] == true;
    final message =
        data['message'] as String? ??
        (success ? 'Video uploaded successfully' : 'Video upload failed');

    _isQueued = false;
    _currentTaskId = null;

    // Show completion notification only if app is backgrounded
    if (!_isAppInForeground) {
      await _notificationService.showCompletion(
        taskId: taskId,
        title: success ? 'Video uploaded' : 'Video upload failed',
        body: message,
        success: success,
      );
    }

    if (success) {
      _setSuccess(message);
      _uploadStatus = UploadStatus.success;
      _shouldPopAfterSuccess = true;
      _resetFormFields();
    } else {
      _setError(message);
      _uploadStatus = UploadStatus.error;
    }
    notifyListeners();
  }

  Future<void> cancelUpload() async {
    if (_currentTaskId != null) {
      await Workmanager().cancelByUniqueName(_currentTaskId!);
      await _notificationService.cancel(_currentTaskId!);
    }
    _currentTaskId = null;
    _isQueued = false;
    _isUploading = false;
    _uploadStatus = UploadStatus.canceled;
    _uploadProgress = 0;
    _uploadTotal = 0;
    _setError('Upload canceled by user');
    notifyListeners();
  }

  void clear() {
    titleController.clear();
    descriptionController.clear();
    clearTags();
    _selectedVideo = null;
    _selectedThumbnail = null;
    _videoThumbnail = null;
    _setError(null);
    _setSuccess(null);
    _uploadStatus = UploadStatus.idle;
    _isGeneratingThumbnail = false;
    _isQueued = false;
    _isUploading = false;
    _currentTaskId = null;
    _uploadProgress = 0;
    _uploadTotal = 0;
    notifyListeners();
  }

  void _setUploading(bool value) {
    _isUploading = value;
    if (!value && _uploadStatus == UploadStatus.uploading) {
      _uploadStatus = UploadStatus.idle;
    }
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    _successMessage = null;
    if (message != null && _uploadStatus != UploadStatus.canceled) {
      _uploadStatus = UploadStatus.error;
    }
    notifyListeners();
  }

  void _setSuccess(String? message) {
    _successMessage = message;
    _errorMessage = null;
    if (message != null && _uploadStatus != UploadStatus.canceled) {
      _uploadStatus = UploadStatus.success;
    }
    notifyListeners();
  }

  void _resetFormFields() {
    titleController.clear();
    descriptionController.clear();
    tagInputController.clear();
    _tags.clear();
    _selectedVideo = null;
    _selectedThumbnail = null;
    _videoThumbnail = null;
    _uploadProgress = 0;
    _uploadTotal = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receivePort?.close();
    ui.IsolateNameServer.removePortNameMapping(videoUploadPortName);
    titleController.dispose();
    descriptionController.dispose();
    tagInputController.dispose();
    super.dispose();
  }
}
