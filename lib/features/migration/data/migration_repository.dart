import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/services/api_client.dart';
import '../domain/models/migration_content_type.dart';
import '../domain/models/migration_request.dart';

class MigrationConfig {
  const MigrationConfig({
    required this.platforms,
    required this.statuses,
  });

  final List<String> platforms;
  final List<String> statuses;

  factory MigrationConfig.fromJson(Map<String, dynamic> json) {
    return MigrationConfig(
      platforms: (json['platforms'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      statuses: (json['statuses'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class MigrationRepository {
  MigrationRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MigrationConfig?> getConfig() async {
    final response = await _apiClient.get(ApiConstants.migrationRequestsConfig);
    if (response.statusCode != 200) return null;

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) return null;

    final data = payload['data'] ?? payload;
    if (data is! Map<String, dynamic>) return null;
    return MigrationConfig.fromJson(data);
  }

  Future<MigrationRequest> submitRequest({
    required String channelUrl,
    required String artistName,
    required MigrationContentType contentType,
    String? userNote,
  }) async {
    final body = <String, dynamic>{
      'platform': 'youtube',
      'channel_url': channelUrl.trim(),
      'artist_name': artistName,
      'note': buildMigrationNote(contentType, userNote: userNote),
    };

    final response = await _apiClient.post(
      ApiConstants.migrationRequests,
      body,
      requiresAuth: true,
    );

    final payload = _decodePayload(response.body);
    if (response.statusCode == 409) {
      throw ApiException(
        _messageFromPayload(payload) ?? 'Request already exists',
        409,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (payload['success'] == false)) {
      throw ApiException(
        _messageFromPayload(payload) ??
            'Could not submit migration request (${response.statusCode})',
        response.statusCode,
      );
    }

    final data = payload['data'] ?? payload;
    final requestJson = unwrapMigrationRequestJson(data);
    if (requestJson == null) {
      throw ApiException('Invalid migration response', response.statusCode);
    }
    return MigrationRequest.fromJson(requestJson);
  }

  Future<MigrationRequest?> getMyStatus() async {
    final response = await _apiClient.get(
      ApiConstants.migrationRequestsStatus,
      requiresAuth: true,
    );

    final payload = _decodePayload(response.body);
    if (response.statusCode != 200 || payload['success'] == false) {
      throw ApiException(
        _messageFromPayload(payload) ??
            'Could not load migration status (${response.statusCode})',
        response.statusCode,
      );
    }

    final data = payload['data'] ?? payload;
    if (data is! Map<String, dynamic>) return null;

    final requestJson = unwrapMigrationRequestJson(data);
    if (requestJson == null) return null;
    return MigrationRequest.fromJson(requestJson);
  }

  Map<String, dynamic> _decodePayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // ignore
    }
    return const {};
  }

  String? _messageFromPayload(Map<String, dynamic> payload) {
    final error = payload['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    final message = payload['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['message'];
      if (nested is String && nested.trim().isNotEmpty) return nested.trim();
    }
    return null;
  }
}
