import 'dart:convert';

import 'package:cs_console/src/core/error/console_error.dart';
import 'package:http/http.dart' as http;

class AdapterClient {
  AdapterClient({required this.baseUrl, required this.anonKey, required this._token, http.Client? client})
    : _http = client ?? http.Client();

  final String baseUrl;
  final String anonKey;
  final Future<String> Function() _token;
  final http.Client _http;

  Future<Object?> get(String ticketId, String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl/agent/tickets/$ticketId/customer/$path').replace(queryParameters: query);
    return _decode(await _http.get(uri, headers: await _headers()));
  }

  Future<Object?> post(String ticketId, String path, [Map<String, Object?>? body]) async {
    final uri = Uri.parse('$baseUrl/agent/tickets/$ticketId/customer/$path');
    return _decode(await _http.post(uri, headers: await _headers(), body: body == null ? null : jsonEncode(body)));
  }

  Future<Map<String, String>> _headers() async => {
    'apikey': anonKey,
    'Authorization': 'Bearer ${await _token()}',
    'Content-Type': 'application/json',
  };

  Object? _decode(http.Response response) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ConsoleError('adapter_invalid_response', status: response.statusCode);
    }
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    if (response.statusCode == 200 && map['available'] == true) return map['data'];
    if (map['available'] == false) throw const ConsoleError('olt_unavailable', status: 503);
    throw ConsoleError(
      map['code'] as String? ?? 'adapter_error',
      message: map['message'] as String?,
      status: response.statusCode,
    );
  }

  void close() => _http.close();
}
