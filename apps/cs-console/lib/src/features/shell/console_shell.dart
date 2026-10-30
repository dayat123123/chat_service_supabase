import 'dart:async';

import 'package:cs_console/src/app/console_dependencies.dart';
import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/admin/presentation/pages/settings_page.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/features/agent/presentation/widgets/top_bar.dart';
import 'package:cs_console/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/cubit/conversation_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/widgets/conversation_pane.dart';
import 'package:cs_console/src/features/notifications/console_alerts.dart';
import 'package:cs_console/src/features/shell/idle_guard.dart';
import 'package:cs_console/src/features/shell/session_events.dart';
import 'package:cs_console/src/features/supervisor/presentation/cubit/report_cubit.dart';
import 'package:cs_console/src/features/supervisor/presentation/cubit/supervisor_cubit.dart';
import 'package:cs_console/src/features/supervisor/presentation/pages/dashboard_page.dart';
import 'package:cs_console/src/features/supervisor/presentation/pages/reports_page.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:cs_console/src/features/tickets/presentation/cubit/ticket_list_cubit.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_column.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/olt_social.dart';

enum ConsoleSection { tickets, dashboard, reports, settings }

class ConsoleShell extends StatefulWidget {
  const ConsoleShell({super.key, required this.agent, required this.deps});

  final AgentProfile agent;
  final ConsoleDependencies deps;

  @override
  State<ConsoleShell> createState() => _ConsoleShellState();
}

