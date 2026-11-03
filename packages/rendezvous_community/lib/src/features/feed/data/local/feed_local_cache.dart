import 'package:rendezvous_community/src/core/storage/offline_cache.dart';
import 'package:rendezvous_community/src/features/feed/data/models/feed_post_model.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_cache_repository.dart';

class FeedLocalCache implements FeedCacheRepository {
  FeedLocalCache(this._cache);

  final OfflineCache _cache;

  @override
  Future<List<Post>?> cachedFeed(FeedScope scope) async {
    final key = feedCacheKey(scope);
    if (key == null) return null;
    final rows = await _cache.read((store) => store.readFeed(key));
    if (rows == null) return null;
    return [for (final row in rows) ?_parse(row)];
  }

  Future<void> saveFirstPage(FeedScope scope, List<Map<String, dynamic>> rows) async {
    final key = feedCacheKey(scope);
    if (key == null) return;
    await _cache.write((store) => store.writeFeed(key, rows, keepScopes: _cache.feedScopeLimit));
  }

  static Post? _parse(Map<String, dynamic> row) {
    try {
      return FeedPostModel.fromJson(row).toEntity();
    } catch (_) {
      return null;
    }
  }
}
