import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/memory_offline_store.dart';
import 'package:rendezvous_community/src/core/storage/offline_cache.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/outbox_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/message_outbox.dart';

const _offline = CommunityException(CommunityErrorKind.network, message: 'SocketException');
const _blocked = CommunityException(CommunityErrorKind.contentBlocked, code: 'content_blocked');
const _slow = CommunityException(CommunityErrorKind.rateLimited, code: 'slow_mode', retryAfter: Duration(seconds: 7));

class _ScriptedChat extends Fake implements ChatRepository {
  final outcomes = <Object>[];
  final sent = <String>[];
  Completer<void>? gate;

  @override
  Future<ChatMessage> sendMessage(
    String roomId, {
    required String body,
    required String clientId,
    String? replyToId,
    List<Attachment> attachments = const [],
  }) async {
    sent.add(clientId);
    await gate?.future;
    final outcome = outcomes.isEmpty ? null : outcomes.removeAt(0);
    if (outcome is Exception) throw outcome;
    return ChatMessage(
      id: 'srv-$clientId',
      roomId: roomId,
      body: body,
      clientId: clientId,
      createdAt: DateTime.utc(2026, 11, 3, 10),
    );
  }
}

void main() {
  final t0 = DateTime.utc(2026, 11, 3, 9);
  late _ScriptedChat chat;
  late OutboxRepositoryImpl store;
  late MessageOutbox outbox;
  late List<OutboxEvent> events;
  late DateTime now;

  OutboxMessage message(String clientId, {int second = 0, String room = 'r1'}) => OutboxMessage(
    clientId: clientId,
    roomId: room,
    body: 'Halo $clientId',
    createdAt: t0.add(Duration(seconds: second)),
  );

  setUp(() {
    chat = _ScriptedChat();
    store = OutboxRepositoryImpl(
      OfflineCache(MemoryOfflineStoreFactory(), currentUserId: () => 'u-1', resolveHostKey: () async => null),
    );
    now = t0;
    outbox = MessageOutbox(chat, store, clock: () => now, baseDelay: const Duration(hours: 1));
    events = [];
    outbox.events.listen(events.add);
  });

  tearDown(() => outbox.dispose());

  group('outboxRetryDelay', () {
    test('network and server outages back off exponentially up to the cap', () {
      expect(outboxRetryDelay(_offline, attempts: 1, interactive: true), const Duration(seconds: 2));
      expect(outboxRetryDelay(_offline, attempts: 3, interactive: false), const Duration(seconds: 8));
      expect(outboxRetryDelay(_offline, attempts: 12, interactive: false), const Duration(minutes: 1));
      expect(
        outboxRetryDelay(const CommunityException(CommunityErrorKind.unavailable), attempts: 1, interactive: true),
        isNotNull,
      );
    });

    test('slow mode is retried in the background a few times, never for a send the user is watching', () {
      expect(outboxRetryDelay(_slow, attempts: 1, interactive: true), isNull);
      expect(outboxRetryDelay(_slow, attempts: 1, interactive: false), const Duration(seconds: 7));
      expect(outboxRetryDelay(_slow, attempts: 3, interactive: false), isNull);
    });

    test('rejections by the server are permanent', () {
      expect(outboxRetryDelay(_blocked, attempts: 1, interactive: false), isNull);
      const limit = CommunityException(CommunityErrorKind.forbidden, code: 'dm_request_limit');
      expect(outboxRetryDelay(limit, attempts: 1, interactive: false), isNull);
    });
  });

  test('a send that fails offline is kept pending and delivered once the network is back', () async {
    chat.outcomes.add(_offline);
    final result = await outbox.send(message('c1'));

    expect(result, isA<OutboxQueued>());
    final [pending] = await store.load();
    expect(pending.state, OutboxState.pending);
    expect(pending.attempts, 1);
    expect(pending.nextAttemptAt, t0.add(const Duration(minutes: 1)));
    expect(pending.error?.kind, CommunityErrorKind.network);

    await outbox.flush();
    expect(chat.sent, ['c1'], reason: 'not due yet');

    await outbox.flush(force: true);
    expect(chat.sent, ['c1', 'c1']);
    expect(await store.load(), isEmpty);
    expect(events.whereType<OutboxDelivered>().single.message.id, 'srv-c1');
  });

  test('due messages are retried by the outbox timer', () async {
    outbox = MessageOutbox(chat, store, baseDelay: Duration.zero);
    chat.outcomes.add(_offline);
    await outbox.send(message('c1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(chat.sent, ['c1', 'c1']);
    expect(await store.load(), isEmpty);
  });

  test('a permanent error marks the message failed until the user retries or deletes it', () async {
    chat.outcomes.add(_blocked);
    final result = await outbox.send(message('c1'));

    expect(result, isA<OutboxFailed>());
    expect((result as OutboxFailed).error.code, 'content_blocked');
    final [failed] = await store.load();
    expect(failed.state, OutboxState.failed);
    expect(failed.error?.code, 'content_blocked');
    expect(failed.toMessage(null).status, MessageStatus.failed);
    expect(failed.toMessage(null).sendError?.code, 'content_blocked');

    await outbox.flush(force: true);
    expect(chat.sent, ['c1'], reason: 'failed messages are not retried automatically');

    expect(await outbox.send(failed), isA<OutboxSent>());
    expect(await store.load(), isEmpty);
  });

  test('slow mode in the background is retried after the server wait and then fails', () async {
    chat.outcomes.addAll([_offline, _slow, _slow, _slow]);
    await outbox.send(message('c1'));

    await outbox.flush(force: true);
    var [entry] = await store.load();
    expect(entry.state, OutboxState.pending);
    expect(entry.nextAttemptAt, t0.add(const Duration(seconds: 7)));

    await outbox.flush(force: true);
    [entry] = await store.load();
    expect(entry.state, OutboxState.failed);
    expect(entry.error?.code, 'slow_mode');
    expect(entry.attempts, 3);
  });

  test('queued messages go out in order and a network failure stops the batch', () async {
    chat.outcomes.addAll([_offline, _offline]);
    await outbox.send(message('c1'));
    final second = await outbox.send(message('c2', second: 1));
    expect(chat.sent, ['c1', 'c1'], reason: 'the earlier message is tried first and the new one waits behind it');
    expect(second, isA<OutboxQueued>());
    expect([for (final m in await store.load()) m.clientId], ['c1', 'c2']);

    chat.outcomes.addAll([_offline]);
    await outbox.flush(force: true);
    expect(chat.sent.skip(2), ['c1']);

    await outbox.flush(force: true);
    expect(chat.sent.skip(3), ['c1', 'c2']);
    expect(await store.load(), isEmpty);
  });

  test('a message is never sent twice at the same time', () async {
    chat.outcomes.add(_offline);
    await outbox.send(message('c1'));
    chat.gate = Completer<void>();

    final flushing = outbox.flush(force: true);
    final again = outbox.send(message('c1'));
    await pumpEventQueue();
    chat.gate!.complete();
    await flushing;

    expect(await again, isA<OutboxBusy>());
    expect(chat.sent, ['c1', 'c1']);
    expect(await store.load(), isEmpty);
    expect(events.whereType<OutboxDelivered>(), hasLength(1));
  });

  test('discarding removes a queued message and tells listeners', () async {
    chat.outcomes.add(_offline);
    await outbox.send(message('c1'));
    await outbox.discard('c1');

    expect(await store.load(), isEmpty);
    expect(events.last, isA<OutboxRemoved>().having((e) => e.clientId, 'clientId', 'c1'));
    await outbox.flush(force: true);
    expect(chat.sent, ['c1']);
  });

  test('reset ignores results that arrive for the previous user', () async {
    chat.gate = Completer<void>();
    final sending = outbox.send(message('c1'));
    await pumpEventQueue();
    outbox.reset();
    chat.gate!.complete();
    expect(await sending, isA<OutboxSent>());
    expect(events.whereType<OutboxDelivered>(), isEmpty);
  });
}
