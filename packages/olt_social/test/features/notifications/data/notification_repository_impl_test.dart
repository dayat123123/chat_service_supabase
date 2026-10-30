import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/src/features/notifications/data/repositories/notification_repository_impl.dart';

import '../../../support/mock_api.dart';

void main() {
  test('tipe notifikasi tak dikenal diabaikan', () async {
    final api = mockApi();
    when(() => api.rpcRows('get_notifications', any())).thenAnswer((_) async => [
      {
        'id': 'n-1',
        'type': 'like',
        'actor_id': 'u-2',
        'actor_username': 'sari_invest',
        'actor_display_name': null,
        'actor_avatar_url': null,
        'payload': {'post_id': 'p-1', 'snippet': 'Halo'},
        'event_count': 2,
        'read_at': null,
        'created_at': '2026-10-29T03:00:00+00:00',
        'cursor': 'a',
      },
      {
        'id': 'n-2',
        'type': 'jenis_baru',
        'payload': <String, Object?>{},
        'event_count': 1,
        'created_at': '2026-10-29T02:00:00+00:00',
        'cursor': 'b',
      },
    ]);

    final page = await NotificationRepositoryImpl(api).getNotifications(limit: 30);

    expect(page.items.single.postId, 'p-1');
    expect(page.items.single.eventCount, 2);
    expect(page.hasMore, isFalse);
  });
}
