import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/workers/video_upload_worker.dart';
import '../../data/models/video_upload_payload.dart';

enum UploadStatus { idle, uploading, success, error, canceled }

class VideoUploadViewModel extends ChangeNotifier {
  VideoUploadViewModel();

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
  ReceivePort? _receivePort;
  int _listenerRefs = 0;

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

  // Get the current thumbnail to display (custom if selected, otherwise auto-generated)
  File? get currentThumbnail => _selectedThumbnail ?? _videoThumbnail;

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

  Future<bool> scheduleUpload() async {
    if (!canUpload || _selectedVideo == null) {
      _setError('Please fill all required fields before uploading.');
      return false;
    }

    _setError(null);
    _setSuccess(null);
    _setUploading(true);
    _uploadStatus = UploadStatus.uploading;
    _shouldPopAfterSuccess = false;
    notifyListeners();

    try {
      if (_videoThumbnail == null && _selectedThumbnail == null) {
        await _generateVideoThumbnail();
      }

      final taskId =
          'video_upload_${DateTime.now().microsecondsSinceEpoch.toString()}';
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
      );

      _ensureReceivePort();
      _currentTaskId = taskId;

      await Workmanager().registerOneOffTask(
        taskId,
        videoUploadTaskName,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: payload.toMap(),
      );

      _isQueued = true;
      _setSuccess(
        'Video upload scheduled. You will be notified when it finishes.',
      );
      _resetFormFields();
      _setUploading(false);
      notifyListeners();
      return true;
    } catch (error) {
      developer.log(
        'Failed to schedule background upload',
        name: 'hiffi.video_upload',
        error: error,
      );
      _setUploading(false);
      _setError('Failed to schedule background upload: $error');
      return false;
    }
  }

  Future<void> cancelScheduledUpload() async {
    if (_currentTaskId == null) return;
    await Workmanager().cancelByUniqueName(_currentTaskId!);
    _currentTaskId = null;
    _isQueued = false;
    _uploadStatus = UploadStatus.canceled;
    _setError('Upload canceled by user');
  }

  void registerForegroundListener() {
    _listenerRefs++;
    _ensureReceivePort();
  }

  void unregisterForegroundListener() {
    if (_listenerRefs > 0) {
      _listenerRefs--;
    }
    if (_listenerRefs == 0 && _receivePort != null) {
      ui.IsolateNameServer.removePortNameMapping(videoUploadPortName);
      _receivePort?.close();
      _receivePort = null;
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

  void _handleBackgroundMessage(dynamic data) {
    if (data is! Map) return;
    final taskId = data['taskId'] as String?;
    if (taskId == null || taskId != _currentTaskId) return;

    final success = data['success'] == true;
    final message =
        data['message'] as String? ??
        (success ? 'Video uploaded successfully' : 'Video upload failed');

    _isQueued = false;
    _currentTaskId = null;

    if (success) {
      _setSuccess(message);
      _uploadStatus = UploadStatus.success;
      _shouldPopAfterSuccess = true;
    } else {
      _setError(message);
      _uploadStatus = UploadStatus.error;
    }
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
    _currentTaskId = null;
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
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    tagInputController.dispose();
    unregisterForegroundListener();
    super.dispose();
  }
}
