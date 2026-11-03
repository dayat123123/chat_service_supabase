import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_composer_field.dart';

Future<String?> showEditContentDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required int maxLength,
}) => showDialog<String>(
  context: context,
  builder: (_) => _EditContentDialog(title: title, initial: initial, maxLength: maxLength),
);

class _EditContentDialog extends StatefulWidget {
  const _EditContentDialog({required this.title, required this.initial, required this.maxLength});

  final String title;
  final String initial;
  final int maxLength;

  @override
  State<_EditContentDialog> createState() => _EditContentDialogState();
}

class _EditContentDialogState extends State<_EditContentDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty || text == widget.initial.trim()) return Navigator.pop(context);
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: CommunityComposerField(
          controller: _controller,
          hintText: widget.title,
          maxLength: widget.maxLength,
          minLines: 3,
          maxLines: 10,
          autofocus: true,
          onSubmit: _save,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
