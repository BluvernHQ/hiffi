import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../constants/api_constants.dart';
import 'token_storage_service.dart';

class ApiClient {
  ApiClient();
  final http.Client _client = http.Client();

  // Custom HTTP client for uploads with relaxed certificate validation (dev only)
  http.Client? _uploadClient;

  http.Client get _uploadHttpClient {
    _uploadClient ??= _createUploadClient();
    return _uploadClient!;
  }

  http.Client _createUploadClient() {
    final httpClient = HttpClient();
    // Allow bad certificates for development (handles hostname mismatch issues)
    // WARNING: Only use this for development environments
    httpClient
        .badCertificateCallback = (X509Certificate cert, String host, int port) {
      // For development, allow certificates even if hostname doesn't match
      // In production, you should validate the certificate properly
      print(
        '   ⚠️ Certificate validation: Allowing certificate for $host:$port (dev mode)',
      );
      return true;
    };
    return IOClient(httpClient);
  }

  Future<String?> _getIdToken({bool forceRefresh = false}) async {
    try {
      developer.log('Getting JWT token from storage', name: 'hiffi.api');
      print('   🔑 Getting JWT token from storage...');

      final token = await TokenStorageService.getToken();

      if (token == null || token.isEmpty) {
        developer.log('JWT token is null or empty', name: 'hiffi.api');
        print('   ⚠️ JWT token is null or empty');
        return null;
      }

      developer.log(
        'Retrieved JWT token (length: ${token.length})',
        name: 'hiffi.api',
      );
      print('   ✅ JWT token retrieved (${token.length} chars)');
      return token;
    } catch (error) {
      developer.log(
        'Failed to get JWT token: $error',
        name: 'hiffi.api',
        error: error,
      );
      print('   ❌ Failed to get JWT token: $error');
      return null;
    }
  }

