import 'package:flutter/material.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

const customChatBuilders = CommunityChatBuilders(
  message: _message,
  composer: _composer,
  roomTile: _roomTile,
  dayDivider: _dayDivider,
);

Widget _message(BuildContext context, CommunityMessageDetails d, Widget fallback) {
  final m = d.message;
  if (m.kind != MessageKind.text || m.isDeleted || m.senderRole != null) return fallback;
  final scheme = Theme.of(context).colorScheme;
  final fg = d.isMine ? scheme.onPrimary : scheme.onSurface;
  final sender = m.sender;
  final bubble = GestureDetector(
    onTap: d.onRetry,
    onLongPress: d.onShowActions,
    onSecondaryTap: d.onShowActions,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: d.isMine ? scheme.primary : scheme.surface,
        border: d.isMine ? null : Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.showSender && sender != null)
            GestureDetector(
              onTap: d.onSenderTap,
              child: Text(
                sender.name,
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
          if (m.replyToBody != null)
            Text(
              '↪ ${m.replyToBody}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12),
            ),
          if (m.attachments.isNotEmpty) AttachmentGrid(attachments: m.attachments, maxHeight: 200),
          if ((m.body ?? '').isNotEmpty) SocialText(m.body!, style: TextStyle(color: fg)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(d.timeLabel, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11)),
              if (d.isMine) ...[
                const SizedBox(width: 4),
                ReceiptIcon(receipt: d.receipt, sendStatus: m.status, color: fg.withValues(alpha: 0.8), size: 14),
              ],
            ],
          ),
        ],
      ),
    ),
  );
  return Padding(
    padding: EdgeInsets.only(top: d.startsGroup ? 10 : 2),
    child: Row(
      mainAxisAlignment: d.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!d.isMine) ...[
          SizedBox(width: 32, child: d.startsGroup ? CommunityAvatar(user: sender, radius: 14) : null),
          const SizedBox(width: 6),
        ],
        Flexible(child: bubble),
      ],
    ),
  );
}

Widget _composer(BuildContext context, CommunityComposerDetails d, Widget fallback) {
  final scheme = Theme.of(context).colorScheme;
  final replyPreview = d.replyPreview;
  return SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyPreview != null)
            Row(
              children: [
                Expanded(child: Text('Membalas $replyPreview', maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(onPressed: d.onCancelReply, icon: const Icon(Icons.close, size: 18)),
              ],
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(28)),
            child: Row(
              children: [
                ...d.extraActions,
                IconButton(
                  onPressed: d.onPickImage,
                  icon: d.uploading
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_circle_outline),
                ),
                Expanded(
                  child: CommunityComposerField(
                    controller: d.controller,
                    focusNode: d.focusNode,
                    hintText: d.hintText,
                    maxLength: d.maxLength,
                    maxLines: 4,
                    onSubmit: d.onSend,
                    decoration: const InputDecoration(border: InputBorder.none, counterText: '', isDense: true),
                  ),
                ),
                IconButton.filled(onPressed: d.onSend, icon: const Icon(Icons.arrow_upward)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _roomTile(BuildContext context, CommunityRoomTileDetails d, Widget fallback) {
  final scheme = Theme.of(context).colorScheme;
  final typing = d.typingText;
  final unread = d.room.unreadCount > 0 && !d.room.muted;
  return Material(
    color: d.selected ? scheme.secondaryContainer : Colors.transparent,
    child: InkWell(
      onTap: d.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CommunityRoomAvatar(room: d.room, online: d.online, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (d.room.pinned) ...[
                        const SizedBox(width: 6),
                        OfficialBadge(color: scheme.primary),
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin, size: 14, color: scheme.outline),
                      ],
                    ],
                  ),
                  Text(
                    typing ?? d.preview ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: typing != null ? scheme.primary : scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(d.timeLabel, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                if (unread)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _dayDivider(BuildContext context, CommunityDayDetails d, Widget fallback) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(d.label, style: Theme.of(context).textTheme.labelSmall),
      ),
      const Expanded(child: Divider()),
    ],
  ),
);
