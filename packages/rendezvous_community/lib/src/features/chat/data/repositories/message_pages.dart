import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';

Paged<ChatMessage> newerPage(List<ChatMessage> items, int limit) {
  if (items.isEmpty || items.length < limit) return Paged(items);
  final newest = items.reduce((a, b) => b.createdAt.isAfter(a.createdAt) ? b : a);
  return Paged(items, nextCursor: newest.cursor);
}
