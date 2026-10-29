import 'package:mocktail/mocktail.dart';
import 'package:olt_social/olt_social.dart';

const me = UserSummary(id: 'u-me', username: 'budi_santoso', displayName: 'Budi Santoso');
const alice = UserSummary(id: 'u-a', username: 'alice', displayName: 'Alice');
const bob = UserSummary(id: 'u-b', username: 'bob_user', displayName: 'Bob');

final now = DateTime.now().toUtc();

ThreadComment comment(
  String id, {
  String? parentId,
  required int depth,
  required String path,
  String? body,
  int replyCount = 0,
  bool deleted = false,
  UserSummary author = bob,
}) => ThreadComment(
  id: id,
  postId: 'p-1',
  parentId: parentId,
  author: deleted ? null : author,
  body: deleted ? null : (body ?? 'Komentar $id'),
  isDeleted: deleted,
  depth: depth,
  path: path,
  replyCount: replyCount,
  createdAt: now.subtract(const Duration(minutes: 5)),
  cursor: path.split('.').last,
);

class FakeFeedRepository extends Fake implements FeedRepository {
  final likes = <String>[];

  @override
  Future<Post?> getPost(String postId) async => Post(
    id: postId,
    author: alice,
    body: r'Analisis $BBCA hari ini',
    sentiment: Sentiment.bullish,
    stockCodes: const ['BBCA'],
    commentCount: 7,
    createdAt: now.subtract(const Duration(hours: 1)),
    cursor: 'c',
  );

  @override
  Stream<PostChange> watchPosts({String? postId}) => const Stream.empty();

  @override
  Future<void> likePost(String postId) async => likes.add(postId);
}

/// Thread uji:
///   c1 (3 balasan, baru 2 termuat) ─ c2 ─ c3 ─ c4 (2 balasan, di batas level 4)
///                                └ c2b (dihapus)
///   t2
class FakeCommentRepository extends Fake implements CommentRepository {
  final requests = <Map<String, Object?>>[];
  final likedComments = <String>[];

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
    requests.add({'root': rootCommentId, 'cursor': cursor, 'maxDepth': maxDepth});
    if (rootCommentId == 'c1' && cursor == '000000000006') {
      return [comment('c2c', parentId: 'c1', depth: 1, path: '000000000001.000000000009', body: 'Balasan C')];
    }
    return [
      comment('c1', depth: 0, path: '000000000001', body: 'Level 1', replyCount: 3),
      comment('c2', parentId: 'c1', depth: 1, path: '000000000001.000000000002', body: 'Level 2', replyCount: 1),
      comment('c3', parentId: 'c2', depth: 2, path: '000000000001.000000000002.000000000003', body: 'Level 3', replyCount: 1),
      comment('c4', parentId: 'c3', depth: 3, path: '000000000001.000000000002.000000000003.000000000004', body: 'Level 4', replyCount: 2),
      comment('c2b', parentId: 'c1', depth: 1, path: '000000000001.000000000006', deleted: true),
      comment('t2', depth: 0, path: '000000000007', body: 'Top kedua', author: alice),
    ];
  }

  @override
  Stream<String> watchComments(String postId) => const Stream.empty();

  @override
  Future<void> likeComment(String commentId) async => likedComments.add(commentId);
}

class _Unused extends Fake implements ProfileRepository, StockRepository, ChatRepository, NotificationRepository, ModerationRepository, MediaRepository {}

class FakeDependencies implements OltSocialDependencies {
  FakeDependencies({FakeFeedRepository? feed, FakeCommentRepository? comments})
    : feed = feed ?? FakeFeedRepository(),
      comments = comments ?? FakeCommentRepository();

  final _unused = _Unused();

  @override
  final FakeFeedRepository feed;
  @override
  final FakeCommentRepository comments;
  @override
  ProfileRepository get profiles => _unused;
  @override
  StockRepository get stocks => _unused;
  @override
  ChatRepository get chat => _unused;
  @override
  NotificationRepository get notifications => _unused;
  @override
  ModerationRepository get moderation => _unused;
  @override
  MediaRepository get media => _unused;
  @override
  OltSocialCallbacks get callbacks => const OltSocialCallbacks();
  @override
  UserSummary? get currentUser => me;
  @override
  Future<UserSummary> ensureSignedIn() async => me;
}
