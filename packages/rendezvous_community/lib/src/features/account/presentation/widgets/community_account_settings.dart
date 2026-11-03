import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_account_scope.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/features/account/presentation/cubit/account_settings_cubit.dart';
import 'package:rendezvous_community/src/features/account/presentation/export_saver.dart';
import 'package:rendezvous_community/src/features/account/presentation/widgets/delete_account_dialog.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_consent_banner.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_consent_flow.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_legal_document_reader.dart';
import 'package:rendezvous_community/src/features/message_requests/presentation/widgets/community_dm_policy_settings.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/widgets/community_notification_settings.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

Future<void> openCommunityAccountSettings(
  BuildContext context, {
  VoidCallback? onAccountDeleted,
  CommunityExportSaver? exportSaver,
}) {
  final account = CommunityAccountScope.of(context);
  final features = context.getInheritedWidgetOfExactType<CommunityFeatureScope>()?.dependencies;
  final title = context.communityL10n.accountSettingsTitle;
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (pageContext) => _withFeatures(
        features,
        CommunityAccountScope(
          dependencies: account,
          child: Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              top: false,
              child: CommunityAccountSettings(
                exportSaver: exportSaver,
                onAccountDeleted: () {
                  Navigator.pop(pageContext);
                  onAccountDeleted?.call();
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _withFeatures(CommunityFeatureDependencies? features, Widget child) =>
    features == null ? child : CommunityFeatureScope(dependencies: features, child: child);

class CommunityAccountSettings extends StatelessWidget {
  const CommunityAccountSettings({super.key, this.onAccountDeleted, this.exportSaver});

  final VoidCallback? onAccountDeleted;
  final CommunityExportSaver? exportSaver;

  @override
  Widget build(BuildContext context) {
    final account = CommunityAccountScope.of(context);
    return BlocProvider(
      create: (_) => AccountSettingsCubit(account)..load(),
      child: _AccountSettingsView(onAccountDeleted: onAccountDeleted, exportSaver: exportSaver),
    );
  }
}

class _AccountSettingsView extends StatelessWidget {
  const _AccountSettingsView({this.onAccountDeleted, this.exportSaver});

  final VoidCallback? onAccountDeleted;
  final CommunityExportSaver? exportSaver;

  Future<void> _export(BuildContext context) async {
    final cubit = context.read<AccountSettingsCubit>();
    final l10n = context.communityL10n;
    final export = await cubit.exportData();
    if (export == null || !context.mounted) return;
    try {
      final saved = await (exportSaver ?? saveCommunityDataExport)(context, export);
      if (saved && context.mounted) showCommunityMessage(context, l10n.accountExportSaved);
    } catch (e) {
      cubit.exportFailed(e);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<AccountSettingsCubit>();
    final l10n = context.communityL10n;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(value: cubit, child: const DeleteAccountDialog()),
    );
    if (deleted != true || !context.mounted) return;
    showCommunityMessage(context, l10n.accountDeleted);
    final callback = onAccountDeleted;
    if (callback != null) {
      callback();
    } else {
      await Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return BlocConsumer<AccountSettingsCubit, AccountSettingsState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId && b.failedAction == AccountAction.export,
      listener: (context, state) {
        final error = state.actionError!;
        showCommunityMessage(
          context,
          mapError(error).kind == CommunityErrorKind.rateLimited ? l10n.accountExportLimit : l10n.errorMessage(error),
        );
      },
      builder: (context, state) {
        final cubit = context.read<AccountSettingsCubit>();
        final features = context.communityFeatures;
        final social = features == null || features.configService.current.socialEnabled;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth),
            child: ListView(
              children: [
                const CommunityConsentBanner(margin: EdgeInsets.fromLTRB(16, 12, 16, 4)),
                _SectionHeader(l10n.accountLegalSection),
                ...switch (state.status) {
                  LoadStatus.initial || LoadStatus.loading => const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: LinearProgressIndicator(),
                    ),
                  ],
                  LoadStatus.failure => [
                    ListTile(
                      leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                      title: Text(l10n.errorMessage(state.error!)),
                      trailing: TextButton(onPressed: () => cubit.load(refresh: true), child: Text(l10n.retry)),
                    ),
                  ],
                  LoadStatus.ready => [
                    for (final document in state.documents)
                      ListTile(
                        leading: Icon(legalDocumentIcon(document.kind)),
                        title: Text(document.title),
                        subtitle: Text(l10n.legalMeta(document), style: muted),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showCommunityLegalDocument(context, document),
                      ),
                  ],
                },
                if (features != null && social) ...[
                  const Divider(height: 24),
                  _SectionHeader(l10n.accountMessagesSection),
                  const CommunityDmPolicySettings(),
                ],
                if (features != null && social && context.communityFeature(CommunityFlags.notificationPrefs)) ...[
                  const Divider(height: 24),
                  _SectionHeader(l10n.notificationSettings),
                  const CommunityNotificationSettings(),
                ],
                if (features != null) ...[
                  const Divider(height: 24),
                  _SectionHeader(l10n.accountAppealsSection),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(l10n.myAppeals),
                    subtitle: Text(l10n.accountAppealsHint, style: muted),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openCommunityAppeals(context),
                  ),
                ],
                const Divider(height: 24),
                _SectionHeader(l10n.accountDataSection),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n.accountExport),
                  subtitle: Text(l10n.accountExportHint, style: muted),
                  trailing: state.exporting
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  enabled: !state.exporting && !state.deleting,
                  onTap: () => _export(context),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                  title: Text(l10n.accountDelete, style: TextStyle(color: theme.colorScheme.error)),
                  subtitle: Text(l10n.accountDeleteHint, style: muted),
                  enabled: !state.deleting,
                  onTap: () => _delete(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}
