import 'package:rendezvous_community/src/features/chat/domain/entities/outbox_message.dart';

abstract interface class OutboxRepository {
  Future<List<OutboxMessage>> load();

  Future<void> save(OutboxMessage message);

  Future<void> remove(String clientId);
}
