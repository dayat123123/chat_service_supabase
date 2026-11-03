import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'search_results.freezed.dart';

enum SearchType { all, posts, users, stocks, hashtags }

@freezed
abstract class UserSearchResult with _$UserSearchResult {
  const factory UserSearchResult({
    required UserSummary user,
    @Default(0) int followerCount,
    @Default(false) bool isOfficial,
    @Default(false) bool isFollowing,
    @Default(false) bool isMe,
  }) = _UserSearchResult;
}

@freezed
abstract class StockSearchResult with _$StockSearchResult {
  const factory StockSearchResult({
    required String code,
    @Default(0) int posts7d,
    @Default(0) int watcherCount,
    @Default(false) bool isWatching,
  }) = _StockSearchResult;
}

@freezed
abstract class SearchResults with _$SearchResults {
  const factory SearchResults({
    required String query,
    required SearchType type,
    @Default(<Post>[]) List<Post> posts,
    @Default(<UserSearchResult>[]) List<UserSearchResult> users,
    @Default(<StockSearchResult>[]) List<StockSearchResult> stocks,
    @Default(<HashtagSummary>[]) List<HashtagSummary> hashtags,
    String? nextCursor,
  }) = _SearchResults;

  const SearchResults._();

  int get count => posts.length + users.length + stocks.length + hashtags.length;

  bool get isEmpty => count == 0;
}

final hashtagPattern = RegExp(r'^[a-z0-9_]{2,50}$');

String? normalizeHashtag(String value) {
  final tag = value.trim().replaceFirst(RegExp('^#'), '').toLowerCase();
  return hashtagPattern.hasMatch(tag) ? tag : null;
}
