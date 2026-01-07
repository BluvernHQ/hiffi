import 'dart:convert';
import 'dart:developer' as developer;
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
typedef VideoUploadProgressCallback =
    Future<void> Function(int sentBytes, int totalBytes);

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
    VideoUploadProgressCallback? onVideoProgress,
  }) async {
    try {
      await onStage?.call(VideoUploadStage.preparing);
      final bridgeResponse = await _apiClient.post(
        ApiConstants.uploadVideo,
        {
          'video_title': payload.title,
          'video_description': payload.description,
          'video_tags': payload.tags,
        },
        requiresAuth: true,
        idToken: payload.idToken,
        headers: {
          'Idempotency-Key': payload.taskId,
        },
      );

      if (bridgeResponse.statusCode != 200) {
        return VideoUploadResult(
          success: false,
          message:
              'Failed to create upload bridge (${bridgeResponse.statusCode})',
        );
      }

      final responseBody = bridgeResponse.body;
      print('   📋 Bridge response body length: ${responseBody.length} chars');

      // Print full response for debugging (first 1000 chars)
      print(
        '   📋 Full response (first 1000 chars): ${responseBody.length > 1000 ? responseBody.substring(0, 1000) + "..." : responseBody}',
      );

      // Check if response looks truncated (doesn't end with } or ")
      if (!responseBody.trim().endsWith('}') &&
          !responseBody.trim().endsWith('"')) {
        print(
          '   ⚠️ WARNING: Response body might be truncated (does not end properly)',
        );
        print(
          '   📋 Response ends with: ${responseBody.substring(responseBody.length - 50)}',
        );
      }

      final responseJson = _decodeJson(responseBody) as Map<String, dynamic>?;

      if (responseJson == null) {
        print('   ❌ Failed to decode bridge response JSON');
        print('   📋 Full response body: $responseBody');
        developer.log(
          'Failed to decode bridge response JSON',
          name: 'hiffi.video_upload_service',
        );
        return VideoUploadResult(
          success: false,
          message:
              'Failed to parse upload bridge response JSON. Response may be truncated or malformed.',
        );
      }

      print('   ✅ JSON decoded successfully');
      print('   📋 Response JSON keys: ${responseJson.keys.toList()}');

      // Handle nested data structure: { "success": true, "data": { "bridge_id": ..., ... } }
      final dataObj = responseJson['data'];
      print('   📋 Data object type: ${dataObj.runtimeType}');

      final bridgeJson = dataObj is Map<String, dynamic>
          ? dataObj
          : responseJson; // Fallback to root if no 'data' key

      print('   📋 Using bridge JSON keys: ${bridgeJson.keys.toList()}');

      final gatewayUrl = bridgeJson['gateway_url'] as String?;
      final gatewayThumbnail = bridgeJson['gateway_url_thumbnail'] as String?;
      final bridgeId = bridgeJson['bridge_id'] as String?;

      print(
        '   📋 Extracted: gatewayUrl=${gatewayUrl != null ? "✅ (${gatewayUrl.length} chars)" : "❌ null"}',
      );
      print(
        '   📋 Extracted: gatewayThumbnail=${gatewayThumbnail != null ? "✅" : "❌ null"}',
      );
      print('   📋 Extracted: bridgeId=${bridgeId != null ? "✅" : "❌ null"}');

      if (gatewayUrl == null || bridgeId == null) {
        print('');
        print('❌ ============================================');
        print('❌ PARSING FAILED - MISSING REQUIRED FIELDS');
        print('❌ ============================================');
        print('❌ gatewayUrl: ${gatewayUrl ?? "NULL"}');
        print('❌ bridgeId: ${bridgeId ?? "NULL"}');
        print('❌ gatewayThumbnail: ${gatewayThumbnail ?? "NULL"}');
        print('❌ Available keys in bridgeJson: ${bridgeJson.keys.toList()}');
        print('❌ Response JSON keys: ${responseJson.keys.toList()}');
        print('❌ Data object is Map: ${dataObj is Map<String, dynamic>}');
        print('❌ Response body length: ${responseBody.length}');
        print(
          '❌ Response body (first 500 chars): ${responseBody.length > 500 ? responseBody.substring(0, 500) + "..." : responseBody}',
        );
        print('❌ ============================================');
        print('');
        developer.log(
          'Missing required fields in bridge response',
          name: 'hiffi.video_upload_service',
          error:
              'gatewayUrl: $gatewayUrl, bridgeId: $bridgeId, keys: ${bridgeJson.keys}, responseKeys: ${responseJson.keys}',
        );
        return VideoUploadResult(
          success: false,
          message:
              'Upload bridge response is missing required fields (gateway_url or bridge_id). Check logs for details.',
        );
      }

      print('');
      print('🚀 ============================================');
      print('🚀 STARTING UPLOAD PROCESS:');
      print('🚀 📹 Video: ${payload.videoPath}');
      print(
        '🚀 📸 Thumbnail: ${payload.resolvedThumbnailPath ?? "Auto-generated"}',
      );
      print('🚀 🔗 Bridge ID: $bridgeId');
      print('🚀 ============================================');
      print('');

      await onStage?.call(VideoUploadStage.uploadingVideo);
      print('📹 Starting video upload...');
      final videoFile = File(payload.videoPath);
      final videoResponse = await _apiClient.uploadFileToGateway(
        gatewayUrl,
        videoFile,
        contentType: _detectVideoMimeType(payload.videoPath),
        onProgress: (sent, total) async {
          if (onVideoProgress != null) {
            await onVideoProgress(sent, total);
          }
        },
      );

      if (videoResponse.statusCode != 200) {
        final errorBody = await videoResponse.stream.bytesToString();
        developer.log(
          'Video upload to gateway failed',
          name: 'hiffi.video_upload_service',
          error: 'Status: ${videoResponse.statusCode}, Body: $errorBody',
        );
        return VideoUploadResult(
          success: false,
          message:
              'Video upload failed (${videoResponse.statusCode}): $errorBody',
        );
      }

      developer.log(
        'Video uploaded to gateway successfully',
        name: 'hiffi.video_upload_service',
      );
      print('✅ Video uploaded successfully to gateway!');

      // Upload thumbnail if available (optional - don't fail if this fails)
      if (payload.resolvedThumbnailPath != null && gatewayThumbnail != null) {
        print('📸 Starting thumbnail upload...');
        await onStage?.call(VideoUploadStage.uploadingThumbnail);
        try {
          final thumbFile = File(payload.resolvedThumbnailPath!);
          print('   📄 Thumbnail file: ${thumbFile.path}');
          final thumbResponse = await _apiClient.uploadFileToGateway(
            gatewayThumbnail,
            thumbFile,
            contentType: 'image/jpeg',
          );

          if (thumbResponse.statusCode != 200) {
            final errorBody = await thumbResponse.stream.bytesToString();
            developer.log(
              'Thumbnail upload failed (non-critical)',
              name: 'hiffi.video_upload_service',
              error: 'Status: ${thumbResponse.statusCode}, Body: $errorBody',
            );
            print(
              '   ⚠️ Thumbnail upload failed (non-critical): ${thumbResponse.statusCode}',
            );
            // Don't fail the whole upload for thumbnail
          } else {
            developer.log(
              'Thumbnail uploaded successfully',
              name: 'hiffi.video_upload_service',
            );
            print('   ✅ Thumbnail uploaded successfully!');
          }
        } catch (e) {
          developer.log(
            'Thumbnail upload error (non-critical)',
            name: 'hiffi.video_upload_service',
            error: e,
          );
          print('   ⚠️ Thumbnail upload error (non-critical): $e');
          // Don't fail the whole upload for thumbnail
        }
      } else {
        print('📸 No thumbnail to upload (skipping thumbnail step)');
      }

      // Always acknowledge upload completion, even if thumbnail failed
      try {
        await onStage?.call(VideoUploadStage.acknowledging);
        developer.log(
          'Acknowledging upload completion',
          name: 'hiffi.video_upload_service',
        );
        print(
          '📤 Acknowledging upload: ${ApiConstants.uploadVideoAck(bridgeId)}',
        );

        final ackResponse = await _apiClient.post(
          ApiConstants.uploadVideoAck(bridgeId),
          const {},
          requiresAuth: true,
          idToken: payload.idToken,
          headers: {
            'Idempotency-Key': 'ack_${payload.taskId}',
          },
        );

        developer.log(
          'Acknowledge response: ${ackResponse.statusCode}',
          name: 'hiffi.video_upload_service',
        );
        print('   ✅ Acknowledge Response: ${ackResponse.statusCode}');
        if (ackResponse.body.isNotEmpty) {
          print('   📄 Acknowledge Body: ${ackResponse.body}');
        }

        if (ackResponse.statusCode != 200) {
          developer.log(
            'Failed to acknowledge upload',
            name: 'hiffi.video_upload_service',
            error:
                'Status: ${ackResponse.statusCode}, Body: ${ackResponse.body}',
          );
          print(
            '   ❌ Acknowledge failed: ${ackResponse.statusCode} - ${ackResponse.body}',
          );
          return VideoUploadResult(
            success: false,
            message:
                'Failed to acknowledge upload (${ackResponse.statusCode}): ${ackResponse.body}',
          );
        }

        developer.log(
          'Upload completed and acknowledged successfully',
          name: 'hiffi.video_upload_service',
        );
        print('   ✅ Upload acknowledged successfully!');
        print('');
        print('🎉 ============================================');
        print('🎉 UPLOAD COMPLETE SUMMARY:');
        print('🎉 ✅ Video: Uploaded');
        print(
          '🎉 ${payload.resolvedThumbnailPath != null && gatewayThumbnail != null ? "✅" : "⏭️"} Thumbnail: ${payload.resolvedThumbnailPath != null && gatewayThumbnail != null ? "Uploaded" : "Skipped"}',
        );
        print('🎉 ✅ Acknowledge: Completed');
        print('🎉 ============================================');
        print('');
        return VideoUploadResult(
          success: true,
          message: 'Video uploaded successfully',
        );
      } catch (ackError, stackTrace) {
        developer.log(
          'Exception during acknowledge step',
          name: 'hiffi.video_upload_service',
          error: ackError,
          stackTrace: stackTrace,
        );
        print('   ❌ Exception during acknowledge: $ackError');
        return VideoUploadResult(
          success: false,
          message: 'Video uploaded but acknowledge failed: $ackError',
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Video upload failed with exception',
        name: 'hiffi.video_upload_service',
        error: error,
        stackTrace: stackTrace,
      );
      print('❌ Upload exception: $error');
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
