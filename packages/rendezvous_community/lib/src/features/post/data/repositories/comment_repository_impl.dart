import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/network/realtime_gateway.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/post/data/models/thread_comment_model.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';
import 'package:rendezvous_community/src/features/post/domain/repositories/comment_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._api, [this._realtime]);

  final SocialRemoteDataSource _api;
  final RealtimeGateway? _realtime;

  @override
  Future<List<ThreadComment>> getThread(
    String postId, {
    String? rootCommentId,
    int maxDepth = 3,
    String? cursor,
    int limit = 20,
    int repliesLimit = 3,
    bool includeRoot = false,
  }) async {
    final rows = await _api.rpcRows('get_comment_thread', {
      'p_post_id': postId,
      'p_root_comment_id': rootCommentId,
      'p_max_depth': maxDepth,
      'p_cursor': cursor,
      'p_limit': limit,
      'p_replies_limit': repliesLimit,
      'p_include_root': includeRoot,
    });
    return [for (final row in rows) ThreadCommentModel.fromJson(row).toEntity()];
  }

  @override
  Future<ThreadComment> createComment({required String postId, String? parentId, required String body}) async {
    final rows = await _api.rpcRows('create_comment', {'p_post_id': postId, 'p_parent_id': parentId, 'p_body': body});
    if (rows.isEmpty) {
      throw const CommunityException(CommunityErrorKind.unknown, message: 'create_comment returned no rows');
    }
    return ThreadCommentModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<void> deleteComment(String commentId) => _api.rpcValue('delete_comment', {'p_comment_id': commentId});

  @override
  Future<void> likeComment(String commentId) async {
    final userId = await _api.requireUserId();
    await _api.insertIgnoringDuplicate('reactions', {
      'user_id': userId,
      'target_type': 'comment',
      'target_id': commentId,
      'type': 'like',
    });
  }

  @override
  Future<void> unlikeComment(String commentId) async {
    final userId = await _api.requireUserId();
    await _api.delete('reactions', {'user_id': userId, 'target_type': 'comment', 'target_id': commentId});
  }

  @override
  Stream<String> watchComments(String postId) {
    final realtime = _realtime;
    if (realtime == null) return const Stream.empty();
    return realtime
        .tableChanges(
          table: 'comments',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'post_id', value: postId),
        )
        .map((p) => (p.newRecord['id'] ?? p.oldRecord['id']) as String?)
        .where((id) => id != null)
        .cast<String>();
  }
}
