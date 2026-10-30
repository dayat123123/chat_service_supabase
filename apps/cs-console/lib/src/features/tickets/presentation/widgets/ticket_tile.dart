import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_badges.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:olt_social/olt_social.dart' show OltCountBadge;

const _returnedColor = Color(0xFFB26A00);

class TicketTile extends StatelessWidget {
  const TicketTile({
    super.key,
    required this.ticket,
    required this.topicName,
    required this.settings,
    required this.now,
    required this.selected,
    required this.showOwner,
    required this.meId,
    required this.onTap,
    this.onClaim,
    this.claiming = false,
  });

  final Ticket ticket;
  final String topicName;
  final AgentSettings settings;
  final DateTime now;
  final bool selected;
  final bool showOwner;
  final String meId;
  final VoidCallback onTap;
  final VoidCallback? onClaim;
  final bool claiming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final since = ticket.waitingSince;
    final waited = since == null ? null : now.difference(since);
    final owner = ticket.owner;
    return Material(
      color: selected ? scheme.secondaryContainer.withValues(alpha: 0.6) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: selected ? scheme.primary : priorityColor(ticket.priority).withValues(alpha: 0.7), width: 3),
              bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Text(
                      ticket.customer?.initials ?? '?',
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: ticket.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: ' · $topicName', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  PriorityChip(ticket.priority),
                ],
              ),
              if ((ticket.preview ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '"${ticket.preview}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (ticket.isOpen && (ticket.returnedReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.undo, size: 14, color: _returnedColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n.returnedTicket(ticket.returnedReason!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: _returnedColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(ticket.ticketNumber, style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
                        if (waited != null)
                          WaitChip(
                            label: l10n.waiting(waitLabel(waited)),
                            minutes: waited.inMinutes,
                            warn: settings.waitWarnMinutes,
                            late: settings.waitLateMinutes,
                          ),
                        for (final flag in ticket.flags) FlagChip(flag),
                        if (showOwner && owner != null)
                          Text(
                            l10n.handledBy(owner.id == meId ? l10n.you : owner.displayName),
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (ticket.unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    OltCountBadge(count: ticket.unreadCount),
                  ],
                  if (onClaim != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: claiming ? null : onClaim,
                      child: claiming
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.claim),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
