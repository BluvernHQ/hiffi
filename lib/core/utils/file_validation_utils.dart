import 'dart:io';

/// Utility class for file validation, especially for uploads
/// Ensures consistent validation rules across the app (matching web behavior)
class FileValidationUtils {
  // File size limits (in bytes)
  static const int maxProfilePictureSizeBytes = 10 * 1024 * 1024; // 10 MB
  // Future: Add more limits as needed
  // static const int maxCoverImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  // static const int maxVideoSizeBytes = 100 * 1024 * 1024; // 100 MB

  /// Validates that a file's size is within the allowed limit for profile pictures
  ///
  /// Returns a [FileValidationResult] indicating whether the file is valid
  /// and providing an error message if validation fails
  static FileValidationResult validateProfilePictureSize(File file) {
    try {
      // First check if file exists
      if (!file.existsSync()) {
        return FileValidationResult(
          isValid: false,
          errorMessage: 'File not found. Please try selecting the image again.',
        );
      }

      // Get file size - try sync first, fallback to async if needed
      int fileSize;
      try {
        fileSize = file.lengthSync();
      } catch (e) {
        // If sync fails, this is a critical error
        print('⚠️ Error reading file size synchronously: $e');
        return FileValidationResult(
          isValid: false,
          errorMessage:
              'Unable to read file size. Please try selecting a different image.',
        );
      }

      // Debug logging to help diagnose issues
      print(
        '📊 File size check: ${formatFileSize(fileSize)} / ${formatFileSize(maxProfilePictureSizeBytes)}',
      );

      if (fileSize > maxProfilePictureSizeBytes) {
        print(
          '❌ File size validation failed: ${formatFileSize(fileSize)} exceeds ${formatFileSize(maxProfilePictureSizeBytes)}',
        );
        return FileValidationResult(
          isValid: false,
          errorMessage:
              'Image size should be less than 10 MB. Please choose a smaller image.',
        );
      }

      print('✅ File size validation passed: ${formatFileSize(fileSize)}');
      return FileValidationResult(isValid: true);
    } catch (e) {
      // If we can't read the file size, treat it as invalid
      print('❌ Unexpected error in file size validation: $e');
      return FileValidationResult(
        isValid: false,
        errorMessage:
            'Unable to read file size. Please try selecting a different image.',
      );
    }
  }

  /// Validates file extension for images
  ///
  /// Returns true if the file extension is a valid image format (jpg, jpeg, png)
  static bool isValidImageExtension(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  /// Formats file size in bytes to a human-readable string
  /// Useful for error messages or debugging
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// Result of file validation
class FileValidationResult {
  const FileValidationResult({required this.isValid, this.errorMessage});

  /// Whether the file passed validation
  final bool isValid;

  /// Error message if validation failed (user-friendly, non-technical)
  final String? errorMessage;
}
