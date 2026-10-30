import 'package:cs_console/src/core/api/cs_api.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class TicketRepository {
  TicketRepository(this._api);

  final CsApi _api;
  List<SupportTopic>? _topics;

  Future<TicketLists> lists() async => TicketLists.fromJson(await _api.object('ticket_lists'));

  Future<List<Ticket>> search(String query) async => [
    for (final row in await _api.list('search_tickets', {'p_query': query})) Ticket.fromJson(row),
  ];

  Future<Ticket> detail(String ticketId) async =>
      Ticket.fromJson(await _api.object('ticket_detail', {'p_ticket_id': ticketId}));

  Future<Ticket> claim(String ticketId) async =>
      Ticket.fromJson(await _api.object('claim_ticket', {'p_ticket_id': ticketId}));

  Future<Ticket> release(Ticket ticket, String reason) async => Ticket.fromJson(await _api.object('release_ticket', {
    'p_ticket_id': ticket.id,
    'p_reason': reason,
    'p_version': ticket.version,
  }));

  Future<void> requestTransfer(Ticket ticket, {required String toAgentId, required String note}) =>
      _api.call('request_transfer', {
        'p_ticket_id': ticket.id,
        'p_to_agent_id': toAgentId,
        'p_note': note,
        'p_version': ticket.version,
      });

  Future<Ticket> respondTransfer(String transferId, {required bool accept, String? reason}) async =>
      Ticket.fromJson(await _api.object('respond_transfer', {
        'p_transfer_id': transferId,
        'p_accept': accept,
        'p_reason': reason,
      }));

  Future<void> cancelTransfer(String transferId) => _api.call('cancel_transfer', {'p_transfer_id': transferId});

  Future<Ticket> waitCustomer(Ticket ticket) async => Ticket.fromJson(
    await _api.object('wait_customer', {'p_ticket_id': ticket.id, 'p_version': ticket.version}),
  );

  Future<Ticket> resolve(Ticket ticket, {required String outcome, required String summary, List<String> tags = const []}) async =>
      Ticket.fromJson(await _api.object('resolve_ticket', {
        'p_ticket_id': ticket.id,
        'p_outcome': outcome,
        'p_summary': summary,
        'p_tags': tags,
        'p_version': ticket.version,
      }));

  Future<Ticket> setPriority(Ticket ticket, String priority) async => Ticket.fromJson(await _api.object(
    'set_ticket_priority',
    {'p_ticket_id': ticket.id, 'p_priority': priority, 'p_version': ticket.version},
  ));

  Future<Ticket> join(String ticketId) async =>
      Ticket.fromJson(await _api.object('join_ticket', {'p_ticket_id': ticketId}));

  Future<Ticket> reassign(String ticketId, {required String toAgentId, required String reason}) async =>
      Ticket.fromJson(await _api.object('reassign_ticket', {
        'p_ticket_id': ticketId,
        'p_to_agent_id': toAgentId,
        'p_reason': reason,
      }));

  Future<Set<String>> members(String roomId) async => {
    for (final row in await _api.list('room_members', {'p_room_id': roomId})) row['user_id'] as String,
  };

  Future<void> sendSpecial(Ticket ticket, {required String kind, String body = '', Map<String, Object?> payload = const {}}) =>
      _api.call('agent_send_message', {
        'p_ticket_id': ticket.id,
        'p_body': body,
        'p_client_id': _uuid.v4(),
        'p_kind': kind,
        'p_payload': payload,
      });

  Future<void> addNote(String ticketId, String body) =>
      _api.call('add_note', {'p_body': body, 'p_ticket_id': ticketId});

  Future<List<QuickReply>> quickReplies(String language) async => [
    for (final row in await _api.list('quick_replies', {'p_language': language})) QuickReply.fromJson(row),
  ];

  Future<List<SupportTopic>> topics() async => _topics ??= [
    for (final row in await _api.list('topics', {'p_language': 'id'})) SupportTopic.fromJson(row),
  ];
}
