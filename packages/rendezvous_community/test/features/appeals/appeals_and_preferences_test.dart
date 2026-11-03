import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/appeals/data/repositories/appeal_repository_impl.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/cubit/appeal_form_cubit.dart';
import 'package:rendezvous_community/src/features/notifications/data/models/notification_model.dart';
import 'package:rendezvous_community/src/features/notifications/data/repositories/notification_preferences_repository_impl.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/cubit/notification_preferences_cubit.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

void main() {
  group('appeals', () {
    test('repository maps create_appeal, get_my_appeals, and get_my_sanctions', () async {
      final api = mockApi();
      when(() => api.rpcValue('create_appeal', any())).thenAnswer(
        (_) async => {
          'id': 'a-1',
          'target_type': 'post',
          'target_id': 'p-1',
          'reason': 'Bukan promosi.',
          'status': 'pending',
          'created_at': '2026-11-03T05:00:00Z',
        },
      );
      when(() => api.rpcRows('get_my_appeals')).thenAnswer(
        (_) async => [
          {
            'id': 'a-1',
            'target_type': 'sanction',
            'target_id': 's-1',
            'reason': 'Salah paham',
            'status': 'rejected',
            'decision_note': 'Tetap berlaku',
            'created_at': '2026-11-03T05:00:00Z',
            'decided_at': '2026-11-03T06:00:00Z',
          },
        ],
      );
      when(() => api.rpcRows('get_my_sanctions')).thenAnswer(
        (_) async => [
          {'id': 's-1', 'kind': 'mute', 'category': 'spam', 'reason': 'Spam', 'starts_at': null, 'ends_at': null},
        ],
      );
      final repository = AppealRepositoryImpl(api);

      final appeal = await repository.createAppeal(AppealTargetType.post, 'p-1', '  Bukan promosi.  ');
      verify(
        () => api.rpcValue('create_appeal', {
          'p_target_type': 'post',
          'p_target_id': 'p-1',
          'p_reason': 'Bukan promosi.',
        }),
      ).called(1);
      expect(appeal.status, AppealStatus.pending);
      final mine = await repository.myAppeals();
      expect(mine.single.status, AppealStatus.rejected);
      expect(mine.single.decisionNote, 'Tetap berlaku');
      expect((await repository.mySanctions()).single.kind, 'mute');
    });

    test('the form validates the 10–1000 character reason and surfaces server errors', () async {
      final repository = FakeAppealRepository();
      final cubit = AppealFormCubit(repository, targetType: AppealTargetType.comment, targetId: 'c-1');
      expect(await cubit.submit('pendek'), isNull);
      expect(repository.created, isEmpty);

      repository.error = const CommunityException(CommunityErrorKind.invalidInput, code: 'appeal_exists');
      expect(await cubit.submit('Alasan yang cukup panjang'), isNull);
      expect(cubit.state.errorId, 1);

      repository.error = null;
      expect(await cubit.submit('Alasan yang cukup panjang'), isNotNull);
      expect(repository.created.single.$1, AppealTargetType.comment);
      await cubit.close();
    });

    testWidgets('"Banding saya" lists sanctions with an appeal action and past appeals', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      features.appeals
        ..sanctions = const [Sanction(id: 's-1', kind: 'mute', reason: 'Spam')]
        ..appeals = [
          Appeal(
            id: 'a-0',
            targetType: AppealTargetType.post,
            targetId: 'p-1',
            reason: 'Konten saya edukatif',
            status: AppealStatus.accepted,
            createdAt: DateTime.utc(2026, 11, 1),
          ),
        ];
      await pumpFeatureApp(tester, const CommunityAppeals(), features: features);
      await tester.pumpAndSettle();
      expect(find.text('Dibatasi mengirim konten'), findsOneWidget);
      expect(find.text('Post · Diterima'), findsOneWidget);

      await tester.tap(find.text('Ajukan banding'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Saya tidak melakukan spam.');
      await tester.pump();
      await tester.tap(find.text('Kirim banding'));
      await tester.pumpAndSettle();
      expect(features.appeals.created.single, (AppealTargetType.sanction, 's-1', 'Saya tidak melakukan spam.'));
    });
  });

  group('notification preferences', () {
    test('repository maps prefs and sends partial updates', () async {
      final api = mockApi();
      final view = {
        'types': [
          {'type': 'like', 'in_app': true, 'push': false},
          {'type': 'olt.trade', 'in_app': null, 'push': true},
        ],
        'quiet_hours': {'enabled': true, 'start': '22:00', 'end': '06:00', 'timezone': 'Asia/Jakarta'},
        'aggregate_minutes': 60,
      };
      when(() => api.rpcValue('get_notification_prefs')).thenAnswer((_) async => view);
      when(() => api.rpcValue('set_notification_prefs', any())).thenAnswer((_) async => view);
      final repository = NotificationPreferencesRepositoryImpl(api);

      final prefs = await repository.get();
      expect(prefs.of('like')!.push, isFalse);
      expect(prefs.of('olt.trade')!.supportsInApp, isFalse);
      expect(prefs.quietHours.start, '22:00');

      await repository.update(
        types: const [NotificationPreferenceChange(type: 'like', push: true)],
        quietHours: const QuietHours(),
      );
      verify(
        () => api.rpcValue('set_notification_prefs', {
          'p_prefs': {
            'types': [
              {'type': 'like', 'push': true},
            ],
            'quiet_hours': {'enabled': false},
          },
        }),
      ).called(1);
    });

    test('cubit toggles optimistically and rolls back on errors', () async {
      final repository = FakeNotificationPreferencesRepository();
      final cubit = NotificationPreferencesCubit(repository);
      await cubit.load();
      await cubit.setChannel('like', push: false);
      expect(cubit.state.preferences.of('like')!.push, isFalse);

      repository.error = const CommunityException(CommunityErrorKind.network);
      await cubit.setChannel('like', inApp: false);
      expect(cubit.state.preferences.of('like')!.inApp, isTrue);
      expect(cubit.state.actionErrorId, 1);

      repository.error = null;
      await cubit.setChannel('olt.trade', inApp: false, push: false);
      expect(repository.updates.last.$1.single.inApp, isNull);
      await cubit.setQuietHours(const QuietHours(enabled: true, start: '23:00', end: '05:30'));
      expect(cubit.state.preferences.quietHours.start, '23:00');
      await cubit.close();
    });

    testWidgets('settings show both channels, push-only trades, and quiet hours', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpFeatureApp(
        tester,
        const SingleChildScrollView(child: CommunityNotificationSettings()),
        features: features,
      );
      await tester.pumpAndSettle();
      expect(find.text('Suka'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Notifikasi OLT'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(4));
      await tester.tap(find.text('Jam tenang'));
      await tester.pumpAndSettle();
      expect(features.notificationPreferences.updates.single.$2!.enabled, isTrue);
      expect(find.text('Mulai 22:00'), findsOneWidget);
    });
  });

  group('aggregated and appeal notifications', () {
    Map<String, dynamic> row(String type, {int actors = 1, Map<String, dynamic> payload = const {}}) => {
      'id': 'n-$type',
      'type': type,
      'actor_id': 'u-1',
      'actor_username': 'budi_santoso',
      'actor_display_name': 'Budi',
      'actor_avatar_url': null,
      'payload': payload,
      'event_count': 9,
      'read_at': null,
      'created_at': '2026-11-03T05:00:00Z',
      'cursor': 'c',
      'actor_count': actors,
      'actors': [
        {'id': 'u-1', 'username': 'budi_santoso', 'display_name': 'Budi', 'avatar_url': null},
      ],
    };

    test('the model maps actor_count, actors, and the appeal type', () {
      final like = NotificationModel.fromJson(row('like', actors: 5)).toEntity()!;
      expect(like.actorCount, 5);
      expect(like.otherActors, 4);
      expect(like.actors.single.username, 'budi_santoso');
      final appeal = NotificationModel.fromJson(
        row('appeal', payload: {'status': 'accepted', 'appeal_id': 'a-1'}),
      ).toEntity()!;
      expect(appeal.type, NotificationType.appeal);
      expect(appeal.appealStatus, 'accepted');
    });

    testWidgets('texts use actor_count rather than event_count', (tester) async {
      final notifications = _Notifications([
        NotificationModel.fromJson(row('like', actors: 5)).toEntity()!,
        NotificationModel.fromJson(row('follow', actors: 3)).toEntity()!,
        NotificationModel.fromJson(row('appeal', payload: {'status': 'rejected', 'note': 'Tetap'})).toEntity()!,
      ]);
      await pumpFeatureApp(
        tester,
        const CommunityNotificationList(),
        dependencies: FakeDependencies(notifications: notifications),
      );
      await tester.pumpAndSettle();
      expect(find.text('Budi dan 4 lainnya menyukai konten Anda'), findsOneWidget);
      expect(find.text('Budi dan 2 lainnya mulai mengikuti Anda'), findsOneWidget);
      expect(find.text('Banding Anda ditolak'), findsOneWidget);
      expect(find.text('Tetap'), findsOneWidget);
    });
  });
}

class _Notifications extends FakeNotificationRepository {
  _Notifications(this.items);

  final List<AppNotification> items;

  @override
  Future<Paged<AppNotification>> getNotifications({String? cursor, int limit = 30}) async => Paged(items);

  @override
  Future<int> unreadCount() async => items.length;
}
