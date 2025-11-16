import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dospace/dospace.dart' as dospace;

import '../../domain/services/spaces_service.dart';

class UploadViewModel extends ChangeNotifier {
  UploadViewModel({required SpacesService spacesService})
    : _spacesService = spacesService;

  final SpacesService _spacesService;
  static const String _bucketName = 'dev.hiffi';

  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;
  File? _selectedFile;
  String? _uploadedEtag;
  String? _uploadedPublicUrl;

  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  File? get selectedFile => _selectedFile;
  String get bucketName => _bucketName;
  String? get uploadedEtag => _uploadedEtag;
  String? get uploadedPublicUrl => _uploadedPublicUrl;
  bool get canUpload => _selectedFile != null && !_isUploading;

  Future<void> pickFile() async {
    _setError(null);
    _setSuccess(null);

    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        _selectedFile = File(result.files.single.path!);
        _uploadedEtag = null;
        _uploadedPublicUrl = null;
        notifyListeners();
      }
    } catch (error) {
      _setError('Failed to pick file: $error');
    }
  }

  Future<void> uploadFile() async {
    if (!canUpload) {
      developer.log(
        'Upload cancelled: canUpload is false',
        name: 'hiffi.upload',
        error: {
          'selectedFile': _selectedFile?.path,
          'isUploading': _isUploading,
        },
      );
      print('❌ Upload cancelled: canUpload is false');
      print('   - Selected file: ${_selectedFile?.path}');
      print('   - Is uploading: $_isUploading');
      return;
    }

    _setUploading(true);
    _setError(null);
    _setSuccess(null);

    final fileName = _selectedFile!.path.split('/').last;
    final fileSize = await _selectedFile!.length();
    final contentType = _getContentType(fileName);

    developer.log(
      'Starting file upload',
      name: 'hiffi.upload',
      error: {
        'bucketName': _bucketName,
        'fileName': fileName,
        'filePath': _selectedFile!.path,
        'fileSize': fileSize,
        'contentType': contentType,
      },
    );

    print('🚀 Starting file upload...');
    print('   📦 Bucket: $_bucketName');
    print('   📄 File name: $fileName');
    print('   📍 File path: ${_selectedFile!.path}');
    print(
      '   📊 File size: ${fileSize} bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)',
    );
    print('   🏷️  Content type: $contentType');

    try {
      print('   ⏳ Uploading to DigitalOcean Spaces...');
      final etag = await _spacesService.uploadFile(
        bucketName: _bucketName,
        file: _selectedFile!,
        key: fileName,
        contentType: contentType,
        permissions: dospace.Permissions.public,
      );

      _uploadedEtag = etag;
      _uploadedPublicUrl = _generatePublicUrl(_bucketName, fileName);

      developer.log(
        'File uploaded successfully',
        name: 'hiffi.upload',
        error: {'etag': etag, 'publicUrl': _uploadedPublicUrl},
      );

      print('✅ File uploaded successfully!');
      print('   🏷️  ETag: $etag');
      print('   🔗 Public URL: $_uploadedPublicUrl');

      _setSuccess('File uploaded successfully!');
    } catch (error, stackTrace) {
      developer.log(
        'Failed to upload file',
        name: 'hiffi.upload',
        error: error,
        stackTrace: stackTrace,
      );

      print('❌ Failed to upload file');
      print('   Error: $error');
      print('   Error type: ${error.runtimeType}');
      if (error is Exception) {
        print('   Exception: ${error.toString()}');
      }
      print('   Stack trace:');
      print(stackTrace);

      _setError('Failed to upload file: $error');
    } finally {
      _setUploading(false);
      print('   ✨ Upload process completed');
    }
  }

  String _generatePublicUrl(String bucketName, String key) {
    // Use path-style URL format to match the upload method
    // Path-style: https://{region}.digitaloceanspaces.com/{bucket}/{key}
    // This works for bucket names with dots (like "dev.hiffi")
    return 'https://blr1.digitaloceanspaces.com/$bucketName/$key';
  }

  String? _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  void _setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String? message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _spacesService.dispose();
    super.dispose();
  }
}
