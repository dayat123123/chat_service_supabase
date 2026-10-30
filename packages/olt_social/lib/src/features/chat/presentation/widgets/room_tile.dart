import 'package:flutter/material.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/receipt_icon.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/room_visuals.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/typing_text.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_message_parts.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_count_badge.dart';

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
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: roomAvatar(context, room, online: online),
      title: room.type == RoomType.support
          ? Row(
              children: [
                Flexible(child: Text(roomTitle(room), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                OfficialBadge(color: OltSocialTheme.of(context).link),
                const SizedBox(width: 4),
                Icon(Icons.push_pin, size: 14, color: theme.colorScheme.outline),
              ],
            )
          : Text(roomTitle(room), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: typing.isNotEmpty ? _typingLine(context) : _previewLine(context),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            l10n.relativeTime(room.sortTime),
            style: theme.textTheme.bodySmall?.copyWith(
              color: room.unreadCount > 0 && !room.muted ? OltSocialTheme.of(context).unreadBadge : null,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (room.muted) Icon(Icons.notifications_off_outlined, size: 14, color: theme.colorScheme.outline),
              OltCountBadge(count: room.unreadCount, muted: room.muted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typingLine(BuildContext context) {
    final text = typingText(context.oltL10n, typing, direct: room.type == RoomType.direct);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: OltSocialTheme.of(context).onlineIndicator, fontWeight: FontWeight.w600),
    );
  }

  Widget? _previewLine(BuildContext context) {
    final preview = room.lastMessagePreview;
    if (preview == null) return null;
    final l10n = context.oltL10n;
    final fromMe = room.lastMessageSenderId != null && room.lastMessageSenderId == me?.id;
    final style = room.unreadCount > 0 ? const TextStyle(fontWeight: FontWeight.w600) : null;
    final text = fromMe && room.type != RoomType.direct ? '${l10n.you}: $preview' : preview;
    return Row(
      children: [
        if (fromMe && room.lastMessageStatus != null) ...[
          ReceiptIcon(receipt: room.lastMessageStatus, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 4),
        ],
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
  }
}
