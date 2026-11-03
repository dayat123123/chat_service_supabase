import 'package:rendezvous_community/src/core/network/json_values.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_preferences.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_preferences_repository.dart';

class NotificationPreferencesRepositoryImpl implements NotificationPreferencesRepository {
  NotificationPreferencesRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<NotificationPreferences> get() async =>
      parseNotificationPreferences(await _api.rpcValue('get_notification_prefs'));

  @override
  Future<NotificationPreferences> update({
    List<NotificationPreferenceChange> types = const [],
    QuietHours? quietHours,
  }) async {
    final prefs = <String, Object?>{
      if (types.isNotEmpty)
        'types': [
          for (final t in types) {'type': t.type, 'in_app': ?t.inApp, 'push': ?t.push},
        ],
      if (quietHours != null)
        'quiet_hours': {
          'enabled': quietHours.enabled,
          if (quietHours.enabled) 'start': quietHours.start,
          if (quietHours.enabled) 'end': quietHours.end,
        },
    };
    return parseNotificationPreferences(await _api.rpcValue('set_notification_prefs', {'p_prefs': prefs}));
  }
}

NotificationPreferences parseNotificationPreferences(Object? value) {
  final json = jsonMap(value);
  final quiet = jsonMap(json['quiet_hours']);
  return NotificationPreferences(
    types: [
      for (final row in jsonList(json['types']))
        if (row['type'] is String)
          NotificationTypePreference(
            type: row['type'] as String,
            inApp: row['in_app'] is bool ? row['in_app'] as bool : null,
            push: row['push'] != false,
            inAppLocked: row['in_app_locked'] == true,
          ),
    ],
    quietHours: QuietHours(
      enabled: quiet['enabled'] == true,
      start: quiet['start'] as String?,
      end: quiet['end'] as String?,
      timezone: quiet['timezone'] as String? ?? 'Asia/Jakarta',
    ),
    aggregateMinutes: (json['aggregate_minutes'] as num?)?.toInt() ?? 60,
  );
}
