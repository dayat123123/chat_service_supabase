import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_events.dart';
import 'package:olt_social/src/features/chat/domain/services/delivery_tracker.dart';

import '../../../support/fakes.dart';

RoomActivity activity(String roomId, String senderId) =>
    RoomActivity(roomId: roomId, senderId: senderId, preview: 'Halo', createdAt: now);

void main() {
  late FakeChatRepository chat;
  late DeliveryTracker tracker;

  setUp(() {
    chat = FakeChatRepository();
    tracker = DeliveryTracker(chat, currentUserId: () => me.id, debounce: const Duration(milliseconds: 20));
  });

  tearDown(() async {
    await tracker.stop();
    await chat.dispose();
  });

  test('saat mulai menandai semua room yang punya pesan baru', () async {
    tracker.start();
    await pumpEventQueue();
    expect(chat.delivered, [null]);
  });

  test('pesan dari orang lain ditandai terkirim per room setelah debounce', () async {
    tracker.start();
    await pumpEventQueue();
    chat.activity
      ..add(activity('r-1', alice.id))
      ..add(activity('r-2', bob.id))
      ..add(activity('r-1', alice.id));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(chat.delivered.last, unorderedEquals(['r-1', 'r-2']));
  });

  test('pesan sendiri tidak ditandai', () async {
    tracker.start();
    await pumpEventQueue();
    chat.activity.add(activity('r-1', me.id));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(chat.delivered, [null]);
  });

  test('stop menghentikan pemantauan', () async {
    tracker.start();
    await pumpEventQueue();
    await tracker.stop();
    expect(tracker.isRunning, isFalse);
  });
}
