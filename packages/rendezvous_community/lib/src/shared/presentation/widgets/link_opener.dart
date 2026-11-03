import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CommunityLinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternal(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

String linkDisplayDomain(Uri uri) => uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;

Future<bool> openCommunityLink(BuildContext context, Uri uri, {CommunityLinkLauncher? launcher}) async {
  final safe = safeLinkUri(uri.toString());
  if (safe == null) return false;
  final l10n = context.communityL10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.linkOpenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.linkOpenBody(linkDisplayDomain(safe))),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${safe.scheme}://'),
                    TextSpan(
                      text: safe.host,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: safe.toString().substring('${safe.scheme}://${safe.host}'.length)),
                  ],
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.linkOpenAction)),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return false;
  final opened = await (launcher ?? _launchExternal)(safe).catchError((Object _) => false);
  if (!opened && context.mounted) showCommunityMessage(context, l10n.linkOpenFailed);
  return opened;
}
