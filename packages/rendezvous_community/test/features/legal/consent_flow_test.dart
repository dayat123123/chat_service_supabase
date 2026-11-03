import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/compose/presentation/cubit/compose_cubit.dart';
import 'package:rendezvous_community/src/features/post/presentation/cubit/comment_thread_cubit.dart';

import '../../support/fakes.dart';
import '../../support/legal_fakes.dart';

class _Feed extends FakeFeedRepository {
  final createdClientIds = <String?>[];
  int consentFailures = 0;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async => const Paged([]);

  @override
  Future<List<PinnedPost>> getPinned(FeedScope scope) async => const [];

  @override
  Future<Post> createPost({
    required String body,
    Sentiment? sentiment,
    List<Attachment> attachments = const [],
    PollDraft? poll,
    String? clientId,
  }) async {
    createdClientIds.add(clientId);
    if (consentFailures > 0) {
      consentFailures--;
      throw consentRequired;
    }
    return Post(id: 'p-new', author: me, body: body, attachments: attachments, createdAt: now, cursor: 'c');
  }
}

class _Comments extends FakeCommentRepository {
  int calls = 0;
  int consentFailures = 1;

  @override
  Future<ThreadComment> createComment({required String postId, String? parentId, required String body}) async {
    calls++;
    if (consentFailures > 0) {
      consentFailures--;
      throw consentRequired;
    }
    return comment('new', depth: 0, path: '000000000099', body: body, author: me);
  }
}

class _Chat extends FakeChatRepository {
  _Chat({required super.rooms, required super.members});

  int calls = 0;
  int consentFailures = 1;

  @override
  Future<ChatMessage> sendMessage(
    String roomId, {
    required String body,
    required String clientId,
    String? replyToId,
    List<Attachment> attachments = const [],
  }) async {
    calls++;
    if (consentFailures > 0) {
      consentFailures--;
      throw consentRequired;
    }
    return super.sendMessage(roomId, body: body, clientId: clientId, replyToId: replyToId, attachments: attachments);
  }
}

class _NoMedia extends Fake implements MediaRepository {}

ConsentGate _gate(List<bool> answers, {List<int>? asked}) => ConsentGate(() async {
  asked?.add(1);
  return answers.removeAt(0);
});

