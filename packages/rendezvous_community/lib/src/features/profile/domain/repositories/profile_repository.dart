import 'dart:typed_data';

import 'package:rendezvous_community/src/features/profile/domain/entities/user_profile.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> getProfile({String? userId, String? username});

  Future<void> updateMyProfile({String? displayName, String? bio, String? avatarUrl});

  Future<String> uploadAvatar(Uint8List bytes, {required String mimeType});

  Future<void> follow(String userId);

  Future<void> unfollow(String userId);

  Future<void> block(String userId);

  Future<void> unblock(String userId);

  Future<List<UserSummary>> searchUsers(String query, {int limit = 8});

  Future<Set<String>> officialAccountIds();
}
