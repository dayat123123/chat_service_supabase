import 'dart:async';

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

class FakePollRepository extends Fake implements PollRepository {
  final votes = <(String, String)>[];
  Poll Function(String postId, String optionId)? onVote;
  Object? error;

  @override
  Future<Poll> vote(String postId, String optionId) async {
    votes.add((postId, optionId));
    final failure = error;
    if (failure != null) throw failure;
    return onVote!(postId, optionId);
  }
}

class FakeChatRepository extends Fake implements ChatRepository {
  FakeChatRepository({this.rooms = const [], this.members = const [], this.messages = const []});

  List<ChatRoom> rooms;
  List<RoomMember> members;
  List<ChatMessage> messages;
  final signals = StreamController<RoomSignal>.broadcast();
  final activity = StreamController<RoomActivity>.broadcast();
  final roomEvents = StreamController<ChatRoomEvent>.broadcast();
  final unreadChanges = StreamController<void>.broadcast();
  final watchedRoomIds = <Set<String>>[];
  final delivered = <List<String>?>[];
  final readRooms = <String>[];
  int unreadChats = 0;
  int unreadChatCalls = 0;
  Object? unreadChatError;

  @override
  Future<List<ChatRoom>> getRooms() async => rooms;

  @override
  Future<int> unreadChatCount() async {
    unreadChatCalls++;
    final error = unreadChatError;
    if (error != null) throw error;
    return unreadChats;
  }

  @override
  Stream<void> watchUnreadChanges() => unreadChanges.stream;

  @override
  Future<List<RoomMember>> getMembers(String roomId) async => members;

  @override
  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30}) async => Paged(messages);

  @override
  Stream<RoomActivity> watchRoomActivity() => activity.stream;

  @override
  Stream<RoomSignal> watchRoomSignals(Set<String> roomIds, {required UserSummary me}) {
    watchedRoomIds.add(roomIds);
    return signals.stream;
  }

  @override
  Future<int> markDelivered({List<String>? roomIds}) async {
    delivered.add(roomIds);
    return roomIds?.length ?? 0;
  }

  @override
  Future<void> markRoomRead(String roomId) async => readRooms.add(roomId);

  @override
  ChatRoomConnection connectRoom(String roomId, {required UserSummary me}) => FakeRoomConnection(roomEvents.stream);

  Future<void> dispose() async {
    await signals.close();
    await activity.close();
    await roomEvents.close();
    await unreadChanges.close();
  }
}

class FakeNotificationRepository extends Fake implements NotificationRepository {
  final changes = StreamController<void>.broadcast();

  @override
  Stream<void> watchNotifications() => changes.stream;

  Future<void> dispose() => changes.close();
}

class FakeRoomConnection implements ChatRoomConnection {
  FakeRoomConnection(this.events);

  @override
  final Stream<ChatRoomEvent> events;

  @override
  Future<void> sendTyping({required bool isTyping}) async {}

  @override
  Future<void> close() async {}
}

class _Unused extends Fake
    implements ProfileRepository, StockRepository, NotificationRepository, ModerationRepository, MediaRepository {}

class FakeDependencies implements OltSocialDependencies {
  FakeDependencies({
    FakeFeedRepository? feed,
    FakeCommentRepository? comments,
    FakePollRepository? polls,
    ChatRepository? chat,
    NotificationRepository? notifications,
  }) : feed = feed ?? FakeFeedRepository(),
       comments = comments ?? FakeCommentRepository(),
       polls = polls ?? FakePollRepository(),
       chat = chat ?? FakeChatRepository(),
       notifications = notifications ?? _Unused();

  final _unused = _Unused();

  @override
  final FakeFeedRepository feed;
  @override
  final FakeCommentRepository comments;
  @override
  final FakePollRepository polls;
  @override
  final ChatRepository chat;
  @override
  ProfileRepository get profiles => _unused;
  @override
  StockRepository get stocks => _unused;
  @override
  final NotificationRepository notifications;
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
