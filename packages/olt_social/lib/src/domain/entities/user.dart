import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// Ringkasan user untuk ditampilkan di kartu post, komentar, chat.
@freezed
abstract class UserSummary with _$UserSummary {
  const factory UserSummary({
    required String id,
    required String username,
    String? displayName,
    String? avatarUrl,
    @Default(false) bool isVerified,
  }) = _UserSummary;

  const UserSummary._();

  /// Nama tampilan, atau username bila kosong.
  String get name => (displayName?.trim().isNotEmpty ?? false) ? displayName!.trim() : username;
}

/// Profil lengkap beserta relasi dengan user yang sedang login.
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

/// Sesi sosial hasil tukar token OLT di auth-bridge.
@freezed
abstract class SocialSession with _$SocialSession {
  const factory SocialSession({
    required String accessToken,
    required DateTime expiresAt,
    required UserSummary user,
  }) = _SocialSession;
}
