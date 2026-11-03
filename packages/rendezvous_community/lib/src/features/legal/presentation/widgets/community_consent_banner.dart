import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_account_scope.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_consent_flow.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_legal_document_reader.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

class CommunityConsentBanner extends StatelessWidget {
  const CommunityConsentBanner({super.key, this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 4)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final consent = CommunityAccountScope.maybeOf(context)?.consent;
    if (consent == null) return const SizedBox.shrink();
    consent.ensureLoaded();
    return ListenableBuilder(
      listenable: consent,
      builder: (context, _) {
        final documents = consent.bannerDocuments;
        if (documents.isEmpty) return const SizedBox.shrink();
        final l10n = context.communityL10n;
        final scheme = Theme.of(context).colorScheme;
        final titles = l10n.legalTitles(documents);
        final text = documents.every((d) => d.isUpdate)
            ? l10n.consentBannerUpdated(titles)
            : l10n.consentBannerRequired(titles);
        return Padding(
          padding: margin,
          child: Material(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Icon(Icons.policy_outlined, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final accepted = await showCommunityConsent(context);
                      if (accepted && context.mounted) showCommunityMessage(context, l10n.consentAccepted);
                    },
                    child: Text(l10n.consentReview),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: consent.dismissBanner,
                    icon: Icon(Icons.close, color: scheme.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
