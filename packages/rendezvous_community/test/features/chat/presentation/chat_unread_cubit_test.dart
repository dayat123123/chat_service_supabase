import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_unread_cubit.dart';

import '../../../support/fakes.dart';

void main() {
  const delay = Duration(milliseconds: 20);
  const settle = Duration(milliseconds: 80);
  late FakeChatRepository chat;
  late FakeNotificationRepository notifications;
  late ChatUnreadCubit cubit;

  setUp(() async {
    chat = FakeChatRepository()..unreadChats = 2;
    notifications = FakeNotificationRepository();
    cubit = ChatUnreadCubit(chat: chat, notifications: notifications, refreshDelay: delay);
    await cubit.load();
  });

  tearDown(() async {
    await cubit.close();
    await chat.dispose();
    await notifications.dispose();
  });

  test('memuat jumlah chat belum dibaca', () {
    expect(cubit.state, 2);
  });

  test('pesan masuk (notifikasi baru) memuat ulang jumlah', () async {
    chat.unreadChats = 3;
    notifications.changes.add(null);
    await Future<void>.delayed(settle);
    expect(cubit.state, 3);
  });

  test('room dibaca di perangkat ini memuat ulang jumlah', () async {
    chat.unreadChats = 1;
    chat.unreadChanges.add(null);
    await Future<void>.delayed(settle);
    expect(cubit.state, 1);
  });

  test('perubahan beruntun digabung menjadi satu permintaan', () async {
    final before = chat.unreadChatCalls;
    for (var i = 0; i < 5; i++) {
      notifications.changes.add(null);
    }
    chat.unreadChanges.add(null);
    await Future<void>.delayed(settle);
    expect(chat.unreadChatCalls - before, 1);
  });

  test('gagal memuat ulang mempertahankan jumlah terakhir', () async {
    chat.unreadChatError = Exception('offline');
    notifications.changes.add(null);
    await Future<void>.delayed(settle);
    expect(cubit.state, 2);
  });
}
