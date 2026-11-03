import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_preferences.freezed.dart';

const notificationTradeType = 'olt.trade';
const notificationFundsType = 'olt.funds';
const notificationMarketType = 'olt.market';
const notificationOltInfoType = 'olt.info';
const notificationPromoType = 'olt.promo';

bool isOltNotificationType(String type) => type.startsWith('olt.');

@freezed
abstract class NotificationTypePreference with _$NotificationTypePreference {
  const factory NotificationTypePreference({
    required String type,
    bool? inApp,
    @Default(true) bool push,
    @Default(false) bool inAppLocked,
  }) = _NotificationTypePreference;

  const NotificationTypePreference._();

  bool get supportsInApp => inApp != null;
  bool get isOlt => isOltNotificationType(type);
}

@freezed
abstract class QuietHours with _$QuietHours {
  const factory QuietHours({
    @Default(false) bool enabled,
    String? start,
    String? end,
    @Default('Asia/Jakarta') String timezone,
  }) = _QuietHours;
}

@freezed
abstract class NotificationPreferences with _$NotificationPreferences {
  const factory NotificationPreferences({
    @Default(<NotificationTypePreference>[]) List<NotificationTypePreference> types,
    @Default(QuietHours()) QuietHours quietHours,
    @Default(60) int aggregateMinutes,
  }) = _NotificationPreferences;

  const NotificationPreferences._();

  NotificationTypePreference? of(String type) => types.where((t) => t.type == type).firstOrNull;
}

class NotificationPreferenceChange {
  const NotificationPreferenceChange({required this.type, this.inApp, this.push});

  final String type;
  final bool? inApp;
  final bool? push;
}
