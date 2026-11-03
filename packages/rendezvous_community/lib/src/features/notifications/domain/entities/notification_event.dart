enum NotificationEvent { opened, tapped }

class NotificationSource {
  const NotificationSource({this.notificationId, this.campaignId, this.broadcastId});

  factory NotificationSource.fromData(Map<String, Object?> data) => NotificationSource(
    notificationId: _text(data['notification_id']),
    campaignId: _text(data['campaign_id']),
    broadcastId: _text(data['broadcast_id']),
  );

  final String? notificationId;
  final String? campaignId;
  final String? broadcastId;

  bool get isEmpty => notificationId == null && campaignId == null && broadcastId == null;

  String get key => notificationId != null
      ? 'n:$notificationId'
      : campaignId != null
      ? 'c:$campaignId'
      : 'b:$broadcastId';

  static String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;
}
