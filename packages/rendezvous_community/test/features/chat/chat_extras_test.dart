import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/chat_extras_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/message_list.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

class _NoMedia extends Fake implements MediaRepository {}

void main() {
  group('rows', () {
    test('get_messages rows map reactions, shared posts, and moderation; post attachments are not images', () {
      final message = ChatMessageModel.fromJson({
        ...messageRow('m-1'),
        'attachments': [
          {'type': 'post', 'post_id': 'p-9'},
          {'path': 'rooms/r-1/u-2/a.jpg', 'mime': 'image/jpeg'},
        ],
        'reactions': [
          {'emoji': '👍', 'count': 2, 'me': true},
        ],
        'shared_post': {
          'post_id': 'p-9',
          'available': true,
          'author_id': 'u-1',
          'author_username': 'budi_santoso',
          'body': r'Analisis $BBCA',
          'attachments': <Object?>[],
          'sentiment': 'bullish',
          'stock_codes': ['BBCA'],
          'like_count': 3,
          'comment_count': 1,
          'created_at': '2026-11-03T05:00:00Z',
        },
        'moderation_status': 'held',
      }).toEntity();
      expect(message.attachments.single.path, 'rooms/r-1/u-2/a.jpg');
      expect(message.sharedPostId, 'p-9');
      expect(message.sharedPost!.author!.username, 'budi_santoso');
      expect(message.sharedPost!.sentiment, Sentiment.bullish);
      expect(message.reactions.single, const MessageReaction(emoji: '👍', count: 2, mine: true));
      expect(message.isHeld, isTrue);
    });

    test('realtime rows keep the shared post id and unavailable posts stay unavailable', () {
      final row = MessageRowModel.fromJson({
        'id': 'm-2',
        'room_id': 'r-1',
        'sender_id': 'u-2',
        'body': '',
        'attachments': [
          {'type': 'post', 'post_id': 'p-7'},
        ],
        'created_at': '2026-11-03T05:00:00Z',
      }).toEntity();
      expect(row.sharedPostId, 'p-7');
      expect(row.attachments, isEmpty);
      final gone = ChatMessageModel.fromJson({
        ...messageRow('m-3'),
        'shared_post': {'post_id': 'p-7', 'available': false},
      }).toEntity();
      expect(gone.sharedPost!.available, isFalse);
    });

    test('applyReaction swaps the caller reaction and recounts', () {
      const start = [MessageReaction(emoji: '👍', count: 2, mine: true), MessageReaction(emoji: '🔥', count: 1)];
      expect(applyReaction(start, '👍', '🔥'), const [
        MessageReaction(emoji: '👍', count: 1),
        MessageReaction(emoji: '🔥', count: 2, mine: true),
      ]);
      expect(applyReaction(start, '👍', null), const [
        MessageReaction(emoji: '👍', count: 1),
        MessageReaction(emoji: '🔥', count: 1),
      ]);
      expect(applyReaction(const [], null, '😂'), const [MessageReaction(emoji: '😂', count: 1, mine: true)]);
    });
  });

  group('ChatExtrasRepositoryImpl', () {
    test('react, share, and stock room state call the RPCs with the documented parameters', () async {
      final api = mockApi();
      when(() => api.rpcValue('react_to_message', any())).thenAnswer(
        (_) async => {
          'message_id': 'm-1',
          'emoji': '🔥',
          'reactions': [
            {'emoji': '🔥', 'count': 1, 'me': true},
          ],
        },
      );
      when(() => api.rpcRows('share_post_to_chat', any())).thenAnswer(
        (_) async => [
          {
            ...messageRow('m-9'),
            'shared_post': {'post_id': 'p-1', 'available': true},
          },
        ],
      );
      when(() => api.rpcValue('get_stock_room_state', any())).thenAnswer(
        (_) async => {
          'stock_code': 'BBCA',
          'room_id': 'r-s',
          'slow_mode': {'seconds': 10, 'until': null, 'source': 'schedule'},
          'wait_seconds': 4,
          'pinned_message': messageRow('m-p'),
          'pinned_at': '2026-11-03T05:00:00Z',
        },
      );
      final repository = ChatExtrasRepositoryImpl(api);

      expect((await repository.react('m-1', '🔥')).single.mine, isTrue);
      verify(() => api.rpcValue('react_to_message', {'p_message_id': 'm-1', 'p_emoji': '🔥'})).called(1);

      final shared = await repository.sharePost('r-1', 'p-1', body: '  ', clientId: 'c-1');
      expect(shared.sharedPostId, 'p-1');
      verify(
        () => api.rpcRows('share_post_to_chat', {
          'p_room_id': 'r-1',
          'p_post_id': 'p-1',
          'p_body': null,
          'p_client_id': 'c-1',
        }),
      ).called(1);

      final state = await repository.stockRoomState('bbca');
      verify(() => api.rpcValue('get_stock_room_state', {'p_code': 'BBCA'})).called(1);
      expect(state.slowModeSeconds, 10);
      expect(state.slowModeActive(), isTrue);
      expect(state.waitSeconds, 4);
      expect(state.pinnedMessage!.id, 'm-p');
    });
  });

  group('ChatRoomCubit', () {
    late FakeChatRepository chat;
    late FakeChatExtrasRepository extras;
    final at = DateTime.utc(2026, 11, 3, 5);

    ChatRoomCubit build({RoomType type = RoomType.direct, DateTime Function()? clock}) =>
        ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'r', extras: extras, clock: clock);

    setUp(() {
      extras = FakeChatExtrasRepository();
    });

    tearDown(() => chat.dispose());

    test('reactions are optimistic and follow realtime counts from other members', () async {
      chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'r', type: RoomType.direct, createdAt: at, lastReadAt: at, otherUser: alice)],
        messages: [ChatMessage(id: 'm-1', roomId: 'r', senderId: alice.id, sender: alice, body: 'Hai', createdAt: at)],
      );
      final cubit = build();
      await cubit.load();
      await cubit.react(cubit.state.messages.single, '👍');
      expect(cubit.state.messages.single.reactions.single.mine, isTrue);
      expect(extras.reactions.single, ('m-1', '👍'));

      chat.roomEvents.add(
        const ReactionChanged(
          messageId: 'm-1',
          userId: 'u-a',
          emoji: '👍',
          counts: [MessageReaction(emoji: '👍', count: 2)],
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.messages.single.reactions.single, const MessageReaction(emoji: '👍', count: 2, mine: true));

      await cubit.react(cubit.state.messages.single, '👍');
      expect(extras.reactions.last, ('m-1', null));
      await cubit.close();
    });

    test('support rooms never react', () async {
      chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'r', type: RoomType.support, createdAt: at, lastReadAt: at)],
        messages: [ChatMessage(id: 'm-1', roomId: 'r', senderId: alice.id, body: 'Hai', createdAt: at)],
      );
      final cubit = build();
      await cubit.load();
      await cubit.react(cubit.state.messages.single, '👍');
      expect(extras.reactions, isEmpty);
      await cubit.close();
    });

    test('stock rooms load slow mode, start a cooldown after sending, and honour slow_mode errors', () async {
      var now = DateTime.utc(2026, 11, 3, 5);
      chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'r', type: RoomType.stock, stockCode: 'BBCA', createdAt: at, lastReadAt: at)],
      );
      extras.stockRoom = const StockRoomState(roomId: 'r', slowModeSeconds: 10, waitSeconds: 3);
      final cubit = build(clock: () => now);
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.stockRoom!.slowModeSeconds, 10);
      expect(cubit.state.cooldownLeft(now), const Duration(seconds: 3));

      now = now.add(const Duration(seconds: 5));
      await cubit.send('Halo');
      expect(cubit.state.cooldownLeft(now), const Duration(seconds: 10));

      chat.sendError = const CommunityException(
        CommunityErrorKind.rateLimited,
        code: 'slow_mode',
        retryAfter: Duration(seconds: 7),
      );
      now = now.add(const Duration(seconds: 20));
      await cubit.send('Lagi');
      expect(cubit.state.cooldownLeft(now), const Duration(seconds: 7));
      expect(cubit.state.messages.first.status, MessageStatus.failed);

      chat.roomEvents.add(const StockRoomStateChanged(StockRoomState(roomId: 'r', slowModeSeconds: 30)));
      await pumpEventQueue();
      expect(cubit.state.stockRoom!.slowModeSeconds, 30);
      await cubit.close();
    });

    test('dm_request_limit marks the room so the sender sees the request notice', () async {
      chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'r', type: RoomType.direct, createdAt: at, lastReadAt: at, otherUser: alice)],
      )..sendError = const CommunityException(CommunityErrorKind.forbidden, code: 'dm_request_limit');
      final cubit = build();
      await cubit.load();
      await cubit.send('Halo ke-4');
      expect(cubit.state.dmRequestLimited, isTrue);
      await cubit.close();
    });

    test('realtime upserts keep reactions, the shared post, and held image flags', () async {
      chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'r', type: RoomType.direct, createdAt: at, lastReadAt: at, otherUser: alice)],
        messages: [
          ChatMessage(
            id: 'm-1',
            roomId: 'r',
            senderId: me.id,
            sender: me,
            body: 'x',
            createdAt: at,
            attachments: const [Attachment(path: 'a.jpg', held: true)],
            reactions: const [MessageReaction(emoji: '🔥', count: 1)],
            sharedPostId: 'p-1',
            sharedPost: const SharedPost(postId: 'p-1'),
          ),
        ],
      );
      final cubit = build();
      await cubit.load();
      chat.roomEvents.add(
        MessageUpserted(
          ChatMessage(
            id: 'm-1',
            roomId: 'r',
            senderId: me.id,
            body: 'x',
            createdAt: at,
            attachments: const [Attachment(path: 'a.jpg')],
            sharedPostId: 'p-1',
          ),
        ),
      );
      await pumpEventQueue();
      final m = cubit.state.messages.single;
      expect(m.reactions.single.emoji, '🔥');
      expect(m.sharedPost, isNotNull);
      expect(m.attachments.single.held, isTrue);
      await cubit.close();
    });
  });

  group('message bubble', () {
    Future<ChatRoomCubit> pumpRoom(
      WidgetTester tester,
      List<ChatMessage> messages,
      FakeFeatureDependencies features,
    ) async {
      final chat = FakeChatRepository(
        rooms: [
          ChatRoom(
            id: 'r',
            type: RoomType.direct,
            createdAt: DateTime.utc(2026),
            lastReadAt: DateTime.utc(2026),
            otherUser: alice,
          ),
        ],
        messages: messages,
      );
      addTearDown(chat.dispose);
      final cubit = ChatRoomCubit(
        chat: chat,
        media: _NoMedia(),
        me: () async => me,
        roomId: 'r',
        extras: features.chatExtras,
        gapFillInterval: Duration.zero,
      );
      await cubit.load();
      addTearDown(cubit.close);
      await pumpFeatureApp(
        tester,
        BlocProviderValue(cubit: cubit, child: const MessageList()),
        dependencies: FakeDependencies(chat: chat),
        features: features,
      );
      await tester.pump();
      return cubit;
    }

    testWidgets('shows reaction chips, the shared post card, and the held label on own messages', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      final now = DateTime.now().toUtc();
      await pumpRoom(tester, [
        ChatMessage(
          id: 'm-2',
          roomId: 'r',
          senderId: me.id,
          sender: me,
          body: 'Lihat',
          createdAt: now,
          sharedPostId: 'p-1',
          sharedPost: const SharedPost(postId: 'p-1', available: false),
          moderationStatus: ModerationStatus.held,
        ),
        ChatMessage(
          id: 'm-1',
          roomId: 'r',
          senderId: alice.id,
          sender: alice,
          body: 'Halo',
          createdAt: now.subtract(const Duration(minutes: 1)),
          reactions: const [MessageReaction(emoji: '🔥', count: 3, mine: true)],
        ),
      ], features);
      expect(find.text('🔥 3'), findsOneWidget);
      expect(find.text('Post tidak tersedia'), findsOneWidget);
      expect(find.text('Menunggu tinjauan'), findsOneWidget);

      await tester.tap(find.text('🔥 3'));
      await tester.pump(const Duration(seconds: 1));
      expect(features.chatExtras.reactions.single, ('m-1', null));
    });

    testWidgets('long press offers the six reactions', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpRoom(tester, [
        ChatMessage(
          id: 'm-1',
          roomId: 'r',
          senderId: alice.id,
          sender: alice,
          body: 'Halo',
          createdAt: DateTime.now().toUtc(),
        ),
      ], features);
      await tester.longPress(find.text('Halo'));
      await tester.pumpAndSettle();
      for (final emoji in const ClientConfig().messageReactions) {
        expect(find.text(emoji), findsOneWidget);
      }
      await tester.tap(find.text('😂'));
      await tester.pumpAndSettle();
      expect(features.chatExtras.reactions.single, ('m-1', '😂'));
    });

    testWidgets('no reactions when the flag is off', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig(flags: {'message_reactions': false}));
      addTearDown(features.dispose);
      await pumpRoom(tester, [
        ChatMessage(
          id: 'm-1',
          roomId: 'r',
          senderId: alice.id,
          sender: alice,
          body: 'Halo',
          createdAt: DateTime.now().toUtc(),
        ),
      ], features);
      await tester.longPress(find.text('Halo'));
      await tester.pumpAndSettle();
      expect(find.text('😂'), findsNothing);
    });
  });
}

class BlocProviderValue extends StatelessWidget {
  const BlocProviderValue({super.key, required this.cubit, required this.child});

  final ChatRoomCubit cubit;
  final Widget child;

  @override
  Widget build(BuildContext context) => BlocProvider<ChatRoomCubit>.value(value: cubit, child: child);
}
