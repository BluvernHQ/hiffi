import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/core/utils/playback_error_utils.dart';

void main() {
  test('maps ExoPlayer source error to offline UI', () {
    const raw =
        'Video player had error androidx.media3.exoplayer.ExoPlaybackException: Source error';
    expect(isLikelyPlaybackNetworkFailure(raw), isTrue);
    final display = playbackErrorDisplay(raw);
    expect(display.title, 'No internet connection');
    expect(display.isOffline, isTrue);
  });

  test('maps generic errors to neutral copy', () {
    final display = playbackErrorDisplay('Decoder init failed');
    expect(display.title, 'Unable to play video');
    expect(display.isOffline, isFalse);
  });
}
