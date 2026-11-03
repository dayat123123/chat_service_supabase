import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

extension LegalDocumentText on CommunityLocalizations {
  String legalMeta(LegalDocument document) =>
      legalVersion(document.version, DateFormat.yMMMMd(localeName).format(document.effectiveAt.toLocal()));

  String legalTitles(List<LegalDocument> documents) {
    final titles = [for (final document in documents) document.title];
    if (titles.length <= 1) return titles.join();
    return '${titles.sublist(0, titles.length - 1).join(', ')} $listAnd ${titles.last}';
  }
}

class CommunityLegalDocumentReader extends StatelessWidget {
  const CommunityLegalDocumentReader({
    super.key,
    required this.document,
    this.padding = const EdgeInsets.all(16),
    this.showTitle = true,
  });

  final LegalDocument document;
  final EdgeInsetsGeometry padding;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = document.changeSummary;
    return Scrollbar(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle) Text(document.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.legalMeta(document), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            if (summary != null) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.legalChanges,
                        style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(summary, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SelectableText(document.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

Future<void> showCommunityLegalDocument(BuildContext context, LegalDocument document) {
  final l10n = context.communityL10n;
  if (CommunityBreakpoints.isWide(context)) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: CommunityLegalDocumentReader(document: document, padding: const EdgeInsets.all(24)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.close)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(document.title)),
        body: SafeArea(top: false, child: CommunityLegalDocumentReader(document: document, showTitle: false)),
      ),
    ),
  );
}
