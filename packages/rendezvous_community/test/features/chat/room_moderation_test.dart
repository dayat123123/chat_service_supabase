import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/chat_extras_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart' show roomMutedError;
import 'package:rendezvous_community/src/features/chat/presentation/widgets/message_list.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';
import 'chat_extras_test.dart' show BlocProviderValue;

class _NoMedia extends Fake implements MediaRepository {}

const moderatorUser = UserSummary(id: 'u-mod', username: 'mod_room', displayName: 'Mod Room');

class _ModerationExtras extends FakeChatExtrasRepository {
  final hidden = <(String, ReportReason, String?)>[];
  final muted = <(String, String, Duration)>[];
  final escalated = <String>[];
  Object? error;
  int stateLoads = 0;

  @override
  Future<StockRoomState> stockRoomState(String stockCode) async {
    stateLoads++;
    return stockRoom;
  }

  @override
  Future<RoomModerationResult> hideMessage(String messageId, ReportReason reason, {String? note}) async {
    final failure = error;
    if (failure != null) throw failure;
    hidden.add((messageId, reason, note));
    return RoomModerationResult(id: 'a-1', action: RoomModerationAction.hide, messageId: messageId);
  }

  @override
  Future<RoomModerationResult> muteMember(
    String roomId,
    String userId,
    Duration duration,
    ReportReason reason, {
    String? note,
    String? messageId,
  }) async {
    muted.add((roomId, userId, duration));
    return RoomModerationResult(
      id: 'a-2',
      action: RoomModerationAction.mute,
      targetUserId: userId,
      muteUntil: DateTime.now().toUtc().add(duration),
    );
  }

  @override
  Future<RoomModerationResult> escalateMessage(String messageId, ReportReason reason, {String? note}) async {
    escalated.add(messageId);
    return RoomModerationResult(id: 'a-3', action: RoomModerationAction.escalate, reportId: 'rep-1');
  }
}

