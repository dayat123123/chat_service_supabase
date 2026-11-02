import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:url_launcher/url_launcher.dart';

typedef DocumentOpener = Future<bool> Function(Uri uri);

String documentSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.round()} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}

class DocumentAttachments extends StatelessWidget {
  const DocumentAttachments({super.key, required this.attachments, required this.color, this.onOpen});

  final List<Attachment> attachments;
  final Color color;
  final DocumentOpener? onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final a in attachments)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _DocumentTile(attachment: a, color: color, onOpen: onOpen),
        ),
    ],
  );
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({required this.attachment, required this.color, this.onOpen});

  final Attachment attachment;
  final Color color;
  final DocumentOpener? onOpen;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _opening = false;

  Future<void> _open() async {
    final l10n = context.communityL10n;
    final media = CommunityScope.of(context).media;
    setState(() => _opening = true);
    try {
      final uri = await media.documentUri(widget.attachment);
      final opened = await (widget.onOpen ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
      if (!opened && mounted) showCommunityMessage(context, l10n.documentOpenFailed);
    } catch (_) {
      if (mounted) showCommunityMessage(context, l10n.documentOpenFailed);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final a = widget.attachment;
    final name = (a.name ?? '').isEmpty ? l10n.documentFallbackName : a.name!;
    final size = documentSize(a.size);
    return Semantics(
      button: true,
      label: l10n.openDocument(name),
      excludeSemantics: true,
      child: InkWell(
        onTap: _opening ? null : _open,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, color: widget.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: widget.color, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      size.isEmpty ? 'PDF' : 'PDF · $size',
                      style: theme.textTheme.bodySmall?.copyWith(color: widget.color.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _opening
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
                    )
                  : Icon(Icons.open_in_new, size: 18, color: widget.color.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
