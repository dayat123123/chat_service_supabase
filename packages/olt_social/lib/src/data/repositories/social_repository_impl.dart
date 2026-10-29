import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/notification.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/realtime_gateway.dart';
import '../datasources/social_remote_data_source.dart';
import '../models/user_models.dart';
import 'feed_repository_impl.dart';

const _uuid = Uuid();

/// Ekstensi file dari MIME gambar yang diizinkan bucket.
String imageExtension(String mimeType) => switch (mimeType) {
  'image/png' => 'png',
  'image/webp' => 'webp',
  'image/gif' => 'gif',
  _ => 'jpg',
};

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<UserProfile?> getProfile({String? userId, String? username}) async {
    final rows = await _api.rpcRows('get_profile', {'p_user_id': userId, 'p_username': username});
    return rows.isEmpty ? null : ProfileModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<void> updateMyProfile({String? displayName, String? bio, String? avatarUrl}) async {
    final me = await _api.requireUserId();
    final values = <String, Object?>{
      'display_name': ?displayName,
      'bio': ?bio,
      'avatar_url': ?avatarUrl,
    };
    if (values.isEmpty) return;
    await _api.update('profiles', values, {'id': me});
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, {required String mimeType}) async {
    final me = await _api.requireUserId();
    // Nama file unik agar cache gambar lama tidak dipakai.
    final path = '$me/avatar-${DateTime.now().millisecondsSinceEpoch}.${imageExtension(mimeType)}';
    await _api.upload('avatars', path, bytes, contentType: mimeType, upsert: true);
    final url = _api.publicUrl('avatars', path);
    await updateMyProfile(avatarUrl: url);
    return url;
  }

  @override
  Future<void> follow(String userId) async {
    final me = await _api.requireUserId();
    await insertIgnoringDuplicate(_api, 'follows', {'follower_id': me, 'following_id': userId});
  }

  @override
  Future<void> unfollow(String userId) async {
    final me = await _api.requireUserId();
    await _api.delete('follows', {'follower_id': me, 'following_id': userId});
  }

  @override
  Future<void> block(String userId) async {
    final me = await _api.requireUserId();
    await insertIgnoringDuplicate(_api, 'blocks', {'blocker_id': me, 'blocked_id': userId});
  }

  @override
  Future<void> unblock(String userId) async {
    final me = await _api.requireUserId();
    await _api.delete('blocks', {'blocker_id': me, 'blocked_id': userId});
  }

  @override
  Future<List<UserSummary>> searchUsers(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _api.rpcRows('search_profiles', {'p_query': query, 'p_limit': limit});
    return [for (final row in rows) ProfileSummaryModel.fromJson(row).toEntity()];
  }
}

class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Stock?> getStock(String code) async {
    final rows = await _api.select(
      'stocks',
      columns: 'code,name,type,sector,watcher_count',
      match: {'code': code.toUpperCase()},
      limit: 1,
    );
    return rows.isEmpty ? null : StockModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<List<Stock>> searchStocks(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _api.rpcRows('search_stocks', {'p_query': query, 'p_limit': limit});
    return [for (final row in rows) StockModel.fromJson(row).toEntity()];
  }

  @override
  Future<bool> isWatching(String code) async {
    final me = await _api.requireUserId();
    final rows = await _api.select(
      'stock_watchers',
      columns: 'stock_code',
      match: {'user_id': me, 'stock_code': code.toUpperCase()},
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> watch(String code) async {
    final me = await _api.requireUserId();
    await insertIgnoringDuplicate(_api, 'stock_watchers', {'user_id': me, 'stock_code': code.toUpperCase()});
  }

  @override
  Future<void> unwatch(String code) async {
    final me = await _api.requireUserId();
    await _api.delete('stock_watchers', {'user_id': me, 'stock_code': code.toUpperCase()});
  }
}

class ModerationRepositoryImpl implements ModerationRepository {
  ModerationRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    final me = await _api.requireUserId();
    // Laporan ganda untuk target yang sama dianggap sudah terkirim.
    await insertIgnoringDuplicate(_api, 'reports', {
      'reporter_id': me,
      'target_type': target.name,
      'target_id': targetId,
      'reason': reason.wireName,
      'details': details,
    });
  }
}

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Attachment> uploadPostImage(Uint8List bytes, {required String mimeType}) async {
    final me = await _api.requireUserId();
    final path = 'posts/$me/${_uuid.v4()}.${imageExtension(mimeType)}';
    await _api.upload('attachments', path, bytes, contentType: mimeType);
    return Attachment(path: path, mime: mimeType);
  }

  @override
  Future<Attachment> uploadChatImage(String roomId, Uint8List bytes, {required String mimeType}) async {
    final me = await _api.requireUserId();
    final path = 'rooms/$roomId/$me/${_uuid.v4()}.${imageExtension(mimeType)}';
    await _api.upload('attachments', path, bytes, contentType: mimeType);
    return Attachment(path: path, mime: mimeType);
  }

  @override
  Future<AuthorizedImage> attachmentImage(Attachment attachment) =>
      _api.authorizedObject('attachments', attachment.path);
}

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._api, [this._realtime]);

  final SocialRemoteDataSource _api;
  final RealtimeGateway? _realtime;

  @override
  Future<Paged<AppNotification>> getNotifications({String? cursor, int limit = 30}) async {
    final rows = await _api.rpcRows('get_notifications', {'p_cursor': cursor, 'p_limit': limit});
    final items = [
      for (final row in rows) ?NotificationModel.fromJson(row).toEntity(),
    ];
    final last = rows.isEmpty ? null : rows.last['cursor'] as String?;
    return Paged(items, nextCursor: rows.length < limit ? null : last);
  }

  @override
  Future<int> unreadCount() async => ((await _api.rpcValue('get_notification_unread_count')) as num?)?.toInt() ?? 0;

  @override
  Future<void> markRead({List<String>? ids}) => _api.rpcValue('mark_notifications_read', {'p_ids': ids});

  @override
  Stream<void> watchNotifications() async* {
    final realtime = _realtime;
    if (realtime == null) return;
    final me = await _api.requireUserId();
    yield* realtime
        .tableChanges(
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: me),
        )
        .map((_) {});
  }
}
