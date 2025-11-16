import 'dart:convert';
import 'dart:io';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_client.dart';
import '../../data/models/video_upload_payload.dart';

enum VideoUploadStage {
  preparing,
  uploadingVideo,
  uploadingThumbnail,
  acknowledging,
}

typedef VideoUploadStageCallback =
    Future<void> Function(VideoUploadStage stage);

class VideoUploadResult {
  VideoUploadResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class VideoUploadService {
  VideoUploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<VideoUploadResult> uploadVideo(
    VideoUploadPayload payload, {
    VideoUploadStageCallback? onStage,
  }) async {
    try {
      await onStage?.call(VideoUploadStage.preparing);
      final bridgeResponse = await _apiClient.post(ApiConstants.uploadVideo, {
        'video_title': payload.title,
        'video_description': payload.description,
        'video_tags': payload.tags,
      }, requiresAuth: true);

      if (bridgeResponse.statusCode != 200) {
        return VideoUploadResult(
          success: false,
          message:
              'Failed to create upload bridge (${bridgeResponse.statusCode})',
        );
      }

      final bridgeJson =
          _decodeJson(bridgeResponse.body) as Map<String, dynamic>? ?? {};
      final gatewayUrl = bridgeJson['gateway_url'] as String?;
      final gatewayThumbnail = bridgeJson['gateway_url_thumbnail'] as String?;
      final bridgeId = bridgeJson['bridge_id'] as String?;

      if (gatewayUrl == null || bridgeId == null) {
        return VideoUploadResult(
          success: false,
          message: 'Upload bridge response is missing required fields',
        );
      }

      await onStage?.call(VideoUploadStage.uploadingVideo);
      final videoFile = File(payload.videoPath);
      final videoResponse = await _apiClient.uploadFileToGateway(
        gatewayUrl,
        videoFile,
        contentType: _detectVideoMimeType(payload.videoPath),
      );

      if (videoResponse.statusCode != 200) {
        final errorBody = await videoResponse.stream.bytesToString();
        return VideoUploadResult(
          success: false,
          message:
              'Video upload failed (${videoResponse.statusCode}): $errorBody',
        );
      }

      if (payload.resolvedThumbnailPath != null && gatewayThumbnail != null) {
        await onStage?.call(VideoUploadStage.uploadingThumbnail);
        final thumbFile = File(payload.resolvedThumbnailPath!);
        final thumbResponse = await _apiClient.uploadFileToGateway(
          gatewayThumbnail,
          thumbFile,
          contentType: 'image/jpeg',
        );

        if (thumbResponse.statusCode != 200) {
          final errorBody = await thumbResponse.stream.bytesToString();
          return VideoUploadResult(
            success: false,
            message:
                'Thumbnail upload failed (${thumbResponse.statusCode}): $errorBody',
          );
        }
      }

      await onStage?.call(VideoUploadStage.acknowledging);
      final ackResponse = await _apiClient.post(
        ApiConstants.uploadVideoAck(bridgeId),
        const {},
        requiresAuth: true,
      );

      if (ackResponse.statusCode != 200) {
        return VideoUploadResult(
          success: false,
          message: 'Failed to acknowledge upload (${ackResponse.statusCode})',
        );
      }

      return VideoUploadResult(
        success: true,
        message: 'Video uploaded successfully',
      );
    } catch (error) {
      return VideoUploadResult(
        success: false,
        message: 'Video upload failed: $error',
      );
    }
  }

  dynamic _decodeJson(String body) {
    try {
      return body.isNotEmpty ? jsonDecode(body) : null;
    } catch (_) {
      return null;
    }
  }

  String _detectVideoMimeType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'video/mp4';
    }
  }
}
