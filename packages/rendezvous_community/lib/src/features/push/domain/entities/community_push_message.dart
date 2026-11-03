import 'dart:convert';

enum CommunityPushPlatform { android, ios, web }

class CommunityPushRegistration {
  const CommunityPushRegistration({required this.token, required this.platform, this.locale, this.appVersion});

  final String token;
  final CommunityPushPlatform platform;
  final String? locale;
  final String? appVersion;
}

class CommunityPushMessage {
  const CommunityPushMessage._(this.data);

  static const source = 'rendezvous_community';

  static CommunityPushMessage? tryParse(Map<String, Object?> data) =>
      data['source'] == source ? CommunityPushMessage._(Map.unmodifiable(data)) : null;

  final Map<String, Object?> data;

  String get type => _text('type') ?? _text('kind') ?? '';
  String? get notificationId => _text('notification_id');
  String? get postId => _text('post_id');
  String? get commentId => _text('comment_id');
  String? get roomId => _text('room_id');
  String? get roomType => _text('room_type');
  String? get ticketId => _text('ticket_id');
  String? get campaignId => _text('campaign_id');
  String? get broadcastId => _text('broadcast_id');
  String? get stockCode => _text('stock_code');
  List<String> get stocks {
    final raw = data['stocks'];
    Object? list = raw;
    if (raw is String) {
      try {
        list = jsonDecode(raw);
      } on FormatException {
        list = null;
      }
    }
    return [
      if (list is List)
        for (final item in list)
          if (item is String && item.isNotEmpty) item,
    ];
  }

  String? get actorId => _text('actor_id');
  String? get actorUsername => _text('actor_username');
  Uri? get link {
    final url = Uri.tryParse(_text('url') ?? '');
    return url != null && url.scheme == 'https' && url.host.isNotEmpty ? url : null;
  }

  bool get isSupport => type == 'message' && roomType == 'support';

  String? _text(String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }
}
