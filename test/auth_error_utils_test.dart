import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/core/utils/auth_error_utils.dart';

void main() {
  test('detects JWT auth guard errors', () {
    expect(
      isAuthRequiredError(
        Exception('Authentication required: No JWT token available'),
      ),
      isTrue,
    );
  });

  test('ignores unrelated errors', () {
    expect(isAuthRequiredError(Exception('Failed to create playlist')), isFalse);
  });
}
