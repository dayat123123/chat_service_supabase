import 'package:cs_console/src/core/browser/browser_alerts.dart';
import 'package:cs_console/src/core/browser/preferences.dart';
import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cs_console/src/features/auth/presentation/pages/auth_frame.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Color statusColor(AgentStatus status, ColorScheme scheme) => switch (status) {
  AgentStatus.online => const Color(0xFF1E9E5A),
  AgentStatus.busy => const Color(0xFFE08A00),
  AgentStatus.onBreak => const Color(0xFF7A6FF0),
  AgentStatus.offline => scheme.outline,
};

String statusLabel(BuildContext context, AgentStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    AgentStatus.online => l10n.statusOnline,
    AgentStatus.busy => l10n.statusBusy,
    AgentStatus.onBreak => l10n.statusBreak,
    AgentStatus.offline => l10n.statusOffline,
  };
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.alerts, required this.preferences, this.navigation, this.trailing = const []});

  final BrowserAlerts alerts;
  final ConsolePreferences preferences;
  final Widget? navigation;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agent = context.watch<AgentCubit>().state;
    final l10n = context.l10n;
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant))),
        child: Row(
          children: [
            const ConsoleLogo(compact: true),
            const SizedBox(width: 24),
            if (navigation != null) ...[navigation!, const SizedBox(width: 24)],
            if (agent.handlesTickets) ...[
              const _StatusMenu(),
              const SizedBox(width: 16),
              Tooltip(
                message: l10n.activeTicketsHint,
                child: Text(
                  l10n.activeTickets(agent.activeTickets, agent.maxActiveTickets),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: agent.atCapacity ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const Spacer(),
            ...trailing,
            _AlertsMenu(alerts: alerts, preferences: preferences),
            const SizedBox(width: 4),
            _AccountMenu(agent: agent),
          ],
        ),
      ),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu();

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentCubit>().state;
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<AgentStatus>(
      tooltip: context.l10n.changeStatus,
      onSelected: (status) async {
        try {
          await context.read<AgentCubit>().setStatus(status);
        } catch (e) {
          if (context.mounted) showError(context, e);
        }
      },
      itemBuilder: (context) => [
        for (final status in AgentStatus.values)
          PopupMenuItem(
            value: status,
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: statusColor(status, scheme)),
                const SizedBox(width: 10),
                Text(statusLabel(context, status)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: statusColor(agent.status, scheme)),
            const SizedBox(width: 8),
            Text(statusLabel(context, agent.status), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _AlertsMenu extends StatefulWidget {
  const _AlertsMenu({required this.alerts, required this.preferences});

  final BrowserAlerts alerts;
  final ConsolePreferences preferences;

  @override
  State<_AlertsMenu> createState() => _AlertsMenuState();
}

class _AlertsMenuState extends State<_AlertsMenu> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mode = widget.preferences.ticketAlerts;
    final permission = widget.alerts.permission;
    return PopupMenuButton<Object>(
      tooltip: l10n.alertsSettings,
      icon: Icon(mode == TicketAlerts.off ? Icons.notifications_off_outlined : Icons.notifications_outlined),
      onSelected: (value) async {
        if (value is TicketAlerts) {
          setState(() => widget.preferences.ticketAlerts = value);
        } else if (value == 'permission') {
          await widget.alerts.requestPermission();
          if (mounted) setState(() {});
        } else if (value == 'test') {
          widget.alerts.play(AlertSound.ticket);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<Object>(enabled: false, child: Text(l10n.alertsNewTickets)),
        for (final (value, label) in [
          (TicketAlerts.all, l10n.alertsAll),
          (TicketAlerts.highPriority, l10n.alertsHighPriority),
          (TicketAlerts.off, l10n.alertsOff),
        ])
          CheckedPopupMenuItem<Object>(value: value, checked: mode == value, child: Text(label)),
        const PopupMenuDivider(),
        if (permission != 'granted')
          PopupMenuItem<Object>(
            value: 'permission',
            child: Text(permission == 'denied' ? l10n.alertsBlocked : l10n.alertsAllowBrowser),
          ),
        PopupMenuItem<Object>(value: 'test', child: Text(l10n.alertsTestSound)),
      ],
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.agent});

  final AgentProfile agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.account,
      onSelected: (value) {
        if (value == 'logout') context.read<AuthCubit>().signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text(_roles(context, agent))),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [const Icon(Icons.logout, size: 18), const SizedBox(width: 10), Text(l10n.signOut)]),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                agent.displayName.isEmpty ? '?' : agent.displayName[0],
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text('${agent.displayName} (${agent.agentCode})', style: theme.textTheme.labelLarge),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  String _roles(BuildContext context, AgentProfile agent) {
    final l10n = context.l10n;
    return [
      if (agent.roles.contains('cs_agent')) l10n.roleAgent,
      if (agent.isSupervisor) l10n.roleSupervisor,
      if (agent.isAdmin) l10n.roleAdmin,
      if (agent.roles.contains('compliance')) l10n.roleCompliance,
    ].join(' · ');
  }
}
