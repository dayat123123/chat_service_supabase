import 'dart:typed_data';

import 'package:olt_social/src/core/auth/token_manager.dart';
import 'package:olt_social/src/core/error/error_mapper.dart';
import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:olt_social/src/core/network/authorized_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SocialRemoteDataSource {
  String? get currentUserId;

  Future<String> requireUserId();

  Future<List<Map<String, dynamic>>> rpcRows(String fn, [Map<String, Object?> params = const {}]);

  Future<Object?> rpcValue(String fn, [Map<String, Object?> params = const {}]);

  Future<void> insert(String table, Map<String, Object?> values);

  Future<void> update(String table, Map<String, Object?> values, Map<String, Object> match);

  Future<void> delete(String table, Map<String, Object> match);

  Future<List<Map<String, dynamic>>> select(String table, {required String columns, Map<String, Object>? match, int? limit});

  Future<void> upload(String bucket, String path, Uint8List bytes, {required String contentType, bool upsert = false});

  String publicUrl(String bucket, String path);

  Future<AuthorizedImage> authorizedObject(String bucket, String path);
}

class SupabaseSocialDataSource implements SocialRemoteDataSource {
  SupabaseSocialDataSource(this._client, this._tokens, {required String supabaseUrl, required this._anonKey})
    : _supabaseUrl = supabaseUrl.replaceAll(RegExp(r'/+$'), '');

  final SupabaseClient _client;
  final TokenManager _tokens;
  final String _supabaseUrl;
  final String _anonKey;

  @override
  String? get currentUserId => _tokens.currentSession?.user.id;

  @override
  Future<String> requireUserId() async {
    final id = currentUserId;
    if (id != null) return id;
    try {
      return (await _tokens.refresh()).user.id;
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<T> _run<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PostgrestException catch (e) {
      if (!jwtErrorCodes.contains(e.code)) throw mapError(e);
      try {
        await _tokens.refresh();
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
    final res = await _client.rpc<Object?>(fn, params: params);
    return (res as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
  });

  @override
  Future<Object?> rpcValue(String fn, [Map<String, Object?> params = const {}]) =>
      _run(() async => await _client.rpc<Object?>(fn, params: params));

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
  Future<void> upload(String bucket, String path, Uint8List bytes, {required String contentType, bool upsert = false}) =>
      _run(() async {
        await _client.storage
            .from(bucket)
            .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: upsert));
      });

  @override
  String publicUrl(String bucket, String path) => _client.storage.from(bucket).getPublicUrl(path);

  @override
  Future<AuthorizedImage> authorizedObject(String bucket, String path) async {
    final token = await _tokens.accessToken();
    return AuthorizedImage(
      '$_supabaseUrl/storage/v1/object/authenticated/$bucket/$path',
      {'apikey': _anonKey, 'Authorization': 'Bearer $token'},
    );
  }
}

extension SocialRemoteDataSourceInsert on SocialRemoteDataSource {
  Future<void> insertIgnoringDuplicate(String table, Map<String, Object?> values) async {
    try {
      await insert(table, values);
    } on OltSocialException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }
}
