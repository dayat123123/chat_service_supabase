import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class StockRoomBanner extends StatelessWidget {
  const StockRoomBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final stockRoom = context.select((ChatRoomCubit c) => c.state.stockRoom);
    if (stockRoom == null) return const SizedBox.shrink();
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final slow = stockRoom.slowModeActive();
    final pinned = stockRoom.pinnedMessage;
    if (!slow && pinned == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinned != null && !pinned.isDeleted)
          Material(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.push_pin, size: 16, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [l10n.pinnedMessageLabel, if (pinned.sender != null) pinned.sender!.name].join(' · '),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                        ),
                        Text(
                          (pinned.body ?? '').isEmpty ? l10n.attachment : pinned.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (slow)
          Container(
            color: theme.colorScheme.tertiaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 6),
                Text(
                  l10n.slowModeBanner(stockRoom.slowModeSeconds),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class DmRequestNotice extends StatelessWidget {
  const DmRequestNotice({super.key, this.maxMessages = defaultRequestMaxMessages});

  final int maxMessages;

  @override
  Widget build(BuildContext context) {
    final state = context.select((ChatRoomCubit c) => c.state);
    final room = state.room;
    if (room == null || room.type != RoomType.direct) return const SizedBox.shrink();
    final l10n = context.communityL10n;
    final name = room.otherUser?.name ?? l10n.someone;
    final request = state.dmRequest;
    if (request != null) {
      if (request.pendingAsRecipient) {
        return _Notice(
          icon: Icons.mark_email_unread_outlined,
          text: l10n.dmRequestPendingRecipient(name),
          action: TextButton(
            onPressed: () => context.read<ChatRoomCubit>().acceptDmRequest(),
            child: Text(l10n.messageRequestAccept),
          ),
        );
      }
      if (request.limitReached || (request.pendingAsSender && state.dmRequestLimited)) {
        return _Notice(
          icon: Icons.mark_email_unread_outlined,
          text: l10n.dmRequestLimitNotice(name, request.maxMessages),
          strong: true,
        );
      }
      if (request.pendingAsSender) {
        return _Notice(
          icon: Icons.outgoing_mail,
          text: l10n.dmRequestPendingSender(name, request.sent, request.maxMessages),
        );
      }
      return const SizedBox.shrink();
    }
    if (state.dmRequestLimited) {
      return _Notice(
        icon: Icons.mark_email_unread_outlined,
        text: l10n.dmRequestLimitNotice(name, maxMessages),
        strong: true,
      );
    }
    if (state.awaitingReply) {
      return _Notice(icon: Icons.info_outline, text: l10n.dmRequestSenderNotice(name, maxMessages));
    }
    return const SizedBox.shrink();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.strong = false, this.action});

  final IconData icon;
  final String text;
  final bool strong;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = strong ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      color: strong ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
          ),
          ?action,
        ],
      ),
    );
  }
}
