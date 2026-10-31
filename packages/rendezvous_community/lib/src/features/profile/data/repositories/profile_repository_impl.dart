import 'dart:typed_data';

import 'package:olt_social/src/core/media/image_mime.dart';
import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/features/profile/data/models/profile_model.dart';
import 'package:olt_social/src/features/profile/domain/entities/user_profile.dart';
import 'package:olt_social/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:olt_social/src/shared/data/models/user_summary_model.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<UserProfile?> getProfile({String? userId, String? username}) async {
    final rows = await _api.rpcRows('get_profile', {'p_user_id': userId, 'p_username': username});
    return rows.isEmpty ? null : ProfileModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<void> updateMyProfile({String? displayName, String? bio, String? avatarUrl}) async {
    final me = await _api.requireUserId();
    final values = <String, Object?>{
      'display_name': ?displayName,
      'bio': ?bio,
      'avatar_url': ?avatarUrl,
    };
    if (values.isEmpty) return;
    await _api.update('profiles', values, {'id': me});
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, {required String mimeType}) async {
    final me = await _api.requireUserId();
    final path = '$me/avatar-${DateTime.now().millisecondsSinceEpoch}.${imageExtension(mimeType)}';
    await _api.upload('avatars', path, bytes, contentType: mimeType, upsert: true);
    final url = _api.publicUrl('avatars', path);
    await updateMyProfile(avatarUrl: url);
    return url;
  }

  @override
  Future<void> follow(String userId) async {
    final me = await _api.requireUserId();
    await _api.insertIgnoringDuplicate('follows', {'follower_id': me, 'following_id': userId});
  }

  @override
  Future<void> unfollow(String userId) async {
    final me = await _api.requireUserId();
    await _api.delete('follows', {'follower_id': me, 'following_id': userId});
  }

  @override
  Future<void> block(String userId) async {
    final me = await _api.requireUserId();
    await _api.insertIgnoringDuplicate('blocks', {'blocker_id': me, 'blocked_id': userId});
  }

  @override
  Future<void> unblock(String userId) async {
    final me = await _api.requireUserId();
    await _api.delete('blocks', {'blocker_id': me, 'blocked_id': userId});
  }

  @override
  Future<List<UserSummary>> searchUsers(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _api.rpcRows('search_profiles', {'p_query': query, 'p_limit': limit});
    return [for (final row in rows) UserSummaryModel.fromJson(row).toEntity()];
  }
}
