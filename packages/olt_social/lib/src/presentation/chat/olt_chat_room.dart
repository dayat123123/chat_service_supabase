import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat.dart';
import '../../domain/entities/paged.dart';
import '../compose/olt_compose_post.dart' show mimeFromName;
import '../feed/feed_cubit.dart' show LoadStatus;
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../theme/olt_social_theme.dart';
import '../widgets/common.dart';
import '../widgets/composer_field.dart';
import '../widgets/moderation_actions.dart';
import 'chat_room_cubit.dart';
import 'olt_chat_list.dart' show roomAvatar, roomTitle;

/// Room chat: riwayat pesan, kirim, balas, indikator mengetik, status kirim/baca.
class OltChatRoom extends StatelessWidget {
  const OltChatRoom({super.key, required this.roomId, this.showHeader = true});

  final String roomId;

  /// Sembunyikan header bila aplikasi host sudah menampilkan judul room.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => ChatRoomCubit(chat: deps.chat, media: deps.media, me: deps.ensureSignedIn, roomId: roomId)..load(),
      child: _ChatRoomView(showHeader: showHeader),
    );
  }
}

class _ChatRoomView extends StatelessWidget {
  const _ChatRoomView({required this.showHeader});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatRoomCubit, ChatRoomState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showOltError(context, state.actionError!),
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        final cubit = context.read<ChatRoomCubit>();
        return switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => const OltSkeleton(itemCount: 6),
          LoadStatus.failure => OltErrorView(error: state.error!, onRetry: cubit.load),
          LoadStatus.ready => Column(
            children: [
              if (showHeader) const _RoomHeader(),
              const _ReconnectBanner(),
              const Expanded(child: _MessageList()),
              const _TypingIndicator(),
              const Divider(height: 1),
              const _MessageComposer(),
            ],
          ),
        };
      },
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return BlocBuilder<ChatRoomCubit, ChatRoomState>(
      buildWhen: (a, b) => a.room != b.room || a.typing != b.typing || a.members.length != b.members.length,
      builder: (context, state) {
        final room = state.room;
        if (room == null) return const SizedBox.shrink();
        final cubit = context.read<ChatRoomCubit>();
        final subtitle = state.typing.isNotEmpty
            ? _typingText(l10n, state)
            : switch (room.type) {
                RoomType.direct => '@${room.otherUser?.username ?? ''}',
                RoomType.group => l10n.members(state.members.length),
                RoomType.stock => '${room.name ?? ''} · ${l10n.members(state.members.length)}',
              };
        return Material(
          color: theme.colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: roomAvatar(context, room),
            title: Text(roomTitle(room), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: room.type == RoomType.direct && room.otherUser != null
                ? () => OltNavigator.openUser(context, room.otherUser!)
                : room.type == RoomType.stock && room.stockCode != null
                    ? () => OltNavigator.openStock(context, room.stockCode!)
                    : null,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                switch (action) {
                  case 'mute':
                    await cubit.setMuted(!room.muted);
                  case 'leave':
                    if (await cubit.leave() && context.mounted) await Navigator.of(context).maybePop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'mute', child: Text(room.muted ? l10n.unmute : l10n.mute)),
                if (room.type != RoomType.direct) PopupMenuItem(value: 'leave', child: Text(l10n.leaveRoom)),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _typingText(OltSocialLocalizations l10n, ChatRoomState state) =>
    state.typing.length == 1 ? l10n.typing(state.typing.values.first.name) : l10n.typingMany;

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    final reconnecting = context.select((ChatRoomCubit c) => c.state.connection == RealtimeStatus.reconnecting);
    if (!reconnecting) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onTertiaryContainer),
          ),
          const SizedBox(width: 8),
          Text(context.oltL10n.reconnecting, style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList();

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // ListView terbalik: ujung atas (pesan lama) = maxScrollExtent.
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) context.read<ChatRoomCubit>().loadOlder();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatRoomCubit, ChatRoomState>(
      buildWhen: (a, b) =>
          a.messages != b.messages || a.members != b.members || a.loadingOlder != b.loadingOlder || a.room != b.room,
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return OltEmptyView(message: context.oltL10n.messageHint, icon: Icons.waving_hand_outlined);
        }
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: state.messages.length + (state.loadingOlder ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.messages.length) {
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            }
            final message = state.messages[i];
            final older = i + 1 < state.messages.length ? state.messages[i + 1] : null;
            final grouped = older != null &&
                older.senderId == message.senderId &&
                message.createdAt.difference(older.createdAt).inMinutes < 3;
            return MessageBubble(
              key: ValueKey(message.clientId ?? message.id),
              message: message,
              mine: state.isMine(message),
              read: state.isMine(message) && state.isReadByOthers(message),
              showSender: !grouped && state.room?.type != RoomType.direct && !state.isMine(message),
            );
          },
        );
      },
    );
  }
}

