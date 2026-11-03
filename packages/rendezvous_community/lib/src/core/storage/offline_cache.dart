import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

class OfflineCache {
  OfflineCache(
    this._stores, {
    required this._currentUserId,
    required this._resolveHostKey,
    this.messageLimit = 200,
    this.feedScopeLimit = 20,
  });

  static const _ownerKey = 'owner';

  final OfflineStoreFactory _stores;
  final String? Function() _currentUserId;
  final Future<String?> Function() _resolveHostKey;
  final int messageLimit;
  final int feedScopeLimit;
  OfflineStore? _store;
  String? _key;
  Future<void> _queue = Future.value();
  bool _disposed = false;

  Future<T?> read<T>(Future<T> Function(OfflineStore store) action) => _serial('read', () async {
    final store = await _current();
    return store == null ? null : action(store);
  });

  Future<void> write(Future<void> Function(OfflineStore store) action) => _serial('write', () async {
    final store = await _current();
    if (store != null) await action(store);
  });

  Future<UserSummary?> owner() => read<UserSummary?>((store) async => _parseOwner(await store.readMeta(_ownerKey)));

  Future<void> remember(UserSummary user, {String? hostKey}) => _serial('remember', () async {
    if (_currentUserId() != user.id) return;
    final store = await _current();
    await store?.writeMeta(_ownerKey, {
      'user_id': user.id,
      'host_key': hostKey,
      'user': {
        'id': user.id,
        'username': user.username,
        'display_name': user.displayName,
        'avatar_url': user.avatarUrl,
        'is_verified': user.isVerified,
      },
    });
  });

  Future<void> wipe() => _serial('wipe', () async {
    await _closeCurrent();
    final keys = await _stores.keys();
    for (final key in keys) {
      await _stores.delete(key);
    }
    CommunityLoggers.offline.event(Level.INFO, 'Offline cache wiped', fields: {'storeCount': keys.length});
  });

  Future<void> dispose() => _serial('dispose', () async {
    _disposed = true;
    await _closeCurrent();
  });

  Future<T?> _serial<T>(String operation, Future<T?> Function() action) {
    final result = _queue
        .then((_) => action())
        .then<T?>(
          (value) => value,
          onError: (Object error) {
            CommunityLoggers.offline.event(
              Level.WARNING,
              'Offline cache operation failed',
              fields: {'operation': operation, 'errorType': error.runtimeType.toString()},
              error: error,
            );
            return null;
          },
        );
    _queue = result.then((_) {});
    return result;
  }

  Future<OfflineStore?> _current() async {
    if (_disposed) return null;
    final userId = _currentUserId();
    if (userId != null) return _openFor(offlineStoreKey(userId));
    return _store ?? await _openForHost();
  }

  Future<OfflineStore> _openFor(String key) async {
    final open = _store;
    if (open != null && _key == key) return open;
    await _closeCurrent();
    for (final other in await _stores.keys()) {
      if (other == key) continue;
      await _stores.delete(other);
      CommunityLoggers.offline.event(Level.INFO, 'Offline cache of a previous user removed');
    }
    final store = await _stores.open(key);
    _key = key;
    return _store = store;
  }

  Future<OfflineStore?> _openForHost() async {
    final hostKey = await _resolveHostKey();
    if (hostKey == null) return null;
    for (final key in await _stores.keys()) {
      final store = await _stores.open(key);
      final owner = await store.readMeta(_ownerKey);
      if (owner != null && owner['host_key'] == hostKey) {
        _key = key;
        return _store = store;
      }
      await store.close();
      await _stores.delete(key);
      CommunityLoggers.offline.event(Level.INFO, 'Offline cache of a previous user removed');
    }
    return null;
  }

  Future<void> _closeCurrent() async {
    final store = _store;
    _store = null;
    _key = null;
    await store?.close();
  }

  static UserSummary? _parseOwner(Map<String, dynamic>? owner) {
    final user = owner?['user'];
    if (user is! Map<String, dynamic>) return null;
    final id = user['id'];
    final username = user['username'];
    if (id is! String || username is! String) return null;
    return UserSummary(
      id: id,
      username: username,
      displayName: user['display_name'] as String?,
      avatarUrl: user['avatar_url'] as String?,
      isVerified: user['is_verified'] as bool? ?? false,
    );
  }
}
