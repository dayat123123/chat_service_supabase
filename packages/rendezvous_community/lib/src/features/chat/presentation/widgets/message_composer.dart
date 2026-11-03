import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/core/media/image_mime.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/stock_cards.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_composer_field.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({super.key, this.onChanged, this.leading = const [], this.allowDocuments = false});

  final ValueChanged<String>? onChanged;
  final List<Widget> leading;
  final bool allowDocuments;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  static const _maxLength = 4000;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _ticker;

  void _syncTicker(Duration cooldown) {
    if (cooldown > Duration.zero) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final left = context.read<ChatRoomCubit>().state.cooldownLeft();
        setState(() {});
        if (left == Duration.zero) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      context.read<ChatRoomCubit>().onTextChanged(_controller.text);
      widget.onChanged?.call(_controller.text);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    if (context.read<ChatRoomCubit>().state.cooldownLeft() > Duration.zero) return;
    _controller.clear();
    _focus.requestFocus();
    await context.read<ChatRoomCubit>().send(text);
  }

  Future<void> _pickImage() async {
    const images = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif']);
    const pdf = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: [pdfMimeType],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final file = await openFile(acceptedTypeGroups: widget.allowDocuments ? const [images, pdf] : const [images]);
    if (file == null || !mounted) return;
    final document = widget.allowDocuments && isPdfFile(file.name, file.mimeType);
    if (document && await file.length() > maxSupportDocumentBytes) {
      if (mounted) showCommunityMessage(context, context.communityL10n.documentTooLarge);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final cubit = context.read<ChatRoomCubit>();
    if (document) {
      await cubit.sendDocument(bytes, file.name);
    } else {
      await cubit.sendImage(bytes, mimeFromName(file.name, file.mimeType));
    }
  }

  Future<void> _pickStockCards() async {
    final cubit = context.read<ChatRoomCubit>();
    final codes = await showStockCardPicker(context);
    if (codes != null && codes.isNotEmpty) await cubit.sendStockCards(codes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final builder = CommunityChatBuilders.of(context).composer;
    return BlocConsumer<ChatRoomCubit, ChatRoomState>(
      listenWhen: (a, b) => a.replyTo?.id != b.replyTo?.id && b.replyTo != null,
      listener: (_, _) => _focus.requestFocus(),
      buildWhen: (a, b) =>
          a.replyTo != b.replyTo ||
          a.uploading != b.uploading ||
          a.cooldownUntil != b.cooldownUntil ||
          a.mutedUntil() != b.mutedUntil(),
      builder: (context, state) {
        final replyTo = state.replyTo;
        final cooldown = state.cooldownLeft();
        _syncTicker(cooldown);
        final details = CommunityComposerDetails(
          controller: _controller,
          focusNode: _focus,
          hintText: l10n.messageHint,
          maxLength: _maxLength,
          uploading: state.uploading,
          onSend: _send,
          replyTo: replyTo,
          replyPreview: replyTo == null
              ? null
              : '${replyTo.sender?.name ?? l10n.someone}: ${replyTo.body ?? l10n.attachment}',
          onCancelReply: replyTo == null ? null : () => context.read<ChatRoomCubit>().setReplyTo(null),
          onPickImage: state.uploading ? null : _pickImage,
          allowsDocuments: widget.allowDocuments,
          extraActions: widget.leading,
          cooldown: cooldown,
          onSendStockCard: context.read<ChatRoomCubit>().canSendStockCards ? _pickStockCards : null,
          mutedUntil: state.mutedUntil(),
        );
        return buildChatPart(builder, context, details, _DefaultComposer(details: details));
      },
    );
  }
}

class _DefaultComposer extends StatelessWidget {
  const _DefaultComposer({required this.details});

  final CommunityComposerDetails details;

  @override
  Widget build(BuildContext context) {
    final d = details;
    final l10n = context.communityL10n;
    final replyPreview = d.replyPreview;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyPreview != null)
              Row(
                children: [
                  const Icon(Icons.reply, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      replyPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    visualDensity: VisualDensity.compact,
                    onPressed: d.onCancelReply,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ...d.extraActions,
                if (d.onSendStockCard != null)
                  IconButton(
                    tooltip: l10n.stockCardSend,
                    onPressed: d.onSendStockCard,
                    icon: const Icon(Icons.candlestick_chart_outlined),
                  ),
                IconButton(
                  tooltip: d.allowsDocuments ? l10n.composeAddImageOrPdf : l10n.composeAddImage,
                  onPressed: d.onPickImage,
                  icon: d.uploading
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: CommunityComposerField(
                    controller: d.controller,
                    focusNode: d.focusNode,
                    hintText: d.hintText,
                    maxLength: d.maxLength,
                    maxLines: 5,
                    onSubmit: d.onSend,
                    decoration: const InputDecoration(border: OutlineInputBorder(), counterText: '', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                if (d.muted)
                  Tooltip(
                    message: l10n.roomMutedComposer,
                    child: IconButton.filled(onPressed: null, icon: const Icon(Icons.volume_off_outlined)),
                  )
                else if (d.coolingDown)
                  Tooltip(
                    message: l10n.errorSlowMode(d.cooldownSeconds),
                    child: FilledButton.tonal(onPressed: null, child: Text(l10n.slowModeWait(d.cooldownSeconds))),
                  )
                else
                  IconButton.filled(tooltip: l10n.composeSubmit, onPressed: d.onSend, icon: const Icon(Icons.send)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
