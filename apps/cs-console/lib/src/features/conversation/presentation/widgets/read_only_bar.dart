import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/cubit/conversation_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/widgets/action_dialogs.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/cubit/ticket_list_cubit.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReadOnlyBar extends StatelessWidget {
  const ReadOnlyBar({super.key, required this.ticket, required this.me, required this.agents});

  final Ticket ticket;
  final AgentProfile me;
  final AgentRepository agents;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final busy = context.select((ConversationCubit c) => c.state.busy);
    final online = context.select((AgentCubit c) => c.state.status == AgentStatus.online);
    final cubit = context.read<ConversationCubit>();
    final owner = ticket.owner;
    final (icon, text) = ticket.isOpen
        ? (Icons.visibility_outlined, l10n.previewBanner)
        : ticket.isActive
            ? (Icons.lock_outline, l10n.handledBy('${owner?.displayName ?? ''} (${owner?.agentCode ?? ''})'))
            : (Icons.task_alt, l10n.closedBanner);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          if (ticket.isOpen && me.handlesTickets)
            FilledButton.icon(
              onPressed: busy || !online
                  ? null
                  : () async {
                      await cubit.claim();
                      if (!context.mounted) return;
                      context.read<TicketListCubit>().selectTab(TicketTab.mine);
                      await context.read<AgentCubit>().beat();
                    },
              icon: const Icon(Icons.pan_tool_alt_outlined, size: 18),
              label: Text(l10n.claim),
            ),
          if (ticket.isActive && me.isSupervisor) ...[
            OutlinedButton.icon(
              onPressed: busy ? null : cubit.join,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: Text(l10n.join),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final choice = await pickAgent(
                        context,
                        agents: agents,
                        title: l10n.reassignTitle,
                        noteLabel: l10n.reassignReason,
                        confirm: l10n.reassignConfirm,
                      );
                      if (choice != null) await cubit.reassign(toAgentId: choice.agent.id, reason: choice.note);
                    },
              icon: const Icon(Icons.move_up, size: 18),
              label: Text(l10n.moveTo),
            ),
          ],
        ],
      ),
    );
  }
}