void main() {
  final at = DateTime.utc(2026, 11, 3, 5);
  ChatRoom stockRoom() => ChatRoom(id: 'r', type: RoomType.stock, stockCode: 'BBCA', createdAt: at, lastReadAt: at);
  ChatMessage fromAlice(String id, {DateTime? createdAt}) => ChatMessage(
    id: id,
    roomId: 'r',
    senderId: alice.id,
    sender: alice,
    body: 'Pesan $id',
    createdAt: createdAt ?? at,
  );

  group('rows', () {
    test('stock room state carries moderators and active mutes', () {
      final state = parseStockRoomState({
        'room_id': 'r',
        'moderators': ['u-mod', 7],
        'mutes': [
          {'user_id': 'u-a', 'until': '2099-01-01T00:00:00Z'},
          {'user_id': 'u-b', 'until': 'bukan tanggal'},
        ],
      });
      expect(state.moderatorIds, {'u-mod'});
      expect(state.isModerator('u-mod'), isTrue);
      expect(state.mutes.keys, ['u-a']);
      expect(state.mutedUntil('u-a'), DateTime.utc(2099));
      expect(state.mutedUntil('u-a', DateTime.utc(2100)), isNull);
    });

    test('members get only their own mute while moderators also get the mute list', () {
      final member = parseStockRoomState({
        'room_id': 'r',
        'moderators': ['u-mod'],
        'is_moderator': false,
        'muted_until': '2099-01-01T07:00:00+07:00',
      });
      expect(member.mutes, isEmpty);
      expect(member.viewerMutedUntil, DateTime.utc(2099));
      expect(member.viewerMute(), DateTime.utc(2099));
      expect(member.viewerMute(DateTime.utc(2100)), isNull);
      expect(parseStockRoomState({'room_id': 'r'}).viewerMute(), isNull);
    });

    test('mute notices come from moderation notifications that target a room', () {
      expect(
        parseRoomMuteNotice({
          'type': 'moderation',
          'payload': {'target_type': 'room', 'room_id': 'r', 'state': 'muted', 'until': '2099-01-01T00:00:00Z'},
        }),
        (roomId: 'r', mutedUntil: DateTime.utc(2099)),
      );
      expect(
        parseRoomMuteNotice({
          'type': 'moderation',
          'payload': '{"target_type": "room", "room_id": "r", "state": "unmuted", "until": null}',
        }),
        (roomId: 'r', mutedUntil: null),
      );
      expect(
        parseRoomMuteNotice({
          'type': 'moderation',
          'payload': {'target_type': 'message', 'room_id': 'r', 'state': 'hidden'},
        }),
        isNull,
      );
      expect(
        parseRoomMuteNotice({
          'type': 'mention',
          'payload': {'room_id': 'r'},
        }),
        isNull,
      );
    });

    test('repository calls the room moderator RPCs', () async {
      final api = mockApi();
      when(
        () => api.rpcValue('room_mod_hide_message', any()),
      ).thenAnswer((_) async => {'id': 'a-1', 'action': 'hide', 'message_id': 'm-1', 'target_user_id': 'u-a'});
      when(
        () => api.rpcValue('room_mod_mute_user', any()),
      ).thenAnswer((_) async => {'id': 'a-2', 'action': 'mute', 'mute_until': '2026-11-03T06:00:00Z'});
      when(
        () => api.rpcValue('room_mod_escalate', any()),
      ).thenAnswer((_) async => {'id': 'a-3', 'action': 'escalate', 'report_id': 'rep-1'});
      final repository = ChatExtrasRepositoryImpl(api);

      final hidden = await repository.hideMessage('m-1', ReportReason.spam, note: '  ');
      expect(hidden.action, RoomModerationAction.hide);
      verify(
        () => api.rpcValue('room_mod_hide_message', {'p_message_id': 'm-1', 'p_reason': 'spam', 'p_note': null}),
      ).called(1);

      final muted = await repository.muteMember(
        'r',
        'u-a',
        const Duration(hours: 1),
        ReportReason.abuse,
        note: 'Kasar',
        messageId: 'm-2',
      );
      expect(muted.muteUntil, DateTime.utc(2026, 11, 3, 6));
      verify(
        () => api.rpcValue('room_mod_mute_user', {
          'p_room_id': 'r',
          'p_user_id': 'u-a',
          'p_minutes': 60,
          'p_reason': 'abuse',
          'p_note': 'Kasar',
          'p_message_id': 'm-2',
        }),
      ).called(1);

      final escalated = await repository.escalateMessage('m-3', ReportReason.pumpAndDump);
      expect(escalated.reportId, 'rep-1');
      verify(
        () => api.rpcValue('room_mod_escalate', {'p_message_id': 'm-3', 'p_reason': 'pump_and_dump', 'p_note': null}),
      ).called(1);
    });
  });

  group('ChatRoomCubit', () {
    late FakeChatRepository chat;
    late _ModerationExtras extras;

    ChatRoomCubit build() =>
        ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'r', extras: extras);

    setUp(() => extras = _ModerationExtras());
    tearDown(() => chat.dispose());

    test('moderators hide, mute, and escalate messages from members but not from other moderators', () async {
      chat = FakeChatRepository(
        rooms: [stockRoom()],
        messages: [
          fromAlice('m-1'),
          fromAlice('m-2', createdAt: at.add(const Duration(minutes: 1))),
          ChatMessage(
            id: 'm-3',
            roomId: 'r',
            senderId: moderatorUser.id,
            sender: moderatorUser,
            body: 'x',
            createdAt: at,
          ),
        ],
      );
      extras.stockRoom = StockRoomState(roomId: 'r', moderatorIds: {me.id, moderatorUser.id});
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.isRoomModerator, isTrue);
      final other = cubit.state.messages.firstWhere((m) => m.id == 'm-3');
      expect(cubit.state.canModerate(other), isFalse);
      expect(cubit.state.canEscalate(other), isTrue);

      expect(await cubit.hideMessage(cubit.state.messages.firstWhere((m) => m.id == 'm-1'), ReportReason.spam), isTrue);
      expect(extras.hidden.single.$1, 'm-1');
      expect(cubit.state.messages.any((m) => m.id == 'm-1'), isFalse);

      final target = cubit.state.messages.firstWhere((m) => m.id == 'm-2');
      final result = await cubit.muteMember(target, const Duration(hours: 1), ReportReason.abuse);
      expect(result, isNotNull);
      expect(extras.muted.single, ('r', alice.id, const Duration(hours: 1)));
      expect(cubit.state.memberMutedUntil(alice.id), isNotNull);

      expect(await cubit.escalateMessage(target, ReportReason.scam), isTrue);
      expect(extras.escalated.single, 'm-2');

      expect(await cubit.hideMessage(other, ReportReason.spam), isFalse);
      expect(extras.hidden, hasLength(1));
      await cubit.close();
    });

    test('members without the moderator role cannot moderate', () async {
      chat = FakeChatRepository(rooms: [stockRoom()], messages: [fromAlice('m-1')]);
      extras.stockRoom = StockRoomState(roomId: 'r', moderatorIds: {moderatorUser.id});
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.isRoomModerator, isFalse);
      expect(await cubit.hideMessage(cubit.state.messages.single, ReportReason.spam), isFalse);
      expect(extras.hidden, isEmpty);
      await cubit.close();
    });

    test('realtime hides drop messages for others and flag own messages', () async {
      chat = FakeChatRepository(
        rooms: [stockRoom()],
        messages: [
          fromAlice('m-1'),
          ChatMessage(id: 'm-2', roomId: 'r', senderId: me.id, sender: me, body: 'Milik saya', createdAt: at),
        ],
      );
      extras.stockRoom = StockRoomState(roomId: 'r', pinnedMessage: fromAlice('m-1'));
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      chat.roomEvents
        ..add(const MessageHidden('m-1'))
        ..add(const MessageHidden('m-2'));
      await pumpEventQueue();
      expect(cubit.state.messages.map((m) => m.id), ['m-2']);
      expect(cubit.state.messages.single.isHidden, isTrue);
      expect(cubit.state.stockRoom!.pinnedMessage, isNull);
      await cubit.close();
    });

    test('room_muted errors and room state mutes block sending until the mute ends', () async {
      chat = FakeChatRepository(rooms: [stockRoom()]);
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      final until = DateTime.now().toUtc().add(const Duration(hours: 2));
      chat.sendError = CommunityException(
        CommunityErrorKind.forbidden,
        code: 'room_muted',
        message: until.toIso8601String(),
      );
      await cubit.send('Halo');
      expect(cubit.state.mutedUntil(), isNotNull);
      expect(cubit.state.messages.single.status, MessageStatus.failed);

      chat.sendError = null;
      await cubit.send('Lagi');
      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.actionError, roomMutedError);

      chat.roomEvents.add(const StockRoomStateChanged(StockRoomState(roomId: 'r', slowModeSeconds: 10)));
      await pumpEventQueue();
      expect(cubit.state.mutedUntil(), isNotNull);
      expect(cubit.state.stockRoom!.slowModeSeconds, 10);

      chat.roomEvents.add(const OwnRoomMuteChanged(null));
      await pumpEventQueue();
      expect(cubit.state.mutedUntil(), isNull);
      await cubit.close();
    });

    test('a personal mute notice mutes and unmutes the viewer and refreshes the room state', () async {
      chat = FakeChatRepository(rooms: [stockRoom()]);
      extras.stockRoom = const StockRoomState(roomId: 'r');
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.mutedUntil(), isNull);

      final until = DateTime.now().toUtc().add(const Duration(minutes: 30));
      extras.stockRoom = StockRoomState(roomId: 'r', viewerMutedUntil: until);
      chat.roomEvents.add(OwnRoomMuteChanged(until));
      await pumpEventQueue();
      expect(cubit.state.mutedUntil(), until);
      expect(extras.stateLoads, 2);
      await cubit.send('Halo');
      expect(cubit.state.actionError, roomMutedError);

      extras.stockRoom = const StockRoomState(roomId: 'r');
      chat.roomEvents.add(const OwnRoomMuteChanged(null));
      await pumpEventQueue();
      expect(cubit.state.mutedUntil(), isNull);
      expect(extras.stateLoads, 3);
      await cubit.close();
    });

    test('mute notices are ignored outside stock rooms', () async {
      chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'r', type: RoomType.direct, createdAt: at, lastReadAt: at)],
      );
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      chat.roomEvents.add(OwnRoomMuteChanged(DateTime.now().toUtc().add(const Duration(hours: 1))));
      await pumpEventQueue();
      expect(cubit.state.mutedUntil(), isNull);
      expect(cubit.state.stockRoom, isNull);
      await cubit.close();
    });

    test('shared room state broadcasts never carry or clear the mute list', () async {
      chat = FakeChatRepository(rooms: [stockRoom()]);
      final muted = DateTime.now().toUtc().add(const Duration(hours: 1));
      extras.stockRoom = StockRoomState(roomId: 'r', moderatorIds: {me.id}, mutes: {alice.id: muted});
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.memberMutedUntil(alice.id), muted);

      chat.roomEvents.add(StockRoomStateChanged(StockRoomState(roomId: 'r', moderatorIds: {me.id})));
      await pumpEventQueue();
      expect(cubit.state.memberMutedUntil(alice.id), muted);

      chat.roomEvents.add(StockRoomStateChanged(StockRoomState(roomId: 'r', moderatorIds: {moderatorUser.id})));
      await pumpEventQueue();
      expect(cubit.state.isRoomModerator, isFalse);
      expect(cubit.state.stockRoom!.mutes, isEmpty);
      await cubit.close();
    });

    test('a member promoted to moderator fetches the mute list', () async {
      chat = FakeChatRepository(rooms: [stockRoom()]);
      extras.stockRoom = const StockRoomState(roomId: 'r');
      final cubit = build();
      await cubit.load();
      await pumpEventQueue();
      expect(extras.stateLoads, 1);

      final muted = DateTime.now().toUtc().add(const Duration(hours: 1));
      extras.stockRoom = StockRoomState(roomId: 'r', moderatorIds: {me.id}, mutes: {alice.id: muted});
      chat.roomEvents.add(StockRoomStateChanged(StockRoomState(roomId: 'r', moderatorIds: {me.id})));
      await pumpEventQueue();
      expect(extras.stateLoads, 2);
      expect(cubit.state.isRoomModerator, isTrue);
      expect(cubit.state.memberMutedUntil(alice.id), muted);
      await cubit.close();
    });
  });

  group('widgets', () {
    Future<void> pumpRoom(
      WidgetTester tester,
      List<ChatMessage> messages,
      StockRoomState stock,
      FakeFeatureDependencies features,
      _ModerationExtras extras,
    ) async {
      final chat = FakeChatRepository(rooms: [stockRoom()], messages: messages);
      addTearDown(chat.dispose);
      extras.stockRoom = stock;
      final cubit = ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'r', extras: extras);
      addTearDown(cubit.close);
      await tester.runAsync(() async {
        await cubit.load();
        await pumpEventQueue();
      });
      await pumpFeatureApp(
        tester,
        BlocProviderValue(
          cubit: cubit,
          child: const Column(
            children: [
              RoomModerationBanner(),
              Expanded(child: MessageList()),
            ],
          ),
        ),
        dependencies: FakeDependencies(chat: chat),
        features: features,
      );
      await tester.pump();
    }

    testWidgets('moderators see the badge, the notice, and long-press moderation actions', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      final extras = _ModerationExtras();
      final now = DateTime.now().toUtc();
      await pumpRoom(
        tester,
        [
          fromAlice('m-1', createdAt: now),
          ChatMessage(
            id: 'm-2',
            roomId: 'r',
            senderId: moderatorUser.id,
            sender: moderatorUser,
            body: 'Pesan moderator',
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
        ],
        StockRoomState(roomId: 'r', moderatorIds: {me.id, moderatorUser.id}),
        features,
        extras,
      );
      expect(find.text('Moderator'), findsOneWidget);
      expect(find.textContaining('Anda moderator room ini'), findsOneWidget);

      await tester.longPress(find.text('Pesan m-1'));
      await tester.pumpAndSettle();
      expect(find.text('Sembunyikan pesan'), findsOneWidget);
      expect(find.text('Bisukan anggota'), findsOneWidget);
      expect(find.text('Eskalasi ke staf'), findsOneWidget);
      await tester.tap(find.text('Sembunyikan pesan'));
      await tester.pumpAndSettle();
      expect(find.text('Sembunyikan pesan ini?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sembunyikan pesan'));
      await tester.pumpAndSettle();
      expect(extras.hidden.single.$1, 'm-1');
      expect(find.text('Pesan m-1'), findsNothing);
      expect(find.text('Pesan disembunyikan'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(MessageList))).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Pesan moderator'));
      await tester.pumpAndSettle();
      expect(find.text('Sembunyikan pesan'), findsNothing);
      expect(find.text('Eskalasi ke staf'), findsOneWidget);
    });

    testWidgets('members see no moderation actions and a banner while muted', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      final extras = _ModerationExtras();
      final now = DateTime.now().toUtc();
      await pumpRoom(
        tester,
        [fromAlice('m-1', createdAt: now)],
        StockRoomState(
          roomId: 'r',
          moderatorIds: {moderatorUser.id},
          viewerMutedUntil: now.add(const Duration(hours: 1)),
        ),
        features,
        extras,
      );
      expect(find.textContaining('Moderator membisukan Anda'), findsOneWidget);
      await tester.longPress(find.text('Pesan m-1'));
      await tester.pumpAndSettle();
      expect(find.text('Sembunyikan pesan'), findsNothing);
      expect(find.text('Laporkan'), findsOneWidget);
    });
  });
}
