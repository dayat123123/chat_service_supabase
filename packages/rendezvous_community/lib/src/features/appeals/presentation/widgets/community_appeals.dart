import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/cubit/appeal_form_cubit.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/cubit/appeals_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

Future<bool> showCommunityAppealDialog(
  BuildContext context, {
  required AppealTargetType targetType,
  required String targetId,
}) async {
  final features = CommunityFeatureScope.maybeOf(context);
  if (features == null) return false;
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => AppealFormCubit(features.appeals, targetType: targetType, targetId: targetId),
      child: const _AppealDialog(),
    ),
  );
  if (created == true && context.mounted) showCommunityMessage(context, context.communityL10n.appealSent);
  return created ?? false;
}

class _AppealDialog extends StatefulWidget {
  const _AppealDialog();

  @override
  State<_AppealDialog> createState() => _AppealDialogState();
}

class _AppealDialogState extends State<_AppealDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final appeal = await context.read<AppealFormCubit>().submit(_controller.text);
    if (appeal != null && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return BlocBuilder<AppealFormCubit, AppealFormState>(
      builder: (context, state) {
        final cubit = context.read<AppealFormCubit>();
        final error = state.error;
        return AlertDialog(
          title: Text(l10n.appealTitle),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appealHint),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: maxAppealReasonLength,
                  enabled: !state.submitting,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                if (error != null)
                  Text(l10n.errorMessage(error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.submitting ? null : () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: state.submitting || !cubit.isValid(_controller.text) ? null : _submit,
              child: state.submitting
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.appealSubmit),
            ),
          ],
        );
      },
    );
  }
}

Future<void> openCommunityAppeals(BuildContext context) {
  final features = CommunityFeatureScope.of(context);
  final title = context.communityL10n.myAppeals;
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CommunityFeatureScope(
        dependencies: features,
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const SafeArea(top: false, child: CommunityAppeals()),
        ),
      ),
    ),
  );
}

class CommunityAppeals extends StatelessWidget {
  const CommunityAppeals({super.key});

  @override
  Widget build(BuildContext context) {
    final features = CommunityFeatureScope.of(context);
    return BlocProvider(create: (_) => AppealsCubit(features.appeals)..load(), child: const _AppealsView());
  }
}

class _AppealsView extends StatelessWidget {
  const _AppealsView();

  Future<void> _appeal(BuildContext context, AppealTargetType type, String id) async {
    final created = await showCommunityAppealDialog(context, targetType: type, targetId: id);
    if (created && context.mounted) await context.read<AppealsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    return BlocBuilder<AppealsCubit, AppealsState>(
      builder: (context, state) {
        final cubit = context.read<AppealsCubit>();
        return switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => const CommunitySkeleton(itemCount: 3),
          LoadStatus.failure => CommunityErrorView(error: state.error!, onRetry: cubit.load),
          LoadStatus.ready => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth),
              child: RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _Header(l10n.activeSanctions),
                    if (state.sanctions.isEmpty)
                      ListTile(title: Text(l10n.noActiveSanctions, style: muted))
                    else
                      for (final sanction in state.sanctions)
                        ListTile(
                          leading: Icon(Icons.gavel_outlined, color: theme.colorScheme.error),
                          title: Text(_sanctionLabel(l10n, sanction.kind)),
                          subtitle: Text(
                            [
                              if (sanction.reason != null && sanction.reason!.isNotEmpty) sanction.reason!,
                              sanction.endsAt == null
                                  ? l10n.sanctionPermanent
                                  : l10n.sanctionUntil(dateFormat.format(sanction.endsAt!.toLocal())),
                            ].join(' · '),
                            style: muted,
                          ),
                          trailing: state.appealFor(AppealTargetType.sanction, sanction.id) == null
                              ? TextButton(
                                  onPressed: () => _appeal(context, AppealTargetType.sanction, sanction.id),
                                  child: Text(l10n.appealAction),
                                )
                              : null,
                        ),
                    const Divider(height: 24),
                    _Header(l10n.moderatedContent),
                    if (state.moderated.isEmpty)
                      ListTile(title: Text(l10n.moderatedContentEmpty, style: muted))
                    else
                      for (final item in state.moderated)
                        ListTile(
                          leading: Icon(
                            item.state == ModeratedState.removed ? Icons.delete_outline : Icons.visibility_off_outlined,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            '${_targetLabel(l10n, item.type)} · '
                            '${item.state == ModeratedState.removed ? l10n.moderationRemoved : l10n.moderationHidden}',
                          ),
                          subtitle: Text(
                            [
                              if (item.decidedAt != null) dateFormat.format(item.decidedAt!.toLocal()),
                              if (item.excerpt != null && item.excerpt!.isNotEmpty) item.excerpt!,
                              if (item.appeal != null)
                                '${l10n.appealAction}: ${_statusLabel(l10n, item.appeal!.status)}',
                            ].join('\n'),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                          isThreeLine: true,
                          trailing: item.appeal == null
                              ? TextButton(
                                  onPressed: () => _appeal(context, item.type, item.id),
                                  child: Text(l10n.appealAction),
                                )
                              : null,
                        ),
                    const Divider(height: 24),
                    _Header(l10n.myAppeals),
                    if (state.appeals.isEmpty)
                      ListTile(title: Text(l10n.myAppealsEmpty, style: muted))
                    else
                      for (final appeal in state.appeals)
                        ListTile(
                          leading: Icon(_statusIcon(appeal.status), color: _statusColor(theme, appeal.status)),
                          title: Text(
                            '${_targetLabel(l10n, appeal.targetType)} · ${_statusLabel(l10n, appeal.status)}',
                          ),
                          subtitle: Text(
                            [
                              dateFormat.format(appeal.createdAt.toLocal()),
                              appeal.reason,
                              if (appeal.decisionNote != null && appeal.decisionNote!.isNotEmpty)
                                l10n.appealDecisionNote(appeal.decisionNote!),
                            ].join('\n'),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                          isThreeLine: true,
                        ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

String _sanctionLabel(CommunityLocalizations l10n, String kind) => switch (kind) {
  'mute' => l10n.sanctionMute,
  'ban' => l10n.sanctionBan,
  _ => l10n.sanctionWarning,
};

String _targetLabel(CommunityLocalizations l10n, AppealTargetType type) => switch (type) {
  AppealTargetType.sanction => l10n.appealTargetSanction,
  AppealTargetType.post => l10n.appealTargetPost,
  AppealTargetType.comment => l10n.appealTargetComment,
  AppealTargetType.message => l10n.appealTargetMessage,
};

String _statusLabel(CommunityLocalizations l10n, AppealStatus status) => switch (status) {
  AppealStatus.pending => l10n.appealStatusPending,
  AppealStatus.accepted => l10n.appealStatusAccepted,
  AppealStatus.rejected => l10n.appealStatusRejected,
};

IconData _statusIcon(AppealStatus status) => switch (status) {
  AppealStatus.pending => Icons.hourglass_top,
  AppealStatus.accepted => Icons.check_circle_outline,
  AppealStatus.rejected => Icons.cancel_outlined,
};

Color _statusColor(ThemeData theme, AppealStatus status) => switch (status) {
  AppealStatus.pending => theme.colorScheme.tertiary,
  AppealStatus.accepted => theme.colorScheme.primary,
  AppealStatus.rejected => theme.colorScheme.error,
};
