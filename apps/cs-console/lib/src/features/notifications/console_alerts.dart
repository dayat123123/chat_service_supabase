import 'package:cs_console/src/core/browser/browser_alerts.dart';
import 'package:cs_console/src/core/browser/preferences.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/l10n/l10n.dart';

class ConsoleAlerts {
  ConsoleAlerts({
    required this._browser,
    required this._preferences,
    required this._l10n,
    required this.agentId,
    required this.supervisor,
    required this._openTicket,
    required this._onSelect,
  });

  final BrowserAlerts _browser;
  final ConsolePreferences _preferences;
  final ConsoleLocalizations _l10n;
  final String agentId;
  final bool supervisor;
  final String? Function() _openTicket;
  final void Function(String ticketId) _onSelect;
  final _overdueSeen = <String>{};

  void handle(QueueEvent event) {
    switch (event) {
      case TicketChanged(event: 'ticket_opened', :final ticketId, :final ticketNumber, :final priority):
        final mode = _preferences.ticketAlerts;
        final urgent = priority == 'P1' || priority == 'P2';
        if (mode == TicketAlerts.off || (mode == TicketAlerts.highPriority && !urgent)) return;
        _alert(
          AlertSound.ticket,
          title: urgent ? _l10n.alertNewUrgentTicket : _l10n.alertNewTicket,
          body: '${ticketNumber ?? ''} · ${priority ?? ''}',
          ticketId: ticketId,
        );
      case CustomerMessaged(:final ticketId, :final status) when status != 'open':
        if (ticketId == _openTicket() && !_browser.pageInBackground) return;
        _alert(AlertSound.message, title: _l10n.alertCustomerMessage, body: _l10n.alertOpenTicket, ticketId: ticketId);
      case TransferChanged(event: 'transfer_requested', :final ticketId, :final ticketNumber, :final byName):
        _alert(
          AlertSound.ticket,
          title: _l10n.alertTransferRequest(byName ?? ''),
          body: ticketNumber ?? '',
          ticketId: ticketId,
          always: true,
        );
      case SupervisorAlert(:final event, :final ticketId, :final ticketNumber) when supervisor:
        _alert(
          AlertSound.ticket,
          title: event == 'fake_cs_reported' ? _l10n.alertFakeCs : _l10n.alertSecretRequest,
          body: ticketNumber ?? '',
          ticketId: ticketId,
          always: true,
        );
      default:
        break;
    }
  }

  void overdue(List<Ticket> tickets) {
    final fresh = [for (final t in tickets) if (!_overdueSeen.contains(t.id)) t];
    _overdueSeen
      ..clear()
      ..addAll(tickets.map((t) => t.id));
    if (fresh.isEmpty) return;
    if (fresh.length > 3) {
      _alert(AlertSound.ticket, title: _l10n.navAttention(fresh.length), body: _l10n.dashboardTitle, ticketId: fresh.first.id, always: true);
      return;
    }
    for (final ticket in fresh) {
      final since = ticket.queuedAt ?? ticket.createdAt;
      _alert(
        AlertSound.ticket,
        title: _l10n.alertOverdueTitle(ticket.priority, since == null ? 0 : DateTime.now().difference(since).inMinutes),
        body: '#${ticket.ticketNumber} · ${ticket.customerName}',
        ticketId: ticket.id,
        always: true,
      );
    }
  }

  void _alert(AlertSound sound, {required String title, required String body, required String ticketId, bool always = false}) {
    _browser.play(sound);
    if (always || _browser.pageInBackground) {
      _browser.notify(title: title, body: body, tag: ticketId, onClick: () => _onSelect(ticketId));
    }
  }
}
