import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/olt_social_exception.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/realtime_gateway.dart';
import '../datasources/social_remote_data_source.dart';
import '../models/post_models.dart';

const _uuid = Uuid();

/// Insert yang boleh "gagal" karena data sudah ada (mis. like dua kali).
Future<void> insertIgnoringDuplicate(SocialRemoteDataSource api, String table, Map<String, Object?> values) async {
  try {
    await api.insert(table, values);
  } on OltSocialException catch (e) {
    if (e.code != '23505') rethrow;
  }
}

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl(this._api, [this._realtime]);

  final SocialRemoteDataSource _api;
  final RealtimeGateway? _realtime;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async {
    final rows = await _api.rpcRows('get_feed', {
      'p_scope': switch (scope) {
        GlobalFeedScope() => 'global',
        FollowingFeedScope() => 'following',
        StockFeedScope() => 'stock',
        UserFeedScope() => 'user',
      },
      'p_stock_code': scope is StockFeedScope ? scope.code : null,
      'p_cursor': cursor,
      'p_limit': limit,
      'p_author_id': scope is UserFeedScope ? scope.userId : null,
    });
    final posts = [for (final row in rows) FeedPostModel.fromJson(row).toEntity()];
    return Paged(posts, nextCursor: posts.length < limit ? null : posts.last.cursor);
  }

  @override
  Future<Post?> getPost(String postId) async {
    final rows = await _api.rpcRows('get_post', {'p_post_id': postId});
    return rows.isEmpty ? null : FeedPostModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<Post> createPost({required String body, Sentiment? sentiment, List<Attachment> attachments = const []}) async {
    final userId = await _api.requireUserId();
    final id = _uuid.v4();
    await _api.insert('posts', {
      'id': id,
      'author_id': userId,
      'body': body,
      'sentiment': sentiment?.name,
      'attachments': [for (final a in attachments) AttachmentModel.fromEntity(a).toJson()],
    });
    final post = await getPost(id);
    if (post == null) throw const OltSocialException(OltSocialErrorKind.notFound);
    return post;
  }

  @override
  Future<void> deletePost(String postId) => _api.rpcValue('delete_post', {'p_post_id': postId});

  @override
  Future<void> likePost(String postId) async {
    final userId = await _api.requireUserId();
    await insertIgnoringDuplicate(_api, 'reactions', {
      'user_id': userId,
      'target_type': 'post',
      'target_id': postId,
      'type': 'like',
    });
  }

  @override
  Future<void> unlikePost(String postId) async {
    final userId = await _api.requireUserId();
    await _api.delete('reactions', {'user_id': userId, 'target_type': 'post', 'target_id': postId});
  }

  @override
  Stream<PostChange> watchPosts({String? postId}) {
    final realtime = _realtime;
    if (realtime == null) return const Stream.empty();
    return realtime
        .tableChanges(
          table: 'posts',
          filter: postId == null
              ? null
              : PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: postId),
        )
        .map(_toPostChange)
        .where((c) => c != null)
        .cast<PostChange>();
  }

  PostChange? _toPostChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final row = PostRowModel.fromJson(payload.newRecord);
        if (row.deletedAt != null) return null;
        return PostInserted(row.id, authorId: row.authorId, body: row.body, createdAt: row.createdAt);
      case PostgresChangeEvent.update:
        final row = PostRowModel.fromJson(payload.newRecord);
        return PostUpdated(
          row.id,
          likeCount: row.likeCount,
          commentCount: row.commentCount,
          deleted: row.deletedAt != null,
        );
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id'] as String?;
        return id == null ? null : PostUpdated(id, likeCount: 0, commentCount: 0, deleted: true);
      case PostgresChangeEvent.all:
        return null;
    }
  }
}

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
    final rows = await _api.rpcRows('create_comment', {
      'p_post_id': postId,
      'p_parent_id': parentId,
      'p_body': body,
    });
    if (rows.isEmpty) throw const OltSocialException(OltSocialErrorKind.unknown, message: 'create_comment kosong');
    return ThreadCommentModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<void> deleteComment(String commentId) => _api.rpcValue('delete_comment', {'p_comment_id': commentId});

  @override
  Future<void> likeComment(String commentId) async {
    final userId = await _api.requireUserId();
    await insertIgnoringDuplicate(_api, 'reactions', {
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
