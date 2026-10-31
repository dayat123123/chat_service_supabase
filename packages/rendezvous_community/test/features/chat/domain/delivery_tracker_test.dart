import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/delivery_tracker.dart';

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

  test('marks every room with new messages on start', () async {
    tracker.start();
    await pumpEventQueue();
    expect(chat.delivered, [null]);
  });

  test('marks messages from others as delivered per room after a debounce', () async {
    tracker.start();
    await pumpEventQueue();
    chat.activity
      ..add(activity('r-1', alice.id))
      ..add(activity('r-2', bob.id))
      ..add(activity('r-1', alice.id));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(chat.delivered.last, unorderedEquals(['r-1', 'r-2']));
  });

  test('does not mark own messages', () async {
    tracker.start();
    await pumpEventQueue();
    chat.activity.add(activity('r-1', me.id));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(chat.delivered, [null]);
  });

  test('stop ends monitoring', () async {
    tracker.start();
    await pumpEventQueue();
    await tracker.stop();
    expect(tracker.isRunning, isFalse);
  });
}