  Future<http.Response> get(
    String endpoint, {
    bool requiresAuth = false,
    bool optionalAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    developer.log('GET $url', name: 'hiffi.api');
    print('🌐 API GET: $url');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Hiffi-Flutter-App/1.0',
    };

    if (requiresAuth || optionalAuth) {
      // Get JWT token from storage
      final token = await _getIdToken(forceRefresh: false);
      if (token != null && token.isNotEmpty) {
        // Trim token to remove any whitespace and ensure clean format
        final cleanToken = token.trim();
        headers['Authorization'] = 'Bearer $cleanToken';
        print('   🔑 Using Bearer token (cached)');
        // Log first and last few chars of token for debugging (not full token for security)
        if (cleanToken.length > 20) {
          print(
            '   🔍 Token preview: ${cleanToken.substring(0, 10)}...${cleanToken.substring(cleanToken.length - 10)}',
          );
        }
      } else if (requiresAuth) {
        // Only throw if auth is required (not optional)
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No JWT token available');
      } else {
        // Optional auth - no token available, continue without auth
        print('   ℹ️ No token available (optional auth - continuing without)');
      }
    }

    try {
      final response = await _client.get(url, headers: headers);
      developer.log(
        'GET $url - Status: ${response.statusCode}',
        name: 'hiffi.api',
      );
      print('   ✅ Response: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('   📄 Body: ${response.body}');
      }

      // If 401, token might be expired - user needs to login again
      if (response.statusCode == 401 && requiresAuth) {
        print('   ⚠️ 401 Unauthorized - Token may be expired');
        print('   💡 User needs to login again to get a new token');
      }
      // For optional auth, 401 is acceptable - endpoint may require auth but we tried without it

      return response;
    } catch (error) {
      developer.log('GET $url failed: $error', name: 'hiffi.api', error: error);
      print('   ❌ Error: $error');
      rethrow;
    }
  }

  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
    String? idToken,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    developer.log('POST $url', name: 'hiffi.api');
    print('🌐 API POST: $url');
    print('   📤 Body: $body');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      // Get JWT token from storage
      final token = idToken ?? await _getIdToken(forceRefresh: false);
      if (token == null) {
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No JWT token available');
      }
      // Trim token to remove any whitespace and ensure clean format
      final cleanToken = token.trim();
      headers['Authorization'] = 'Bearer $cleanToken';
      print('   🔑 Using Bearer token');
      // Log first and last few chars of token for debugging (not full token for security)
      if (cleanToken.length > 20) {
        print(
          '   🔍 Token preview: ${cleanToken.substring(0, 10)}...${cleanToken.substring(cleanToken.length - 10)}',
        );
      }
    }

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      developer.log(
        'POST $url - Status: ${response.statusCode}',
        name: 'hiffi.api',
      );
      print('   ✅ Response: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('   📄 Body: ${response.body}');
      }

      // If 401, token might be expired - user needs to login again
      if (response.statusCode == 401 && requiresAuth && idToken == null) {
        print('   ⚠️ 401 Unauthorized - Token may be expired');
        print('   💡 User needs to login again to get a new token');
      }

      return response;
    } catch (error) {
      developer.log(
        'POST $url failed: $error',
        name: 'hiffi.api',
        error: error,
      );
      print('   ❌ Error: $error');
      rethrow;
    }
  }

  Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    developer.log('PUT $url', name: 'hiffi.api');
    print('🌐 API PUT: $url');
    print('   📤 Body: $body');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Hiffi-Flutter-App/1.0',
    };

    if (requiresAuth) {
      // Get JWT token from storage
      final token = await _getIdToken(forceRefresh: false);
      if (token == null) {
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No JWT token available');
      }
      // Trim token to remove any whitespace and ensure clean format
      final cleanToken = token.trim();
      headers['Authorization'] = 'Bearer $cleanToken';
      print('   🔑 Using Bearer token');
      // Log first and last few chars of token for debugging (not full token for security)
      if (cleanToken.length > 20) {
        print(
          '   🔍 Token preview: ${cleanToken.substring(0, 10)}...${cleanToken.substring(cleanToken.length - 10)}',
        );
      }
    }

    try {
      final response = await _client.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      developer.log(
        'PUT $url - Status: ${response.statusCode}',
        name: 'hiffi.api',
      );
      print('   ✅ Response: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('   📄 Body: ${response.body}');
      }

      // If 401, token might be expired - user needs to login again
      if (response.statusCode == 401 && requiresAuth) {
        print('   ⚠️ 401 Unauthorized - Token may be expired');
        print('   💡 User needs to login again to get a new token');
      }

      return response;
    } catch (error) {
      developer.log('PUT $url failed: $error', name: 'hiffi.api', error: error);
      print('   ❌ Error: $error');
      rethrow;
    }
  }

  Future<http.Response> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    developer.log('DELETE $url', name: 'hiffi.api');
    print('🌐 API DELETE: $url');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Hiffi-Flutter-App/1.0',
    };

    if (requiresAuth) {
      // Get JWT token from storage
      final token = await _getIdToken(forceRefresh: false);
      if (token == null) {
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No JWT token available');
      }
      // Trim token to remove any whitespace and ensure clean format
      final cleanToken = token.trim();
      headers['Authorization'] = 'Bearer $cleanToken';
      print('   🔑 Using Bearer token');
      // Log first and last few chars of token for debugging (not full token for security)
      if (cleanToken.length > 20) {
        print(
          '   🔍 Token preview: ${cleanToken.substring(0, 10)}...${cleanToken.substring(cleanToken.length - 10)}',
        );
      }
    }

    try {
      final response = await _client.delete(url, headers: headers);
      developer.log(
        'DELETE $url - Status: ${response.statusCode}',
        name: 'hiffi.api',
      );
      print('   ✅ Response: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('   📄 Body: ${response.body}');
      }

      // If 401, token might be expired - user needs to login again
      if (response.statusCode == 401 && requiresAuth) {
        print('   ⚠️ 401 Unauthorized - Token may be expired');
        print('   💡 User needs to login again to get a new token');
      }

      return response;
    } catch (error) {
      developer.log(
        'DELETE $url failed: $error',
        name: 'hiffi.api',
        error: error,
      );
      print('   ❌ Error: $error');
      rethrow;
    }
  }

  /// Upload binary file to a gateway URL (e.g., DigitalOcean Spaces)
  /// Supports optional progress callback and automatic retry on connection errors.
  Future<http.StreamedResponse> uploadFileToGateway(
    String gatewayUrl,
    File file, {
    String? contentType,
    void Function(int sent, int total)? onProgress,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      attempt++;
      if (attempt > 1) {
        print('   🔄 Retry attempt $attempt/$maxRetries...');
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: attempt * 2));
      }

      try {
        return await _performUpload(
          gatewayUrl,
          file,
          contentType: contentType,
          onProgress: onProgress,
        );
      } on HandshakeException catch (e) {
        lastError = e;
        print('   ⚠️ SSL/TLS handshake error: $e');
        if (attempt < maxRetries) {
          print('   🔄 Will retry with custom certificate handling...');
          continue;
        }
        rethrow;
      } on SocketException catch (e) {
        lastError = e;
        final isConnectionReset =
            e.message.contains('Connection reset') ||
            e.message.contains('errno = 104');

        if (isConnectionReset && attempt < maxRetries) {
          print('   ⚠️ Connection reset detected, will retry...');
          continue;
        }
        rethrow;
      } on http.ClientException catch (e) {
        lastError = e;
        final isConnectionReset =
            e.message.contains('Connection reset') ||
            e.toString().contains('Connection reset');

        if (isConnectionReset && attempt < maxRetries) {
          print('   ⚠️ Connection reset detected, will retry...');
          continue;
        }
        rethrow;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          print('   ⚠️ Upload error: $e, will retry...');
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? Exception('Upload failed after $maxRetries attempts');
  }

  Future<http.StreamedResponse> _performUpload(
    String gatewayUrl,
    File file, {
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    developer.log('PUT (binary) $gatewayUrl', name: 'hiffi.api');
    print('🌐 Uploading file to gateway: $gatewayUrl');
    print('   📄 File: ${file.path}');
    final total = await file.length();
    print('   📊 Size: $total bytes');

    final uri = Uri.parse(gatewayUrl);
    final request = http.StreamedRequest('PUT', uri);
    if (contentType != null) {
      request.headers['Content-Type'] = contentType;
    }
    request.headers['Content-Length'] = total.toString();
    // Note: Do NOT add x-amz-acl header unless it's explicitly in the signed headers
    // Adding unsigned headers will cause SignatureDoesNotMatch errors
    // The presigned URL signature is calculated based on specific headers
    // Only include headers that are part of the signature

    // Stream file by chunks and report progress
    const int chunkSize = 64 * 1024; // 64KiB
    final raf = await file.open();
    int sent = 0;

    // Start sending the request first, then stream data
    // Use custom upload client with relaxed certificate validation for dev
    print('   🚀 Starting request send...');
    final responseFuture = _uploadHttpClient.send(request);

    try {
      print('   📖 Reading and streaming file in chunks...');
      while (sent < total) {
        final remaining = total - sent;
        final toRead = remaining < chunkSize ? remaining : chunkSize;

        final bytes = await raf.read(toRead);
        if (bytes.isEmpty) {
          print('   ⚠️ Read empty bytes at position $sent/$total');
          break;
        }

        request.sink.add(bytes);
        sent += bytes.length;

        if (onProgress != null) {
          onProgress(sent, total);
        }

        // Log every 10% progress
        if (sent % (total ~/ 10) < chunkSize || sent == total) {
          final percent = ((sent / total) * 100).toInt();
          print('   📊 Upload progress: $percent% ($sent/$total bytes)');
        }
      }

      print('   ✅ Finished streaming file ($sent/$total bytes)');
      print('   🔒 Closing request sink...');

      // Close the sink after all data is streamed
      await request.sink.close();
      print('   📤 Request sink closed successfully');
    } catch (e, stackTrace) {
      print('   ❌ Error during file read/stream: $e');
      developer.log(
        'Error during file upload stream',
        name: 'hiffi.api',
        error: e,
        stackTrace: stackTrace,
      );
      try {
        await request.sink.close();
      } catch (_) {}
      await raf.close();
      rethrow;
    } finally {
      await raf.close();
      print('   📂 File handle closed');
    }

    // Wait for the response with timeout
    print('   ⏳ Waiting for upload response...');
    try {
      final streamedResponse = await responseFuture.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException(
            'Upload response timeout after 5 minutes',
            const Duration(minutes: 5),
          );
        },
      );
      developer.log(
        'PUT (binary) $gatewayUrl - Status: ${streamedResponse.statusCode}',
        name: 'hiffi.api',
      );
      print('   ✅ Upload Response: ${streamedResponse.statusCode}');
      return streamedResponse;
    } on TimeoutException catch (e) {
      print('   ❌ Upload response timeout: $e');
      rethrow;
    } catch (e) {
      print('   ❌ Error waiting for upload response: $e');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
    _uploadClient?.close();
  }
}