class _ConsoleShellState extends State<ConsoleShell> {
  late final AgentProfile _me = widget.agent;
  late final List<ConsoleSection> _sections = [
    if (_me.handlesTickets) ConsoleSection.tickets,
    if (_me.isSupervisor) ConsoleSection.dashboard,
    if (_me.isSupervisor || _me.isAdmin) ConsoleSection.reports,
    if (_me.isAdmin) ConsoleSection.settings,
  ];
  late ConsoleSection? _section = _me.handlesTickets || !_me.isAdmin ? _sections.firstOrNull : ConsoleSection.settings;
  late final OltSupportStaff _staff = OltSupportStaff(
    client: widget.deps.client,
    supabaseUrl: widget.deps.config.apiUrl,
    anonKey: widget.deps.config.anonKey,
    me: UserSummary(id: _me.id, username: _me.agentCode, displayName: _me.displayName),
  );
  late final AgentCubit _agent = AgentCubit(widget.deps.agents, _me, onRevoked: _revoked)..start();
  SessionEvents? _events;
  TicketListCubit? _tickets;
  SupervisorCubit? _supervisor;
  ReportCubit? _reports;
  late bool _infoOpen = widget.deps.preferences.infoPanelOpen;
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    final deps = widget.deps;
    if (_me.handlesTickets) {
      final events = _events = SessionEvents(deps.events.watch(_me.id));
      _tickets = TicketListCubit(tickets: deps.tickets, events: events.stream)..start();
      if (_me.isSupervisor) _supervisor = SupervisorCubit(supervisor: deps.supervisor, events: events.stream)..start();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final alerts = ConsoleAlerts(
        browser: deps.alerts,
        preferences: deps.preferences,
        l10n: context.l10n,
        agentId: _me.id,
        supervisor: _me.isSupervisor,
        openTicket: () => _section == ConsoleSection.tickets ? _tickets?.state.selectedId : null,
        onSelect: _openTicket,
      );
      final events = _events;
      if (events != null) {
        _subscriptions.add(events.stream.listen((event) {
          alerts.handle(event);
          _inAppNotice(event);
          if (event is TicketChanged || event is TransferChanged) unawaited(_agent.beat());
        }));
      }
      final supervisor = _supervisor;
      if (supervisor != null) {
        _subscriptions.add(supervisor.stream.listen((state) {
          final overview = state.overview;
          if (overview != null) alerts.overdue(overview.overdue);
        }));
      }
    });
  }

  void _revoked() {
    if (mounted) unawaited(context.read<AuthCubit>().signOut(reason: SignOutReason.notStaff));
  }

  void _openTicket(String ticketId) {
    final tickets = _tickets;
    if (tickets == null) return;
    tickets.select(ticketId);
    _show(ConsoleSection.tickets);
  }

  void _show(ConsoleSection section) {
    if (section == ConsoleSection.reports && _reports == null) {
      _reports = ReportCubit(widget.deps.supervisor)..reload();
    }
    setState(() => _section = section);
  }

  void _inAppNotice(QueueEvent event) {
    final l10n = context.l10n;
    final message = switch (event) {
      TransferChanged(event: 'transfer_rejected', :final byName, :final ticketNumber) =>
        l10n.transferRejected(byName ?? '', ticketNumber ?? ''),
      TransferChanged(event: 'transfer_expired', :final ticketNumber) => l10n.transferExpired(ticketNumber ?? ''),
      TransferChanged(event: 'transfer_cancelled', :final ticketNumber, :final reason) =>
        l10n.transferCancelled(ticketNumber ?? '', reason ?? ''),
      _ => null,
    };
    if (message != null && mounted) showNotice(context, message);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_tickets?.close());
    unawaited(_supervisor?.close());
    unawaited(_reports?.close());
    unawaited(_agent.close());
    unawaited(_events?.dispose());
    super.dispose();
  }

  void _toggleInfo() {
    setState(() => _infoOpen = !_infoOpen);
    widget.deps.preferences.infoPanelOpen = _infoOpen;
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    final tickets = _tickets;
    final supervisor = _supervisor;
    final reports = _reports;
    return IdleGuard(
      timeout: Duration(minutes: _me.settings.idleLogoutMinutes),
      onTimeout: () => context.read<AuthCubit>().signOut(reason: SignOutReason.idle),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _agent),
          if (tickets != null) BlocProvider.value(value: tickets),
          if (supervisor != null) BlocProvider.value(value: supervisor),
          if (reports != null) BlocProvider.value(value: reports),
        ],
        child: Scaffold(
          body: Column(
            children: [
              TopBar(
                alerts: deps.alerts,
                preferences: deps.preferences,
                navigation: _sections.length > 1 ? _navigation() : null,
              ),
              Expanded(
                child: switch (_section) {
                  ConsoleSection.tickets => _ticketsView(deps),
                  ConsoleSection.dashboard => DashboardPage(onOpenTicket: _openTicket),
                  ConsoleSection.reports => const ReportsPage(),
                  ConsoleSection.settings => SettingsPage(admin: deps.admin),
                  null => const _NoAccess(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigation() {
    Widget nav(int attention) =>
        _SectionNav(sections: _sections, current: _section, attention: attention, onSelect: _show);
    final supervisor = _supervisor;
    if (supervisor == null) return nav(0);
    return BlocSelector<SupervisorCubit, SupervisorState, int>(
      bloc: supervisor,
      selector: (state) => state.overview?.attentionCount ?? 0,
      builder: (context, attention) => nav(attention),
    );
  }

  Widget _ticketsView(ConsoleDependencies deps) => Row(
    children: [
      const SizedBox(width: 380, child: TicketColumn()),
      const VerticalDivider(width: 1),
      Expanded(
        child: BlocSelector<TicketListCubit, TicketListState, String?>(
          selector: (state) => state.selectedId,
          builder: (context, ticketId) {
            if (ticketId == null) return const _NoSelection();
            return BlocProvider(
              key: ValueKey(ticketId),
              create: (_) => ConversationCubit(
                tickets: deps.tickets,
                staff: _staff,
                agent: () => _agent.state,
                events: _events!.stream,
                ticketId: ticketId,
              )..load(),
              child: ConversationPane(
                staff: _staff,
                agents: deps.agents,
                customers: deps.customers,
                infoOpen: _infoOpen,
                onToggleInfo: _toggleInfo,
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.sections, required this.current, required this.attention, required this.onSelect});

  final List<ConsoleSection> sections;
  final ConsoleSection? current;
  final int attention;
  final void Function(ConsoleSection section) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _NavButton(
              selected: section == current,
              onPressed: () => onSelect(section),
              icon: switch (section) {
                ConsoleSection.tickets => Icons.confirmation_number_outlined,
                ConsoleSection.dashboard => Icons.space_dashboard_outlined,
                ConsoleSection.reports => Icons.bar_chart,
                ConsoleSection.settings => Icons.settings_outlined,
              },
              label: switch (section) {
                ConsoleSection.tickets => l10n.navTickets,
                ConsoleSection.dashboard => l10n.navDashboard,
                ConsoleSection.reports => l10n.navReports,
                ConsoleSection.settings => l10n.navSettings,
              },
              badge: section == ConsoleSection.dashboard && attention > 0 ? attention : null,
              badgeHint: l10n.navAttention(attention),
            ),
          ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.selected,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.badge,
    required this.badgeHint,
  });

  final bool selected;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final int? badge;
  final String badgeHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = badge;
    final button = TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: selected ? scheme.secondaryContainer : null,
        foregroundColor: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: onPressed,
      icon: count == null
          ? Icon(icon, size: 18)
          : Badge(label: Text('$count'), child: Icon(icon, size: 18)),
      label: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
    );
    return Semantics(
      selected: selected,
      child: count == null ? button : Tooltip(message: badgeHint, child: button),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) => Center(child: Text(context.l10n.noConsoleAccess));
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(context.l10n.selectTicket, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
