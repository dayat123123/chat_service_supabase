import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/gap_horizon.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/message_index_repository.dart';

const _missingFunction = 'PGRST202';

sealed class GapFillResult {
  const GapFillResult();
}

final class GapFilled extends GapFillResult {
  const GapFilled(this.messages, this.horizon);

  final List<ChatMessage> messages;
  final GapHorizon horizon;
}

final class GapTooLong extends GapFillResult {
  const GapTooLong();
}

class MessageGapFill {
  MessageGapFill(
    this._chat,
    this.roomId, {
    this.maxPages = 5,
    this.overlap = const Duration(seconds: 10),
    this.idPageSize = 1000,
    this.idBatchSize = 100,
    this.afterPageSize = 100,
  });

  final ChatRepository _chat;
  final String roomId;
  final int maxPages;
  final Duration overlap;
  final int idPageSize;
  final int idBatchSize;
  final int afterPageSize;

  bool _indexMissing = false;

  Future<GapFillResult> run(GapHorizon horizon, {GapHorizon? floor, required Set<String> Function() known}) async {
    final back = horizon.back(overlap);
    final start = floor != null && floor.isAfter(back) ? floor : back;
    if (_chat case final MessageIndexRepository index when !_indexMissing) {
      try {
        return await _byIndex(index, start, horizon, known);
      } on CommunityException catch (e) {
        if (e.code != _missingFunction) rethrow;
        _indexMissing = true;
      }
    }
    return _byPages(start, horizon);
  }

  Future<GapFillResult> _byIndex(
    MessageIndexRepository index,
    GapHorizon start,
    GapHorizon horizon,
    Set<String> Function() known,
  ) async {
    final ids = <String>[];
    var newest = horizon;
    var cursor = start.cursor;
    for (var page = 0; ; page++) {
      if (page == maxPages) return const GapTooLong();
      final batch = await index.getMessageIdsAfter(roomId, cursor, limit: idPageSize);
      final last = batch.last;
      ids.addAll(batch.ids);
      newest = newest.later(GapHorizon.parse(last));
      if (!batch.hasMore || last == null) break;
      cursor = last;
    }
    final seen = known();
    final missing = [
      for (final id in ids.toSet())
        if (!seen.contains(id)) id,
    ];
    if (missing.length > maxPages * idBatchSize) return const GapTooLong();
    final messages = <ChatMessage>[];
    for (var i = 0; i < missing.length; i += idBatchSize) {
      final end = i + idBatchSize < missing.length ? i + idBatchSize : missing.length;
      messages.addAll(await index.getMessagesByIds(roomId, missing.sublist(i, end)));
    }
    return GapFilled(messages, newest);
  }

  Future<GapFillResult> _byPages(GapHorizon start, GapHorizon horizon) async {
    final messages = <ChatMessage>[];
    var newest = horizon;
    String? cursor = start.cursor;
    for (var page = 0; cursor != null; page++) {
      if (page == maxPages) return const GapTooLong();
      final batch = await _chat.getMessagesAfter(roomId, cursor, limit: afterPageSize);
      messages.addAll(batch.items);
      for (final message in batch.items) {
        newest = newest.later(GapHorizon.of(message));
      }
      cursor = batch.nextCursor;
    }
    return GapFilled(messages, newest);
  }
}
