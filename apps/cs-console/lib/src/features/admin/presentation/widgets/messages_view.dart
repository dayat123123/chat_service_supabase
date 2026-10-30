import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/admin_frame.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/settings_support.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';

final _variable = RegExp(r'\{[a-z_]+\}');

class MessagesView extends StatelessWidget {
  const MessagesView({super.key, required this.admin});

  final AdminRepository admin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdminFrame(
      title: l10n.messagesTitle,
      description: l10n.messagesDescription,
      children: [
        AdminLoader<SettingEntry>(
          builder: (context, settings) => Column(
            children: [
              for (final entry in settings.where((s) => s.key.startsWith('messages.')))
                _MessageEditor(key: ValueKey(entry.key), admin: admin, entry: entry),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageEditor extends StatefulWidget {
  const _MessageEditor({super.key, required this.admin, required this.entry});

  final AdminRepository admin;
  final SettingEntry entry;

  @override
  State<_MessageEditor> createState() => _MessageEditorState();
}

class _MessageEditorState extends State<_MessageEditor> {
  late Map<String, String> _saved = _texts(widget.entry.value);
  late final _id = TextEditingController(text: _saved['id']);
  late final _en = TextEditingController(text: _saved['en']);

  static Map<String, String> _texts(Object? value) => {
    'id': value is Map ? '${value['id'] ?? ''}' : '',
    'en': value is Map ? '${value['en'] ?? ''}' : '',
  };

  bool get _changed => _id.text != _saved['id'] || _en.text != _saved['en'];

  bool get _valid => [_id.text, _en.text].every((t) => t.trim().length >= 2 && t.trim().length <= 500);

  @override
  void dispose() {
    _id.dispose();
    _en.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = {'id': _id.text.trim(), 'en': _en.text.trim()};
    if (await saveSettings(context, widget.admin, {widget.entry.key: value}) && mounted) {
      setState(() => _saved = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final variables = {
      for (final text in _texts(widget.entry.value).values) ..._variable.allMatches(text).map((m) => m.group(0)!),
    };
    return SettingsCard(
      title: widget.entry.description ?? widget.entry.key,
      subtitle: variables.isEmpty ? l10n.noVariables : '${l10n.variables}: ${variables.join(', ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (controller, label) in [(_id, l10n.messageId), (_en, l10n.messageEn)]) ...[
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              SaveButton(label: l10n.save, onPressed: _changed && _valid ? _save : null),
              const SizedBox(width: 12),
              Expanded(child: ChangedBy(entry: widget.entry)),
            ],
          ),
        ],
      ),
    );
  }
}
