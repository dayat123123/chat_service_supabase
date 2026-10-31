import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/src/features/notifications/domain/entities/app_notification.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

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
  }) = _NotificationModel;

  const NotificationModel._();

  factory NotificationModel.fromJson(Map<String, dynamic> json) => _$NotificationModelFromJson(json);

  AppNotification? toEntity() {
    final kind = NotificationType.values.asNameMap()[type];
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
    );
  }
}
