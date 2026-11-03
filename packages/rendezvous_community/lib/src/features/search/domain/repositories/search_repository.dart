import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/search/domain/entities/search_results.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';

abstract interface class SearchRepository {
  Future<SearchResults> search(String query, {SearchType type = SearchType.all, String? cursor, int limit = 20});

  Future<Paged<Post>> hashtagFeed(String tag, {String? cursor, int limit = 20});

  Future<List<HashtagSummary>> trendingHashtags({TrendWindow window = TrendWindow.day, int limit = 10});
}
