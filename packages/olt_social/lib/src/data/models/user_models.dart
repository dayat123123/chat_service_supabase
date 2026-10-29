import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/notification.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/user.dart';

part 'user_models.freezed.dart';
part 'user_models.g.dart';

/// Baris hasil RPC search_profiles.
@freezed
abstract class ProfileSummaryModel with _$ProfileSummaryModel {
  const factory ProfileSummaryModel({
    required String id,
    required String username,
    String? displayName,
    String? avatarUrl,
    @Default(false) bool isVerified,
  }) = _ProfileSummaryModel;

  const ProfileSummaryModel._();

  factory ProfileSummaryModel.fromJson(Map<String, dynamic> json) => _$ProfileSummaryModelFromJson(json);

  UserSummary toEntity() => UserSummary(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    isVerified: isVerified,
  );
}

/// Baris hasil RPC get_profile.
@freezed
abstract class ProfileModel with _$ProfileModel {
  const factory ProfileModel({
    required String id,
    required String username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    @Default(false) bool isVerified,
    @Default(0) int followerCount,
    @Default(0) int followingCount,
    @Default(0) int postCount,
    required DateTime createdAt,
    @Default(false) bool isMe,
    @Default(false) bool isFollowing,
    @Default(false) bool followsMe,
    @Default(false) bool isBlocked,
  }) = _ProfileModel;

  const ProfileModel._();

  factory ProfileModel.fromJson(Map<String, dynamic> json) => _$ProfileModelFromJson(json);

  UserProfile toEntity() => UserProfile(
    user: UserSummary(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
    ),
    bio: bio,
    followerCount: followerCount,
    followingCount: followingCount,
    postCount: postCount,
    createdAt: createdAt,
    isMe: isMe,
    isFollowing: isFollowing,
    followsMe: followsMe,
    isBlocked: isBlocked,
  );
}

/// Baris tabel stocks / RPC search_stocks.
@freezed
abstract class StockModel with _$StockModel {
  const factory StockModel({
    required String code,
    required String name,
    @Default('stock') String type,
    String? sector,
    @Default(0) int watcherCount,
  }) = _StockModel;

  const StockModel._();

  factory StockModel.fromJson(Map<String, dynamic> json) => _$StockModelFromJson(json);

  Stock toEntity() => Stock(
    code: code,
    name: name,
    type: type == 'index' ? StockType.marketIndex : StockType.stock,
    sector: sector,
    watcherCount: watcherCount,
  );
}

/// Baris hasil RPC get_notifications.
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

  /// null jika tipe tidak dikenal versi client ini (diabaikan UI).
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
