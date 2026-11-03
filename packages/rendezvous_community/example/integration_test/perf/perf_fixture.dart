import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

const perfMe = UserSummary(id: 'u-0', username: 'budi_santoso', displayName: 'Budi Santoso');

final perfUsers = [
  perfMe,
  for (var i = 1; i < 8; i++)
    UserSummary(
      id: 'u-$i',
      username: 'trader_$i',
      displayName: 'Trader $i',
      avatarUrl: i.isEven ? 'http://perf.local/storage/v1/object/public/avatars/u-$i.png?token=t$i' : null,
      isVerified: i == 3,
    ),
];

const perfStocks = ['BBCA', 'BBRI', 'TLKM', 'GOTO', 'ADRO', 'ANTM'];

final perfStart = DateTime.utc(2026, 10, 1, 1);

Future<Uint8List> _png(int width, int height, Color a, Color b) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  canvas.drawRect(rect, Paint()..shader = LinearGradient(colors: [a, b]).createShader(rect));
  for (var i = 0; i < 24; i++) {
    canvas.drawCircle(
      Offset(width * ((i * 37) % 100) / 100, height * ((i * 53) % 100) / 100),
      width / 12,
      Paint()..color = Color.lerp(a, b, i / 24)!.withValues(alpha: 0.6),
    );
  }
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

class PerfImages {
  PerfImages._(this.photo, this.thumbnail, this.avatar);

  static Future<PerfImages> create() async => PerfImages._(
    await _png(1600, 1200, Colors.indigo, Colors.teal),
    await _png(600, 400, Colors.orange, Colors.pink),
    await _png(256, 256, Colors.blueGrey, Colors.amber),
  );

  final Uint8List photo;
  final Uint8List thumbnail;
  final Uint8List avatar;

  http.Client client() => MockClient((request) async {
    final path = request.url.path;
    final bytes = path.contains('/avatars/')
        ? avatar
        : path.contains('/previews/')
        ? thumbnail
        : photo;
    return http.Response.bytes(bytes, 200);
  });
}

Poll _poll(int i) => Poll(
  endsAt: perfStart.add(const Duration(days: 400)),
  closed: false,
  totalVotes: 40 + i,
  resultsVisible: i.isEven,
  options: const [
    PollOption(id: 'a', label: 'Naik', votes: 21),
    PollOption(id: 'b', label: 'Turun', votes: 12),
    PollOption(id: 'c', label: 'Sideways', votes: 7),
  ],
);

List<Post> perfPosts(int count) => [
  for (var i = 0; i < count; i++)
    Post(
      id: 'p-$i',
      author: perfUsers[1 + i % (perfUsers.length - 1)],
      body: [
        'Analisis \$${perfStocks[i % perfStocks.length]} hari ke-$i: volume naik, support kuat di area MA20. #saham',
        if (i % 4 == 2) 'Baca selengkapnya https://news.perf.local/artikel/$i',
        if (i % 3 == 0) 'Target jangka menengah masih terbuka, tetap disiplin dengan manajemen risiko.',
      ].join('\n'),
      sentiment: Sentiment.values[i % Sentiment.values.length],
      stockCodes: [perfStocks[i % perfStocks.length]],
      attachments: [
        if (i % 3 == 0) Attachment(path: 'posts/u/$i-a.png', mime: 'image/png', width: 1600, height: 1200),
        if (i % 5 == 1)
          for (var k = 0; k < 3; k++)
            Attachment(path: 'posts/u/$i-$k.png', mime: 'image/png', width: 1600, height: 1200),
      ],
      poll: i % 7 == 3 ? _poll(i) : null,
      likeCount: i * 3 % 97,
      commentCount: i % 13,
      likedByMe: i % 6 == 0,
      isBot: i % 29 == 5,
      createdAt: perfStart.add(Duration(minutes: 5 * (count - i))),
      cursor: '$i',
    ),
];

