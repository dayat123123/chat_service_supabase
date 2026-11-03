import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/appeals/data/repositories/appeal_repository_impl.dart';
import 'package:rendezvous_community/src/features/message_requests/data/repositories/message_request_repository_impl.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

class _NoMedia extends Fake implements MediaRepository {}

void main() {
  group('get_dm_request_state', () {
    test('maps sender, recipient, declined, and plain rooms', () async {
      final api = mockApi();
      final answers = <Object?>[
        {'is_request': true, 'role': 'sender', 'status': 'pending', 'sent': 2, 'max_messages': 3},
        {'is_request': true, 'role': 'recipient', 'status': 'declined'},
        {'is_request': false},
      ];
      when(() => api.rpcValue('get_dm_request_state', any())).thenAnswer((_) async => answers.removeAt(0));
      final repository = MessageRequestRepositoryImpl(api);

      final sender = await repository.requestState('r-1');
      verify(() => api.rpcValue('get_dm_request_state', {'p_room_id': 'r-1'})).called(1);
      expect(sender.pendingAsSender, isTrue);
      expect((sender.sent, sender.maxMessages, sender.limitReached), (2, 3, false));
      final recipient = await repository.requestState('r-1');
      expect(recipient.role, DmRequestRole.recipient);
      expect(recipient.declined, isTrue);
      expect(recipient.pendingAsRecipient, isFalse);
      expect((await repository.requestState('r-1')).isRequest, isFalse);
    });

    test('the room cubit counts sent requests up to the limit', () async {
      final at = DateTime.utc(2026, 11, 3);
      final chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'dm', type: RoomType.direct, createdAt: at, lastReadAt: at, otherUser: alice)],
      );
      addTearDown(chat.dispose);
      final requests = FakeMessageRequestRepository()
        ..state = const DmRequestState(isRequest: true, role: DmRequestRole.sender, sent: 1, maxMessages: 3);
      final cubit = ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'dm', requests: requests);
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.dmRequest!.sent, 1);
      await cubit.send('dua');
      await cubit.send('tiga');
      expect(cubit.state.dmRequest!.sent, 3);
      expect(cubit.state.dmRequest!.limitReached, isTrue);
      expect(cubit.state.dmRequestLimited, isTrue);
      await cubit.close();
    });

    Future<FakeMessageRequestRepository> pumpRoom(WidgetTester tester, DmRequestState state) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      features.messageRequests.state = state;
      final chat = FakeChatRepository(
        rooms: [ChatRoom(id: 'dm', type: RoomType.direct, createdAt: now, lastReadAt: now, otherUser: alice)],
      );
      addTearDown(chat.dispose);
      await pumpFeatureApp(
        tester,
        const CommunityChatRoom(roomId: 'dm'),
        dependencies: FakeDependencies(chat: chat),
        features: features,
      );
      await tester.pumpAndSettle();
      return features.messageRequests;
    }

    testWidgets('the sender sees a firm request state with the count', (tester) async {
      await pumpRoom(
        tester,
        const DmRequestState(isRequest: true, role: DmRequestRole.sender, sent: 1, maxMessages: 3),
      );
      expect(
        find.text(
          'Pesan Anda masih berupa permintaan (1/3). Alice perlu menerimanya sebelum Anda bisa mengirim lebih banyak.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the recipient can accept from the room', (tester) async {
      final requests = await pumpRoom(tester, const DmRequestState(isRequest: true, role: DmRequestRole.recipient));
      expect(find.text('Alice mengirim permintaan pesan. Terima untuk membalas.'), findsOneWidget);
      await tester.tap(find.text('Terima'));
      await tester.pumpAndSettle();
      expect(requests.responses.single, ('dm', MessageRequestAction.accept));
      expect(find.textContaining('permintaan pesan'), findsNothing);
    });

    testWidgets('accepted rooms show no request hint', (tester) async {
      await pumpRoom(tester, const DmRequestState());
      expect(find.textContaining('permintaan'), findsNothing);
    });
  });

  group('get_my_moderated_content', () {
    test('maps hidden and removed items with their latest appeal', () async {
      final api = mockApi();
      when(() => api.rpcValue('get_my_moderated_content', any())).thenAnswer(
        (_) async => [
          {
            'type': 'comment',
            'id': 'c-1',
            'state': 'removed',
            'excerpt': 'Komentar lama',
            'decided_at': '2026-11-02T05:00:00Z',
            'appeal': {
              'id': 'a-1',
              'status': 'rejected',
              'created_at': '2026-11-02T06:00:00Z',
              'decided_at': '2026-11-02T07:00:00Z',
              'decision_note': 'Tetap',
            },
          },
          {'type': 'post', 'id': 'p-1', 'state': 'hidden', 'excerpt': 'Post', 'decided_at': null, 'appeal': null},
        ],
      );
      final items = await AppealRepositoryImpl(api).myModeratedContent(limit: 20);
      verify(() => api.rpcValue('get_my_moderated_content', {'p_limit': 20})).called(1);
      expect(items.first.state, ModeratedState.removed);
      expect(items.first.appeal!.status, AppealStatus.rejected);
      expect(items.first.appeal!.targetType, AppealTargetType.comment);
      expect(items.first.appeal!.targetId, 'c-1');
      expect(items.last.type, AppealTargetType.post);
      expect(items.last.appeal, isNull);
    });

    testWidgets('the appeals screen lists moderated content and appeals removed items', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      features.appeals.moderated = [
        ModeratedContent(
          type: AppealTargetType.message,
          id: 'm-1',
          state: ModeratedState.removed,
          excerpt: 'Pesan saya',
          decidedAt: DateTime.utc(2026, 11, 2),
        ),
        ModeratedContent(
          type: AppealTargetType.post,
          id: 'p-1',
          state: ModeratedState.hidden,
          appeal: Appeal(
            id: 'a-1',
            targetType: AppealTargetType.post,
            targetId: 'p-1',
            createdAt: DateTime.utc(2026, 11, 2),
          ),
        ),
      ];
      await pumpFeatureApp(tester, const CommunityAppeals(), features: features);
      await tester.pumpAndSettle();
      expect(find.text('Konten yang dimoderasi'), findsOneWidget);
      expect(find.text('Pesan · Dihapus moderator'), findsOneWidget);
      expect(find.text('Post · Disembunyikan moderator'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Ajukan banding'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Ajukan banding'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pesan ini tidak melanggar aturan.');
      await tester.pump();
      await tester.tap(find.text('Kirim banding'));
      await tester.pumpAndSettle();
      expect(features.appeals.created.single.$1, AppealTargetType.message);
      expect(features.appeals.created.single.$2, 'm-1');
    });
  });

  group('desktop platforms', () {
    test('the default platform covers Windows, macOS, and Linux', () {
      final expected = {
        TargetPlatform.windows: CommunityPlatform.windows,
        TargetPlatform.macOS: CommunityPlatform.macos,
        TargetPlatform.linux: CommunityPlatform.linux,
        TargetPlatform.android: CommunityPlatform.android,
        TargetPlatform.iOS: CommunityPlatform.ios,
      };
      try {
        expected.forEach((platform, value) {
          debugDefaultTargetPlatformOverride = platform;
          expect(defaultCommunityPlatform(), value);
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('the platform name reaches get_client_config', () async {
      final community = RendezvousCommunity.create(
        supabaseUrl: 'http://api.test',
        anonKey: 'anon',
        tokenProvider: () async => null,
        trackDelivery: false,
        platform: CommunityPlatform.windows,
        appVersion: '1.3.0',
      );
      addTearDown(community.dispose);
      expect(community.configService.platform, 'windows');
      expect(community.configService.appVersion, '1.3.0');
      expect(community.analytics.platform, 'windows');
    });
  });
}
