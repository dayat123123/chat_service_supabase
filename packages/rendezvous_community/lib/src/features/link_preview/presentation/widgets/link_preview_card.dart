import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_builders.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_details.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/entities/link_preview.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_network_image.dart';
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
      builder: (context, preview, _) {
        if (preview == null || !preview.hasCard) return const SizedBox.shrink();
        final target = safeLinkUri(preview.finalUrl ?? '') ?? safeLinkUri(preview.url);
        final details = CommunityLinkPreviewDetails(
          preview: preview,
          onOpen: target == null ? null : () => openCommunityLink(context, target),
        );
        return buildCommunityPart(
          CommunityFeedBuilders.of(context).linkPreview,
          context,
          details,
          _PreviewCard(details: details, margin: margin),
        );
      },
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.details, required this.margin});

  final CommunityLinkPreviewDetails details;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = details.preview;
    final title = preview.title?.trim();
    final description = preview.description?.trim();
    final site = preview.siteName?.trim();
    final image = preview.imageUrl;
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
          onTap: details.onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null)
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CommunityNetworkImage.url(image, error: ColoredBox(color: scheme.surfaceContainerHighest)),
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
