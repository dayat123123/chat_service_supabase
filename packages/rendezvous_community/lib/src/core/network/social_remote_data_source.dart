import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:rendezvous_community/src/core/auth/session_tokens.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/network/authorized_image.dart';
import 'package:rendezvous_community/src/core/network/media_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CommunityErrorListener = void Function(CommunityException error);

typedef CommunityReachabilityListener = void Function({required bool reachable});

abstract interface class SocialRemoteDataSource {
  String? get currentUserId;

  Future<String> requireUserId();

  SocialRemoteDataSource inSchema(String schema);

  Future<List<Map<String, dynamic>>> rpcRows(String fn, [Map<String, Object?> params = const {}]);

  Future<Object?> rpcValue(String fn, [Map<String, Object?> params = const {}]);

  Future<Object?> anonymousRpcValue(String fn, [Map<String, Object?> params = const {}]);

  Future<void> insert(String table, Map<String, Object?> values);

  Future<void> update(String table, Map<String, Object?> values, Map<String, Object> match);

  Future<void> delete(String table, Map<String, Object> match);

  Future<List<Map<String, dynamic>>> select(
    String table, {
    required String columns,
    Map<String, Object>? match,
    int? limit,
  });

  Future<UploadedObject> upload(
    String bucket,
    String path,
    Uint8List bytes, {
    required String contentType,
    bool upsert = false,
  });

  String publicUrl(String bucket, String path);

  Future<AuthorizedImage> authorizedObject(String bucket, String path);

  Future<String> signedUrl(String bucket, String path, {int expiresIn = 300});
}

class SupabaseSocialDataSource implements SocialRemoteDataSource {
  SupabaseSocialDataSource(
    this._client,
    this._tokens, {
    required String supabaseUrl,
    required this._anonKey,
    http.Client? httpClient,
  }) : _supabaseUrl = supabaseUrl.replaceAll(RegExp(r'/+$'), ''),
       _media = MediaGatewayClient(baseUrl: supabaseUrl, anonKey: _anonKey, tokens: _tokens, httpClient: httpClient),
       _errors = _ErrorListeners(),
       _httpClient = httpClient,
       _schema = null;

  SupabaseSocialDataSource._forSchema(SupabaseSocialDataSource base, String this._schema)
    : _client = base._client,
      _tokens = base._tokens,
      _supabaseUrl = base._supabaseUrl,
      _anonKey = base._anonKey,
      _media = base._media,
      _errors = base._errors,
      _httpClient = base._httpClient;

  final SupabaseClient _client;
  final SessionTokens _tokens;
  final String _supabaseUrl;
  final String _anonKey;
  final MediaGatewayClient _media;
  final _ErrorListeners _errors;
  final http.Client? _httpClient;
  final String? _schema;

  set errorListener(CommunityErrorListener? listener) => _errors.listener = listener;

  set reachabilityListener(CommunityReachabilityListener? listener) => _errors.reachability = listener;

  @override
  String? get currentUserId => _tokens.currentUserId;

