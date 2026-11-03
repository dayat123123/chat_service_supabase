import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/notifications/data/models/notification_model.dart';
import 'package:rendezvous_community/src/features/notifications/data/repositories/notification_preferences_repository_impl.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

const _types = [
  'reply',
  'mention',
  'like',
  'follow',
  'message',
  'announcement',
  'appeal',
  'olt.trade',
  'olt.funds',
  'olt.market',
  'olt.info',
  'olt.promo',
];

Map<String, dynamic> _oltRow({
  String id = 'n-olt',
  Object? title = const {'id': 'Order BBCA terpenuhi', 'en': 'BBCA order filled'},
  Object? body = const {'id': '100 lot @ 9.200', 'en': '100 lots @ 9,200'},
  String kind = 'olt.trade',
  String category = 'info',
}) => {
  'id': id,
  'type': 'announcement',
  'actor_id': null,
  'payload': {
    'source': 'olt',
    'kind': kind,
    'category': category,
    'title': title,
    'body': ?body,
    'data': {'screen': 'orders', 'order_id': 'o-9'},
    'message_id': 'm-1',
    'cust_id': 'W137',
  },
  'event_count': 1,
  'read_at': null,
  'created_at': '2026-11-03T05:00:00Z',
  'cursor': 'c-$id',
  'actor_count': 0,
  'actors': <Map<String, dynamic>>[],
};

AppNotification _olt({
  String id = 'n-olt',
  Object? title = const {'id': 'Order BBCA terpenuhi', 'en': 'BBCA order filled'},
  Object? body = const {'id': '100 lot @ 9.200', 'en': '100 lots @ 9,200'},
  String kind = 'olt.trade',
  String category = 'info',
}) => NotificationModel.fromJson(_oltRow(id: id, title: title, body: body, kind: kind, category: category)).toEntity()!;

