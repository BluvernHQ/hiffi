import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/core/exceptions/api_exception.dart';
import 'package:hiffi/core/utils/network_error_utils.dart';

void main() {
  test('maps NoInternetException to friendly message', () {
    expect(
      userFriendlyErrorMessage(NoInternetException()),
      offlineUserMessage,
    );
  });

  test('maps wrapped register error to friendly message', () {
    expect(
      userFriendlyErrorMessage(
        Exception(
          'Failed to register: NoInternetException: No internet connection',
        ),
      ),
      offlineUserMessage,
    );
  });

  test('uses fallback for unknown errors', () {
    expect(
      userFriendlyErrorMessage(Exception('Server error')),
      'Something went wrong. Please try again.',
    );
  });
}
