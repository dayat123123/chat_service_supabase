import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/admin_frame.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_badges.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final _codePattern = RegExp(r'^[a-z][a-z0-9_]{1,31}$');

class TopicsView extends StatelessWidget {
  const TopicsView({super.key, required this.admin});

  final AdminRepository admin;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AdminListCubit<TopicConfig>(admin.topics)..load(),
    child: Builder(
      builder: (context) {
        final l10n = context.l10n;
        final cubit = context.read<AdminListCubit<TopicConfig>>();
        return AdminFrame(
          title: l10n.topicsTitle,
          description: l10n.topicsDescription,
          action: FilledButton.icon(
            onPressed: () => _showTopicDialog(context, admin, cubit),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.addTopic),
          ),
          children: [
            FutureBuilder<AdminOptions>(
              future: admin.options(),
              builder: (context, options) => AdminLoader<TopicConfig>(
                builder: (context, topics) => AdminTable(
                  columns: [
                    l10n.colOrder,
                    l10n.colCode,
                    l10n.colName,
                    l10n.colSkill,
                    l10n.colDefaultPriority,
                    l10n.colHelpLink,
                    l10n.colStatus,
                    '',
                  ],
                  numeric: const {0},
                  rows: [
                    for (final topic in topics)
                      DataRow(cells: [
                        DataCell(Text('${topic.sortOrder}')),
                        DataCell(Text(topic.code)),
                        DataCell(Text('${topic.nameId} / ${topic.nameEn}')),
                        DataCell(Text(
                          options.data?.skills.where((s) => s.code == topic.skill).firstOrNull?.name ?? topic.skill,
                        )),
                        DataCell(PriorityChip(topic.defaultPriority)),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(topic.helpUrl ?? '–', overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(ActiveBadge(active: topic.active)),
                        DataCell(TextButton(
                          onPressed: () => _showTopicDialog(context, admin, cubit, topic: topic),
                          child: Text(l10n.edit),
                        )),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _showTopicDialog(
  BuildContext context,
  AdminRepository admin,
  AdminListCubit<TopicConfig> cubit, {
  TopicConfig? topic,
}) => showDialog<void>(
  context: context,
  builder: (_) => BlocProvider.value(value: cubit, child: _TopicDialog(admin: admin, topic: topic)),
);

class _TopicDialog extends StatefulWidget {
  const _TopicDialog({required this.admin, required this.topic});

  final AdminRepository admin;
  final TopicConfig? topic;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.topic?.code ?? '');
  late final _nameId = TextEditingController(text: widget.topic?.nameId ?? '');
  late final _nameEn = TextEditingController(text: widget.topic?.nameEn ?? '');
  late final _helpUrl = TextEditingController(text: widget.topic?.helpUrl ?? '');
  late final _sort = TextEditingController(text: '${widget.topic?.sortOrder ?? 100}');
  late String _skill = widget.topic?.skill ?? 'general';
  late String _priority = widget.topic?.defaultPriority ?? 'P3';
  late bool _active = widget.topic?.active ?? true;
  late final Future<AdminOptions> _options = widget.admin.options();
  Object? _error;

  @override
  void dispose() {
    for (final controller in [_code, _nameId, _nameEn, _helpUrl, _sort]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final topic = TopicConfig(
      code: _code.text.trim(),
      nameId: _nameId.text.trim(),
      nameEn: _nameEn.text.trim(),
      skill: _skill,
      defaultPriority: _priority,
      helpUrl: _helpUrl.text.trim().isEmpty ? null : _helpUrl.text.trim(),
      sortOrder: int.parse(_sort.text.trim()),
      active: _active,
    );
    try {
      await context.read<AdminListCubit<TopicConfig>>().save((_) => widget.admin.saveTopic(topic));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saving = context.select((AdminListCubit<TopicConfig> c) => c.state.saving);
    final editing = widget.topic != null;
    String? name(String? value) => (value?.trim().length ?? 0) >= 2 ? null : l10n.invalidName;
    return AlertDialog(
      title: Text(editing ? l10n.editTopicTitle(widget.topic!.nameId) : l10n.addTopic),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _code,
                  enabled: !editing,
                  autofocus: !editing,
                  decoration: InputDecoration(
                    labelText: l10n.topicCode,
                    helperText: l10n.topicCodeHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => _codePattern.hasMatch(value?.trim() ?? '') ? null : l10n.invalidTopicCode,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameId,
                  maxLength: 40,
                  decoration: InputDecoration(labelText: l10n.topicNameId, border: const OutlineInputBorder()),
                  validator: name,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameEn,
                  maxLength: 40,
                  decoration: InputDecoration(labelText: l10n.topicNameEn, border: const OutlineInputBorder()),
                  validator: name,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<AdminOptions>(
                        future: _options,
                        builder: (context, snapshot) {
                          final skills = snapshot.data?.skills ?? const <Choice>[];
                          return DropdownButtonFormField<String>(
                            initialValue: skills.any((s) => s.code == _skill) ? _skill : null,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l10n.topicSkill, border: const OutlineInputBorder()),
                            items: [for (final skill in skills) DropdownMenuItem(value: skill.code, child: Text(skill.name))],
                            onChanged: (value) => setState(() => _skill = value ?? _skill),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: InputDecoration(labelText: l10n.defaultPriority, border: const OutlineInputBorder()),
                        items: [for (final p in ticketPriorities) DropdownMenuItem(value: p, child: Text(p))],
                        onChanged: (value) => setState(() => _priority = value ?? _priority),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _helpUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.helpUrl,
                    helperText: l10n.helpUrlHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final url = value?.trim() ?? '';
                    return url.isEmpty || url.startsWith('https://') ? null : l10n.helpUrlHint;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _sort,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(labelText: l10n.sortOrder, border: const OutlineInputBorder()),
                        validator: (value) {
                          final order = int.tryParse(value?.trim() ?? '');
                          return order != null && order <= 999 ? null : l10n.numberRange(0, 999);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.topicActive),
                        value: _active,
                        onChanged: (value) => setState(() => _active = value),
                      ),
                    ),
                  ],
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
