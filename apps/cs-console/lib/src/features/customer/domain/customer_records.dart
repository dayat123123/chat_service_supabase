import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer_records.freezed.dart';
part 'customer_records.g.dart';

@freezed
abstract class NoteAuthor with _$NoteAuthor {
  const factory NoteAuthor({required String displayName, String? agentCode}) = _NoteAuthor;

  factory NoteAuthor.fromJson(Map<String, dynamic> json) => _$NoteAuthorFromJson(json);
}

@freezed
abstract class AgentNote with _$AgentNote {
  const factory AgentNote({
    required String id,
    @JsonKey(readValue: _ticketOf) String? ticketId,
    @Default('note') String kind,
    required String body,
    required DateTime createdAt,
    NoteAuthor? author,
  }) = _AgentNote;

  factory AgentNote.fromJson(Map<String, dynamic> json) => _$AgentNoteFromJson(json);
}

Object? _ticketOf(Map<dynamic, dynamic> json, String key) => json['ticket_id'] ?? json['session_id'];

@freezed
abstract class TicketHistoryItem with _$TicketHistoryItem {
  const factory TicketHistoryItem({
    required String id,
    String? ticketNumber,
    required String topic,
    required String status,
    @Default(<String>[]) List<String> flags,
    required DateTime createdAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    String? outcome,
    int? rating,
    String? agent,
  }) = _TicketHistoryItem;

  factory TicketHistoryItem.fromJson(Map<String, dynamic> json) => _$TicketHistoryItemFromJson(json);
}

class RevealedField {
  const RevealedField({required this.field, required this.value, required this.until});

  final String field;
  final String value;
  final DateTime until;
}
