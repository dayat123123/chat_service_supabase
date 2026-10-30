import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/core/media/image_mime.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_composer_field.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({super.key, this.onChanged, this.leading = const []});

  final ValueChanged<String>? onChanged;
  final List<Widget> leading;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

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
                    ...widget.leading,
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
