import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/app_notification.dart';

abstract interface class NotificationRepository {
  Future<Paged<AppNotification>> getNotifications({String? cursor, int limit = 30});

  Future<int> unreadCount();

  Future<void> markRead({List<String>? ids});

  Stream<void> watchNotifications();
}
