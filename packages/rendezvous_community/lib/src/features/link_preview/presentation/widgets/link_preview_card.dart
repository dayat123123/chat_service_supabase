import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/entities/link_preview.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/link_opener.dart';

class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({super.key, required this.text, this.margin = const EdgeInsets.only(top: 8)});

  final String text;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final features = context.communityFeatures;
    final url = extractLinks(text, max: 1).firstOrNull;
    if (features == null || url == null) return const SizedBox.shrink();
    return ValueListenableBuilder<LinkPreview?>(
      valueListenable: features.linkPreviews.watch(url),
      builder: (context, preview, _) => preview == null || !preview.hasCard
          ? const SizedBox.shrink()
          : _PreviewCard(preview: preview, margin: margin),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview, required this.margin});

  final LinkPreview preview;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = preview.title?.trim();
    final description = preview.description?.trim();
    final site = preview.siteName?.trim();
    final image = preview.imageUrl;
    final target = safeLinkUri(preview.finalUrl ?? '') ?? safeLinkUri(preview.url);
    return Padding(
      padding: margin,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: target == null ? null : () => openCommunityLink(context, target),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null)
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (site != null && site.isNotEmpty)
                          Text(
                            site,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        if (title != null && title.isNotEmpty)
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                        if (description != null && description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.link, size: 12, color: scheme.outline),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                preview.domain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
