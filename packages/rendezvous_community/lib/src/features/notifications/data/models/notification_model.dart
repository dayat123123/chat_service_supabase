import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/app_notification.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
abstract class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    required String type,
    String? actorId,
    String? actorUsername,
    String? actorDisplayName,
    String? actorAvatarUrl,
    @Default(<String, Object?>{}) Map<String, Object?> payload,
    @Default(1) int eventCount,
    DateTime? readAt,
    required DateTime createdAt,
    required String cursor,
    int? actorCount,
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> actors,
  }) = _NotificationModel;

  const NotificationModel._();

  factory NotificationModel.fromJson(Map<String, dynamic> json) => _$NotificationModelFromJson(json);

  AppNotification? toEntity() {
    final kind = notificationTypeFromKey(type);
    if (kind == null) return null;
    return AppNotification(
      id: id,
      type: kind,
      actor: actorId == null || actorUsername == null
          ? null
          : UserSummary(
              id: actorId!,
              username: actorUsername!,
              displayName: actorDisplayName,
              avatarUrl: actorAvatarUrl,
            ),
      payload: payload,
      eventCount: eventCount,
      readAt: readAt,
      createdAt: createdAt,
      cursor: cursor,
      actorCount: actorCount ?? (actorId == null ? 0 : 1),
      actors: [
        for (final a in actors)
          if (a['id'] is String)
            UserSummary(
              id: a['id'] as String,
              username: a['username'] as String? ?? '',
              displayName: a['display_name'] as String?,
              avatarUrl: a['avatar_url'] as String?,
            ),
      ],
    );
  }
}
