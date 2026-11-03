import 'package:rendezvous_community/src/core/network/json_values.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/feed/data/models/feed_post_model.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/search/domain/entities/search_results.dart';
import 'package:rendezvous_community/src/features/search/domain/repositories/search_repository.dart';
import 'package:rendezvous_community/src/features/trending/data/models/trending_models.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<SearchResults> search(String query, {SearchType type = SearchType.all, String? cursor, int limit = 20}) async {
    final json = jsonMap(
      await _api.rpcValue('search', {
        'p_query': query,
        'p_type': type.name,
        'p_cursor': type == SearchType.all ? null : cursor,
        'p_limit': limit,
      }),
    );
    return SearchResults(
      query: json['query'] as String? ?? query,
      type: type,
      posts: [for (final row in jsonList(json['posts'])) FeedPostModel.fromJson(row).toEntity()],
      users: [for (final row in jsonList(json['users'])) _user(row)],
      stocks: [for (final row in jsonList(json['stocks'])) _stock(row)],
      hashtags: [for (final row in jsonList(json['hashtags'])) HashtagSummaryModel.fromJson(row).toEntity()],
      nextCursor: json['next_cursor'] as String?,
    );
  }

  UserSearchResult _user(Map<String, dynamic> row) => UserSearchResult(
    user: UserSummary(
      id: row['id'] as String,
      username: row['username'] as String? ?? '',
      displayName: row['display_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isVerified: row['is_verified'] == true,
    ),
    followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
    isOfficial: row['is_official'] == true,
    isFollowing: row['is_following'] == true,
    isMe: row['is_me'] == true,
  );

  StockSearchResult _stock(Map<String, dynamic> row) => StockSearchResult(
    code: row['code'] as String,
    posts7d: (row['posts_7d'] as num?)?.toInt() ?? 0,
    watcherCount: (row['watcher_count'] as num?)?.toInt() ?? 0,
    isWatching: row['is_watching'] == true,
  );

  @override
  Future<Paged<Post>> hashtagFeed(String tag, {String? cursor, int limit = 20}) async {
    final rows = await _api.rpcRows('get_hashtag_feed', {
      'p_tag': tag.replaceFirst(RegExp('^#'), ''),
      'p_cursor': cursor,
      'p_limit': limit,
    });
    final posts = [for (final row in rows) FeedPostModel.fromJson(row).toEntity()];
    return Paged(posts, nextCursor: posts.length < limit ? null : posts.last.cursor);
  }

  @override
  Future<List<HashtagSummary>> trendingHashtags({TrendWindow window = TrendWindow.day, int limit = 10}) async {
    final rows = await _api.rpcRows('get_trending_hashtags', {'p_window': window.value, 'p_limit': limit});
    return [for (final row in rows) HashtagSummaryModel.fromJson(row).toEntity()];
  }
}