/// Gelembung pesan dengan status kirim/baca dan aksi (hover di desktop,
/// tekan lama di mobile).
class MessageBubble extends StatefulWidget {
  const MessageBubble({super.key, required this.message, required this.mine, required this.read, required this.showSender});

  final ChatMessage message;
  final bool mine;
  final bool read;
  final bool showSender;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final t = OltSocialTheme.of(context);
    final cubit = context.read<ChatRoomCubit>();
    final bg = widget.mine ? t.myBubble : t.otherBubble;
    final fg = widget.mine ? t.onMyBubble : t.onOtherBubble;
    final meta = theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7));

    final statusIcon = !widget.mine
        ? null
        : switch (m.status) {
            MessageStatus.sending => Icon(Icons.schedule, size: 14, color: fg, semanticLabel: l10n.messageSending),
            MessageStatus.failed => Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error, semanticLabel: l10n.messageFailed),
            MessageStatus.sent => Icon(
              widget.read ? Icons.done_all : Icons.done,
              size: 14,
              color: widget.read ? t.link : fg,
              semanticLabel: widget.read ? l10n.messageRead : l10n.messageSent,
            ),
          };

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72 > 520 ? 520 : MediaQuery.sizeOf(context).width * 0.72),
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
            if ((m.body ?? '').isNotEmpty) SocialText(m.body!, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
          ],
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.editedAt != null && !m.isDeleted) Text('${l10n.edited} ', style: meta),
              Text(l10n.clockTime(m.createdAt), style: meta),
              if (statusIcon != null) ...[const SizedBox(width: 4), statusIcon],
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
              if (widget.mine)
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
            if (widget.mine)
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

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final state = context.select((ChatRoomCubit c) => c.state);
    if (state.typing.isEmpty) return const SizedBox(height: 0);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _typingText(context.oltL10n, state),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer();

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => context.read<ChatRoomCubit>().onTextChanged(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    _focus.requestFocus();
    await context.read<ChatRoomCubit>().send(text);
  }

  Future<void> _pickImage() async {
    const group = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await context.read<ChatRoomCubit>().sendImage(bytes, mimeFromName(file.name, file.mimeType));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return BlocConsumer<ChatRoomCubit, ChatRoomState>(
      listenWhen: (a, b) => a.replyTo?.id != b.replyTo?.id && b.replyTo != null,
      listener: (_, _) => _focus.requestFocus(),
      buildWhen: (a, b) => a.replyTo != b.replyTo || a.uploading != b.uploading,
      builder: (context, state) {
        final replyTo = state.replyTo;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyTo != null)
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${replyTo.sender?.name ?? l10n.someone}: ${replyTo.body ?? l10n.attachment}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.cancel,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context.read<ChatRoomCubit>().setReplyTo(null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: l10n.composeAddImage,
                      onPressed: state.uploading ? null : _pickImage,
                      icon: state.uploading
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_photo_alternate_outlined),
                    ),
                    Expanded(
                      child: OltComposerField(
                        controller: _controller,
                        focusNode: _focus,
                        hintText: l10n.messageHint,
                        maxLength: 4000,
                        maxLines: 5,
                        onSubmit: _send,
                        decoration: const InputDecoration(border: OutlineInputBorder(), counterText: '', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(tooltip: l10n.composeSubmit, onPressed: _send, icon: const Icon(Icons.send)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
