import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_client.dart';

class FlagTypeConfig {
  const FlagTypeConfig({
    required this.reasons,
    required this.maxDescriptionLength,
  });

  final List<String> reasons;
  final int maxDescriptionLength;
}

class FlagsConfig {
  const FlagsConfig({
    required this.reportTypes,
    required this.statuses,
    required this.config,
  });

  final List<String> reportTypes;
  final List<String> statuses;
  final Map<String, FlagTypeConfig> config;
}

class FlagCase {
  const FlagCase({
    required this.id,
    required this.referenceId,
    required this.reportType,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.targetId,
    required this.targetType,
  });

  final String id;
  final String referenceId;
  final String reportType;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String targetId;
  final String targetType;

  factory FlagCase.fromJson(Map<String, dynamic> json) {
    return FlagCase(
      id: (json['id'] as String?) ?? '',
      referenceId: (json['reference_id'] as String?) ?? '',
      reportType: (json['report_type'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      targetId: (json['target_id'] as String?) ?? '',
      targetType: (json['target_type'] as String?) ?? '',
    );
  }
}

class FlagCaseDetail extends FlagCase {
  const FlagCaseDetail({
    required super.id,
    required super.referenceId,
    required super.reportType,
    required super.reason,
    required super.status,
    required super.createdAt,
    required super.targetId,
    required super.targetType,
    this.description,
    this.metadata = const {},
    this.updatedAt,
    this.resolvedAt,
  });

  final String? description;
  final Map<String, dynamic> metadata;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  factory FlagCaseDetail.fromJson(Map<String, dynamic> json) {
    return FlagCaseDetail(
      id: (json['id'] as String?) ?? '',
      referenceId: (json['reference_id'] as String?) ?? '',
      reportType: (json['report_type'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      targetId: (json['target_id'] as String?) ?? '',
      targetType: (json['target_type'] as String?) ?? '',
      description: json['description'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      updatedAt: DateTime.tryParse((json['updated_at'] as String?) ?? ''),
      resolvedAt: DateTime.tryParse((json['resolved_at'] as String?) ?? ''),
    );
  }
}

class FlagSubmissionResult {
  const FlagSubmissionResult({
    this.referenceId,
    this.status = 'pending',
  });

  final String? referenceId;
  final String status;

  factory FlagSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FlagSubmissionResult(
      referenceId: json['reference_id'] as String?,
      status: (json['status'] as String?)?.trim().isNotEmpty == true
          ? (json['status'] as String).trim()
          : 'pending',
    );
  }
}

class FlagRepository {
  FlagRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<FlagsConfig> getConfig() async {
    final response = await _apiClient.get(ApiConstants.flagsConfig);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || payload['success'] != true) {
      throw Exception(
        payload['error'] as String? ??
            'Failed to load report config (${response.statusCode})',
      );
    }
    final data = payload['data'] as Map<String, dynamic>? ?? const {};
    final reportTypes = (data['report_types'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final statuses = (data['statuses'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();

    final rawConfig = data['config'] as Map<String, dynamic>? ?? const {};
    final parsed = <String, FlagTypeConfig>{};
    rawConfig.forEach((key, value) {
      final map = value as Map<String, dynamic>? ?? const {};
      parsed[key] = FlagTypeConfig(
        reasons: (map['reasons'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        maxDescriptionLength:
            (map['max_description_length'] as num?)?.toInt() ?? 500,
      );
    });

    return FlagsConfig(
      reportTypes: reportTypes,
      statuses: statuses,
      config: parsed,
    );
  }

  Future<FlagSubmissionResult> createFlag({
    required String reportType,
    required String targetId,
    required String targetType,
    required String reason,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      'report_type': reportType,
      'target_id': targetId,
      'target_type': targetType,
      'reason': reason,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    final response = await _apiClient.post(
      ApiConstants.createFlag,
      body,
      requiresAuth: true,
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || payload['success'] != true) {
      throw Exception(
        payload['error'] as String? ??
            'Could not submit report (${response.statusCode})',
      );
    }
    final data = payload['data'] as Map<String, dynamic>? ?? const {};
    return FlagSubmissionResult.fromJson(data);
  }

  Future<List<FlagCase>> listMyFlags({int limit = 50, int offset = 0}) async {
    final endpoint = '${ApiConstants.flagsSelf}?limit=$limit&offset=$offset';
    final response = await _apiClient.get(endpoint, requiresAuth: true);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || payload['success'] != true) {
      throw Exception(
        payload['error'] as String? ??
            'Could not load reports (${response.statusCode})',
      );
    }
    final data = payload['data'] as Map<String, dynamic>? ?? const {};
    final flags = (data['flags'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FlagCase.fromJson)
        .toList();
    return flags;
  }

  Future<FlagCaseDetail> getByReference(String referenceId) async {
    final response = await _apiClient.get(
      ApiConstants.flagByReference(referenceId),
      requiresAuth: true,
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || payload['success'] != true) {
      throw Exception(
        payload['error'] as String? ??
            'Could not load report details (${response.statusCode})',
      );
    }
    final data = payload['data'] as Map<String, dynamic>? ?? const {};
    // resolution_notes are admin/moderator-only; never expose to reporters.
    final sanitized = Map<String, dynamic>.from(data)..remove('resolution_notes');
    return FlagCaseDetail.fromJson(sanitized);
  }
}
