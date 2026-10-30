import 'package:cs_console/src/core/error/console_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CsApi {
  CsApi(this._client);

  final SupabaseClient _client;

  Future<Object?> call(String fn, [Map<String, Object?> params = const {}]) async {
    try {
      return await _client.schema('cs_api').rpc<Object?>(fn, params: params);
    } catch (e) {
      throw ConsoleError.from(e);
    }
  }

  Future<Map<String, dynamic>> object(String fn, [Map<String, Object?> params = const {}]) async =>
      (await call(fn, params))! as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> list(String fn, [Map<String, Object?> params = const {}]) async =>
      ((await call(fn, params)) as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
}
