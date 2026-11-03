import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'app_notification.freezed.dart';

enum NotificationType {
  reply,
  mention,
  like,
  follow,
  message,
  announcement,
  appeal,
  followedPost,
  watchlistDigest,
  moderation,
}

const notificationTypeKeys = {
  NotificationType.followedPost: 'followed_post',
  NotificationType.watchlistDigest: 'watchlist_digest',
};

NotificationType? notificationTypeFromKey(String key) =>
    NotificationType.values.where((t) => (notificationTypeKeys[t] ?? t.name) == key).firstOrNull;

@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required NotificationType type,
    UserSummary? actor,
    @Default(<String, Object?>{}) Map<String, Object?> payload,
    @Default(1) int eventCount,
    DateTime? readAt,
    required DateTime createdAt,
    required String cursor,
    @Default(1) int actorCount,
    @Default(<UserSummary>[]) List<UserSummary> actors,
  }) = _AppNotification;

  const AppNotification._();

  bool get isRead => readAt != null;
  String? get postId => payload['post_id'] as String?;
  String? get commentId => payload['comment_id'] as String?;
  String? get roomId => payload['room_id'] as String?;
  String? get snippet => payload['snippet'] as String?;
  String? get targetType => payload['target_type'] as String?;
  String? get title => payload['title'] is String ? payload['title'] as String : null;
  String? get body => payload['body'] is String ? payload['body'] as String : null;
  String? get url => payload['url'] as String?;
  String? get appealId => payload['appeal_id'] as String?;
  String? get appealStatus => payload['status'] as String?;
  String? get note => payload['note'] as String?;
  int get otherActors => actorCount > 1 ? actorCount - 1 : 0;
  bool get isOlt => payload['source'] == 'olt';
  String? get oltKind => payload['kind'] is String ? payload['kind'] as String : null;
  String? get oltCategory => payload['category'] is String ? payload['category'] as String : null;
  String? get stockCode => payload['stock_code'] is String ? payload['stock_code'] as String : null;
  List<String> get stocks => _strings(payload['stocks']);
  int get postCount => (payload['post_count'] as num?)?.toInt() ?? 0;
  int get stockCount => (payload['stock_count'] as num?)?.toInt() ?? stocks.length;
  String? get moderationState => payload['state'] is String ? payload['state'] as String : null;
  bool get appealable => payload['appealable'] == true || payload['appealable'] == 'true';
  String? get excerpt => payload['excerpt'] is String ? payload['excerpt'] as String : null;
  bool get isRoomMention => type == NotificationType.mention && roomId != null && postId == null;
  bool get isRoomMute => type == NotificationType.moderation && targetType == 'room';
  DateTime? get muteUntil => payload['until'] is String ? DateTime.tryParse(payload['until'] as String)?.toUtc() : null;
  String? localizedTitle(String languageCode) => _localizedText(payload['title'], languageCode);
  String? localizedBody(String languageCode) => _localizedText(payload['body'], languageCode);
}

List<String> _strings(Object? value) {
  final list = value is String ? _decodeList(value) : value;
  return [
    if (list is List)
      for (final item in list)
        if (item is String && item.isNotEmpty) item,
  ];
}

Object? _decodeList(String value) {
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

String? _localizedText(Object? value, String languageCode) {
  if (value is String) return value.isEmpty ? null : value;
  if (value is! Map) return null;
  for (final key in [languageCode, 'id', 'en']) {
    final text = value[key];
    if (text is String && text.isNotEmpty) return text;
  }
  return null;
}
