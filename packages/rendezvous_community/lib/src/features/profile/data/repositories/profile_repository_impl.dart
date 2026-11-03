import 'dart:typed_data';

import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/media/image_mime.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/profile/data/models/profile_model.dart';
import 'package:rendezvous_community/src/features/profile/domain/entities/user_profile.dart';
import 'package:rendezvous_community/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:rendezvous_community/src/shared/data/models/user_summary_model.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

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
    final values = <String, Object?>{'display_name': ?displayName, 'bio': ?bio, 'avatar_url': ?avatarUrl};
    if (values.isEmpty) return;
    await _api.update('profiles', values, {'id': me});
  }

  @override
  Future<Set<String>> officialAccountIds() async {
    final rows = await _api.rpcRows('get_official_accounts');
    return {for (final row in rows) row['id'] as String};
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, {required String mimeType}) async {
    if (mimeType == gifMimeType) {
      throw const CommunityException(CommunityErrorKind.invalidInput, code: 'unsupported_type');
    }
    final me = await _api.requireUserId();
    final path = '$me/avatar-${DateTime.now().millisecondsSinceEpoch}.${imageExtension(mimeType)}';
    final object = await _api.upload(avatarBucket, path, bytes, contentType: mimeType, upsert: true);
    final url = _api.publicUrl(avatarBucket, object.path);
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
