import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/features/agent/presentation/widgets/top_bar.dart';
import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:cs_console/src/features/supervisor/presentation/cubit/supervisor_cubit.dart';
import 'package:cs_console/src/features/supervisor/presentation/widgets/stat_card.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/cubit/ticket_list_cubit.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_badges.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onOpenTicket});

  final void Function(String ticketId) onOpenTicket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<SupervisorCubit, SupervisorState>(
      builder: (context, state) {
        final overview = state.overview;
        if (overview == null) {
          return Center(
            child: state.status == LoadStatus.failure
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorText(context, state.error!)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: context.read<SupervisorCubit>().refresh, child: Text(l10n.retry)),
                    ],
                  )
                : const CircularProgressIndicator(),
          );
        }
        return _Dashboard(overview: overview, stale: state.error != null, onOpenTicket: onOpenTicket);
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.overview, required this.stale, required this.onOpenTicket});

  final SupervisorOverview overview;
  final bool stale;
  final void Function(String ticketId) onOpenTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final settings = context.select((AgentCubit c) => c.state.settings);
    final now = DateTime.now();
    final oldest = overview.oldestOpenAt;
    final waitMinutes = oldest == null ? 0 : now.difference(oldest).inMinutes;
    final limits = overview.thresholds;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.dashboardTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (stale)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(l10n.dashboardStale, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
            Text(
              l10n.updatedAt(clock(overview.generatedAt)),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            IconButton(
              tooltip: l10n.refresh,
              onPressed: context.read<SupervisorCubit>().refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(label: l10n.statOpen, value: number(overview.openCount), icon: Icons.inbox_outlined),
            StatCard(
              label: l10n.statLongestWait,
              value: oldest == null ? '–' : waitLabel(now.difference(oldest)),
              caption: oldest == null ? l10n.statNoQueue : l10n.since(clock(oldest)),
              icon: Icons.schedule,
              color: oldest == null ? null : _waitColor(waitMinutes, settings),
            ),
            StatCard(label: l10n.statActive, value: number(overview.activeCount), icon: Icons.support_agent),
            StatCard(label: l10n.statResolvedToday, value: number(overview.resolvedToday), icon: Icons.task_alt),
            StatCard(
              label: l10n.statAgentsOnline,
              value: '${overview.onlineCount}/${overview.agents.length}',
              icon: Icons.people_outline,
            ),
          ],
        ),
        SectionTitle(l10n.needsAttention),
        LayoutBuilder(
          builder: (context, constraints) {
            final panels = [
              _AttentionPanel(
                title: l10n.overdueTitle(limits.unclaimedMinutes, limits.p1UnclaimedMinutes),
                empty: l10n.overdueEmpty,
                icon: Icons.alarm,
                color: theme.colorScheme.error,
                tickets: overview.overdue,
                urgent: true,
                onOpenTicket: onOpenTicket,
              ),
              _AttentionPanel(
                title: l10n.flaggedTitle,
                empty: l10n.flaggedEmpty,
                icon: Icons.gpp_maybe_outlined,
                color: const Color(0xFF6A1B9A),
                tickets: overview.flaggedOpen,
                onOpenTicket: onOpenTicket,
              ),
              _AttentionPanel(
                title: l10n.offlineOwnedTitle,
                empty: l10n.offlineOwnedEmpty,
                icon: Icons.person_off_outlined,
                color: const Color(0xFFE08A00),
                tickets: overview.offlineOwned,
                showOwner: true,
                onOpenTicket: onOpenTicket,
              ),
            ];
            if (constraints.maxWidth < 960) {
              return Column(
                children: [for (final panel in panels) Padding(padding: const EdgeInsets.only(bottom: 12), child: panel)],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, panel) in panels.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: panel)],
                ],
              ),
            );
          },
        ),
        SectionTitle(l10n.agentsToday),
        _AgentsTable(agents: overview.agents),
      ],
    );
  }
}

