import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:hiffi/core/utils/image_utils.dart';

/// A local HLS proxy service that mirrors Next.js XHR hooks.
///
/// It solves:
/// 1. iOS AVPlayer not forwarding headers to segments.
/// 2. Missing '/segments/' directory in HLS playlists.
class HlsProxyService {
  static final HlsProxyService _instance = HlsProxyService._internal();
  factory HlsProxyService() => _instance;
  HlsProxyService._internal();

  HttpServer? _server;
  int? _port;

  /// Starts the local proxy server if it's not already running.
  Future<int> start() async {
    if (_server != null) return _port!;

    // The base proxy handler for our workers domain
    final baseProxy = proxyHandler('https://prod.hiffi.workers.dev');

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_authAndPathMiddleware)
        .addHandler(baseProxy);

    _server = await io.serve(handler, InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    debugPrint('HLS Proxy: Started on port $_port');
    return _port!;
  }

  /// Middleware to inject authentication and rewrite segment paths.
  Middleware get _authAndPathMiddleware => (innerHandler) {
    return (Request request) async {
      // 1. Inject Authentication Header (x-api-key)
      final headers = Map<String, String>.from(request.headers);
      headers['x-api-key'] = ImageUtils.profileImageApiKey;

      // 2. Mirror Next.js Segment Path Rewriting
      // The manifest you provided shows segments like 'seg_000.ts'
      // These are relative to the variant playlist path (e.g., .../hls/original/)
      final path = request.url.path;

      // Match: videos/{id}/hls/{variant}/seg_{number}.ts
      // This correctly identifies segments in any quality variant (original, 720p, etc.)
      final hlsSegmentPattern = RegExp(
        r'(videos/[^/]+/hls/[^/]+/)(seg_\d+\.(ts|m4s))$',
      );

      Uri finalUri = request.requestedUri;
      if (hlsSegmentPattern.hasMatch(path)) {
        final newPath = path.replaceFirstMapped(hlsSegmentPattern, (match) {
          return '${match.group(1)}segments/${match.group(2)}';
        });
        debugPrint('HLS Proxy: Rewriting segment path: $path -> $newPath');
        finalUri = request.requestedUri.replace(path: newPath);
      }

      // Create a new request with the updated headers and rewritten path
      final proxiedRequest = Request(
        request.method,
        finalUri,
        headers: headers,
        body: request.read(),
        context: request.context,
      );

      return await innerHandler(proxiedRequest);
    };
  };

  /// Converts a remote Workers URL to a local proxy URL.
  String getProxiedUrl(String originalUrl) {
    if (_port == null) return originalUrl;

    final uri = Uri.parse(originalUrl);
    // Replace the base URL with localhost:[port]
    return uri
        .replace(scheme: 'http', host: '127.0.0.1', port: _port)
        .toString();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }
}
