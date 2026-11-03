import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/storage/offline_cache.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/outbox_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/outbox_repository.dart';

class OutboxRepositoryImpl implements OutboxRepository {
  OutboxRepositoryImpl(this._cache);

  final OfflineCache _cache;

  @override
  Future<List<OutboxMessage>> load() async => [
    for (final row in await _cache.read((store) => store.readOutbox()) ?? const <Map<String, dynamic>>[])
      ?outboxFromJson(row),
  ];

  @override
  Future<void> save(OutboxMessage message) => _cache.write(
    (store) => store.writeOutbox(
      StoredRow(id: message.clientId, group: message.roomId, createdAt: message.createdAt, data: outboxToJson(message)),
    ),
  );

  @override
  Future<void> remove(String clientId) => _cache.write((store) => store.deleteOutbox(clientId));
}

Map<String, dynamic> outboxToJson(OutboxMessage m) => {
  'client_id': m.clientId,
  'room_id': m.roomId,
  'body': m.body,
  'reply_to_id': m.replyToId,
  'reply_to_body': m.replyToBody,
  'reply_to_sender_username': m.replyToSenderUsername,
  'created_at': m.createdAt.toUtc().toIso8601String(),
  'state': m.isFailed ? OutboxState.failed.name : OutboxState.pending.name,
  'attempts': m.attempts,
  'next_attempt_at': m.nextAttemptAt?.toUtc().toIso8601String(),
  if (m.error case final error?)
    'error': {
      'kind': error.kind.name,
      'code': error.code,
      'message': error.message,
      'retry_after_ms': error.retryAfter?.inMilliseconds,
    },
};

OutboxMessage? outboxFromJson(Map<String, dynamic> row) {
  try {
    final error = row['error'] as Map<String, dynamic>?;
    final retryAfter = (error?['retry_after_ms'] as num?)?.toInt();
    return OutboxMessage(
      clientId: row['client_id'] as String,
      roomId: row['room_id'] as String,
      body: row['body'] as String,
      replyToId: row['reply_to_id'] as String?,
      replyToBody: row['reply_to_body'] as String?,
      replyToSenderUsername: row['reply_to_sender_username'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      state: row['state'] == OutboxState.failed.name ? OutboxState.failed : OutboxState.pending,
      attempts: (row['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: DateTime.tryParse(row['next_attempt_at'] as String? ?? ''),
      error: error == null
          ? null
          : CommunityException(
              CommunityErrorKind.values.asNameMap()[error['kind']] ?? CommunityErrorKind.unknown,
              code: error['code'] as String?,
              message: error['message'] as String?,
              retryAfter: retryAfter == null ? null : Duration(milliseconds: retryAfter),
            ),
    );
  } catch (_) {
    return null;
  }
}
