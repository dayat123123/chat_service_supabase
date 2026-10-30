import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_support_scope.dart';
import 'package:olt_social/src/features/support/presentation/cubit/support_cubit.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_dialogs.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';

IconData supportTopicIcon(String code) => switch (code) {
  'account' => Icons.person_outline,
  'funds' => Icons.account_balance_wallet_outlined,
  'orders' => Icons.receipt_long_outlined,
  'portfolio' => Icons.pie_chart_outline,
  'technical' => Icons.build_outlined,
  'fraud' => Icons.gpp_maybe_outlined,
  _ => Icons.help_outline,
};

class SupportTopicPicker extends StatelessWidget {
  const SupportTopicPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final cubit = context.read<SupportCubit>();
    final state = context.watch<SupportCubit>().state;
    final card = state.pendingCard;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Text(l10n.supportPickTopic, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(l10n.supportPickTopicHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (card == null)
              OutlinedButton.icon(
                onPressed: state.busy
                    ? null
                    : () async {
                        final picked = await pickSupportOrder(context, OltSupportScope.of(context).support);
                        if (picked != null) cubit.setPendingCard(picked);
                      },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(l10n.supportAttachOrder),
              )
            else
              InputChip(
                avatar: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(l10n.supportAttached(card.ref)),
                onDeleted: () => cubit.setPendingCard(null),
              ),
            if (state.home?.roomId != null)
              TextButton.icon(
                onPressed: cubit.showHistory,
                icon: const Icon(Icons.history, size: 18),
                label: Text(l10n.supportHistory),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final topic in state.topics)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ListTile(
              enabled: !state.busy,
              leading: Icon(supportTopicIcon(topic.code), color: topic.urgent ? theme.colorScheme.error : theme.colorScheme.primary),
              title: Text(topic.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => cubit.start(topic.code),
            ),
          ),
      ],
    );
  }
}
