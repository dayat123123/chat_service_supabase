import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/notifications/data/models/notification_model.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';

AppNotification _notification(String type, Map<String, Object?> payload, {String id = 'n-1', int count = 1}) =>
    NotificationModel.fromJson({
      'id': id,
      'type': type,
      'actor_id': type == 'followed_post' || type == 'mention' ? alice.id : null,
      'actor_username': type == 'followed_post' || type == 'mention' ? alice.username : null,
      'actor_display_name': type == 'followed_post' || type == 'mention' ? alice.displayName : null,
      'payload': payload,
      'event_count': count,
      'read_at': null,
      'created_at': '2026-11-03T05:00:00Z',
      'cursor': 'c-$id',
    }).toEntity()!;

class _Notifications extends FakeNotificationRepository {
  _Notifications(this.items);

  final List<AppNotification> items;
  final marked = <List<String>?>[];

  @override
  Future<Paged<AppNotification>> getNotifications({String? cursor, int limit = 30}) async => Paged(items);

  @override
  Future<int> unreadCount() async => items.length;

  @override
  Future<void> markRead({List<String>? ids}) async => marked.add(ids);
}

void main() {
  final digest = _notification('watchlist_digest', {
    'date': '2026-11-03',
    'post_count': 12,
    'stock_count': 4,
    'stocks': ['BBCA', 'TLKM', 'ASII'],
  }, id: 'n-d');
  final moderation = _notification('moderation', {
    'target_type': 'comment',
    'target_id': 'c-1',
    'state': 'removed',
    'excerpt': 'Komentar saya',
    'appealable': true,
    'post_id': 'p-1',
  }, id: 'n-m');
  final roomMention = _notification('mention', {
    'room_id': 'room-bbca',
    'room_type': 'stock',
    'stock_code': 'BBCA',
    'message_id': 'm-1',
    'snippet': 'halo @budi',
  }, id: 'n-r');
  final followed = _notification('followed_post', {'post_id': 'p-9', 'author_id': alice.id}, id: 'n-f', count: 3);

  group('new notification types', () {
    test('are parsed with their payloads', () {
      expect(digest.type, NotificationType.watchlistDigest);
      expect(digest.stocks, ['BBCA', 'TLKM', 'ASII']);
      expect(digest.postCount, 12);
      expect(moderation.type, NotificationType.moderation);
      expect(moderation.appealable, isTrue);
      expect(moderation.moderationState, 'removed');
      expect(roomMention.isRoomMention, isTrue);
      expect(roomMention.stockCode, 'BBCA');
      expect(followed.type, NotificationType.followedPost);
      expect(notificationTypeFromKey('olt.trade'), isNull);
      expect(CommunityPushMessage.tryParse({'source': 'rendezvous_community', 'stocks': '["BBCA","TLKM"]'})!.stocks, [
        'BBCA',
        'TLKM',
      ]);
    });

    testWidgets('render localized texts and open their targets', (tester) async {
      final notifications = _Notifications([digest, moderation, roomMention, followed]);
      final stocks = <String>[];
      final rooms = <String>[];
      final posts = <String>[];
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpFeatureApp(
        tester,
        const CommunityNotificationList(),
        dependencies: FakeDependencies(
          notifications: notifications,
          callbacks: CommunityCallbacks(
            onStockTap: (_, code) => stocks.add(code),
            onRoomTap: (_, id) => rooms.add(id),
            onPostTap: (_, id) => posts.add(id),
          ),
        ),
        features: features,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan saham pantauan'), findsOneWidget);
      expect(find.text(r'12 postingan baru tentang $BBCA, $TLKM, $ASII, dan 1 saham lainnya'), findsOneWidget);
      expect(find.text('Komentar Anda dihapus moderator'), findsOneWidget);
      expect(find.textContaining('mengajukan banding'), findsOneWidget);
      expect(find.text(r'Alice menyebut Anda di $BBCA'), findsOneWidget);
      expect(find.text('Alice membuat 3 postingan baru'), findsOneWidget);

      await tester.tap(find.text('Ringkasan saham pantauan'));
      await tester.tap(find.text(r'Alice menyebut Anda di $BBCA'));
      await tester.tap(find.text('Alice membuat 3 postingan baru'));
      await tester.pumpAndSettle();

      expect(stocks, ['BBCA']);
      expect(rooms, ['room-bbca']);
      expect(posts, ['p-9']);
      final events = [
        for (final (event, source) in features.notificationEvents.reported) '${event.name}:${source.key}',
      ];
      expect(events, ['opened:n:n-d', 'tapped:n:n-d', 'opened:n:n-r', 'tapped:n:n-r', 'opened:n:n-f', 'tapped:n:n-f']);
    });

    testWidgets('room mute notices name the stock room, skip the appeal hint, and open the room', (tester) async {
      final until = DateTime.now().toUtc().add(const Duration(hours: 1));
      final muted = _notification('moderation', {
        'target_type': 'room',
        'target_id': 'room-bbca',
        'state': 'muted',
        'room_id': 'room-bbca',
        'stock_code': 'BBCA',
        'until': until.toIso8601String(),
        'reason': 'spam',
        'appealable': false,
      }, id: 'n-mu');
      final unmuted = _notification('moderation', {
        'target_type': 'room',
        'target_id': 'room-tlkm',
        'state': 'unmuted',
        'room_id': 'room-tlkm',
        'stock_code': 'TLKM',
        'until': null,
        'appealable': false,
      }, id: 'n-un');
      expect(muted.isRoomMute, isTrue);
      expect(muted.muteUntil, until);
      expect(moderation.isRoomMute, isFalse);
      final rooms = <String>[];
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpFeatureApp(
        tester,
        const CommunityNotificationList(),
        dependencies: FakeDependencies(
          notifications: _Notifications([muted, unmuted]),
          callbacks: CommunityCallbacks(onRoomTap: (_, id) => rooms.add(id)),
        ),
        features: features,
      );
      await tester.pumpAndSettle();

      expect(find.text(r'Anda dibisukan moderator di $BBCA'), findsOneWidget);
      expect(find.textContaining('Anda bisa mengirim pesan lagi setelah'), findsOneWidget);
      expect(find.text(r'Bisu Anda di $TLKM dicabut'), findsOneWidget);
      expect(find.text('Anda bisa mengirim pesan lagi di room ini'), findsOneWidget);
      expect(find.textContaining('banding'), findsNothing);

      await tester.tap(find.text(r'Anda dibisukan moderator di $BBCA'));
      await tester.tap(find.text(r'Bisu Anda di $TLKM dicabut'));
      await tester.pumpAndSettle();
      expect(rooms, ['room-bbca', 'room-tlkm']);
    });

    testWidgets('the in-app switch is disabled when the server locks it', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      features.notificationPreferences.preferences = const NotificationPreferences(
        types: [NotificationTypePreference(type: 'moderation', inApp: true, inAppLocked: true)],
      );
      await pumpFeatureApp(
        tester,
        const SingleChildScrollView(child: CommunityNotificationSettings()),
        features: features,
      );
      await tester.pumpAndSettle();

      expect(find.text('Moderasi'), findsOneWidget);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.where((s) => s.onChanged == null), hasLength(1));
    });
  });

  group('NotificationReporter', () {
    test('reports each source and event once and skips empty sources', () async {
      final repository = FakeNotificationEventRepository();
      final reporter = NotificationReporter(repository);

      await reporter.opened(const NotificationSource(notificationId: 'n-1'));
      await reporter.opened(const NotificationSource(notificationId: 'n-1'));
      await reporter.tapped(NotificationSource.fromData({'broadcast_id': 'b-1', 'data': 'x'}));
      await reporter.opened(NotificationSource.fromData(const {}));

      expect([for (final (e, s) in repository.reported) '${e.name}:${s.key}'], ['opened:n:n-1', 'tapped:b:b-1']);
    });

    test('queues events while offline and sends them later', () async {
      final repository = FakeNotificationEventRepository()
        ..error = const CommunityException(CommunityErrorKind.network);
      final reporter = NotificationReporter(repository);

      await reporter.opened(const NotificationSource(campaignId: 'c-1'));
      expect(reporter.queuedCount, 1);

      repository.error = null;
      await reporter.flush();
      expect(reporter.queuedCount, 0);
      expect(repository.reported.single.$2.campaignId, 'c-1');
    });

    testWidgets('opening a push reports opened and tapped with the push ids', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpFeatureApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openCommunityPush(context, {
              'source': 'rendezvous_community',
              'type': 'followed_post',
              'notification_id': 'n-7',
              'post_id': 'p-7',
            }),
            child: const Text('push'),
          ),
        ),
        dependencies: FakeDependencies(
          notifications: _Notifications(const []),
          callbacks: CommunityCallbacks(onPostTap: (_, _) {}),
        ),
        features: features,
      );
      await tester.tap(find.text('push'));
      await tester.pump();

      expect(
        [for (final (e, s) in features.notificationEvents.reported) '${e.name}:${s.key}'],
        ['opened:n:n-7', 'tapped:n:n-7'],
      );
    });
  });
}