List<ChatMessage> perfMessages(int count) => [
  for (var i = 0; i < count; i++)
    ChatMessage(
      id: 'm-$i',
      roomId: 'perf-room',
      senderId: perfUsers[i % 4 == 0 ? 0 : 1 + i % (perfUsers.length - 1)].id,
      sender: perfUsers[i % 4 == 0 ? 0 : 1 + i % (perfUsers.length - 1)],
      body: i % 15 == 7
          ? null
          : [
              'Pesan $i tentang \$${perfStocks[i % perfStocks.length]}',
              if (i % 3 == 0) 'menurut saya entry bertahap lebih aman sambil menunggu konfirmasi breakout.',
            ].join(' '),
      attachments: [
        if (i % 10 == 4) Attachment(path: 'rooms/perf-room/u/$i.png', mime: 'image/png', width: 1600, height: 1200),
      ],
      stockCodes: i % 15 == 7 ? ['BBCA', 'TLKM'] : const [],
      reactions: i % 6 == 1
          ? const [MessageReaction(emoji: '👍', count: 3), MessageReaction(emoji: '🔥', count: 1, mine: true)]
          : const [],
      createdAt: perfStart.add(Duration(minutes: 17 * i)),
      cursor: '${perfStart.add(Duration(minutes: 17 * i)).toIso8601String()}|m-$i',
    ),
];

class PerfFeedRepository extends Fake implements FeedRepository {
  PerfFeedRepository(this.posts);

  final List<Post> posts;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async {
    final start = cursor == null ? 0 : int.parse(cursor) + 1;
    final items = posts.skip(start).take(limit).toList();
    return Paged(items, nextCursor: start + limit >= posts.length ? null : items.last.cursor);
  }

  @override
  Future<List<PinnedPost>> getPinned(FeedScope scope) async => const [];

  @override
  Stream<PostChange> watchPosts({String? postId}) => const Stream.empty();

  @override
  Future<void> likePost(String postId) async {}

  @override
  Future<void> unlikePost(String postId) async {}
}

class _Connection implements ChatRoomConnection {
  @override
  Stream<ChatRoomEvent> get events => const Stream.empty();

  @override
  Future<void> sendTyping({required bool isTyping}) async {}

  @override
  Future<void> close() async {}
}

class PerfChatRepository extends Fake implements ChatRepository {
  PerfChatRepository(this.messages);

  final List<ChatMessage> messages;

  late final room = ChatRoom(
    id: 'perf-room',
    type: RoomType.group,
    name: 'Diskusi Swing Trader',
    createdAt: perfStart,
    lastReadAt: perfStart.add(const Duration(days: 365)),
    memberCount: perfUsers.length,
  );

  @override
  Future<ChatRoom?> getRoom(String roomId) async => room;

  @override
  Future<List<RoomMember>> getMembers(String roomId) async => [
    for (final user in perfUsers)
      RoomMember(user: user, lastReadAt: perfStart, lastDeliveredAt: perfStart, joinedAt: perfStart),
  ];

  @override
  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30}) async {
    final newestFirst = messages.reversed.toList();
    final start = cursor == null ? 0 : newestFirst.indexWhere((m) => m.cursor == cursor) + 1;
    final items = newestFirst.skip(start).take(limit).toList();
    return Paged(items, nextCursor: items.length < limit ? null : items.last.cursor);
  }

  @override
  Future<Paged<ChatMessage>> getMessagesAfter(String roomId, String cursor, {int limit = 100}) async => const Paged([]);

  @override
  ChatRoomConnection connectRoom(String roomId, {required UserSummary me}) => _Connection();

  @override
  Future<void> markRoomRead(String roomId) async {}

  @override
  Future<int> markDelivered({List<String>? roomIds}) async => 0;
}

