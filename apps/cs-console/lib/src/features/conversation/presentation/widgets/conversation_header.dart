import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/conversation/presentation/cubit/conversation_cubit.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_badges.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.ticket,
    required this.topicName,
    required this.me,
    required this.infoOpen,
    required this.onToggleInfo,
  });

  final Ticket ticket;
  final String topicName;
  final AgentProfile me;
  final bool infoOpen;
  final VoidCallback onToggleInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final owner = ticket.owner;
    final canChangePriority = ticket.isActive && (owner?.id == me.id || me.isSupervisor);
    final ownerText = owner == null
        ? statusText(context, ticket.status)
        : l10n.handledBy(owner.id == me.id ? l10n.you : '${owner.displayName} (${owner.agentCode ?? ''})');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SelectableText('#${ticket.ticketNumber}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('· $topicName', style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    if (canChangePriority)
                      PopupMenuButton<String>(
                        tooltip: l10n.priority,
                        onSelected: context.read<ConversationCubit>().setPriority,
                        itemBuilder: (context) => [
                          for (final p in ticketPriorities)
                            CheckedPopupMenuItem(value: p, checked: p == ticket.priority, child: Text(p)),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [PriorityChip(ticket.priority), const Icon(Icons.arrow_drop_down, size: 18)],
                        ),
                      )
                    else
                      PriorityChip(ticket.priority),
                    _StatusChip(ticket.status),
                    for (final flag in ticket.flags) FlagChip(flag),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    ticket.customerName,
                    ownerText,
                    if (ticket.createdAt != null) l10n.createdAt(stamp(ticket.createdAt!)),
                    if (ticket.complaintDueAt != null) l10n.complaintDue(stamp(ticket.complaintDueAt!)),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: infoOpen ? l10n.hideInfo : l10n.showInfo,
            onPressed: onToggleInfo,
            icon: Icon(infoOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      TicketStatus.open => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      TicketStatus.claimed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      TicketStatus.waitingCustomer => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      TicketStatus.resolved || TicketStatus.closed => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(statusText(context, status), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}
