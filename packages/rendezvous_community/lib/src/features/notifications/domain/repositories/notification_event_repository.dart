import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_event.dart';

abstract interface class NotificationEventRepository {
  Future<void> report(NotificationEvent event, NotificationSource source);
}
