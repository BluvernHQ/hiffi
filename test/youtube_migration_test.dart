import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/core/utils/youtube_url.dart';
import 'package:hiffi/features/migration/domain/models/migration_content_type.dart';

void main() {
  group('parseYoutubeTargetUrl', () {
    test('parses channel id URLs', () {
      final target = parseYoutubeTargetUrl(
        'https://www.youtube.com/channel/UCxxxxxxxxxxxxxxxxxxxxxx',
      );
      expect(target?.kind, YoutubeTargetKind.channelId);
      expect(target?.value, 'UCxxxxxxxxxxxxxxxxxxxxxx');
    });

    test('parses handle URLs', () {
      final target = parseYoutubeTargetUrl('https://youtube.com/@artisthandle');
      expect(target?.kind, YoutubeTargetKind.handle);
      expect(target?.value, '@artisthandle');
    });

    test('parses legacy user URLs', () {
      final target = parseYoutubeTargetUrl('https://youtube.com/user/someuser');
      expect(target?.kind, YoutubeTargetKind.username);
      expect(target?.value, 'someuser');
    });

    test('parses custom /c/ URLs', () {
      final target = parseYoutubeTargetUrl('https://youtube.com/c/CustomName');
      expect(target?.kind, YoutubeTargetKind.handle);
      expect(target?.value, 'CustomName');
    });

    test('parses playlist URLs', () {
      final target = parseYoutubeTargetUrl(
        'https://youtube.com/playlist?list=PLxxxxxxxxxxxxxxxx',
      );
      expect(target?.kind, YoutubeTargetKind.playlistId);
      expect(target?.value, 'PLxxxxxxxxxxxxxxxx');
    });

    test('parses watch URLs with list param', () {
      final target = parseYoutubeTargetUrl(
        'https://youtube.com/watch?v=abc123&list=PLxxxxxxxxxxxxxxxx',
      );
      expect(target?.kind, YoutubeTargetKind.playlistId);
    });

    test('rejects youtu.be short links', () {
      expect(
        parseYoutubeTargetUrl('https://youtu.be/abc123'),
        isNull,
      );
    });

    test('rejects bare watch URLs without playlist', () {
      expect(
        parseYoutubeTargetUrl('https://youtube.com/watch?v=abc123'),
        isNull,
      );
    });
  });

  group('isValidYoutubeUrl', () {
    test('returns false for empty input', () {
      expect(isValidYoutubeUrl(''), isFalse);
    });

    test('returns false for non-youtube domains', () {
      expect(isValidYoutubeUrl('https://vimeo.com/channels/staffpicks'), isFalse);
    });
  });

  group('buildMigrationNote', () {
    test('encodes content type in note', () {
      expect(
        buildMigrationNote(MigrationContentType.musicVideos),
        'Content type: Music Videos',
      );
    });

    test('appends optional user note', () {
      expect(
        buildMigrationNote(
          MigrationContentType.other,
          userNote: 'Mostly live sessions',
        ),
        'Content type: Other\n\nMostly live sessions',
      );
    });
  });

  group('extractContentTypeFromNote', () {
    test('parses first line', () {
      expect(
        extractContentTypeFromNote('Content type: Audio Tracks\n\nExtra'),
        'Audio Tracks',
      );
    });
  });
}