void main() {
  group('notification preferences with OLT types', () {
    test('parses all twelve types with in-app toggles for OLT', () async {
      final api = mockApi();
      when(() => api.rpcValue('get_notification_prefs')).thenAnswer(
        (_) async => {
          'types': [
            for (final type in _types) {'type': type, 'in_app': true, 'push': type != 'olt.promo'},
          ],
          'quiet_hours': {'enabled': false},
          'aggregate_minutes': 60,
        },
      );

      final prefs = await NotificationPreferencesRepositoryImpl(api).get();

      expect(prefs.types.map((t) => t.type), _types);
      for (final type in _types.where((t) => t.startsWith('olt.'))) {
        expect(prefs.of(type)!.supportsInApp, isTrue);
        expect(prefs.of(type)!.isOlt, isTrue);
      }
      expect(prefs.of('olt.promo')!.push, isFalse);
      expect(prefs.of('olt.promo')!.inApp, isTrue);
      expect(prefs.of('like')!.isOlt, isFalse);
    });

    testWidgets('settings list OLT types in their own section with both channels', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      features.notificationPreferences.preferences = NotificationPreferences(
        types: [
          for (final type in _types) NotificationTypePreference(type: type, inApp: true, push: type != 'olt.promo'),
          const NotificationTypePreference(type: 'jenis_baru', inApp: true),
        ],
      );
      await pumpFeatureApp(
        tester,
        const SingleChildScrollView(child: CommunityNotificationSettings()),
        features: features,
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifikasi OLT'), findsOneWidget);
      for (final label in ['Transaksi', 'Dana', 'Pasar', 'Info', 'Promo', 'jenis_baru']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Setoran, penarikan, dan RDN'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(_types.length * 2 + 3));

      final tradeRow = find.ancestor(of: find.text('Transaksi'), matching: find.byType(Row)).first;
      final inApp = find.descendant(of: tradeRow, matching: find.byType(Switch)).first;
      await tester.ensureVisible(inApp);
      await tester.tap(inApp);
      await tester.pumpAndSettle();

      final change = features.notificationPreferences.updates.single.$1.single;
      expect(change.type, 'olt.trade');
      expect(change.inApp, isFalse);
      expect(change.push, isNull);
    });
  });

  group('OLT inbox items', () {
    test('the model keeps OLT payloads and localizes titles with fallbacks', () {
      final n = _olt();
      expect(n.type, NotificationType.announcement);
      expect(n.isOlt, isTrue);
      expect(n.actor, isNull);
      expect(n.oltKind, 'olt.trade');
      expect(n.oltCategory, 'info');
      expect(n.title, isNull);
      expect(n.localizedTitle('en'), 'BBCA order filled');
      expect(n.localizedTitle('id'), 'Order BBCA terpenuhi');
      expect(n.localizedTitle('fr'), 'Order BBCA terpenuhi');
      expect(_olt(title: const {'en': 'Only English'}).localizedTitle('id'), 'Only English');
      expect(_olt(title: 'Teks biasa').localizedTitle('en'), 'Teks biasa');
      expect(_olt(title: 'Teks biasa').title, 'Teks biasa');
      expect(_olt(body: null).localizedBody('id'), isNull);
    });

    testWidgets('render localized text and hand the payload to onOltNotificationTap', (tester) async {
      final tapped = <Map<String, Object?>>[];
      final notifications = _Notifications([
        _olt(),
        _olt(id: 'n-promo', title: const {'en': 'Weekend promo'}, body: null, kind: 'olt.promo', category: 'promo'),
        _olt(id: 'n-important', title: 'Pemeliharaan sistem', body: null, kind: 'olt.info', category: 'important'),
      ]);
      await pumpFeatureApp(
        tester,
        const CommunityNotificationList(),
        dependencies: FakeDependencies(
          notifications: notifications,
          callbacks: CommunityCallbacks(onOltNotificationTap: (_, data) => tapped.add(data)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order BBCA terpenuhi'), findsOneWidget);
      expect(find.text('100 lot @ 9.200'), findsOneWidget);
      expect(find.text('Weekend promo'), findsOneWidget);
      expect(find.text('Pemeliharaan sistem'), findsOneWidget);
      expect(find.byIcon(Icons.notification_important_outlined), findsOneWidget);
      expect(find.byIcon(Icons.local_offer_outlined), findsOneWidget);
      expect(find.byType(CommunityAvatar), findsNothing);

      await tester.tap(find.text('Order BBCA terpenuhi'));
      await tester.pump();

      final data = tapped.single;
      expect(data['kind'], 'olt.trade');
      expect(data['category'], 'info');
      expect(data['message_id'], 'm-1');
      expect(data['notification_id'], 'n-olt');
      expect((data['data']! as Map)['order_id'], 'o-9');
      expect(notifications.marked, [
        ['n-olt'],
      ]);
    });

    testWidgets('community announcements keep the regular rendering', (tester) async {
      final announcement = NotificationModel.fromJson({
        ..._oltRow(id: 'n-campaign'),
        'payload': {'title': 'Fitur baru', 'body': 'Coba sekarang'},
      }).toEntity()!;
      await pumpFeatureApp(
        tester,
        const CommunityNotificationList(),
        dependencies: FakeDependencies(notifications: _Notifications([announcement])),
      );
      await tester.pumpAndSettle();

      expect(announcement.isOlt, isFalse);
      expect(find.text('Fitur baru'), findsOneWidget);
      expect(find.text('Coba sekarang'), findsOneWidget);
      expect(find.byType(CommunityAvatar), findsOneWidget);
    });
  });

  group('OLT pushes', () {
    testWidgets('route to onOltNotificationTap and mark the notification read', (tester) async {
      final tapped = <Map<String, Object?>>[];
      final notifications = _Notifications(const []);
      late bool handled;
      await pumpFeatureApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => handled = openCommunityPush(context, {
              'source': 'olt',
              'kind': 'olt.funds',
              'message_id': 'm-2',
              'notification_id': 'n-2',
              'category': 'important',
            }),
            child: const Text('push'),
          ),
        ),
        dependencies: FakeDependencies(
          notifications: notifications,
          callbacks: CommunityCallbacks(onOltNotificationTap: (_, data) => tapped.add(data)),
        ),
      );
      await tester.tap(find.text('push'));
      await tester.pump();

      expect(handled, isTrue);
      expect(tapped.single['kind'], 'olt.funds');
      expect(tapped.single['message_id'], 'm-2');
      expect(notifications.marked, [
        ['n-2'],
      ]);
    });
  });
}

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
