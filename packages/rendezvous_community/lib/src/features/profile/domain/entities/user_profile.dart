import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'user_profile.freezed.dart';

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required UserSummary user,
    String? bio,
    required int followerCount,
    required int followingCount,
    required int postCount,
    required DateTime createdAt,
    required bool isMe,
    required bool isFollowing,
    required bool followsMe,
    required bool isBlocked,
  }) = _UserProfile;
}
