import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/receipt.dart';
import 'package:olt_social/src/features/chat/presentation/builders/olt_chat_builders.dart';
import 'package:olt_social/src/features/chat/presentation/builders/olt_chat_details.dart';
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

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.receipt,
    required this.showSender,
    this.startsGroup = true,
  });

  final ChatMessage message;
  final bool mine;
  final ReceiptStatus? receipt;
  final bool showSender;
  final bool startsGroup;

  @override
  Widget build(BuildContext context) {
    final details = _details(context);
    final fallback = message.isSystem ? SupportSystemNotice(message: message) : _DefaultBubble(details: details);
    return buildChatPart(OltChatBuilders.of(context).message, context, details, fallback);
  }

  OltMessageDetails _details(BuildContext context) {
    final cubit = context.read<ChatRoomCubit>();
    final m = message;
    final sender = m.sender;
    final support = m.senderRole != null;
    final sent = m.status == MessageStatus.sent && !m.isDeleted && !m.isSystem;
    late final OltMessageDetails details;
    details = OltMessageDetails(
      message: m,
      isMine: mine,
      receipt: receipt,
      showSender: showSender,
      startsGroup: startsGroup,
      timeLabel: context.oltL10n.clockTime(m.createdAt),
      onReply: sent ? () => cubit.setReplyTo(m) : null,
      onDelete: sent && mine && !support ? () => _delete(context, cubit) : null,
      onReport: sent && !mine && !support
          ? () => showReportDialog(context, target: ReportTarget.message, targetId: m.id)
          : null,
      onRetry: m.status == MessageStatus.failed ? () => cubit.retry(m) : null,
      onSenderTap: sender != null && !support && !mine ? () => OltNavigator.openUser(context, sender) : null,
      onShowActions: sent ? () => _showActions(context, details) : null,
    );
    return details;
  }

  Future<void> _delete(BuildContext context, ChatRoomCubit cubit) async {
    if (await confirmOlt(context, context.oltL10n.deleteMessageConfirm)) await cubit.deleteMessage(message);
  }

  Future<void> _showActions(BuildContext context, OltMessageDetails details) async {
    final l10n = context.oltL10n;
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (handler, icon, label) in [
              (details.onReply, Icons.reply, l10n.replyToMessage),
              (details.onDelete, Icons.delete_outline, l10n.delete),
              (details.onReport, Icons.flag_outlined, l10n.report),
            ])
              if (handler != null)
                ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(sheetContext, handler)),
          ],
        ),
      ),
    );
    if (context.mounted) action?.call();
  }
}

class _DefaultBubble extends StatefulWidget {
  const _DefaultBubble({required this.details});

  final OltMessageDetails details;

  @override
  State<_DefaultBubble> createState() => _DefaultBubbleState();
}

class _DefaultBubbleState extends State<_DefaultBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final m = d.message;
    final support = m.senderRole != null;
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final t = OltSocialTheme.of(context);
    final bg = d.isMine ? t.myBubble : t.otherBubble;
    final fg = d.isMine ? t.onMyBubble : t.onOtherBubble;
    final meta = theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7));
    final width = MediaQuery.sizeOf(context).width * 0.72;
    final senderStyle = theme.textTheme.labelMedium?.copyWith(color: t.link, fontWeight: FontWeight.w700);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: width > 520 ? 520 : width),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(d.isMine ? 16 : 4),
          bottomRight: Radius.circular(d.isMine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.showSender && m.sender != null)
            if (m.isOfficial)
              OfficialSenderLabel(sender: m.sender!, color: t.link)
            else
              GestureDetector(onTap: d.onSenderTap, child: Text(m.sender!.name, style: senderStyle)),
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
              SupportMessageExtras(message: m, color: fg, mine: d.isMine)
            else ...[
              if ((m.body ?? '').isNotEmpty)
                support
                    ? SelectableText(m.body!, style: theme.textTheme.bodyMedium?.copyWith(color: fg))
                    : SocialText(m.body!, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
              if (m.kind == MessageKind.quickReply || m.kind == MessageKind.helpLink)
                SupportMessageExtras(message: m, color: fg, mine: d.isMine),
            ],
          ],
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.editedAt != null && !m.isDeleted) Text('${l10n.edited} ', style: meta),
              Text(d.timeLabel, style: meta),
              if (d.isMine) ...[
                const SizedBox(width: 4),
                ReceiptIcon(receipt: d.receipt, sendStatus: m.status, color: fg.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ],
      ),
    );

    final actions = _hovered && (d.onReply != null || d.onDelete != null)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (d.onReply != null)
                IconButton(
                  tooltip: l10n.replyToMessage,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: d.onReply,
                  icon: const Icon(Icons.reply),
                ),
              if (d.onDelete != null)
                IconButton(
                  tooltip: l10n.delete,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: d.onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          )
        : const SizedBox(width: 72);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: EdgeInsets.only(top: d.showSender ? 8 : 2, bottom: 2),
        child: Row(
          mainAxisAlignment: d.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (d.isMine) actions,
            Flexible(
              child: GestureDetector(
                onTap: d.onRetry,
                onLongPress: d.onShowActions,
                child: Column(
                  crossAxisAlignment: d.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    bubble,
                    if (m.status == MessageStatus.failed)
                      Text(l10n.messageFailed, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ),
            if (!d.isMine) actions,
          ],
        ),
      ),
    );
  }
}
