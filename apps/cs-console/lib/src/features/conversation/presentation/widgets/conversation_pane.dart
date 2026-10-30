import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/cubit/conversation_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/widgets/agent_composer.dart';
import 'package:cs_console/src/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:cs_console/src/features/conversation/presentation/widgets/read_only_bar.dart';
import 'package:cs_console/src/features/customer/data/customer_repository.dart';
import 'package:cs_console/src/features/customer/presentation/widgets/customer_pane.dart';
import 'package:cs_console/src/features/tickets/presentation/cubit/ticket_list_cubit.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/olt_social.dart';
import 'package:url_launcher/url_launcher.dart';

class ConversationPane extends StatelessWidget {
  const ConversationPane({
    super.key,
    required this.staff,
    required this.agents,
    required this.customers,
    required this.infoOpen,
    required this.onToggleInfo,
  });

  final OltSupportStaff staff;
  final AgentRepository agents;
  final CustomerRepository customers;
  final bool infoOpen;
  final VoidCallback onToggleInfo;

  String _notice(BuildContext context, ConversationNotice notice) {
    final l10n = context.l10n;
    return switch (notice) {
      ConversationNotice.claimed => l10n.noticeClaimed,
      ConversationNotice.released => l10n.noticeReleased,
      ConversationNotice.transferRequested => l10n.noticeTransferRequested,
      ConversationNotice.resolved => l10n.noticeResolved,
      ConversationNotice.waiting => l10n.noticeWaiting,
      ConversationNotice.joined => l10n.noticeJoined,
      ConversationNotice.reassigned => l10n.noticeReassigned,
      ConversationNotice.sent => l10n.noticeSent,
      ConversationNotice.stale => l10n.noticeStale,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = context.watch<AgentCubit>().state;
    final topics = context.select((TicketListCubit c) => c.state.topics);
    return MultiBlocListener(
      listeners: [
        BlocListener<ConversationCubit, ConversationState>(
          listenWhen: (a, b) => a.noticeId != b.noticeId,
          listener: (context, state) => showNotice(context, _notice(context, state.notice!)),
        ),
        BlocListener<ConversationCubit, ConversationState>(
          listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
          listener: (context, state) => showError(context, state.actionError!),
        ),
      ],
      child: BlocBuilder<ConversationCubit, ConversationState>(
        builder: (context, state) {
          final ticket = state.ticket;
          if (ticket == null) {
            if (state.status == LoadStatus.failure) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorText(context, state.error!)),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: context.read<ConversationCubit>().load, child: Text(l10n.retry)),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final canReply = state.canReply(me.id);
          final canViewData = canViewCustomerData(ticket, me);
          final topicName = context.select((TicketListCubit c) => c.state.topicName(ticket.topic));
          return CustomerScope(
            ticket: ticket,
            me: me,
            repository: customers,
            child: Builder(
              builder: (context) => Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        ConversationHeader(
                          ticket: ticket,
                          topicName: topicName,
                          me: me,
                          infoOpen: infoOpen,
                          onToggleInfo: onToggleInfo,
                        ),
                        if (state.busy) const LinearProgressIndicator(minHeight: 2),
                        Expanded(
                          child: OltSocialScope(
                            dependencies: staff,
                            child: OltSupportMessageActions(
                              onOpenLink: (uri) => launchUrl(uri, webOnlyWindowName: '_blank'),
                              onOpenCard: canViewData ? (card, ref) => showCardDetail(context, card, ref) : null,
                              child: OltChatRoom(
                                key: ValueKey('${ticket.id}-$canReply'),
                                roomId: ticket.roomId,
                                repository: staff.chat,
                                showHeader: false,
                                composer: canReply
                                    ? AgentComposer(ticket: ticket, me: me, topics: topics, agents: agents)
                                    : ReadOnlyBar(ticket: ticket, me: me, agents: agents),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (infoOpen) SizedBox(width: 340, child: CustomerPane(ticket: ticket, me: me)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
