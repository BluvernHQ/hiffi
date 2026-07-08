import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'analytics_tags.dart';
import 'first_party_analytics_service.dart';

/// Thin helpers for first-party analytics aligned with hiffi_web.
abstract final class AnalyticsCapture {
  static FirstPartyAnalyticsService _service(BuildContext context) =>
      context.read<FirstPartyAnalyticsService>();

  static Future<void> click(
    BuildContext context, {
    required String elementUiName,
    required String screenName,
    String? videoId,
    String? videoTitle,
    Map<String, Object?>? properties,
  }) {
    return _service(context).capture(
      AnalyticsEvents.click,
      elementUiName: elementUiName,
      screenName: screenName,
      videoId: videoId,
      videoTitle: videoTitle,
      properties: properties,
    );
  }

  static Future<void> videoOpened(
    BuildContext context, {
    required String openUiName,
    required String screenName,
    required String videoId,
    required String videoTitle,
    required String source,
    String? sourcePath,
    Map<String, Object?>? extra,
  }) {
    final path = sourcePath ?? '/watch/$videoId';
    return _service(context).capture(
      AnalyticsEvents.openedVideo,
      elementUiName: openUiName,
      screenName: screenName,
      videoId: videoId,
      videoTitle: videoTitle,
      properties: {
        'source': source,
        'open_source': source,
        'source_path': path,
        'open_ui_name': openUiName,
        'video_id': videoId,
        'video_title': videoTitle,
        if (extra != null) ...extra,
      },
    );
  }

  static Future<void> conversion(
    BuildContext context, {
    required String eventName,
    required String screenName,
    String? videoId,
    String? videoTitle,
    Map<String, Object?>? properties,
  }) {
    final path = videoId != null ? '/watch/$videoId' : null;
    return _service(context).capture(
      eventName,
      screenName: screenName,
      videoId: videoId,
      videoTitle: videoTitle,
      properties: {
        if (path != null) 'source_path': path,
        if (properties != null) ...properties,
      },
    );
  }

  static Map<String, Object?> watchProperties({
    required String videoId,
    String? source,
    String? navigateTrigger,
    String? playbackStartTrigger,
    bool? isAutoplay,
    bool? isClick,
    String? playlistId,
    int? playlistTrackIndex,
  }) {
    return {
      'video_id': videoId,
      'source_path': '/watch/$videoId',
      if (source != null) ...{'source': source, 'open_source': source},
      if (navigateTrigger != null) 'navigate_trigger': navigateTrigger,
      if (playbackStartTrigger != null)
        'playback_start_trigger': playbackStartTrigger,
      if (isAutoplay != null) 'is_autoplay': isAutoplay,
      if (isClick != null) 'is_click': isClick,
      if (playlistId != null) 'playlist_id': playlistId,
      if (playlistTrackIndex != null) 'playlist_track_index': playlistTrackIndex,
    };
  }
}