class PerfMediaRepository extends Fake implements MediaRepository {
  @override
  Future<AuthorizedImage> attachmentImage(Attachment attachment) async =>
      AuthorizedImage('http://perf.local/storage/v1/object/authenticated/attachments/${attachment.path}', const {});
}

class _Previews implements LinkPreviewRepository {
  @override
  Future<List<LinkPreview>> lookup(List<String> urls) async => [
    for (final url in urls)
      LinkPreview(
        url: url,
        status: LinkPreviewStatus.ok,
        title: 'Judul artikel pasar ${url.split('/').last}',
        description: 'Ringkasan berita pasar modal untuk uji performa scroll.',
        siteName: 'Perf News',
        imageUrl: 'http://perf.local/previews/${url.split('/').last}.png',
      ),
  ];
}

class _Config implements ClientConfigRepository {
  @override
  Future<ClientConfig> fetch({String? platform, String? appVersion}) async => const ClientConfig();
}

class _Analytics implements AnalyticsRepository {
  @override
  Future<AnalyticsResult> track(List<AnalyticsEvent> events, {String? platform, String? appVersion}) =>
      throw UnimplementedError();
}

class _Dismissals implements BannerDismissalRepository {
  @override
  Future<Set<String>> load() async => const {};

  @override
  Future<void> save(Set<String> ids) async {}
}

class _Unused extends Fake
    implements
        CommentRepository,
        PollRepository,
        ProfileRepository,
        StockRepository,
        NotificationRepository,
        ModerationRepository,
        BookmarkRepository,
        ContentEditRepository,
        ChatExtrasRepository,
        MessageRequestRepository {}

class PerfDependencies implements CommunityDependencies, CommunityFeatureDependencies {
  PerfDependencies({required this.feed, required this.chat});

  final _unused = _Unused();

  @override
  final FeedRepository feed;
  @override
  final ChatRepository chat;
  @override
  final MediaRepository media = PerfMediaRepository();
  @override
  final CommunityCallbacks callbacks = CommunityCallbacks(
    onStockTap: (_, _) {},
    onUserTap: (_, _) {},
    stockInfo: (code) => CommunityStockInfo(name: 'Emiten $code', price: '9.150', change: '+1,1%', rising: true),
  );
  @override
  final ClientConfigService configService = ClientConfigService(_Config());
  @override
  final LinkPreviewLoader linkPreviews = LinkPreviewLoader(_Previews(), batchDelay: Duration.zero);
  @override
  final CommunityAnalytics analytics = CommunityAnalytics(_Analytics(), enabled: () => false, signedIn: () => true);

  @override
  final BannerDismissals bannerDismissals = BannerDismissals(_Dismissals());

  @override
  CommentRepository get comments => _unused;
  @override
  PollRepository get polls => _unused;
  @override
  ProfileRepository get profiles => _unused;
  @override
  StockRepository get stocks => _unused;
  @override
  NotificationRepository get notifications => _unused;
  @override
  ModerationRepository get moderation => _unused;
  @override
  BookmarkRepository get bookmarks => _unused;
  @override
  ContentEditRepository get edits => _unused;
  @override
  ChatExtrasRepository get chatExtras => _unused;
  @override
  MessageRequestRepository get messageRequests => _unused;
  @override
  UserSummary? get currentUser => perfMe;
  @override
  Future<UserSummary> ensureSignedIn() async => perfMe;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class PerfApp extends StatelessWidget {
  const PerfApp({super.key, required this.dependencies, required this.images, required this.child});

  final PerfDependencies dependencies;
  final CommunityImageLoader images;
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('id'),
    localizationsDelegates: CommunityLocalizations.localizationsDelegates,
    supportedLocales: CommunityLocalizations.supportedLocales,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FFF)), useMaterial3: true),
    home: Scaffold(
      body: CommunityImageScope(
        loader: images,
        child: CommunityScope(
          dependencies: dependencies,
          child: CommunityFeatureScope(dependencies: dependencies, child: child),
        ),
      ),
    ),
  );
}
