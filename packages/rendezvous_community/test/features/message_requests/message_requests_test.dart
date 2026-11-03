import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/message_requests/data/repositories/message_request_repository_impl.dart';
import 'package:rendezvous_community/src/features/message_requests/presentation/cubit/dm_policy_cubit.dart';
import 'package:rendezvous_community/src/features/message_requests/presentation/cubit/message_requests_cubit.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

MessageRequest _request({String roomId = 'r-1', bool image = true}) => MessageRequest(
  roomId: roomId,
  sender: alice,
  messageCount: 2,
  hasImage: image,
  lastMessagePreview: 'Halo kak',
  createdAt: DateTime.utc(2026, 11, 3, 5),
);

void main() {
  test('repository maps requests, count, responses, and the DM policy', () async {
    final api = mockApi();
    when(() => api.rpcRows('get_message_requests', any())).thenAnswer(
      (_) async => [
        {
          'room_id': 'r-1',
          'sender_id': 'u-a',
          'username': 'alice',
          'display_name': 'Alice',
          'avatar_url': null,
          'is_verified': false,
          'message_count': 3,
          'has_image': true,
          'last_message_preview': '[lampiran]',
          'last_message_at': '2026-11-03T05:01:00Z',
          'created_at': '2026-11-03T05:00:00Z',
        },
      ],
    );
    when(() => api.rpcValue('get_message_request_count')).thenAnswer((_) async => 4);
    when(() => api.rpcValue('respond_message_request', any())).thenAnswer((_) async => {'status': 'accepted'});
    when(
      () => api.rpcValue('get_dm_policy'),
    ).thenAnswer((_) async => {'policy': 'following', 'request_max_messages': 3});
    when(
      () => api.rpcValue('set_dm_policy', any()),
    ).thenAnswer((_) async => {'policy': 'none', 'request_max_messages': 3});
    final repository = MessageRequestRepositoryImpl(api);

    final requests = await repository.getRequests(limit: 10, before: DateTime.utc(2026, 11, 4));
    verify(
      () => api.rpcRows('get_message_requests', {'p_limit': 10, 'p_before': '2026-11-04T00:00:00.000Z'}),
    ).called(1);
    expect(requests.single.sender.username, 'alice');
    expect(requests.single.hasImage, isTrue);
    expect(await repository.requestCount(), 4);
    await repository.respond('r-1', MessageRequestAction.block);
    verify(() => api.rpcValue('respond_message_request', {'p_room_id': 'r-1', 'p_action': 'block'})).called(1);
    expect((await repository.dmPolicy()).policy, DmPolicy.following);
    expect((await repository.setDmPolicy(DmPolicy.none)).policy, DmPolicy.none);
    verify(() => api.rpcValue('set_dm_policy', {'p_policy': 'none'})).called(1);
  });

  test('responding removes the request and lowers the count', () async {
    final repository = FakeMessageRequestRepository()
      ..requests = [_request(), _request(roomId: 'r-2')]
      ..count = 2;
    final cubit = MessageRequestsCubit(repository);
    await cubit.loadCount();
    await cubit.load();
    expect(await cubit.respond('r-1', MessageRequestAction.decline), isTrue);
    expect(cubit.state.requests.map((r) => r.roomId), ['r-2']);
    expect(cubit.state.count, 1);
    expect(repository.responses.single, ('r-1', MessageRequestAction.decline));
    await cubit.close();
  });

  test('DM policy changes are optimistic and saved', () async {
    final repository = FakeMessageRequestRepository();
    final cubit = DmPolicyCubit(repository);
    await cubit.load();
    await cubit.setPolicy(DmPolicy.none);
    expect(cubit.state.settings.policy, DmPolicy.none);
    expect(cubit.state.savedId, 1);
    await cubit.close();
  });

  testWidgets('the chat list shows the request entry; the request room blurs images and offers actions', (
    tester,
  ) async {
    final features = FakeFeatureDependencies(config: loadedConfig());
    addTearDown(features.dispose);
    features.messageRequests
      ..requests = [_request()]
      ..count = 1;
    final chat = FakeChatRepository(
      messages: [
        ChatMessage(
          id: 'm-1',
          roomId: 'r-1',
          senderId: alice.id,
          sender: alice,
          body: 'Lihat ini',
          attachments: const [Attachment(path: 'rooms/r-1/u-a/x.jpg', mime: 'image/jpeg')],
          createdAt: DateTime.utc(2026, 11, 3, 5),
        ),
      ],
    );
    addTearDown(chat.dispose);
    await pumpFeatureApp(
      tester,
      const MessageRequestsEntry(),
      dependencies: FakeDependencies(chat: chat, mediaRepository: _Media()),
      features: features,
    );
    await tester.pumpAndSettle();
    expect(find.text('Permintaan pesan'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Permintaan pesan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Halo kak'), findsOneWidget);
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.text('Terima'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    expect(find.text('Blokir & laporkan'), findsOneWidget);

    await tester.tap(find.text('Blokir & laporkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Blokir & laporkan'));
    await tester.pumpAndSettle();
    expect(features.messageRequests.responses.single, ('r-1', MessageRequestAction.block));
    expect(find.text('Tidak ada permintaan pesan.'), findsOneWidget);
  });

  testWidgets('the sender sees the request hint and the limit notice in a direct room', (tester) async {
    final chat = FakeChatRepository(
      rooms: [ChatRoom(id: 'dm', type: RoomType.direct, createdAt: now, lastReadAt: now, otherUser: alice)],
      messages: [ChatMessage(id: 'm-1', roomId: 'dm', senderId: me.id, sender: me, body: 'Halo', createdAt: now)],
    )..sendError = const CommunityException(CommunityErrorKind.forbidden, code: 'dm_request_limit');
    addTearDown(chat.dispose);
    await pumpFeatureApp(
      tester,
      const CommunityChatRoom(roomId: 'dm'),
      dependencies: FakeDependencies(chat: chat),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('masuk sebagai permintaan pesan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Halo lagi');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tunggu Alice menerima permintaan pesan Anda'), findsOneWidget);
  });
}

class _Media extends Fake implements MediaRepository {
  @override
  Future<AuthorizedImage> attachmentImage(Attachment attachment) async => AuthorizedImage('http://x/a.jpg', const {});
}
