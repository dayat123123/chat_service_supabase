import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/core/media/image_mime.dart';
import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_network_image.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/moderation_notice.dart';

class AttachmentGrid extends StatelessWidget {
  const AttachmentGrid({super.key, required this.attachments, this.maxHeight = 280, this.blurred = false});

  final List<Attachment> attachments;
  final double maxHeight;
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final media = CommunityScope.of(context).media;
    final columns = attachments.length == 1 ? 1 : 2;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: attachments.length == 1 ? 16 / 9 : 1,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final a in attachments)
              Stack(
                fit: StackFit.expand,
                children: [
                  if (blurred)
                    ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: _AttachmentImage(attachment: a, media: media),
                      ),
                    )
                  else
                    _AttachmentImage(attachment: a, media: media),
                  if (blurred)
                    const Center(child: Icon(Icons.visibility_off_outlined, color: Colors.white70, size: 32)),
                  if (a.held) const Positioned(left: 6, top: 6, child: HeldAttachmentLabel()),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentImage extends StatelessWidget {
  const _AttachmentImage({required this.attachment, required this.media});

  final Attachment attachment;
  final MediaRepository media;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bucket = attachment.bucket ?? attachmentBucket;
    return CommunityNetworkImage(
      cacheKey: imageCacheKeyForObject(bucket, attachment.path),
      source: () => media.attachmentImage(attachment),
      persist: bucket != supportDocumentBucket,
      placeholder: ColoredBox(color: scheme.surfaceContainerHighest),
      error: Center(child: Icon(Icons.broken_image_outlined, color: scheme.outline)),
    );
  }
}
