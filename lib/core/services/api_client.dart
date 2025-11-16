import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/api_constants.dart';

class ApiClient {
  ApiClient({required FirebaseAuth firebaseAuth})
    : _firebaseAuth = firebaseAuth;

  final FirebaseAuth _firebaseAuth;
  final http.Client _client = http.Client();

  Future<String?> _getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        developer.log('No current user for API request', name: 'hiffi.api');
        print('   ⚠️ No current Firebase user');
        return null;
      }

      developer.log(
        'Getting Firebase ID token (forceRefresh: $forceRefresh)',
        name: 'hiffi.api',
      );
      print(
        '   🔑 Getting Firebase ID token${forceRefresh ? " (forced refresh)" : ""}...',
      );

      final token = forceRefresh
          ? await user.getIdToken(true)
          : await user.getIdToken();

      if (token == null || token.isEmpty) {
        developer.log('ID token is null or empty', name: 'hiffi.api');
        print('   ⚠️ ID token is null or empty');
        return null;
      }

      developer.log(
        'Retrieved Firebase ID token (length: ${token.length})',
        name: 'hiffi.api',
      );
      print('   ✅ ID token retrieved (${token.length} chars)');
      return token;
    } catch (error) {
      developer.log(
        'Failed to get ID token: $error',
        name: 'hiffi.api',
        error: error,
      );
      print('   ❌ Failed to get ID token: $error');
      return null;
    }
  }

  Future<http.Response> get(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    developer.log('GET $url', name: 'hiffi.api');
    print('🌐 API GET: $url');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Hiffi-Flutter-App/1.0',
    };

    if (requiresAuth) {
      // Use cached token first (Firebase SDK handles token refresh automatically)
      final token = await _getIdToken(forceRefresh: false);
      if (token == null) {
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No Firebase token available');
      }
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

      // If 401, try once more with refreshed token
      if (response.statusCode == 401 && requiresAuth) {
        print('   ⚠️ 401 Unauthorized - Retrying with refreshed token...');
        final refreshedToken = await _getIdToken(forceRefresh: true);
        if (refreshedToken != null) {
          headers['Authorization'] = 'Bearer ${refreshedToken.trim()}';
          print('   🔄 Retrying request with refreshed token...');
          final retryResponse = await _client.get(url, headers: headers);
          developer.log(
            'GET $url (retry) - Status: ${retryResponse.statusCode}',
            name: 'hiffi.api',
          );
          print('   ✅ Retry Response: ${retryResponse.statusCode}');
          return retryResponse;
        }
        print('   ⚠️ 401 Unauthorized - Response headers: ${response.headers}');
        print('   ⚠️ Request headers sent: $headers');
        print(
          '   ⚠️ Full Authorization header value: ${headers['Authorization']?.substring(0, 50)}...',
        );
        print(
          '   💡 Compare this with Postman - check if token format matches exactly',
        );
      }

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
      // Use cached token first (Firebase SDK handles token refresh automatically)
      final token = await _getIdToken(forceRefresh: false);
      if (token == null) {
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No Firebase token available');
      }
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

      // If 401, try once more with refreshed token
      if (response.statusCode == 401 && requiresAuth) {
        print('   ⚠️ 401 Unauthorized - Retrying with refreshed token...');
        final refreshedToken = await _getIdToken(forceRefresh: true);
        if (refreshedToken != null) {
          headers['Authorization'] = 'Bearer ${refreshedToken.trim()}';
          print('   🔄 Retrying request with refreshed token...');
          final retryResponse = await _client.post(
            url,
            headers: headers,
            body: jsonEncode(body),
          );
          developer.log(
            'POST $url (retry) - Status: ${retryResponse.statusCode}',
            name: 'hiffi.api',
          );
          print('   ✅ Retry Response: ${retryResponse.statusCode}');
          return retryResponse;
        }
        print('   ⚠️ 401 Unauthorized - Response headers: ${response.headers}');
        print('   ⚠️ Request headers sent: $headers');
        print(
          '   ⚠️ Full Authorization header value: ${headers['Authorization']?.substring(0, 50)}...',
        );
        print(
          '   💡 Compare this with Postman - check if token format matches exactly',
        );
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
      // Use cached token first (Firebase SDK handles token refresh automatically)
      final token = await _getIdToken(forceRefresh: false);
      if (token == null) {
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No Firebase token available');
      }
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

      // If 401, try once more with refreshed token
      if (response.statusCode == 401 && requiresAuth) {
        print('   ⚠️ 401 Unauthorized - Retrying with refreshed token...');
        final refreshedToken = await _getIdToken(forceRefresh: true);
        if (refreshedToken != null) {
          headers['Authorization'] = 'Bearer ${refreshedToken.trim()}';
          print('   🔄 Retrying request with refreshed token...');
          final retryResponse = await _client.put(
            url,
            headers: headers,
            body: jsonEncode(body),
          );
          developer.log(
            'PUT $url (retry) - Status: ${retryResponse.statusCode}',
            name: 'hiffi.api',
          );
          print('   ✅ Retry Response: ${retryResponse.statusCode}');
          return retryResponse;
        }
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
      // Use cached token first (Firebase SDK handles token refresh automatically)
      final token = await _getIdToken(forceRefresh: false);
      if (token == null) {
        developer.log(
          'No token available for authenticated request',
          name: 'hiffi.api',
        );
        print('   ❌ No token available');
        throw Exception('Authentication required: No Firebase token available');
      }
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

      // If 401, try once more with refreshed token
      if (response.statusCode == 401 && requiresAuth) {
        print('   ⚠️ 401 Unauthorized - Retrying with refreshed token...');
        final refreshedToken = await _getIdToken(forceRefresh: true);
        if (refreshedToken != null) {
          headers['Authorization'] = 'Bearer ${refreshedToken.trim()}';
          print('   🔄 Retrying request with refreshed token...');
          final retryResponse = await _client.delete(url, headers: headers);
          developer.log(
            'DELETE $url (retry) - Status: ${retryResponse.statusCode}',
            name: 'hiffi.api',
          );
          print('   ✅ Retry Response: ${retryResponse.statusCode}');
          return retryResponse;
        }
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
  /// This is used for uploading video and thumbnail files
  Future<http.StreamedResponse> uploadFileToGateway(
    String gatewayUrl,
    File file, {
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    developer.log('PUT (binary) $gatewayUrl', name: 'hiffi.api');
    print('🌐 Uploading file to gateway: $gatewayUrl');
    print('   📄 File: ${file.path}');
    print('   📊 Size: ${await file.length()} bytes');

    final request = http.Request('PUT', Uri.parse(gatewayUrl));
    if (contentType != null) {
      request.headers['Content-Type'] = contentType;
    }

    final fileBytes = await file.readAsBytes();
    request.bodyBytes = fileBytes;

    final streamedResponse = await _client.send(request);

    developer.log(
      'PUT (binary) $gatewayUrl - Status: ${streamedResponse.statusCode}',
      name: 'hiffi.api',
    );
    print('   ✅ Upload Response: ${streamedResponse.statusCode}');

    return streamedResponse;
  }

  void dispose() {
    _client.close();
  }
}
