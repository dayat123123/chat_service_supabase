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
  String? get title => payload['title'] as String?;
  String? get body => payload['body'] as String?;
  String? get url => payload['url'] as String?;
  String? get appealId => payload['appeal_id'] as String?;
  String? get appealStatus => payload['status'] as String?;
  String? get note => payload['note'] as String?;
  int get otherActors => actorCount > 1 ? actorCount - 1 : 0;
}
