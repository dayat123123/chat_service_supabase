import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'app_notification.freezed.dart';

enum NotificationType { reply, mention, like, follow, message, announcement, appeal }

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
  String? localizedTitle(String languageCode) => _localizedText(payload['title'], languageCode);
  String? localizedBody(String languageCode) => _localizedText(payload['body'], languageCode);
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