Color _waitColor(int minutes, AgentSettings settings) => minutes < settings.waitWarnMinutes
    ? const Color(0xFF2E7D32)
    : minutes < settings.waitLateMinutes
    ? const Color(0xFFF9A825)
    : const Color(0xFFD32F2F);

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.title,
    required this.empty,
    required this.icon,
    required this.color,
    required this.tickets,
    required this.onOpenTicket,
    this.showOwner = false,
    this.urgent = false,
  });

  final String title;
  final String empty;
  final IconData icon;
  final Color color;
  final List<Ticket> tickets;
  final bool showOwner;
  final bool urgent;
  final void Function(String ticketId) onOpenTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tickets.isEmpty ? scheme.outlineVariant : color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: tickets.isEmpty ? scheme.outline : color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (tickets.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${tickets.length}',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(empty, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            )
          else
            for (final ticket in tickets.take(8))
              _AttentionRow(ticket: ticket, showOwner: showOwner, urgent: urgent, onTap: () => onOpenTicket(ticket.id)),
          if (tickets.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                context.l10n.moreTickets(tickets.length - 8),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.ticket, required this.showOwner, required this.urgent, required this.onTap});

  final Ticket ticket;
  final bool showOwner;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final settings = context.select((AgentCubit c) => c.state.settings);
    final topic = context.select((TicketListCubit c) => c.state.topicName(ticket.topic));
    final since = showOwner ? (ticket.lastCustomerMessageAt ?? ticket.claimedAt) : ticket.queuedAt;
    final minutes = since == null ? 0 : DateTime.now().difference(since).inMinutes;
    final owner = ticket.owner;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            PriorityChip(ticket.priority),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${ticket.ticketNumber} · ${ticket.customerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      topic,
                      if (showOwner && owner != null) l10n.ownerOffline(owner.displayName),
                      for (final flag in ticket.flags) flagText(context, flag),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (since != null)
              WaitChip(
                label: waitLabel(DateTime.now().difference(since)),
                minutes: urgent ? settings.waitLateMinutes : minutes,
                warn: settings.waitWarnMinutes,
                late: settings.waitLateMinutes,
              ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AgentsTable extends StatelessWidget {
  const _AgentsTable({required this.agents});

  final List<AgentLoad> agents;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (agents.isEmpty) return Text(l10n.noAgents);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: _table(context, l10n, scheme),
          ),
        ),
      ),
    );
  }

  DataTable _table(BuildContext context, ConsoleLocalizations l10n, ColorScheme scheme) => DataTable(
    headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
    columns: [
      DataColumn(label: Text(l10n.colAgent)),
      DataColumn(label: Text(l10n.colStatus)),
      DataColumn(label: Text(l10n.colActiveTickets), numeric: true),
      DataColumn(label: Text(l10n.colResolvedToday), numeric: true),
      DataColumn(label: Text(l10n.colStatusSince)),
    ],
    rows: [
      for (final agent in agents)
        DataRow(
          cells: [
            DataCell(Text('${agent.displayName} (${agent.agentCode ?? ''})')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: statusColor(agent.status, scheme)),
                  const SizedBox(width: 6),
                  Text(statusLabel(context, agent.status)),
                  if (agent.status != AgentStatus.offline && !agent.connected) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.connectionLostHint,
                      child: Icon(Icons.wifi_off, size: 14, color: scheme.error),
                    ),
                  ],
                ],
              ),
            ),
            DataCell(
              Text(
                '${agent.activeTickets}/${agent.maxActiveTickets}',
                style: TextStyle(color: agent.activeTickets >= agent.maxActiveTickets ? scheme.error : null),
              ),
            ),
            DataCell(Text(number(agent.resolvedToday))),
            DataCell(Text(agent.statusChangedAt == null ? '–' : stamp(agent.statusChangedAt!))),
          ],
        ),
    ],
  );
}
