import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/presentation/cubit/dm_policy_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

class CommunityDmPolicySettings extends StatelessWidget {
  const CommunityDmPolicySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final features = CommunityFeatureScope.of(context);
    return BlocProvider(create: (_) => DmPolicyCubit(features.messageRequests)..load(), child: const _PolicyView());
  }
}

class _PolicyView extends StatelessWidget {
  const _PolicyView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return BlocListener<DmPolicyCubit, DmPolicyState>(
      listenWhen: (a, b) => a.savedId != b.savedId,
      listener: (context, _) => showCommunityMessage(context, l10n.dmPolicySaved),
      child: BlocConsumer<DmPolicyCubit, DmPolicyState>(
        listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
        listener: (context, state) => showCommunityError(context, state.actionError!),
        builder: (context, state) => _build(context, state),
      ),
    );
  }

  Widget _build(BuildContext context, DmPolicyState state) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final cubit = context.read<DmPolicyCubit>();
    switch (state.status) {
      case LoadStatus.initial || LoadStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LinearProgressIndicator(),
        );
      case LoadStatus.failure:
        return ListTile(
          leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
          title: Text(l10n.errorMessage(state.error!)),
          trailing: TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
        );
      case LoadStatus.ready:
        break;
    }
    return RadioGroup<DmPolicy>(
      groupValue: state.settings.policy,
      onChanged: (policy) {
        if (policy != null && !state.saving) cubit.setPolicy(policy);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l10n.dmPolicyTitle, style: muted),
          ),
          RadioListTile<DmPolicy>(
            value: DmPolicy.everyone,
            title: Text(l10n.dmPolicyEveryone),
            subtitle: Text(l10n.dmPolicyEveryoneHint, style: muted),
          ),
          RadioListTile<DmPolicy>(value: DmPolicy.following, title: Text(l10n.dmPolicyFollowing)),
          RadioListTile<DmPolicy>(
            value: DmPolicy.none,
            title: Text(l10n.dmPolicyNone),
            subtitle: Text(l10n.dmPolicyNoneHint, style: muted),
          ),
        ],
      ),
    );
  }
}
