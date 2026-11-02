import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/push/data/repositories/push_repository_impl.dart';
import 'package:rendezvous_community/src/features/push/domain/repositories/push_repository.dart';
import 'package:rendezvous_community/src/features/push/domain/services/push_registrar.dart';

import '../../support/fakes.dart';
import '../../support/mock_api.dart';

class _MockPushRepository extends Mock implements PushRepository {}

class _MockNotifications extends Mock implements NotificationRepository {}

const _registration = CommunityPushRegistration(
  token: 'fcm-token-0000000001',
  platform: CommunityPushPlatform.android,
  locale: 'id',
  appVersion: '2.4.1',
);

Map<String, Object?> _push(Map<String, Object?> extra) => {
  'source': 'rendezvous_community',
  'notification_id': 'n-1',
  ...extra,
};

void main() {
  setUpAll(() => registerFallbackValue(_registration));

  group('CommunityPushMessage', () {
    test('ignores pushes that do not come from the community backend', () {
      expect(CommunityPushMessage.tryParse({'type': 'order_filled'}), isNull);
      expect(CommunityPushMessage.tryParse({'source': 'olt', 'type': 'reply'}), isNull);
    });

    test('reads the push data sent by the notifier', () {
      final message = CommunityPushMessage.tryParse(
        _push({'type': 'message', 'room_id': 'r-1', 'room_type': 'support', 'push_id': '42', 'url': ''}),
      )!;
      expect(message.type, 'message');
      expect(message.roomId, 'r-1');
      expect(message.isSupport, isTrue);
      expect(message.notificationId, 'n-1');
      expect(message.link, isNull);
    });

    test('only follows https links', () {
      expect(
        CommunityPushMessage.tryParse(_push({'url': 'https://olt.co.id/promo'}))!.link.toString(),
        'https://olt.co.id/promo',
      );
      expect(CommunityPushMessage.tryParse(_push({'url': 'http://olt.co.id'}))!.link, isNull);
      expect(CommunityPushMessage.tryParse(_push({'url': 'javascript:alert(1)'}))!.link, isNull);
    });
  });

  test('the repository registers and removes device tokens through the backend', () async {
    final api = mockApi();
    when(() => api.rpcValue(any(), any())).thenAnswer((_) async => null);
    final repo = PushRepositoryImpl(api);

    await repo.register(_registration);
    await repo.unregister('fcm-token-0000000001');

    verify(
      () => api.rpcValue('register_push_device', {
        'p_token': 'fcm-token-0000000001',
        'p_platform': 'android',
        'p_locale': 'id',
        'p_app_version': '2.4.1',
      }),
    ).called(1);
    verify(() => api.rpcValue('unregister_push_device', {'p_token': 'fcm-token-0000000001'})).called(1);
  });

  group('PushRegistrar', () {
    late _MockPushRepository repository;
    late String? userId;
    late PushRegistrar registrar;

    setUp(() {
      repository = _MockPushRepository();
      when(() => repository.register(any())).thenAnswer((_) async {});
      when(() => repository.unregister(any())).thenAnswer((_) async {});
      userId = 'u-1';
      registrar = PushRegistrar(repository, currentUserId: () => userId);
    });

    test('binds the token to whoever is signed in', () async {
      await registrar.register(_registration);
      registrar.onUserChanged('u-1');
      await pumpEventQueue();
      verify(() => repository.register(_registration)).called(1);

      userId = 'u-2';
      registrar.onUserChanged('u-2');
      await pumpEventQueue();
      verify(() => repository.register(_registration)).called(1);
    });

    test('releases the token on sign-out and binds it again on the next sign-in', () async {
      await registrar.register(_registration);
      await registrar.detach();
      await registrar.detach();
      verify(() => repository.unregister('fcm-token-0000000001')).called(1);

      registrar.onUserChanged('u-3');
      await pumpEventQueue();
      verify(() => repository.register(_registration)).called(2);
    });

    test('a sign-out failure does not block signing out', () async {
      when(() => repository.unregister(any())).thenThrow(StateError('offline'));
      await registrar.register(_registration);
      await expectLater(registrar.detach(), completes);
    });

    test('forgetting the token stops push for good', () async {
      await registrar.register(_registration);
      await registrar.forget();
      registrar.onUserChanged('u-9');
      await pumpEventQueue();
      verify(() => repository.unregister('fcm-token-0000000001')).called(1);
      verify(() => repository.register(_registration)).called(1);
      expect(registrar.registration, isNull);
    });
  });

  group('openCommunityPush', () {
    late _MockNotifications notifications;
    late List<String> opened;

    setUp(() {
      notifications = _MockNotifications();
      when(() => notifications.markRead(ids: any(named: 'ids'))).thenAnswer((_) async {});
      opened = [];
    });

    Future<BuildContext> pump(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScope(
            dependencies: FakeDependencies(
              notifications: notifications,
              callbacks: CommunityCallbacks(
                onPostTap: (_, id) => opened.add('post:$id'),
                onRoomTap: (_, id) => opened.add('room:$id'),
                onUserTap: (_, user) => opened.add('user:${user.id}:${user.username}'),
              ),
            ),
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return captured;
    }

    testWidgets('opens the post, chat, or profile behind a push and marks it read', (tester) async {
      final context = await pump(tester);

      expect(openCommunityPush(context, _push({'type': 'reply', 'post_id': 'p-1'})), isTrue);
      expect(openCommunityPush(context, _push({'type': 'message', 'room_id': 'r-1', 'room_type': 'direct'})), isTrue);
      expect(
        openCommunityPush(context, _push({'type': 'follow', 'actor_id': 'u-7', 'actor_username': 'budi'})),
        isTrue,
      );
      await tester.pump();

      expect(opened, ['post:p-1', 'room:r-1', 'user:u-7:budi']);
      verify(() => notifications.markRead(ids: ['n-1'])).called(3);
    });

    testWidgets('leaves pushes it cannot route to the host app', (tester) async {
      final context = await pump(tester);

      expect(openCommunityPush(context, {'type': 'order_filled'}), isFalse);
      expect(openCommunityPush(context, _push({'type': 'test'})), isFalse);
      expect(opened, isEmpty);
    });
  });
}
