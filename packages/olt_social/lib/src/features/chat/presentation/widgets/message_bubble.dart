import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/receipt.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/receipt_icon.dart';
import 'package:olt_social/src/features/media/presentation/widgets/attachment_grid.dart';
import 'package:olt_social/src/features/moderation/domain/entities/report.dart';
import 'package:olt_social/src/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_message_parts.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';
import 'package:olt_social/src/shared/presentation/widgets/social_text.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.receipt,
    required this.showSender,
  });

  final ChatMessage message;
  final bool mine;
  final ReceiptStatus? receipt;
  final bool showSender;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    if (m.isSystem) return SupportSystemNotice(message: m);
    final support = m.senderRole != null;
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final t = OltSocialTheme.of(context);
    final cubit = context.read<ChatRoomCubit>();
    final bg = widget.mine ? t.myBubble : t.otherBubble;
    final fg = widget.mine ? t.onMyBubble : t.onOtherBubble;
    final meta = theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7));
    final width = MediaQuery.sizeOf(context).width * 0.72;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: width > 520 ? 520 : width),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(widget.mine ? 16 : 4),
          bottomRight: Radius.circular(widget.mine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showSender && m.sender != null)
            if (m.isOfficial)
              OfficialSenderLabel(sender: m.sender!, color: t.link)
            else if (support)
              Text(m.sender!.name, style: theme.textTheme.labelMedium?.copyWith(color: t.link, fontWeight: FontWeight.w700))
            else
              GestureDetector(
                onTap: () => OltNavigator.openUser(context, m.sender!),
                child: Text(m.sender!.name, style: theme.textTheme.labelMedium?.copyWith(color: t.link, fontWeight: FontWeight.w700)),
              ),
          if (m.replyToId != null)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.08),
                border: Border(left: BorderSide(color: t.link, width: 3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                [if (m.replyToSenderUsername != null) '@${m.replyToSenderUsername}', m.replyToBody ?? l10n.messageDeleted].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
            ),
          if (m.isDeleted)
            Text(l10n.messageDeleted, style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontStyle: FontStyle.italic))
          else ...[
            if (m.attachments.isNotEmpty) AttachmentGrid(attachments: m.attachments, maxHeight: 220),
            if (m.kind == MessageKind.card)
              SupportMessageExtras(message: m, color: fg, mine: widget.mine)
            else ...[
              if ((m.body ?? '').isNotEmpty)
                support
                    ? SelectableText(m.body!, style: theme.textTheme.bodyMedium?.copyWith(color: fg))
                    : SocialText(m.body!, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
              if (m.kind == MessageKind.quickReply || m.kind == MessageKind.helpLink)
                SupportMessageExtras(message: m, color: fg, mine: widget.mine),
            ],
          ],
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.editedAt != null && !m.isDeleted) Text('${l10n.edited} ', style: meta),
              Text(l10n.clockTime(m.createdAt), style: meta),
              if (widget.mine) ...[
                const SizedBox(width: 4),
                ReceiptIcon(receipt: widget.receipt, sendStatus: m.status, color: fg.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ],
      ),
    );

    final actions = _hovered && !m.isDeleted && m.status == MessageStatus.sent
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.replyToMessage,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: () => cubit.setReplyTo(m),
                icon: const Icon(Icons.reply),
              ),
              if (widget.mine && !support)
                IconButton(
                  tooltip: l10n.delete,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          )
        : const SizedBox(width: 72);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: EdgeInsets.only(top: widget.showSender ? 8 : 2, bottom: 2),
        child: Row(
          mainAxisAlignment: widget.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (widget.mine) actions,
            Flexible(
              child: GestureDetector(
                onTap: m.status == MessageStatus.failed ? () => cubit.retry(m) : null,
                onLongPress: m.isDeleted || m.status != MessageStatus.sent ? null : () => _showActions(context),
                child: Column(
                  crossAxisAlignment: widget.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    bubble,
                    if (m.status == MessageStatus.failed)
                      Text(l10n.messageFailed, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ),
            if (!widget.mine) actions,
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<ChatRoomCubit>();
    if (await confirmOlt(context, context.oltL10n.deleteMessageConfirm)) await cubit.deleteMessage(widget.message);
  }

  Future<void> _showActions(BuildContext context) async {
    final l10n = context.oltL10n;
    final cubit = context.read<ChatRoomCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.reply), title: Text(l10n.replyToMessage), onTap: () => Navigator.pop(sheetContext, 'reply')),
            if (widget.message.senderRole != null)
              const SizedBox.shrink()
            else if (widget.mine)
              ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.delete), onTap: () => Navigator.pop(sheetContext, 'delete'))
            else
              ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l10n.report), onTap: () => Navigator.pop(sheetContext, 'report')),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'reply':
        cubit.setReplyTo(widget.message);
      case 'delete':
        await _delete(context);
      case 'report':
        await showReportDialog(context, target: ReportTarget.message, targetId: widget.message.id);
    }
  }
}
