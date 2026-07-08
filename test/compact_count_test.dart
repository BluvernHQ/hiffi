import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/core/utils/compact_count.dart';

void main() {
  group('shouldShowEngagementCount', () {
    test('hides counts below 10k', () {
      expect(shouldShowEngagementCount(0), isFalse);
      expect(shouldShowEngagementCount(9999), isFalse);
    });

    test('shows counts at or above 10k', () {
      expect(shouldShowEngagementCount(10000), isTrue);
      expect(shouldShowEngagementCount(15000), isTrue);
    });
  });
}
