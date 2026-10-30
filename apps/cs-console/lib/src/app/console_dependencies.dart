import 'package:cs_console/src/app/console_config.dart';
import 'package:cs_console/src/core/api/cs_api.dart';
import 'package:cs_console/src/core/browser/browser_alerts.dart';
import 'package:cs_console/src/core/browser/preferences.dart';
import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/auth/data/auth_repository.dart';
import 'package:cs_console/src/features/customer/data/adapter_client.dart';
import 'package:cs_console/src/features/customer/data/customer_repository.dart';
import 'package:cs_console/src/features/supervisor/data/supervisor_repository.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:cs_console/src/features/tickets/data/ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsoleDependencies {
  ConsoleDependencies({
    required this.config,
    required this.client,
    required this.auth,
    required this.agents,
    required this.tickets,
    required this.customers,
    required this.events,
    required this.alerts,
    required this.preferences,
    required this.supervisor,
    required this.admin,
  });

  factory ConsoleDependencies.create(ConsoleConfig config, SupabaseClient client) {
    final api = CsApi(client);
    final auth = AuthRepository(client.auth, client.realtime);
    return ConsoleDependencies(
      config: config,
      client: client,
      auth: auth,
      agents: AgentRepository(api),
      tickets: TicketRepository(api),
      customers: CustomerRepository(
        api: api,
        adapter: AdapterClient(baseUrl: config.adapterUrl, anonKey: config.anonKey, token: auth.freshToken),
      ),
      events: QueueEvents(client),
      alerts: BrowserAlerts(),
      preferences: const ConsolePreferences(),
      supervisor: SupervisorRepository(api),
      admin: AdminRepository(api, client.functions),
    );
  }

  final ConsoleConfig config;
  final SupabaseClient client;
  final AuthRepository auth;
  final AgentRepository agents;
  final TicketRepository tickets;
  final CustomerRepository customers;
  final QueueEvents events;
  final BrowserAlerts alerts;
  final ConsolePreferences preferences;
  final SupervisorRepository supervisor;
  final AdminRepository admin;
}
