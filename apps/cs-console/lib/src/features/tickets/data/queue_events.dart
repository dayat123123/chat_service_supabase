import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

sealed class QueueEvent {
  const QueueEvent();
}

class TicketChanged extends QueueEvent {
  const TicketChanged({
    required this.event,
    required this.ticketId,
    this.ticketNumber,
    this.status,
    this.priority,
    this.ownerId,
    this.ownerName,
    this.topic,
  });

  final String event;
  final String ticketId;
  final String? ticketNumber;
  final String? status;
  final String? priority;
  final String? ownerId;
  final String? ownerName;
  final String? topic;
}

class CustomerMessaged extends QueueEvent {
  const CustomerMessaged({required this.ticketId, this.status});

  final String ticketId;
  final String? status;
}

class TransferChanged extends QueueEvent {
  const TransferChanged({required this.event, required this.ticketId, this.ticketNumber, this.byName, this.reason});

  final String event;
  final String ticketId;
  final String? ticketNumber;
  final String? byName;
  final String? reason;
}

class SupervisorAlert extends QueueEvent {
  const SupervisorAlert({required this.event, required this.ticketId, this.ticketNumber, this.agentCode});

  final String event;
  final String ticketId;
  final String? ticketNumber;
  final String? agentCode;
}

class ColleagueStatusChanged extends QueueEvent {
  const ColleagueStatusChanged({required this.agentId, required this.status});

  final String agentId;
  final String status;
}

class QueueReconnected extends QueueEvent {
  const QueueReconnected();
}

class QueueEvents {
  QueueEvents(this._client);

  final SupabaseClient _client;

  Stream<QueueEvent> watch(String agentId) => Stream.multi((multi) {
    final reconnected = <RealtimeChannel, bool>{};

    void onStatus(RealtimeChannel channel, RealtimeSubscribeStatus status) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (reconnected[channel] ?? false) multi.add(const QueueReconnected());
      } else {
        reconnected[channel] = true;
      }
    }

    final queue = _client.channel('cs:queue', opts: const RealtimeChannelConfig(private: true));
    queue
      ..onBroadcast(event: 'ticket', callback: (p) => _ticket(_unwrap(p), multi.add))
      ..onBroadcast(event: 'alert', callback: (p) => _alert(_unwrap(p), multi.add))
      ..onBroadcast(event: 'agent', callback: (p) {
        final data = _unwrap(p);
        final id = data['agent_id'] as String?;
        if (id != null) multi.add(ColleagueStatusChanged(agentId: id, status: data['status'] as String? ?? 'offline'));
      })
      ..subscribe((status, _) => onStatus(queue, status));

    final mine = _client.channel('cs:agent:$agentId', opts: const RealtimeChannelConfig(private: true));
    mine
      ..onBroadcast(event: 'ticket', callback: (p) => _ticket(_unwrap(p), multi.add))
      ..onBroadcast(event: 'transfer', callback: (p) {
        final data = _unwrap(p);
        final ticketId = data['ticket_id'] as String?;
        if (ticketId == null) return;
        multi.add(TransferChanged(
          event: data['event'] as String? ?? '',
          ticketId: ticketId,
          ticketNumber: data['ticket_number'] as String?,
          byName: (data['from_name'] ?? data['by_name']) as String?,
          reason: data['reason'] as String?,
        ));
      })
      ..subscribe((status, _) => onStatus(mine, status));

    multi.onCancel = () async {
      await _client.removeChannel(queue);
      await _client.removeChannel(mine);
    };
  });

  static void _ticket(Map<String, dynamic> data, void Function(QueueEvent) add) {
    final ticketId = data['ticket_id'] as String?;
    if (ticketId == null) return;
    final event = data['event'] as String? ?? '';
    if (event == 'ticket_message') {
      add(CustomerMessaged(ticketId: ticketId, status: data['status'] as String?));
      return;
    }
    add(TicketChanged(
      event: event,
      ticketId: ticketId,
      ticketNumber: data['ticket_number'] as String?,
      status: data['status'] as String?,
      priority: data['priority'] as String?,
      ownerId: data['owner_id'] as String?,
      ownerName: data['owner_name'] as String?,
      topic: data['topic'] as String?,
    ));
  }

  static void _alert(Map<String, dynamic> data, void Function(QueueEvent) add) {
    final ticketId = data['ticket_id'] as String?;
    if (ticketId == null) return;
    add(SupervisorAlert(
      event: data['event'] as String? ?? '',
      ticketId: ticketId,
      ticketNumber: data['ticket_number'] as String?,
      agentCode: data['agent_code'] as String?,
    ));
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> payload) {
    final inner = payload['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : payload;
  }
}
