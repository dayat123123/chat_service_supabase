import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/account_dialogs.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/admin_frame.dart';
import 'package:cs_console/src/features/agent/presentation/widgets/top_bar.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

String roleLabel(BuildContext context, String role) {
  final l10n = context.l10n;
  return switch (role) {
    'cs_agent' => l10n.roleAgent,
    'cs_supervisor' => l10n.roleSupervisor,
    'cs_admin' => l10n.roleAdmin,
    'compliance' => l10n.roleCompliance,
    _ => role,
  };
}

class AccountsView extends StatelessWidget {
  const AccountsView({super.key, required this.admin});

  final AdminRepository admin;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AdminListCubit<StaffAccount>(admin.accounts)..load(),
    child: _Accounts(admin: admin),
  );
}

class _Accounts extends StatelessWidget {
  const _Accounts({required this.admin});

  final AdminRepository admin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AdminListCubit<StaffAccount>>();
    return AdminFrame(
      title: l10n.accountsTitle,
      description: l10n.accountsDescription,
      action: FilledButton.icon(
        onPressed: () => showAccountDialog(context, admin: admin, cubit: cubit),
        icon: const Icon(Icons.person_add_alt, size: 18),
        label: Text(l10n.addAccount),
      ),
      children: [
        AdminLoader<StaffAccount>(
          builder: (context, accounts) => AdminTable(
            columns: [
              l10n.colAgent,
              l10n.email,
              l10n.colRoles,
              l10n.colTeam,
              l10n.colTicketLimit,
              l10n.colTwoFactor,
              l10n.colStatus,
              '',
            ],
            numeric: const {4},
            rows: [
              for (final account in accounts)
                DataRow(
                  color: account.disabled
                      ? WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5))
                      : null,
                  cells: [
                    DataCell(Text('${account.displayName} (${account.agentCode})')),
                    DataCell(Text(account.email ?? '–')),
                    DataCell(Text(account.roles.map((r) => roleLabel(context, r)).join(', '))),
                    DataCell(Text(account.team ?? '–')),
                    DataCell(Text('${account.activeTickets}/${account.maxActiveTickets}')),
                    DataCell(account.totp
                        ? Tooltip(message: l10n.twoFactorOn, child: const Icon(Icons.verified_user, size: 18, color: Color(0xFF1E9E5A)))
                        : Text(l10n.twoFactorPending, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    DataCell(account.disabled
                        ? Tooltip(
                            message: l10n.disabledSince(stamp(account.disabledAt!)),
                            child: ActiveBadge(active: false, inactiveLabel: l10n.accountDisabled),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 10, color: statusColor(account.status, Theme.of(context).colorScheme)),
                              const SizedBox(width: 6),
                              Text(statusLabel(context, account.status)),
                            ],
                          )),
                    DataCell(TextButton(
                      onPressed: () => showAccountDialog(context, admin: admin, cubit: cubit, account: account),
                      child: Text(l10n.edit),
                    )),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
