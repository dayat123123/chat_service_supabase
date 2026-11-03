import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/config/data/models/client_config_model.dart';
import 'package:rendezvous_community/src/features/config/data/repositories/client_config_repository_impl.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

Map<String, dynamic> _configJson({bool social = true, bool update = false}) => {
  'social_enabled': social,
  'flags': {'search': true, 'trending': false, 'analytics': true},
  'min_version': {'android': '2.10.0', 'ios': null, 'web': null},
  'update_required': update,
  'config': {
    'edit_minutes': 10,
    'message_reactions': ['👍', '🔥'],
    'search_min_length': 3,
    'notification_types': ['like', 'appeal', 'olt.trade'],
    'notification_aggregate_minutes': 30,
    'trending_windows': ['24h', '7d'],
    'server_time': '2026-11-03T05:00:00Z',
  },
};

void main() {
  group('ClientConfigModel', () {
    test('maps flags, versions, limits, and the server clock skew', () {
      final config = ClientConfigModel.fromJson(
        _configJson(),
      ).toEntity(receivedAt: DateTime.utc(2026, 11, 3, 4, 59, 50));
      expect(config.loaded, isTrue);
      expect(config.flag(CommunityFlags.search), isTrue);
      expect(config.flag(CommunityFlags.trending), isFalse);
      expect(config.flag(CommunityFlags.bookmarks), isFalse);
      expect(config.minVersions['android'], '2.10.0');
      expect(config.editWindow, const Duration(minutes: 10));
      expect(config.messageReactions, ['👍', '🔥']);
      expect(config.searchMinLength, 3);
      expect(config.notificationTypes, contains('appeal'));
      expect(config.clockSkew, const Duration(seconds: 10));
    });

    test('before loading every flag is optimistic; social off disables features', () {
      const fallback = ClientConfig();
      expect(fallback.flag(CommunityFlags.search), isTrue);
      expect(fallback.copyWith(socialEnabled: false).feature(CommunityFlags.search), isFalse);
    });

    test('canEdit follows the edit window measured with server time', () {
      final config = ClientConfig(editWindow: const Duration(minutes: 15), fetchedAt: DateTime.now());
      final now = DateTime.utc(2026, 11, 3, 10);
      expect(
        config.copyWith(flags: {'post_edit': true}).canEdit(now.subtract(const Duration(minutes: 14)), now: now),
        isTrue,
      );
      expect(
        config.copyWith(flags: {'post_edit': true}).canEdit(now.subtract(const Duration(minutes: 16)), now: now),
        isFalse,
      );
      expect(config.copyWith(flags: {'post_edit': false}).canEdit(now, now: now), isFalse);
      expect(
        config
            .copyWith(flags: {'post_edit': true}, clockSkew: const Duration(minutes: 2))
            .canEdit(now.subtract(const Duration(minutes: 14)), now: now),
        isFalse,
      );
    });
  });

  group('ClientConfigRepositoryImpl', () {
    test('uses the anonymous endpoint before sign-in and the session afterwards', () async {
      final api = mockApi();
      when(() => api.currentUserId).thenReturn(null);
      when(() => api.anonymousRpcValue('get_client_config', any())).thenAnswer((_) async => _configJson());
      final anonymous = await ClientConfigRepositoryImpl(api).fetch(platform: 'android', appVersion: '1.3.0');
      expect(anonymous.socialEnabled, isTrue);
      verify(
        () => api.anonymousRpcValue('get_client_config', {'p_platform': 'android', 'p_app_version': '1.3.0'}),
      ).called(1);

      when(() => api.currentUserId).thenReturn('u-1');
      when(() => api.rpcValue('get_client_config', any())).thenAnswer((_) async => _configJson(social: false));
      expect((await ClientConfigRepositoryImpl(api).fetch()).socialEnabled, isFalse);
    });
  });

  group('ClientConfigService', () {
    test('publishes changes, calls onUpdateRequired once per transition, keeps the last good config', () async {
      final repository = FakeConfigRepository(loadedConfig());
      final updates = <ClientConfig>[];
      final service = ClientConfigService(
        repository,
        platform: 'android',
        appVersion: '1.0.0',
        onUpdateRequired: updates.add,
      );
      final changes = <ClientConfig>[];
      final sub = service.changes.listen(changes.add);
      addTearDown(sub.cancel);

      await service.refresh();
      expect(service.current.loaded, isTrue);
      expect(repository.requests.single, ('android', '1.0.0'));

      repository.config = loadedConfig().copyWith(updateRequired: true);
      await service.refresh();
      await service.refresh();
      expect(updates, hasLength(1));

      repository.error = Exception('offline');
      await service.refresh();
      expect(service.current.updateRequired, isTrue);
      await pumpEventQueue();
      expect(changes.length, 2);
      await service.dispose();
    });

    test('concurrent refreshes share one request; social_disabled flips the switch immediately', () async {
      final repository = FakeConfigRepository(loadedConfig());
      final service = ClientConfigService(repository);
      await Future.wait([service.refresh(), service.refresh()]);
      expect(repository.calls, 1);

      repository.config = loadedConfig(social: false);
      service.markSocialDisabled();
      expect(service.current.socialEnabled, isFalse);
      await pumpEventQueue();
      expect(repository.calls, 2);
      await service.dispose();
    });
  });

  group('widgets', () {
    testWidgets('CommunitySocialGate shows the child, the default placeholder, or the host builder', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpFeatureApp(tester, const CommunitySocialGate(child: Text('feed')), features: features);
      expect(find.text('feed'), findsOneWidget);

      features.configRepository.config = loadedConfig(social: false);
      features.configService.markSocialDisabled();
      await tester.pump();
      expect(find.text('feed'), findsNothing);
      expect(find.text('Komunitas sedang tidak tersedia'), findsOneWidget);

      await pumpFeatureApp(
        tester,
        CommunityAvailabilityScope(
          builder: (context, reason, fallback) => Text('host ${reason.name}'),
          child: const CommunitySocialGate(child: Text('feed')),
        ),
        features: features,
      );
      expect(find.text('host socialDisabled'), findsOneWidget);
    });

    testWidgets('a disabled feature flag shows the feature placeholder', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig(flags: {'search': false}));
      addTearDown(features.dispose);
      await pumpFeatureApp(
        tester,
        const CommunitySocialGate(feature: CommunityFlags.search, child: Text('search')),
        features: features,
      );
      expect(find.text('search'), findsNothing);
      expect(find.text('Fitur ini sedang tidak tersedia.'), findsOneWidget);
    });

    testWidgets('with social off the chat list keeps only the support room', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig(social: false));
      addTearDown(features.dispose);
      final at = DateTime.utc(2026, 11, 3);
      final chat = FakeChatRepository(
        rooms: [
          ChatRoom(id: 'cs', type: RoomType.support, name: 'CS OLT', createdAt: at, lastReadAt: at),
          ChatRoom(id: 'dm', type: RoomType.direct, createdAt: at, lastReadAt: at, otherUser: alice),
        ],
      );
      addTearDown(chat.dispose);
      await pumpFeatureApp(
        tester,
        const CommunityChatList(),
        dependencies: FakeDependencies(chat: chat),
        features: features,
      );
      await tester.pumpAndSettle();
      expect(find.text('CS OLT'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Komunitas sedang tidak tersedia'), findsOneWidget);
    });

    testWidgets('without feature dependencies the gate is transparent', (tester) async {
      await pumpFeatureApp(tester, const CommunitySocialGate(child: Text('feed')));
      expect(find.text('feed'), findsOneWidget);
    });

    testWidgets('CommunityUpdateListener calls the host once when an update becomes required', (tester) async {
      final repository = FakeConfigRepository(loadedConfig());
      final features = FakeFeatureDependencies(config: loadedConfig(), configRepository: repository);
      addTearDown(features.dispose);
      var calls = 0;
      await pumpFeatureApp(
        tester,
        CommunityUpdateListener(onUpdateRequired: (context, config) => calls++, child: const SizedBox()),
        features: features,
      );
      repository.config = loadedConfig().copyWith(updateRequired: true);
      await tester.runAsync(features.configService.refresh);
      await tester.pump();
      await tester.pump();
      expect(calls, 1);
    });
  });
}
