import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_builders.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/support/domain/entities/support_ticket.dart';
import 'package:rendezvous_community/src/features/support/presentation/cubit/support_cubit.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/community_support_tickets.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_dialogs.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_message_parts.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

String supportStatusText(CommunityLocalizations l10n, SupportTicket ticket) => switch (ticket.status) {
  SupportStatus.open => [
    l10n.supportStatusWaiting,
    if ((ticket.queueAhead ?? 0) > 0) l10n.supportQueueAhead(ticket.queueAhead!),
  ].join(' · '),
  SupportStatus.claimed => l10n.supportStatusHandled(ticket.agent?.displayName ?? ''),
  SupportStatus.waitingCustomer => l10n.supportStatusWaitingYou,
  SupportStatus.resolved => l10n.supportStatusResolved,
  SupportStatus.closed => l10n.supportStatusClosed,
};

enum _MenuAction { complaint, reportFake, endChat, myTickets, newTicket }

Color _statusColor(ColorScheme scheme, SupportStatus status) => switch (status) {
  SupportStatus.open => scheme.tertiary,
  SupportStatus.claimed => scheme.primary,
  SupportStatus.waitingCustomer => scheme.secondary,
  SupportStatus.resolved || SupportStatus.closed => scheme.outline,
};

class SupportHeader extends StatelessWidget {
  const SupportHeader({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final state = context.watch<SupportCubit>().state;
    final home = state.home;
    final ticket = state.ticket;
    final active = ticket?.isActive ?? false;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.support_agent),
            ),
            title: Row(
              children: [
                Flexible(child: Text(home?.supportName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                OfficialBadge(color: theme.colorScheme.primary),
              ],
            ),
            subtitle: ticket == null
                ? Text(l10n.supportOfficialChannel)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${ticket.ticketNumber} · ${ticket.topicName ?? ticket.topic}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        supportStatusText(l10n, ticket),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _statusColor(theme.colorScheme, ticket.status),
                        ),
                      ),
                    ],
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<_MenuAction>(
                  tooltip: l10n.supportMenu,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (action) => _onAction(context, action),
                  itemBuilder: (context) => [
                    if (active && ticket?.complaintReceivedAt == null)
                      PopupMenuItem(value: _MenuAction.complaint, child: Text(l10n.supportComplaint)),
                    PopupMenuItem(value: _MenuAction.reportFake, child: Text(l10n.supportReportFake)),
                    if (!active) PopupMenuItem(value: _MenuAction.newTicket, child: Text(l10n.supportNewTicket)),
                    PopupMenuItem(value: _MenuAction.myTickets, child: Text(l10n.supportMyTickets)),
                    if (active) PopupMenuItem(value: _MenuAction.endChat, child: Text(l10n.supportEndChat)),
                  ],
                ),
                if (onClose != null) IconButton(tooltip: l10n.close, onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
          ),
          if (state.busy) const LinearProgressIndicator(minHeight: 2),
          if (home != null && !home.serviceOpen && home.nextOpenAt != null)
            _Banner(
              text: l10n.supportOutOfHours('${l10n.dayLabel(home.nextOpenAt!)} ${l10n.clockTime(home.nextOpenAt!)}'),
            ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _MenuAction action) async {
    final l10n = context.communityL10n;
    final cubit = context.read<SupportCubit>();
    switch (action) {
      case _MenuAction.complaint:
        if (await confirmSupport(context, message: l10n.supportComplaintConfirm, confirm: l10n.supportComplaint)) {
          await cubit.fileComplaint();
        }
      case _MenuAction.reportFake:
        final description = await askFakeCsReport(context);
        if (description != null) await cubit.reportFakeCs(description);
      case _MenuAction.endChat:
        if (await confirmSupport(context, message: l10n.supportEndConfirm, confirm: l10n.supportEndChat)) {
          await cubit.closeTicket();
        }
      case _MenuAction.newTicket:
        cubit.pickTopic();
      case _MenuAction.myTickets:
        if (!context.mounted) return;
        final deps = CommunityScope.of(context);
        final carry = carryCommunityBuilders(context);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => carry(
              CommunityScope(
                dependencies: deps,
                child: Scaffold(
                  appBar: AppBar(title: Text(l10n.supportMyTickets)),
                  body: const CommunitySupportTickets(),
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }
}
