import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_account_scope.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/consent_gate.dart';
import 'package:rendezvous_community/src/features/legal/presentation/cubit/consent_cubit.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_legal_document_reader.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

Future<bool> showCommunityConsent(BuildContext context) {
  final account = CommunityAccountScope.maybeOf(context);
  if (account == null) return Future.value(false);
  return account.consent.prompt(() => _presentConsent(context, account));
}

ConsentGate? communityConsentGate(BuildContext context) {
  if (CommunityAccountScope.maybeOf(context) == null) return null;
  return ConsentGate(() async => context.mounted && await showCommunityConsent(context));
}

Future<bool> _presentConsent(BuildContext context, CommunityAccountDependencies account) async {
  if (!context.mounted) return false;
  final l10n = context.communityL10n;
  Widget view(BuildContext routeContext, {required bool showTitle}) => CommunityAccountScope(
    dependencies: account,
    child: CommunityConsentView(showTitle: showTitle, onDone: (accepted) => Navigator.pop(routeContext, accepted)),
  );
  final bool? accepted;
  if (CommunityBreakpoints.isWide(context)) {
    accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85),
          child: view(dialogContext, showTitle: true),
        ),
      ),
    );
  } else {
    accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (pageContext) => Scaffold(
          appBar: AppBar(title: Text(l10n.consentTitle)),
          body: SafeArea(top: false, child: view(pageContext, showTitle: false)),
        ),
      ),
    );
  }
  return accepted ?? false;
}

class CommunityConsentView extends StatelessWidget {
  const CommunityConsentView({super.key, required this.onDone, this.showTitle = true});

  final ValueChanged<bool> onDone;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final account = CommunityAccountScope.of(context);
    return BlocProvider(
      create: (_) => ConsentCubit(account.consent)..load(),
      child: BlocConsumer<ConsentCubit, ConsentState>(
        listenWhen: (a, b) => !a.accepted && b.accepted,
        listener: (_, _) => onDone(true),
        builder: (context, state) => PopScope(
          canPop: !state.submitting,
          child: switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            LoadStatus.failure => _ConsentFailure(error: state.error!, onLater: () => onDone(false)),
            LoadStatus.ready => _ConsentBody(state: state, showTitle: showTitle, onLater: () => onDone(false)),
          },
        ),
      ),
    );
  }
}

class _ConsentFailure extends StatelessWidget {
  const _ConsentFailure({required this.error, required this.onLater});

  final Object error;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: CommunityErrorView(error: error, onRetry: context.read<ConsentCubit>().load),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onLater, child: Text(context.communityL10n.consentLater)),
        ),
      ),
    ],
  );
}

class _ConsentBody extends StatelessWidget {
  const _ConsentBody({required this.state, required this.showTitle, required this.onLater});

  final ConsentState state;
  final bool showTitle;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final cubit = context.read<ConsentCubit>();
    final error = state.actionError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle) ...[Text(l10n.consentTitle, style: theme.textTheme.titleLarge), const SizedBox(height: 8)],
              Text(l10n.consentIntro, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [for (final document in state.documents) _DocumentTile(document: document)],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: state.agreed,
          onChanged: state.submitting ? null : (value) => cubit.setAgreed(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(l10n.consentAgree(l10n.legalTitles(state.documents))),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.errorMessage(error),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: state.submitting ? null : onLater, child: Text(l10n.consentLater)),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.canAccept ? cubit.accept : null,
                child: state.submitting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.consentAccept),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final summary = document.changeSummary;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(legalDocumentIcon(document.kind)),
        title: Text(document.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.legalMeta(document), style: muted),
            if (summary != null)
              Text(
                '${l10n.legalChanges}: $summary',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => showCommunityLegalDocument(context, document),
          child: Text(l10n.consentRead),
        ),
        onTap: () => showCommunityLegalDocument(context, document),
      ),
    );
  }
}

IconData legalDocumentIcon(LegalDocumentKind kind) => switch (kind) {
  LegalDocumentKind.terms => Icons.description_outlined,
  LegalDocumentKind.communityGuidelines => Icons.groups_outlined,
  LegalDocumentKind.privacy => Icons.privacy_tip_outlined,
  LegalDocumentKind.other => Icons.article_outlined,
};
