import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/features/account/presentation/cubit/account_settings_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BlocConsumer<AccountSettingsCubit, AccountSettingsState>(
      listenWhen: (a, b) => !a.deleted && b.deleted,
      listener: (context, _) => Navigator.pop(context, true),
      builder: (context, state) {
        final cubit = context.read<AccountSettingsCubit>();
        final error = state.failedAction == AccountAction.delete && !state.deleting ? state.actionError : null;
        return PopScope(
          canPop: !state.deleting,
          child: AlertDialog(
            icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(l10n.accountDeleteTitle),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.accountDeleteIntro, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    _Consequence(icon: Icons.visibility_off_outlined, text: l10n.accountDeleteContent),
                    _Consequence(icon: Icons.inventory_2_outlined, text: l10n.accountDeleteArchive),
                    _Consequence(icon: Icons.people_outline, text: l10n.accountDeleteRelations),
                    _Consequence(icon: Icons.support_agent_outlined, text: l10n.accountDeleteSupport),
                    _Consequence(icon: Icons.account_balance_outlined, text: l10n.accountDeleteTrading),
                    _Consequence(icon: Icons.person_add_alt_outlined, text: l10n.accountDeleteFresh),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('community-delete-confirmation'),
                      controller: _confirmation,
                      enabled: !state.deleting,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.accountDeleteTypeToConfirm(l10n.accountDeleteWord),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (state.deleting) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.accountDeleteProgress)),
                        ],
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(l10n.errorMessage(error), style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: state.deleting ? null : () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ValueListenableBuilder(
                valueListenable: _confirmation,
                builder: (context, value, _) {
                  final confirmed = value.text.trim() == l10n.accountDeleteWord;
                  return FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                    onPressed: confirmed && !state.deleting ? cubit.deleteAccount : null,
                    child: Text(l10n.accountDeleteConfirm),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Consequence extends StatelessWidget {
  const _Consequence({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
