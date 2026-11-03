import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_preferences.dart';

abstract interface class NotificationPreferencesRepository {
  Future<NotificationPreferences> get();

  Future<NotificationPreferences> update({List<NotificationPreferenceChange> types = const [], QuietHours? quietHours});
}
