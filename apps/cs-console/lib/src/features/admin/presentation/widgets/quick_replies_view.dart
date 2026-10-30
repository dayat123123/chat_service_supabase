import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/admin_frame.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final _shortcutPattern = RegExp(r'^[a-z0-9_-]{2,32}$');
const quickReplyVariables = '{nama}, {nomor_tiket}, {nama_cs}';

class QuickRepliesView extends StatelessWidget {
  const QuickRepliesView({super.key, required this.admin});

  final AdminRepository admin;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AdminListCubit<QuickReplyConfig>(admin.quickReplies)..load(),
    child: Builder(
      builder: (context) {
        final l10n = context.l10n;
        final cubit = context.read<AdminListCubit<QuickReplyConfig>>();
        return AdminFrame(
          title: l10n.quickRepliesTitle,
          description: l10n.quickRepliesDescription,
          action: FilledButton.icon(
            onPressed: () => _showReplyDialog(context, admin, cubit),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.addQuickReply),
          ),
          children: [
            AdminLoader<QuickReplyConfig>(
              builder: (context, replies) => AdminTable(
                columns: [l10n.colShortcut, l10n.colTitle, l10n.replyBody, l10n.colLanguage, l10n.colStatus, l10n.colUpdated, ''],
                rows: [
                  for (final reply in replies)
                    DataRow(cells: [
                      DataCell(Text('/${reply.shortcut}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(reply.title)),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(reply.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Text(reply.language == 'en' ? l10n.languageEn : l10n.languageId)),
                      DataCell(ActiveBadge(active: reply.active)),
                      DataCell(Text(reply.updatedAt == null ? '–' : stamp(reply.updatedAt!))),
                      DataCell(TextButton(
                        onPressed: () => _showReplyDialog(context, admin, cubit, reply: reply),
                        child: Text(l10n.edit),
                      )),
                    ]),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _showReplyDialog(
  BuildContext context,
  AdminRepository admin,
  AdminListCubit<QuickReplyConfig> cubit, {
  QuickReplyConfig? reply,
}) => showDialog<void>(
  context: context,
  builder: (_) => BlocProvider.value(value: cubit, child: _ReplyDialog(admin: admin, reply: reply)),
);

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({required this.admin, required this.reply});

  final AdminRepository admin;
  final QuickReplyConfig? reply;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  final _form = GlobalKey<FormState>();
  late final _shortcut = TextEditingController(text: widget.reply?.shortcut ?? '');
  late final _title = TextEditingController(text: widget.reply?.title ?? '');
  late final _body = TextEditingController(text: widget.reply?.body ?? '');
  late String _language = widget.reply?.language ?? 'id';
  late bool _active = widget.reply?.active ?? true;
  Object? _error;

  @override
  void dispose() {
    _shortcut.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final reply = QuickReplyConfig(
      id: widget.reply?.id,
      shortcut: _shortcut.text.trim(),
      title: _title.text.trim(),
      body: _body.text.trim(),
      language: _language,
      active: _active,
    );
    try {
      await context.read<AdminListCubit<QuickReplyConfig>>().save((_) => widget.admin.saveQuickReply(reply));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saving = context.select((AdminListCubit<QuickReplyConfig> c) => c.state.saving);
    String? required(String? value) => (value?.trim().isEmpty ?? true) ? l10n.requiredField : null;
    return AlertDialog(
      title: Text(widget.reply == null ? l10n.addQuickReply : l10n.editQuickReplyTitle),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _shortcut,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: l10n.shortcut,
                          prefixText: '/',
                          helperText: l10n.shortcutHint,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => _shortcutPattern.hasMatch(value?.trim() ?? '') ? null : l10n.invalidShortcut,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: _language,
                        decoration: InputDecoration(labelText: l10n.languageLabel, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'id', child: Text(l10n.languageId)),
                          DropdownMenuItem(value: 'en', child: Text(l10n.languageEn)),
                        ],
                        onChanged: (value) => setState(() => _language = value ?? _language),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  maxLength: 80,
                  decoration: InputDecoration(labelText: l10n.replyTitle, border: const OutlineInputBorder()),
                  validator: required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _body,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.replyBody,
                    helperText: '${l10n.variables}: $quickReplyVariables',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: required,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.active),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
                DialogError(_error),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: saving ? null : _submit,
          child: saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
