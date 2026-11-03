import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';

abstract interface class BookmarkRepository {
  Future<bool> setBookmarked(String postId, {bool? bookmarked});

  Future<Paged<Post>> getBookmarks({String? cursor, int limit = 20});
}
