import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/accounts_view.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/assignment_view.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/hours_view.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/messages_view.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/quick_replies_view.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/topics_view.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SettingsSection { accounts, topics, quickReplies, hours, messages, assignment }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.admin});

  final AdminRepository admin;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsSection _section = SettingsSection.accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final admin = widget.admin;
    final items = [
      (SettingsSection.accounts, Icons.manage_accounts_outlined, l10n.menuAccounts),
      (SettingsSection.topics, Icons.topic_outlined, l10n.menuTopics),
      (SettingsSection.quickReplies, Icons.quickreply_outlined, l10n.menuQuickReplies),
      (SettingsSection.hours, Icons.event_available_outlined, l10n.menuHours),
      (SettingsSection.messages, Icons.sms_outlined, l10n.menuMessages),
      (SettingsSection.assignment, Icons.tune, l10n.menuAssignment),
    ];
    return BlocProvider(
      create: (_) => AdminListCubit<SettingEntry>(admin.settings)..load(),
      child: Row(
        children: [
          Container(
            width: 248,
            color: theme.colorScheme.surfaceContainerLow,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Text(l10n.settingsTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
                for (final (section, icon, label) in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ListTile(
                      dense: true,
                      selected: _section == section,
                      selectedTileColor: theme.colorScheme.secondaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      leading: Icon(icon, size: 20),
                      title: Text(label),
                      onTap: () => setState(() => _section = section),
                    ),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: switch (_section) {
              SettingsSection.accounts => AccountsView(admin: admin),
              SettingsSection.topics => TopicsView(admin: admin),
              SettingsSection.quickReplies => QuickRepliesView(admin: admin),
              SettingsSection.hours => HoursView(admin: admin),
              SettingsSection.messages => MessagesView(admin: admin),
              SettingsSection.assignment => AssignmentView(admin: admin),
            },
          ),
        ],
      ),
    );
  }
}
