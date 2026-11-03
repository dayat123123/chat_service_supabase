import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/message_bubble.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_card.dart';
import 'package:rendezvous_community/src/shared/presentation/images/community_image_provider.dart';

import '../../support/chat_app.dart';
import '../../support/fakes.dart';

class _Media extends Fake implements MediaRepository {
  final requested = <String>[];

  @override
  Future<AuthorizedImage> attachmentImage(Attachment attachment) async {
    requested.add(attachment.path);
    return AuthorizedImage('http://api.test/storage/v1/object/authenticated/attachments/${attachment.path}', const {
      'Authorization': 'Bearer t',
    });
  }
}

class _Feed extends FakeFeedRepository {
  _Feed(this.posts);

  final List<Post> posts;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async => Paged(posts);

  @override
  Future<List<PinnedPost>> getPinned(FeedScope scope) async => const [];
}

(int?, int?) _cover(int width, int height, int? targetWidth, int? targetHeight) {
  final size = coverTargetSize(width, height, targetWidth: targetWidth, targetHeight: targetHeight);
  return (size.width, size.height);
}

final _loader = CommunityImageLoader(client: MockClient((request) async => http.Response('', 404)));

Future<void> _pump(WidgetTester tester, Widget child, {CommunityDependencies? deps, double dpr = 2}) async {
  tester.view.physicalSize = Size(900 * dpr, 1600 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: CommunityLocalizations.localizationsDelegates,
      supportedLocales: CommunityLocalizations.supportedLocales,
      home: Scaffold(
        body: CommunityImageScope(
          loader: _loader,
          child: CommunityScope(dependencies: deps ?? FakeDependencies(), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Iterable<CommunityImageProvider> _providers(WidgetTester tester) => [
  for (final image in tester.widgetList<Image>(find.byType(Image)))
    if (image.image is CommunityImageProvider) image.image as CommunityImageProvider,
];

void main() {
  testWidgets('attachment tiles decode at layout size times device pixel ratio with a stable key', (tester) async {
    final media = _Media();
    await _pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: AttachmentGrid(attachments: [Attachment(path: 'posts/u/a.jpg', width: 4000, height: 3000)]),
        ),
      ),
      deps: FakeDependencies(mediaRepository: media),
    );

    final provider = _providers(tester).single;
    expect(provider.cacheKey, 'storage:attachments/posts/u/a.jpg');
    expect(provider.targetWidth, 640);
    expect(provider.targetHeight, lessThanOrEqualTo(384));
    expect(provider.persist, isTrue);
  });

  testWidgets('support documents and CS chat images are never persisted to disk', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          SizedBox(
            width: 200,
            child: AttachmentGrid(
              attachments: [Attachment(path: 'rooms/r/u/a.jpg', bucket: 'cs-documents')],
            ),
          ),
          CommunityImagePersistence(
            persist: false,
            child: SizedBox(
              width: 200,
              child: AttachmentGrid(attachments: [Attachment(path: 'rooms/cs/u/b.jpg')]),
            ),
          ),
        ],
      ),
      deps: FakeDependencies(mediaRepository: _Media()),
    );

    final providers = _providers(tester).toList();
    expect(providers, hasLength(2));
    expect(providers.every((p) => !p.persist), isTrue);
  });

  testWidgets('avatars request a decode at their diameter and ignore signed URL tokens', (tester) async {
    const first = UserSummary(
      id: 'a',
      username: 'a',
      avatarUrl: 'http://api.test/storage/v1/object/sign/avatars/a.png?token=one',
    );
    const second = UserSummary(
      id: 'a',
      username: 'a',
      avatarUrl: 'http://api.test/storage/v1/object/sign/avatars/a.png?token=two',
    );
    await _pump(
      tester,
      const Row(
        children: [
          CommunityAvatar(user: first),
          CommunityAvatar(user: second, radius: 32),
        ],
      ),
    );
    final avatars = [
      for (final avatar in tester.widgetList<CircleAvatar>(find.byType(CircleAvatar)))
        avatar.foregroundImage! as CommunityImageProvider,
    ];
    expect(avatars.map((p) => p.cacheKey).toSet(), {'storage:avatars/a.png'});
    expect(avatars.map((p) => p.targetWidth), [128, 128]);
  });

  test('cover sizing keeps the aspect ratio, never upscales, and caps huge images', () {
    final size = _cover(4000, 3000, 640, 384);
    expect(size, (640, 480));
    expect(_cover(100, 100, 640, 640), (null, null));
    expect(_cover(10000, 5000, null, null), (2048, 1024));
  });

  testWidgets('a 200-post feed builds only the visible cards', (tester) async {
    final posts = [
      for (var i = 0; i < 200; i++)
        Post(id: 'p-$i', author: alice, body: 'Post $i', createdAt: now, cursor: 'p-$i', likeCount: i),
    ];
    await _pump(
      tester,
      const CommunityFeedList(scope: FeedScope.global(), emptyMessage: 'Kosong'),
      deps: FakeDependencies(feed: _Feed(posts)),
      dpr: 1,
    );
    await tester.pumpAndSettle();
    expect(find.byType(PostCard).evaluate().length, inInclusiveRange(1, 25));

    await tester.drag(find.byType(ListView), const Offset(0, -8000));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard).evaluate().length, inInclusiveRange(1, 25));
  });

  testWidgets('a 500-message room builds only the visible bubbles', (tester) async {
    final chat = FakeChatRepository(rooms: [directRoom()], members: directMembers(), messages: chatHistory(500));
    await _pump(
      tester,
      const CommunityChatRoom(roomId: 'dm'),
      deps: FakeDependencies(chat: chat),
      dpr: 1,
    );
    await tester.pumpAndSettle();
    expect(find.byType(MessageBubble).evaluate().length, inInclusiveRange(1, 40));
  });
}
