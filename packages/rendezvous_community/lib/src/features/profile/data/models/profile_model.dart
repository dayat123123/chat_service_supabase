import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/profile/domain/entities/user_profile.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

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
