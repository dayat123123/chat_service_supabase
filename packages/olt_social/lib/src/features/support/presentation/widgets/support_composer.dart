import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_support_scope.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/message_composer.dart';
import 'package:olt_social/src/features/support/presentation/cubit/support_cubit.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_dialogs.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';

class SupportComposer extends StatelessWidget {
  const SupportComposer({super.key});

  String _kinds(OltSocialLocalizations l10n, List<String> kinds) => <String>{
    for (final kind in kinds)
      switch (kind) {
        'otp' => l10n.supportKindOtp,
        'password' => l10n.supportKindPassword,
        'card' => l10n.supportKindCard,
        'nik' => l10n.supportKindNik,
        'account' => l10n.supportKindAccount,
        _ => kind,
      },
  }.join(', ');

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final cubit = context.read<SupportCubit>();
    final sensitive = context.select((SupportCubit c) => c.state.sensitive);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sensitive.masked)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 18, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.supportSensitiveWarning(_kinds(l10n, sensitive.kinds.isEmpty ? const ['otp'] : sensitive.kinds)),
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        MessageComposer(
          onChanged: cubit.checkText,
          leading: [
            IconButton(
              tooltip: l10n.supportAttachOrder,
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () async {
                final card = await pickSupportOrder(context, OltSupportScope.of(context).support);
                if (card != null) await cubit.attachCard(card);
              },
            ),
          ],
        ),
      ],
    );
  }
}
