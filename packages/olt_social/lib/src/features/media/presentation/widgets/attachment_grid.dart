import 'package:flutter/material.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/core/network/authorized_image.dart';
import 'package:olt_social/src/features/media/domain/repositories/media_repository.dart';
import 'package:olt_social/src/shared/domain/entities/attachment.dart';

class AttachmentGrid extends StatelessWidget {
  const AttachmentGrid({super.key, required this.attachments, this.maxHeight = 280});

  final List<Attachment> attachments;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final media = OltSocialScope.of(context).media;
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
          children: [for (final a in attachments) _AttachmentImage(attachment: a, media: media)],
        ),
      ),
    );
  }
}

class _AttachmentImage extends StatefulWidget {
  const _AttachmentImage({required this.attachment, required this.media});

  final Attachment attachment;
  final MediaRepository media;

  @override
  State<_AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends State<_AttachmentImage> {
  late final Future<AuthorizedImage> _image = widget.media.attachmentImage(widget.attachment);

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
    return FutureBuilder<AuthorizedImage>(
      future: _image,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) return placeholder;
        return Image.network(
          image.url,
          headers: image.headers,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.outline)),
          loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
        );
      },
    );
  }
}
