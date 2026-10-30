import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/accounts_view.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/admin_frame.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final _emailPattern = RegExp(r'^[^\s@]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,24}$');

Future<void> showAccountDialog(
  BuildContext context, {
  required AdminRepository admin,
  required AdminListCubit<StaffAccount> cubit,
  StaffAccount? account,
}) async {
  final me = context.read<AgentCubit>().state.id;
  final created = await showDialog<CreatedAccount>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _AccountDialog(admin: admin, account: account, me: me),
    ),
  );
  if (created != null && context.mounted) {
    await showDialog<void>(context: context, builder: (_) => _CreatedDialog(created: created));
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.admin, required this.account, required this.me});

  final AdminRepository admin;
  final StaffAccount? account;
  final String me;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.account?.email ?? '');
  late final _name = TextEditingController(text: widget.account?.displayName ?? '');
  late final _limit = TextEditingController(text: '${widget.account?.maxActiveTickets ?? 5}');
  late final Set<String> _roles = {...?widget.account?.roles};
  late String? _team = widget.account?.team ?? 'general';
  late bool _active = !(widget.account?.disabled ?? false);
  late final Future<AdminOptions> _options = widget.admin.options();
  bool _rolesTouched = false;
  Object? _error;

  bool get _editing => widget.account != null;

  bool get _self => widget.account?.id == widget.me;

  @override
  void initState() {
    super.initState();
    if (!_editing) _roles.add('cs_agent');
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _rolesTouched = true;
      _error = null;
    });
    if (!_form.currentState!.validate() || _roles.isEmpty) return;
    final draft = AccountDraft(
      email: _editing ? null : _email.text.trim().toLowerCase(),
      displayName: _name.text.trim(),
      roles: [for (final role in staffRoles) if (_roles.contains(role)) role],
      team: _team ?? 'general',
      maxActiveTickets: int.parse(_limit.text.trim()),
      disabled: !_active,
    );
    final cubit = context.read<AdminListCubit<StaffAccount>>();
    try {
      CreatedAccount? created;
      await cubit.save((items) async {
        if (_editing) {
          final updated = await widget.admin.updateAccount(widget.account!.id, draft);
          return [for (final item in items) item.id == updated.id ? updated : item];
        }
        created = await widget.admin.createAccount(draft);
        return [...items, created!.agent];
      });
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final saving = context.select((AdminListCubit<StaffAccount> c) => c.state.saving);
    final account = widget.account;
    final disabling = _editing && !_active && !account!.disabled;
    return AlertDialog(
      title: Text(_editing ? l10n.editAccountTitle(account!.displayName) : l10n.addAccountTitle),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !_editing,
                  autofocus: !_editing,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    helperText: _editing ? null : l10n.staffEmailHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      _editing || _emailPattern.hasMatch(value?.trim() ?? '') ? null : l10n.invalidEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  autofocus: _editing,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: l10n.displayName,
                    helperText: l10n.displayNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().length ?? 0) >= 2 ? null : l10n.invalidName,
                ),
                const SizedBox(height: 8),
                Text(l10n.rolesLabel, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final role in staffRoles)
                      FilterChip(
                        label: Text(roleLabel(context, role)),
                        selected: _roles.contains(role),
                        onSelected: _self && role == 'cs_admin'
                            ? null
                            : (selected) => setState(() => selected ? _roles.add(role) : _roles.remove(role)),
                      ),
                  ],
                ),
                if (_rolesTouched && _roles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(l10n.rolesRequired, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                  ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FutureBuilder<AdminOptions>(
                        future: _options,
                        builder: (context, snapshot) {
                          final teams = snapshot.data?.teams ?? const <Choice>[];
                          return DropdownButtonFormField<String>(
                            initialValue: teams.any((t) => t.code == _team) ? _team : null,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l10n.teamLabel, border: const OutlineInputBorder()),
                            items: [for (final team in teams) DropdownMenuItem(value: team.code, child: Text(team.name))],
                            onChanged: (value) => setState(() => _team = value),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _limit,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(labelText: l10n.ticketLimitLabel, border: const OutlineInputBorder()),
                        validator: (value) {
                          final limit = int.tryParse(value?.trim() ?? '');
                          return limit != null && limit >= 1 && limit <= 20 ? null : l10n.numberRange(1, 20);
                        },
                      ),
                    ),
                  ],
                ),
                if (_editing) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.accountActive),
                    value: _active,
                    onChanged: _self ? null : (value) => setState(() => _active = value),
                  ),
                  if (_self)
                    Text(l10n.selfLocked, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (disabling)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.disableWarning(account.activeTickets),
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                ],
                DialogError(_error),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: disabling ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error) : null,
          onPressed: saving ? null : _submit,
          child: saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_editing ? l10n.save : l10n.createAccount),
        ),
      ],
    );
  }
}

class _CreatedDialog extends StatefulWidget {
  const _CreatedDialog({required this.created});

  final CreatedAccount created;

  @override
  State<_CreatedDialog> createState() => _CreatedDialogState();
}

class _CreatedDialogState extends State<_CreatedDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final agent = widget.created.agent;
    return AlertDialog(
      icon: const Icon(Icons.verified_user_outlined),
      title: Text(l10n.accountCreatedTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.accountCreatedBody('${agent.displayName} (${agent.agentCode})')),
            const SizedBox(height: 16),
            Text(l10n.email, style: theme.textTheme.labelMedium),
            SelectableText(agent.email ?? '', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(l10n.temporaryPassword, style: theme.textTheme.labelMedium),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    widget.created.temporaryPassword,
                    style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace', letterSpacing: 1),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.created.temporaryPassword));
                    if (mounted) setState(() => _copied = true);
                  },
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                  label: Text(_copied ? l10n.copied : l10n.copy),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.accountCreatedSteps, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done))],
    );
  }
}
