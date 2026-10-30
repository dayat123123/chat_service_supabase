import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef SettingsCubit = AdminListCubit<SettingEntry>;

SettingEntry? findSetting(List<SettingEntry> items, String key) => items.where((s) => s.key == key).firstOrNull;

Future<bool> saveSettings(BuildContext context, AdminRepository admin, Map<String, Object?> values) async {
  final cubit = context.read<SettingsCubit>();
  final me = context.read<AgentCubit>().state.displayName;
  try {
    await cubit.save((items) async {
      var next = items;
      for (final MapEntry(:key, :value) in values.entries) {
        final saved = await admin.setSetting(key, value);
        next = [
          for (final item in next)
            item.key == key
                ? item.copyWith(value: saved.value, version: saved.version, updatedAt: saved.updatedAt, updatedBy: me)
                : item,
        ];
      }
      return next;
    });
    if (context.mounted) showNotice(context, context.l10n.saved);
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final saving = context.select((SettingsCubit c) => c.state.saving);
    return FilledButton(
      onPressed: saving ? null : onPressed,
      child: saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class ChangedBy extends StatelessWidget {
  const ChangedBy({super.key, required this.entry});

  final SettingEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final updatedAt = entry.updatedAt;
    if (updatedAt == null) return const SizedBox.shrink();
    final by = entry.updatedBy;
    return Text(
      by == null ? l10n.lastChanged(stamp(updatedAt)) : l10n.lastChangedBy(stamp(updatedAt), by),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
