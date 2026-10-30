import 'package:cs_console/src/core/api/cs_api.dart';
import 'package:cs_console/src/features/customer/data/adapter_client.dart';
import 'package:cs_console/src/features/customer/domain/customer_records.dart';

class CustomerRepository {
  CustomerRepository({required this._api, required this._adapter});

  final CsApi _api;
  final AdapterClient _adapter;

  Future<Map<String, dynamic>> profile(String ticketId) async =>
      (await _adapter.get(ticketId, 'profile'))! as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> orders(String ticketId) async =>
      _items(await _adapter.get(ticketId, 'orders', {'limit': '5'}), 'orders');

  Future<Map<String, dynamic>> order(String ticketId, String ref) async =>
      (await _adapter.get(ticketId, 'orders/${Uri.encodeComponent(ref)}'))! as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> cashTransactions(String ticketId) async =>
      _items(await _adapter.get(ticketId, 'cash-transactions', {'limit': '5'}), 'transactions');

  Future<Map<String, dynamic>> cashTransaction(String ticketId, String ref) async =>
      (await _adapter.get(ticketId, 'cash-transactions/${Uri.encodeComponent(ref)}'))! as Map<String, dynamic>;

  Future<Map<String, dynamic>> devices(String ticketId) async =>
      (await _adapter.get(ticketId, 'sessions'))! as Map<String, dynamic>;

  Future<Map<String, dynamic>> security(String ticketId) async =>
      (await _adapter.get(ticketId, 'security'))! as Map<String, dynamic>;

  Future<RevealedField> reveal(String ticketId, {required String field, required String reason}) async {
    final data = (await _adapter.post(ticketId, 'reveal', {'field': field, 'reason': reason}))! as Map<String, dynamic>;
    final seconds = (data['valid_seconds'] as num?)?.toInt() ?? 300;
    return RevealedField(
      field: field,
      value: data['value'] as String? ?? '',
      until: DateTime.now().add(Duration(seconds: seconds)),
    );
  }

  Future<Map<String, dynamic>> secureAccount(String ticketId) async =>
      (await _adapter.post(ticketId, 'secure-account'))! as Map<String, dynamic>;

  Future<List<TicketHistoryItem>> history(String customerId) async => [
    for (final row in await _api.list('customer_history', {'p_customer_id': customerId})) TicketHistoryItem.fromJson(row),
  ];

  Future<List<AgentNote>> notes(String customerId) async => [
    for (final row in await _api.list('notes', {'p_customer_id': customerId})) AgentNote.fromJson(row),
  ];

  Future<AgentNote> addNote({required String body, String? ticketId, String? customerId}) async =>
      AgentNote.fromJson(await _api.object('add_note', {
        'p_body': body,
        'p_ticket_id': ticketId,
        'p_customer_id': customerId,
      }));

  List<Map<String, dynamic>> _items(Object? data, String key) =>
      ((data as Map<String, dynamic>?)?[key] as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
}
