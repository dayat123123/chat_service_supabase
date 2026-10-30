import 'package:web/web.dart' as web;

enum TicketAlerts { all, highPriority, off }

class ConsolePreferences {
  const ConsolePreferences();

  static const _alerts = 'cs-console.ticket-alerts';
  static const _infoPanel = 'cs-console.info-panel';

  TicketAlerts get ticketAlerts =>
      TicketAlerts.values.asNameMap()[_read(_alerts)] ?? TicketAlerts.all;

  set ticketAlerts(TicketAlerts value) => _write(_alerts, value.name);

  bool get infoPanelOpen => _read(_infoPanel) != 'closed';

  set infoPanelOpen(bool value) => _write(_infoPanel, value ? 'open' : 'closed');

  String? _read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  void _write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }
}
