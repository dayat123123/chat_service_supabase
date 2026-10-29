import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/utils/social_text_parser.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../theme/olt_social_theme.dart';

/// Avatar bulat: foto bila ada, inisial bila tidak.
class OltAvatar extends StatelessWidget {
  const OltAvatar({super.key, required this.user, this.radius = 20, this.online = false, this.onTap});

  final UserSummary? user;
  final double radius;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user?.name ?? '?';
    final initials = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final url = user?.avatarUrl;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      foregroundImage: url == null ? null : NetworkImage(url),
      child: Text(initials, style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600)),
    );

    if (online) {
      final dot = radius * 0.55;
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: OltSocialTheme.of(context).onlineIndicator,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return Semantics(label: name, child: avatar);
    return Semantics(
      button: true,
      label: name,
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: avatar),
    );
  }
}

/// Nama tampilan + centang verifikasi + @username.
class OltUserName extends StatelessWidget {
  const OltUserName({super.key, required this.user, this.showUsername = true, this.style});

  final UserSummary user;
  final bool showUsername;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            user.name,
            overflow: TextOverflow.ellipsis,
            style: style ?? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (user.isVerified) ...[
          const SizedBox(width: 4),
          Icon(Icons.verified, size: 16, color: theme.colorScheme.primary),
        ],
        if (showUsername && user.displayName != null && user.displayName!.isNotEmpty) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '@${user.username}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

/// Badge sentimen bullish / bearish / netral.
class SentimentBadge extends StatelessWidget {
  const SentimentBadge({super.key, required this.sentiment});

  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final t = OltSocialTheme.of(context);
    final l10n = context.oltL10n;
    final (bg, fg, label, icon) = switch (sentiment) {
      Sentiment.bullish => (t.bullish, t.onBullish, l10n.sentimentBullish, Icons.trending_up),
      Sentiment.bearish => (t.bearish, t.onBearish, l10n.sentimentBearish, Icons.trending_down),
      Sentiment.neutral => (t.neutral, t.onNeutral, l10n.sentimentNeutral, Icons.trending_flat),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Teks dengan `$KODE` dan `@mention` yang bisa diketuk.
class SocialText extends StatefulWidget {
  const SocialText(this.text, {super.key, this.validStockCodes, this.style, this.maxLines});

  final String text;

  /// Bila diisi, hanya kode ini yang dijadikan tautan (tag tervalidasi server).
  final Set<String>? validStockCodes;
  final TextStyle? style;
  final int? maxLines;

  @override
  State<SocialText> createState() => _SocialTextState();
}

class _SocialTextState extends State<SocialText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final link = TextStyle(color: OltSocialTheme.of(context).link, fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[
      for (final segment in parseSocialText(widget.text, validStockCodes: widget.validStockCodes))
        switch (segment) {
          PlainSegment() => TextSpan(text: segment.text),
          CashtagSegment(:final code) => TextSpan(
            text: segment.text,
            style: link,
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => OltNavigator.openStock(context, code)),
          ),
          MentionSegment(:final username) => TextSpan(
            text: segment.text,
            style: link,
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => OltNavigator.openUsername(context, username)),
          ),
        },
    ];
    return Text.rich(
      TextSpan(children: spans),
      style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }

  TapGestureRecognizer _recognizer(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }
}

/// Disclaimer wajib di composer & detail post.
class OltDisclaimer extends StatelessWidget {
  const OltDisclaimer({super.key, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.oltL10n.disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tampilan saat data kosong.
class OltEmptyView extends StatelessWidget {
  const OltEmptyView({super.key, required this.message, this.icon = Icons.forum_outlined, this.action});

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Tampilan error dengan tombol coba lagi.
class OltErrorView extends StatelessWidget {
  const OltErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(l10n.errorMessage(error), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Menampilkan error aksi sebagai SnackBar.
void showOltError(BuildContext context, Object error) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.oltL10n.errorMessage(error))));
}

void showOltMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Dialog konfirmasi sederhana.
Future<bool> confirmOlt(BuildContext context, String message, {String? confirmLabel}) async {
  final l10n = context.oltL10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel ?? l10n.delete)),
      ],
    ),
  );
  return ok ?? false;
}

/// Placeholder berdenyut saat memuat.
class OltSkeleton extends StatefulWidget {
  const OltSkeleton({super.key, this.itemCount = 5, this.itemBuilder});

  final int itemCount;
  final WidgetBuilder? itemBuilder;

  @override
  State<OltSkeleton> createState() => _OltSkeletonState();
}

class _OltSkeletonState extends State<OltSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        itemBuilder: (context, _) => widget.itemBuilder?.call(context) ?? const _PostSkeleton(),
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, {double height = 12}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 20, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(140),
                const SizedBox(height: 10),
                bar(double.infinity),
                const SizedBox(height: 6),
                bar(double.infinity),
                const SizedBox(height: 6),
                bar(180),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid gambar lampiran dari bucket privat (dimuat dengan header otorisasi).
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

/// Badge jumlah belum dibaca ("99+").
class OltCountBadge extends StatelessWidget {
  const OltCountBadge({super.key, required this.count, this.muted = false});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = OltSocialTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? scheme.outline : t.unreadBadge,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: muted ? scheme.surface : t.onUnreadBadge,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
