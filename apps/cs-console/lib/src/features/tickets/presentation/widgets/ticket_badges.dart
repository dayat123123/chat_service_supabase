import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';

Color priorityColor(String priority) => switch (priority) {
  'P1' => const Color(0xFFD32F2F),
  'P2' => const Color(0xFFEF6C00),
  'P3' => const Color(0xFF1565C0),
  _ => const Color(0xFF607D8B),
};

String statusText(BuildContext context, TicketStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    TicketStatus.open => l10n.statusOpenLabel,
    TicketStatus.claimed => l10n.statusClaimedLabel,
    TicketStatus.waitingCustomer => l10n.statusWaitingLabel,
    TicketStatus.resolved => l10n.statusResolvedLabel,
    TicketStatus.closed => l10n.statusClosedLabel,
  };
}

String flagText(BuildContext context, String flag) {
  final l10n = context.l10n;
  return switch (flag) {
    'complaint' => l10n.flagComplaint,
    'fraud' => l10n.flagFraud,
    'vip' => l10n.flagVip,
    _ => flag,
  };
}

class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        priority,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class FlagChip extends StatelessWidget {
  const FlagChip(this.flag, {super.key});

  final String flag;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (flag) {
      'fraud' => (const Color(0xFFC62828), Icons.gpp_maybe_outlined),
      'complaint' => (const Color(0xFF6A1B9A), Icons.report_outlined),
      _ => (const Color(0xFFB8860B), Icons.star_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(flagText(context, flag), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class WaitChip extends StatelessWidget {
  const WaitChip({super.key, required this.label, required this.minutes, required this.warn, required this.late});

  final String label;
  final int minutes;
  final int warn;
  final int late;

  @override
  Widget build(BuildContext context) {
    final color = minutes < warn
        ? const Color(0xFF2E7D32)
        : minutes < late
            ? const Color(0xFFF9A825)
            : const Color(0xFFD32F2F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
