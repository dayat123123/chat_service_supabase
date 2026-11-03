import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:rendezvous_community/src/features/feed/data/models/feed_post_model.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  BookmarkRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<bool> setBookmarked(String postId, {bool? bookmarked}) async =>
      await _api.rpcValue('toggle_bookmark', {'p_post_id': postId, 'p_bookmarked': bookmarked}) == true;

  @override
  Future<Paged<Post>> getBookmarks({String? cursor, int limit = 20}) async {
    final rows = await _api.rpcRows('get_bookmarks', {'p_cursor': cursor, 'p_limit': limit});
    final posts = [for (final row in rows) FeedPostModel.fromJson(row).toEntity()];
    return Paged(posts, nextCursor: posts.length < limit ? null : posts.last.cursor);
  }
}
