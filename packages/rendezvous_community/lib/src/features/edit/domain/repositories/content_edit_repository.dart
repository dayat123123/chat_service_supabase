import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';

abstract interface class ContentEditRepository {
  Future<Post> editPost(String postId, String body);

  Future<ThreadComment> editComment(String commentId, String body);
}