  @override
  Future<String> requireUserId() async {
    final id = currentUserId;
    if (id != null) return id;
    try {
      return await _tokens.refreshUserId();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  SocialRemoteDataSource inSchema(String schema) => SupabaseSocialDataSource._forSchema(this, schema);

  PostgrestFilterBuilder<T> _rpc<T>(String fn, Map<String, Object?> params) {
    final schema = _schema;
    return schema == null ? _client.rpc<T>(fn, params: params) : _client.schema(schema).rpc<T>(fn, params: params);
  }

  Future<T> _run<T>(Future<T> Function() fn) async {
    try {
      final result = await _attempt(fn);
      _errors.succeeded();
      return result;
    } on CommunityException catch (e) {
      _errors.failed(e);
      rethrow;
    }
  }

  Future<T> _attempt<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PostgrestException catch (e) {
      if (!jwtErrorCodes.contains(e.code)) throw mapError(e);
      try {
        await _tokens.refreshUserId();
        return await fn();
      } catch (retryError) {
        throw mapError(retryError);
      }
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> rpcRows(String fn, [Map<String, Object?> params = const {}]) => _run(() async {
    final res = await _rpc<Object?>(fn, params);
    return (res as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
  });

  @override
  Future<Object?> rpcValue(String fn, [Map<String, Object?> params = const {}]) =>
      _run(() async => await _rpc<Object?>(fn, params));

  @override
  Future<Object?> anonymousRpcValue(String fn, [Map<String, Object?> params = const {}]) async {
    final uri = Uri.parse('$_supabaseUrl/rest/v1/rpc/$fn');
    final headers = {
      'apikey': _anonKey,
      'Authorization': 'Bearer $_anonKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_schema != null) 'Content-Profile': _schema,
    };
    final shared = _httpClient;
    final client = shared ?? http.Client();
    try {
      final response = await client
          .post(uri, headers: headers, body: jsonEncode(params))
          .timeout(const Duration(seconds: 20));
      final text = utf8.decode(response.bodyBytes);
      final body = text.isEmpty ? null : jsonDecode(text);
      if (response.statusCode >= 400) {
        final map = body is Map ? body : const <String, Object?>{};
        throw mapError(
          PostgrestException(
            message: map['message']?.toString() ?? 'HTTP ${response.statusCode}',
            code: map['code']?.toString() ?? '${response.statusCode}',
            details: map['details']?.toString(),
            hint: map['hint']?.toString(),
          ),
        );
      }
      _errors.succeeded();
      return body;
    } on CommunityException catch (e) {
      _errors.failed(e);
      rethrow;
    } catch (e) {
      final mapped = mapError(e);
      _errors.failed(mapped);
      throw mapped;
    } finally {
      if (shared == null) client.close();
    }
  }

  @override
  Future<void> insert(String table, Map<String, Object?> values) =>
      _run(() async => await _client.from(table).insert(values));

  @override
  Future<void> update(String table, Map<String, Object?> values, Map<String, Object> match) =>
      _run(() async => await _client.from(table).update(values).match(match));

  @override
  Future<void> delete(String table, Map<String, Object> match) =>
      _run(() async => await _client.from(table).delete().match(match));

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    required String columns,
    Map<String, Object>? match,
    int? limit,
  }) => _run(() async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client.from(table).select(columns);
    if (match != null) query = query.match(match);
    return limit == null ? await query : await query.limit(limit);
  });

  @override
  Future<UploadedObject> upload(
    String bucket,
    String path,
    Uint8List bytes, {
    required String contentType,
    bool upsert = false,
  }) => _media.upload(bucket, path, bytes, contentType: contentType, upsert: upsert);

  @override
  String publicUrl(String bucket, String path) => _client.storage.from(bucket).getPublicUrl(path);

  @override
  Future<String> signedUrl(String bucket, String path, {int expiresIn = 300}) =>
      _run(() => _client.storage.from(bucket).createSignedUrl(path, expiresIn));

  @override
  Future<AuthorizedImage> authorizedObject(String bucket, String path) async {
    final token = await _tokens.accessToken();
    return AuthorizedImage('$_supabaseUrl/storage/v1/object/authenticated/$bucket/$path', {
      'apikey': _anonKey,
      'Authorization': 'Bearer $token',
    });
  }
}

class _ErrorListeners {
  CommunityErrorListener? listener;
  CommunityReachabilityListener? reachability;

  void succeeded() => reachability?.call(reachable: true);

  void failed(CommunityException error) {
    reachability?.call(reachable: error.kind != CommunityErrorKind.network);
    listener?.call(error);
  }
}

extension SocialRemoteDataSourceInsert on SocialRemoteDataSource {
  Future<void> insertIgnoringDuplicate(String table, Map<String, Object?> values) async {
    try {
      await insert(table, values);
    } on CommunityException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }
}
