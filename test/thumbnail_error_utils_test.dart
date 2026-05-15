import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/core/utils/thumbnail_error_utils.dart';

void main() {
  const thumbUri =
      'https://prod.hiffi.workers.dev/thumbnails/videos/abc.jpg';

  test('detects 404 thumbnail errors', () {
    expect(
      isExpectedThumbnailLoadError(
        Exception('HTTP request failed, statusCode: 404, $thumbUri'),
      ),
      isTrue,
    );
  });

  test('detects connection abort on thumbnail URLs', () {
    expect(
      isExpectedThumbnailLoadError(
        HttpException('Software caused connection abort', uri: Uri.parse(thumbUri)),
      ),
      isTrue,
    );
  });

  test('ignores non-thumbnail errors', () {
    expect(
      isExpectedThumbnailLoadError(
        HttpException('Software caused connection abort', uri: Uri.parse('https://example.com/foo')),
      ),
      isFalse,
    );
  });
}
