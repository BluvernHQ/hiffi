import 'dart:convert';

class VideoUploadPayload {
  const VideoUploadPayload({
    required this.taskId,
    required this.title,
    required this.description,
    required this.tags,
    required this.videoPath,
    this.customThumbnailPath,
    this.autoThumbnailPath,
  });

  final String taskId;
  final String title;
  final String description;
  final List<String> tags;
  final String videoPath;
  final String? customThumbnailPath;
  final String? autoThumbnailPath;

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'title': title,
      'description': description,
      'tags': jsonEncode(tags),
      'videoPath': videoPath,
      'customThumbnailPath': customThumbnailPath,
      'autoThumbnailPath': autoThumbnailPath,
    };
  }

  static VideoUploadPayload? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final tagsJson = map['tags'] as String?;
    return VideoUploadPayload(
      taskId: map['taskId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      tags: tagsJson != null
          ? (jsonDecode(tagsJson) as List<dynamic>).cast<String>()
          : const [],
      videoPath: map['videoPath'] as String? ?? '',
      customThumbnailPath: map['customThumbnailPath'] as String?,
      autoThumbnailPath: map['autoThumbnailPath'] as String?,
    );
  }

  String? get resolvedThumbnailPath => customThumbnailPath ?? autoThumbnailPath;
}
