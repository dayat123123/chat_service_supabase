import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';

const zeroMessageId = '00000000-0000-0000-0000-000000000000';

class GapHorizon {
  const GapHorizon(this.at, this.id, this.cursor);

  factory GapHorizon.of(ChatMessage message) {
    final at = message.createdAt.toUtc();
    return GapHorizon(at, message.id, message.cursor ?? '${at.toIso8601String()}|${message.id}');
  }

  static GapHorizon? parse(String? cursor) {
    if (cursor == null) return null;
    final parts = cursor.split('|');
    final at = DateTime.tryParse(parts.first);
    if (parts.length != 2 || at == null) return null;
    return GapHorizon(at.toUtc(), parts.last, cursor);
  }

  static final origin = GapHorizon(DateTime.utc(1970), zeroMessageId, '1970-01-01T00:00:00.000Z|$zeroMessageId');

  final DateTime at;
  final String id;
  final String cursor;

  bool isAfter(GapHorizon other) {
    final time = at.compareTo(other.at);
    return time > 0 || (time == 0 && id.compareTo(other.id) > 0);
  }

  GapHorizon later(GapHorizon? other) => other != null && other.isAfter(this) ? other : this;

  GapHorizon back(Duration overlap) {
    if (overlap <= Duration.zero) return this;
    final start = at.subtract(overlap);
    return GapHorizon(start, zeroMessageId, '${start.toIso8601String()}|$zeroMessageId');
  }
}
