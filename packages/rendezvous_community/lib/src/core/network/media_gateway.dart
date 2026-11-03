import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:rendezvous_community/src/core/auth/session_tokens.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';

class UploadedObject {
  const UploadedObject({
    required this.bucket,
    required this.path,
    required this.mime,
    this.size,
    this.width,
    this.height,
    this.held = false,
  });

  final String bucket;
  final String path;
  final String mime;
  final int? size;
  final int? width;
  final int? height;
  final bool held;
}

class MediaGatewayClient {
  MediaGatewayClient({
    required String baseUrl,
    required this._anonKey,
    required this._tokens,
    this._httpClient,
    this.timeout = const Duration(seconds: 90),
  }) : _objectBase = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/media/v1/object';

  final String _objectBase;
  final String _anonKey;
  final SessionTokens _tokens;
  final http.Client? _httpClient;
  final Duration timeout;

  Uri objectUri(String bucket, String path) =>
      Uri.parse('$_objectBase/${[bucket, ...path.split('/')].map(Uri.encodeComponent).join('/')}');

  Future<UploadedObject> upload(
    String bucket,
    String path,
    Uint8List bytes, {
    required String contentType,
    bool upsert = false,
  }) async {
    final uri = objectUri(bucket, path);
    try {
      var response = await _post(uri, await _tokens.accessToken(), bytes, contentType, upsert);
      if (response.statusCode == 401) {
        await _tokens.refreshUserId();
        response = await _post(uri, await _tokens.accessToken(), bytes, contentType, upsert);
      }
      return _parse(response, bucket);
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<http.Response> _post(Uri uri, String token, Uint8List bytes, String contentType, bool upsert) async {
    final headers = {
      'apikey': _anonKey,
      'Authorization': 'Bearer $token',
      'Content-Type': contentType,
      if (upsert) 'x-upsert': 'true',
    };
    final shared = _httpClient;
    if (shared != null) return shared.post(uri, headers: headers, body: bytes).timeout(timeout);
    final client = http.Client();
    try {
      return await client.post(uri, headers: headers, body: bytes).timeout(timeout);
    } finally {
      client.close();
    }
  }

  UploadedObject _parse(http.Response response, String bucket) {
    final body = _decode(response.body);
    if (response.statusCode != 200) {
      throw mapMediaError(
        response.statusCode,
        code: body?['code'] as String?,
        message: body?['message'] as String?,
        retryAfter: response.headers['retry-after'],
      );
    }
    final path = body?['path'];
    final mime = body?['mime'];
    if (path is! String || path.isEmpty || mime is! String || mime.isEmpty) {
      throw const CommunityException(
        CommunityErrorKind.unavailable,
        code: 'media_unavailable',
        message: 'Media gateway returned an invalid response',
      );
    }
    return UploadedObject(
      bucket: body?['bucket'] as String? ?? bucket,
      path: path,
      mime: mime,
      size: (body?['size'] as num?)?.toInt(),
      width: (body?['width'] as num?)?.toInt(),
      height: (body?['height'] as num?)?.toInt(),
      held: body?['held'] == true,
    );
  }

  static Map<String, dynamic>? _decode(String text) {
    try {
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }
}
