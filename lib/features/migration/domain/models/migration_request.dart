enum MigrationPlatform { youtube, vimeo, twitch, other }

enum MigrationStatus {
  pending,
  underReview,
  approved,
  rejected,
  completed,
}

extension MigrationStatusLabels on MigrationStatus {
  String get label => switch (this) {
    MigrationStatus.pending => 'Pending',
    MigrationStatus.underReview => 'Under Review',
    MigrationStatus.approved => 'Approved',
    MigrationStatus.rejected => 'Rejected',
    MigrationStatus.completed => 'Completed',
  };

  static MigrationStatus? fromApi(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pending':
        return MigrationStatus.pending;
      case 'under_review':
        return MigrationStatus.underReview;
      case 'approved':
        return MigrationStatus.approved;
      case 'rejected':
        return MigrationStatus.rejected;
      case 'completed':
        return MigrationStatus.completed;
      default:
        return null;
    }
  }
}

class MigrationRequest {
  const MigrationRequest({
    required this.id,
    required this.requesterId,
    required this.platform,
    required this.channelUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.artistName,
    this.note,
    this.verifiedChannelId,
    this.verifiedGoogleEmail,
    this.referenceId,
    this.adminNotes,
    this.resolvedAt,
  });

  final String id;
  final String requesterId;
  final MigrationPlatform platform;
  final String channelUrl;
  final String? artistName;
  final String? note;
  final String? verifiedChannelId;
  final String? verifiedGoogleEmail;
  final MigrationStatus status;
  final String? referenceId;
  final String? adminNotes;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get blocksNewSubmission => switch (status) {
    MigrationStatus.pending ||
    MigrationStatus.underReview ||
    MigrationStatus.approved ||
    MigrationStatus.completed => true,
    MigrationStatus.rejected => false,
  };

  factory MigrationRequest.fromJson(Map<String, dynamic> json) {
    final platformRaw = (json['platform'] as String?) ?? 'youtube';
    final platform = switch (platformRaw.toLowerCase()) {
      'vimeo' => MigrationPlatform.vimeo,
      'twitch' => MigrationPlatform.twitch,
      'other' => MigrationPlatform.other,
      _ => MigrationPlatform.youtube,
    };

    return MigrationRequest(
      id: (json['id'] as String?) ?? '',
      requesterId: (json['requester_id'] as String?) ?? '',
      platform: platform,
      channelUrl: (json['channel_url'] as String?) ?? '',
      artistName: json['artist_name'] as String?,
      note: json['note'] as String?,
      verifiedChannelId: json['verified_channel_id'] as String?,
      verifiedGoogleEmail: json['verified_google_email'] as String?,
      status:
          MigrationStatusLabels.fromApi(json['status'] as String?) ??
          MigrationStatus.pending,
      referenceId: json['reference_id'] as String?,
      adminNotes: json['admin_notes'] as String?,
      resolvedAt: DateTime.tryParse((json['resolved_at'] as String?) ?? ''),
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse((json['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

Map<String, dynamic>? unwrapMigrationRequestJson(dynamic data) {
  if (data == null) return null;
  if (data is! Map<String, dynamic>) return null;

  for (final key in ['request', 'migration_request', 'migrationRequest']) {
    final nested = data[key];
    if (nested is Map<String, dynamic>) return nested;
  }

  if (data.containsKey('id') && data.containsKey('status')) {
    return data;
  }

  return null;
}
