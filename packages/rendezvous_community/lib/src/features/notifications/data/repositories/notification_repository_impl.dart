import 'package:rendezvous_community/src/core/network/realtime_gateway.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/notifications/data/models/notification_model.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/app_notification.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._api, [this._realtime]);

  final SocialRemoteDataSource _api;
  final RealtimeGateway? _realtime;

  @override
  Future<Paged<AppNotification>> getNotifications({String? cursor, int limit = 30}) async {
    final rows = await _api.rpcRows('get_notifications', {'p_cursor': cursor, 'p_limit': limit});
    final items = [for (final row in rows) ?NotificationModel.fromJson(row).toEntity()];
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