void main() {
  group('the consent gate in the cubits', () {
    test('a post waits for consent, then is retried once with the same draft id', () async {
      final feed = _Feed()..consentFailures = 1;
      final asked = <int>[];
      final cubit = ComposeCubit(
        feed: feed,
        media: _NoMedia(),
        consent: _gate([true], asked: asked),
      );
      addTearDown(cubit.close);

      final post = await cubit.submit('Analisis BBCA');

      expect(post?.id, 'p-new');
      expect(asked, hasLength(1));
      expect(feed.createdClientIds, hasLength(2));
      expect(feed.createdClientIds.toSet(), hasLength(1));
    });

    test('a declined consent keeps the draft and reports a short message', () async {
      final feed = _Feed()..consentFailures = 1;
      final cubit = ComposeCubit(feed: feed, media: _NoMedia(), consent: _gate([false]));
      addTearDown(cubit.close);
      cubit.setSentiment(Sentiment.bullish);

      final post = await cubit.submit('Analisis BBCA');

      expect(post, isNull);
      expect(feed.createdClientIds, hasLength(1));
      expect(cubit.state.sentiment, Sentiment.bullish);
      expect(cubit.state.submitting, isFalse);
      expect((cubit.state.error! as CommunityException).code, 'consent_declined');
    });

    test('comments are retried after consent', () async {
      final comments = _Comments();
      final cubit = CommentThreadCubit(
        feed: FakeFeedRepository(),
        comments: comments,
        postId: 'p-1',
        consent: _gate([true]),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(await cubit.send('Setuju'), isTrue);
      expect(comments.calls, 2);
      expect(cubit.state.comments['new']?.body, 'Setuju');
    });

    group('chat messages', () {
      final start = DateTime.utc(2026, 11, 3, 1);
      final members = [
        RoomMember(user: me, lastReadAt: start, lastDeliveredAt: start, joinedAt: start),
        RoomMember(user: alice, lastReadAt: start, lastDeliveredAt: start, joinedAt: start),
      ];

      Future<(ChatRoomCubit, _Chat)> room(RoomType type, ConsentGate gate) async {
        final chat = _Chat(
          rooms: [ChatRoom(id: 'r', type: type, createdAt: start, lastReadAt: start, otherUser: alice)],
          members: members,
        );
        final cubit = ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'r', consent: gate);
        addTearDown(() async {
          await cubit.close();
          await chat.dispose();
        });
        await cubit.load();
        return (cubit, chat);
      }

      test('are delivered after consent', () async {
        final (cubit, chat) = await room(RoomType.direct, _gate([true]));

        await cubit.send('Halo');

        expect(chat.calls, 2);
        expect(cubit.state.messages.single.status, MessageStatus.sent);
        expect(cubit.state.messages.single.isLocal, isFalse);
      });

      test('stay as a failed draft when consent is declined', () async {
        final (cubit, chat) = await room(RoomType.direct, _gate([false]));

        await cubit.send('Halo');

        expect(chat.calls, 1);
        expect(cubit.state.messages.single.status, MessageStatus.failed);
        expect(cubit.state.messages.single.body, 'Halo');
        expect((cubit.state.actionError! as CommunityException).code, 'consent_declined');
      });

      test('in the support room never open the consent flow', () async {
        final asked = <int>[];
        final (cubit, chat) = await room(RoomType.support, _gate([true], asked: asked));

        await cubit.send('Halo CS');

        expect(asked, isEmpty);
        expect(chat.calls, 1);
      });
    });
  });

  group('showCommunityConsent', () {
    late FakeLegalRepository legal;
    late FakeAccount account;

    setUp(() {
      legal = FakeLegalRepository([updatedTerms, updatedGuidelines, privacyPolicy]);
      account = FakeAccount(legal);
    });

    Future<List<bool>> pumpLauncher(WidgetTester tester) async {
      final results = <bool>[];
      await pumpCommunity(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await showCommunityConsent(context)),
            child: const Text('Buka persetujuan'),
          ),
        ),
        account: account,
      );
      await tester.tap(find.text('Buka persetujuan'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('lists the pending documents and accepts all of them', (tester) async {
      final results = await pumpLauncher(tester);

      expect(find.text('Persetujuan diperlukan'), findsOneWidget);
      expect(find.text('Syarat & Ketentuan'), findsOneWidget);
      expect(find.text('Pedoman Komunitas'), findsOneWidget);
      expect(find.text('Kebijakan Privasi'), findsNothing);
      expect(find.text('Versi 3 · berlaku 1 November 2026'), findsOneWidget);

      FilledButton accept() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Setuju'));
      expect(accept().onPressed, isNull);

      await tester.tap(find.text('Saya telah membaca dan menyetujui Syarat & Ketentuan dan Pedoman Komunitas.'));
      await tester.pump();
      expect(accept().onPressed, isNotNull);

      await tester.tap(find.text('Setuju'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(legal.accepted, ['d-terms', 'd-guide']);
      expect(account.consent.pendingNow, isEmpty);
      expect(find.text('Persetujuan diperlukan'), findsNothing);
    });

    testWidgets('each document opens in full with its version and changes', (tester) async {
      await pumpLauncher(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Baca').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Syarat & Ketentuan'), findsOneWidget);
      expect(find.text('Versi 3 · berlaku 1 November 2026'), findsWidgets);
      expect(find.text('Yang berubah'), findsOneWidget);
      expect(find.text('Pasal 4 tentang larangan ajakan goreng saham diperjelas.'), findsOneWidget);
      final body = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(body.data, 'Pasal 1\nIsi pasal satu.\n\nPasal 2\nIsi pasal dua.');

      Navigator.of(tester.element(find.byType(CommunityLegalDocumentReader))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Persetujuan diperlukan'), findsOneWidget);
    });

    testWidgets('"Nanti" closes the flow without accepting', (tester) async {
      final results = await pumpLauncher(tester);

      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();

      expect(results, [false]);
      expect(legal.accepted, isEmpty);
    });

    testWidgets('uses a dialog on wide screens', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final results = await pumpLauncher(tester);

      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Persetujuan diperlukan')), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Setuju'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('closes right away when nothing is pending', (tester) async {
      legal.documents = [privacyPolicy];
      final results = await pumpLauncher(tester);

      expect(results, [true]);
      expect(find.text('Persetujuan diperlukan'), findsNothing);
    });
  });

  group('posting from the composer', () {
    testWidgets('opens the consent flow and sends the post after acceptance', (tester) async {
      final feed = _Feed()..consentFailures = 1;
      final legal = FakeLegalRepository([updatedGuidelines]);
      await pumpCommunity(
        tester,
        const CommunityComposePost(),
        account: FakeAccount(legal),
        dependencies: FakeDependencies(feed: feed),
      );

      await tester.enterText(find.byType(TextField), r'$BBCA lanjut naik');
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(find.text('Persetujuan diperlukan'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Setuju'));
      await tester.pumpAndSettle();

      expect(legal.accepted, ['d-guide']);
      expect(feed.createdClientIds, hasLength(2));
      expect(find.text('Post terkirim'), findsOneWidget);
    });

    testWidgets('keeps the draft when the user declines', (tester) async {
      final feed = _Feed()..consentFailures = 1;
      await pumpCommunity(
        tester,
        const CommunityComposePost(),
        account: FakeAccount(FakeLegalRepository([updatedGuidelines])),
        dependencies: FakeDependencies(feed: feed),
      );

      await tester.enterText(find.byType(TextField), r'$BBCA lanjut naik');
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();

      expect(feed.createdClientIds, hasLength(1));
      expect(find.text(r'$BBCA lanjut naik'), findsOneWidget);
      expect(
        find.text('Belum terkirim. Setujui dokumen terbaru untuk mengirim; tulisan Anda tetap tersimpan.'),
        findsOneWidget,
      );
    });
  });

  group('CommunityConsentBanner in the feed', () {
    Future<FakeLegalRepository> pumpFeed(WidgetTester tester, List<LegalDocument> documents) async {
      final legal = FakeLegalRepository(documents);
      await pumpCommunity(
        tester,
        const CommunityFeedList(scope: FeedScope.global(), emptyMessage: 'Belum ada post'),
        account: FakeAccount(legal),
        dependencies: FakeDependencies(feed: _Feed()),
      );
      return legal;
    }

    const updatedText = 'Pedoman Komunitas diperbarui — tinjau dan setujui.';

    testWidgets('shows pending documents and hides after dismissing', (tester) async {
      final legal = await pumpFeed(tester, [updatedGuidelines]);

      expect(find.text(updatedText), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text(updatedText), findsOneWidget);
      expect(legal.loads, 1);

      await tester.tap(find.byTooltip('Tutup'));
      await tester.pump();
      expect(find.text(updatedText), findsNothing);
    });

    testWidgets('first-time documents ask for review instead of announcing an update', (tester) async {
      await pumpFeed(tester, [legalDocument('d-1'), privacyPolicy]);

      expect(find.text('Tinjau dan setujui Syarat & Ketentuan untuk ikut berdiskusi.'), findsOneWidget);
    });

    testWidgets('stays hidden when everything is accepted', (tester) async {
      await pumpFeed(tester, [updatedGuidelines.copyWith(isAccepted: true), privacyPolicy]);

      expect(find.byType(CommunityConsentBanner), findsOneWidget);
      expect(find.textContaining('setujui'), findsNothing);
    });

    testWidgets('"Tinjau" opens the consent flow and the banner disappears after accepting', (tester) async {
      final legal = await pumpFeed(tester, [updatedGuidelines]);

      await tester.tap(find.text('Tinjau'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Setuju'));
      await tester.pumpAndSettle();

      expect(legal.accepted, ['d-guide']);
      expect(find.text(updatedText), findsNothing);
      expect(find.text('Terima kasih. Persetujuan Anda sudah tersimpan.'), findsOneWidget);
    });
  });
}
