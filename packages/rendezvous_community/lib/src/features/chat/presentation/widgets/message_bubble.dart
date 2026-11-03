import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/room_moderation.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/receipt_icon.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_moderation.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/shared_post_card.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/stock_cards.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:rendezvous_community/src/features/media/presentation/widgets/attachment_grid.dart';
import 'package:rendezvous_community/src/features/media/presentation/widgets/document_attachments.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_message_parts.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/moderation_notice.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/social_text.dart';

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
    return buildChatPart(CommunityChatBuilders.of(context).message, context, details, fallback);
  }

  CommunityMessageDetails _details(BuildContext context) {
    final cubit = context.read<ChatRoomCubit>();
    final m = message;
    final sender = m.sender;
    final support = m.senderRole != null;
    final sent = m.status == MessageStatus.sent && !m.isDeleted && !m.isSystem;
    final reacting =
        sent &&
        !support &&
        !m.isLocal &&
        cubit.state.supportsReactions &&
        context.communityFeature(CommunityFlags.messageReactions);
    final sharedPostId = m.sharedPostId;
    final room = cubit.state;
    final moderating = room.canModerate(m);
    VoidCallback moderate(RoomModerationAction action) =>
        () => runRoomModeration(context, cubit, m, action);
    late final CommunityMessageDetails details;
    details = CommunityMessageDetails(
      message: m,
      isMine: mine,
      receipt: receipt,
      showSender: showSender,
      startsGroup: startsGroup,
      timeLabel: context.communityL10n.clockTime(m.createdAt),
      onReply: sent ? () => cubit.setReplyTo(m) : null,
      onDelete: sent && mine && !support ? () => _delete(context, cubit) : null,
      onReport: sent && !mine && !support
          ? () => showReportDialog(context, target: ReportTarget.message, targetId: m.id)
          : null,
      onRetry: m.status == MessageStatus.failed ? () => cubit.retry(m) : null,
      onDiscard: m.isLocal && (m.status == MessageStatus.failed || m.status == MessageStatus.pending)
          ? () => cubit.discard(m)
          : null,
      onSenderTap: sender != null && !support && !mine ? () => CommunityNavigator.openUser(context, sender) : null,
      onShowActions: sent ? () => _showActions(context, details) : null,
      reactions: m.reactions,
      reactionChoices: reacting ? context.communityConfig.messageReactions : const [],
      onReact: reacting ? (emoji) => cubit.react(m, emoji) : null,
      onAppeal: mine && m.isHidden && context.communityFeatures != null
          ? () => showCommunityAppealDialog(context, targetType: AppealTargetType.message, targetId: m.id)
          : null,
      onOpenSharedPost: sharedPostId == null ? null : () => CommunityNavigator.openPost(context, sharedPostId),
      senderIsModerator: room.isModerator(m.senderId),
      senderMutedUntil: room.isRoomModerator ? room.memberMutedUntil(m.senderId) : null,
      onHide: moderating ? moderate(RoomModerationAction.hide) : null,
      onMuteSender: moderating ? moderate(RoomModerationAction.mute) : null,
      onEscalate: room.canEscalate(m) ? moderate(RoomModerationAction.escalate) : null,
    );
    return details;
  }

  Future<void> _delete(BuildContext context, ChatRoomCubit cubit) async {
    if (await confirmCommunityAction(context, context.communityL10n.deleteMessageConfirm)) {
      await cubit.deleteMessage(message);
    }
  }

  Future<void> _showActions(BuildContext context, CommunityMessageDetails details) async {
    final l10n = context.communityL10n;
    final onReact = details.onReact;
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      isScrollControlled: details.hasModeration,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onReact != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: ReactionPicker(
                    choices: details.reactionChoices,
                    selected: myReaction(details.reactions),
                    onSelected: (emoji) => Navigator.pop(sheetContext, () => onReact(emoji)),
                  ),
                ),
              for (final (handler, icon, label) in [
                (details.onReply, Icons.reply, l10n.replyToMessage),
                (details.onDelete, Icons.delete_outline, l10n.delete),
                (details.onReport, Icons.flag_outlined, l10n.report),
              ])
                if (handler != null)
                  ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(sheetContext, handler)),
              if (details.hasModeration) ...[
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(l10n.roomModeratorBadge),
                  subtitle: details.senderMutedUntil == null
                      ? null
                      : Text(l10n.roomModMemberMuted(roomModerationTime(l10n, details.senderMutedUntil!))),
                ),
                for (final (handler, icon, label) in [
                  (details.onHide, Icons.visibility_off_outlined, l10n.roomModHide),
                  (details.onMuteSender, Icons.volume_off_outlined, l10n.roomModMute),
                  (details.onEscalate, Icons.outlined_flag, l10n.roomModEscalate),
                ])
                  if (handler != null)
                    ListTile(
                      leading: Icon(icon),
                      title: Text(label),
                      onTap: () => Navigator.pop(sheetContext, handler),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
    if (context.mounted) action?.call();
  }
}

