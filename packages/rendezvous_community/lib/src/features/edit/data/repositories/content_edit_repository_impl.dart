import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/edit/domain/repositories/content_edit_repository.dart';
import 'package:rendezvous_community/src/features/feed/data/models/feed_post_model.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/post/data/models/thread_comment_model.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';

class ContentEditRepositoryImpl implements ContentEditRepository {
  ContentEditRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Post> editPost(String postId, String body) async {
    final rows = await _api.rpcRows('edit_post', {'p_post_id': postId, 'p_body': body});
    if (rows.isEmpty) throw const CommunityException(CommunityErrorKind.notFound, code: 'post_not_found');
    return FeedPostModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<ThreadComment> editComment(String commentId, String body) async {
    final rows = await _api.rpcRows('edit_comment', {'p_comment_id': commentId, 'p_body': body});
    if (rows.isEmpty) throw const CommunityException(CommunityErrorKind.notFound, code: 'comment_not_found');
    return ThreadCommentModel.fromJson(rows.first).toEntity();
  }
}
