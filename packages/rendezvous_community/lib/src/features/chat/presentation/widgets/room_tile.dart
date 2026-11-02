import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/receipt_icon.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_visuals.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/typing_text.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_message_parts.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_count_badge.dart';

class RoomTile extends StatelessWidget {
  const RoomTile({
    super.key,
    required this.room,
    required this.me,
    required this.online,
    required this.typing,
    required this.selected,
    required this.onTap,
  });

  final ChatRoom room;
  final UserSummary? me;
  final bool online;
  final List<UserSummary> typing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final preview = room.lastMessagePreview;
    final fromMe = room.lastMessageSenderId != null && room.lastMessageSenderId == me?.id;
    final details = CommunityRoomTileDetails(
      room: room,
      title: roomTitle(room),
      timeLabel: l10n.relativeTime(room.sortTime),
      online: online,
      selected: selected,
      typing: typing,
      onTap: onTap,
      preview: preview == null || !fromMe || room.type == RoomType.direct ? preview : '${l10n.you}: $preview',
      typingText: typing.isEmpty ? null : typingText(l10n, typing, direct: room.type == RoomType.direct),
      lastMessageReceipt: fromMe ? room.lastMessageStatus : null,
    );
    return buildChatPart(
      CommunityChatBuilders.of(context).roomTile,
      context,
      details,
      _DefaultRoomTile(details: details),
    );
  }
}

class _DefaultRoomTile extends StatelessWidget {
  const _DefaultRoomTile({required this.details});

  final CommunityRoomTileDetails details;

  @override
  Widget build(BuildContext context) {
    final d = details;
    final room = d.room;
    final theme = Theme.of(context);
    final t = CommunityTheme.of(context);
    return ListTile(
      selected: d.selected,
      onTap: d.onTap,
      leading: roomAvatar(context, room, online: d.online),
      title: room.type == RoomType.support
          ? Row(
              children: [
                Flexible(child: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                OfficialBadge(color: t.link),
                const SizedBox(width: 4),
                Icon(Icons.push_pin, size: 14, color: theme.colorScheme.outline),
              ],
            )
          : Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: _subtitle(context),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            d.timeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: room.unreadCount > 0 && !room.muted ? t.unreadBadge : null,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (room.muted) Icon(Icons.notifications_off_outlined, size: 14, color: theme.colorScheme.outline),
              CommunityCountBadge(count: room.unreadCount, muted: room.muted),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _subtitle(BuildContext context) {
    final d = details;
    final typing = d.typingText;
    if (typing != null) {
      return Text(
        typing,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: CommunityTheme.of(context).onlineIndicator, fontWeight: FontWeight.w600),
      );
    }
    final preview = d.preview;
    if (preview == null) return null;
    final receipt = d.lastMessageReceipt;
    return Row(
      children: [
        if (receipt != null) ...[
          ReceiptIcon(receipt: receipt, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: d.room.unreadCount > 0 ? const TextStyle(fontWeight: FontWeight.w600) : null,
          ),
        ),
      ],
    );
  }
}
