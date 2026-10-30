import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

class SessionTabStorage extends LocalStorage {
  const SessionTabStorage();

  static const _key = 'cs-console.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => web.window.sessionStorage.getItem(_key) != null;

  @override
  Future<String?> accessToken() async => web.window.sessionStorage.getItem(_key);

  @override
  Future<void> removePersistedSession() async => web.window.sessionStorage.removeItem(_key);

  @override
  Future<void> persistSession(String persistSessionString) async =>
      web.window.sessionStorage.setItem(_key, persistSessionString);
}