class _DefaultBubble extends StatefulWidget {
  const _DefaultBubble({required this.details});

  final CommunityMessageDetails details;

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
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final t = CommunityTheme.of(context);
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
            else if (d.senderIsModerator)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: d.onSenderTap,
                      child: Text(m.sender!.name, style: senderStyle, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 4),
                  RoomModeratorBadge(color: t.link),
                ],
              )
            else
              GestureDetector(
                onTap: d.onSenderTap,
                child: Text(m.sender!.name, style: senderStyle),
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
                [
                  if (m.replyToSenderUsername != null) '@${m.replyToSenderUsername}',
                  m.replyToBody ?? l10n.messageDeleted,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
            ),
          if (m.isDeleted)
            Text(
              l10n.messageDeleted,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontStyle: FontStyle.italic),
            )
          else ...[
            if (m.attachments.any((a) => !a.isDocument))
              AttachmentGrid(
                attachments: [
                  for (final a in m.attachments)
                    if (!a.isDocument) a,
                ],
                maxHeight: 220,
              ),
            if (m.attachments.any((a) => a.isDocument))
              DocumentAttachments(
                attachments: [
                  for (final a in m.attachments)
                    if (a.isDocument) a,
                ],
                color: fg,
              ),
            if (m.sharedPostId != null)
              SharedPostCard(postId: m.sharedPostId!, sharedPost: m.sharedPost, color: fg, onOpen: d.onOpenSharedPost),
            if (m.stockCodes.isNotEmpty) StockCards(codes: m.stockCodes, isMine: d.isMine),
            if ((m.body ?? '').isNotEmpty)
              support
                  ? SelectableText(m.body!, style: theme.textTheme.bodyMedium?.copyWith(color: fg))
                  : SocialText(
                      m.body!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                      source: 'chat',
                    ),
            if (!support && (m.body ?? '').isNotEmpty)
              LinkPreviewCard(text: m.body!, margin: const EdgeInsets.only(top: 6)),
            if (m.kind == MessageKind.quickReply || m.kind == MessageKind.helpLink)
              SupportMessageExtras(message: m, color: fg, mine: d.isMine),
          ],
          if (d.isMine && !m.isDeleted)
            ModerationNotice(status: m.moderationStatus, compact: true, color: fg, onAppeal: d.onAppeal),
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

    final actions = _hovered && (d.onReply != null || d.onDelete != null || d.onReact != null)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (d.onReact != null)
                PopupMenuButton<String>(
                  tooltip: l10n.reactionAdd,
                  iconSize: 18,
                  icon: const Icon(Icons.add_reaction_outlined),
                  onSelected: d.onReact,
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: ReactionPicker(
                        choices: d.reactionChoices,
                        selected: myReaction(d.reactions),
                        onSelected: (emoji) {
                          Navigator.pop(context);
                          d.onReact!(emoji);
                        },
                      ),
                    ),
                  ],
                ),
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
        : const SizedBox(width: 108);

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
                    if (d.reactions.isNotEmpty) ReactionChips(reactions: d.reactions, onReact: d.onReact),
                    if (m.status == MessageStatus.pending || m.status == MessageStatus.failed)
                      MessageDeliveryNotice(details: d),
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

class MessageDeliveryNotice extends StatelessWidget {
  const MessageDeliveryNotice({super.key, required this.details});

  final CommunityMessageDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final message = details.message;
    final failed = message.status == MessageStatus.failed;
    final error = message.sendError;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: failed ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
    );
    final buttonStyle = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Column(
      crossAxisAlignment: details.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(failed ? l10n.messageFailed : l10n.messagePending, style: style),
        if (failed && error != null) Text(l10n.errorMessage(error), style: style),
        if (details.onRetry != null || details.onDiscard != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (details.onRetry != null)
                TextButton(style: buttonStyle, onPressed: details.onRetry, child: Text(l10n.retry)),
              if (details.onDiscard != null)
                TextButton(style: buttonStyle, onPressed: details.onDiscard, child: Text(l10n.delete)),
            ],
          ),
      ],
    );
  }
}

class ReactionPicker extends StatelessWidget {
  const ReactionPicker({super.key, required this.choices, required this.onSelected, this.selected});

  final List<String> choices;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final emoji in choices)
          InkResponse(
            radius: 24,
            onTap: () => onSelected(emoji),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: emoji == selected ? scheme.primaryContainer : null,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
      ],
    );
  }
}

class ReactionChips extends StatelessWidget {
  const ReactionChips({super.key, required this.reactions, this.onReact});

  final List<MessageReaction> reactions;
  final ValueChanged<String>? onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final r in reactions)
            Material(
              color: r.mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
              shape: StadiumBorder(side: BorderSide(color: r.mine ? scheme.primary : scheme.outlineVariant)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onReact == null ? null : () => onReact!(r.emoji),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text('${r.emoji} ${r.count}', style: theme.textTheme.labelMedium),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
