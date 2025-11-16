import 'dart:io';

import 'package:dospace/dospace.dart' as dospace;

class SpacesService {
  SpacesService({
    required String region,
    required String accessKey,
    required String secretKey,
  }) : _spaces = dospace.Spaces(
         region: region,
         accessKey: accessKey,
         secretKey: secretKey,
       );

  final dospace.Spaces _spaces;

  Future<String> uploadFile({
    required String bucketName,
    required File file,
    required String key,
    String? contentType,
    dospace.Permissions permissions = dospace.Permissions.private,
  }) async {
    final bucket = _spaces.bucket(bucketName);
    final etag = await bucket.uploadFile(
      key,
      file,
      contentType ?? 'application/octet-stream',
      permissions,
    );
    return etag ?? '';
  }

  void dispose() {
    _spaces.close();
  }
}
