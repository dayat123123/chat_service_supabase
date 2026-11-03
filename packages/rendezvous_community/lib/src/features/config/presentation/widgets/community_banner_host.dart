import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/presentation/cubit/community_banners_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/link_opener.dart';

typedef CommunityBannerBuilder =
    Widget Function(BuildContext context, CommunityBanner banner, VoidCallback? onOpen, VoidCallback? onDismiss);

class CommunityBannerHost extends StatelessWidget {
  const CommunityBannerHost({super.key, this.maxVisible = 3, this.padding = EdgeInsets.zero, this.builder});

  final int maxVisible;
  final EdgeInsetsGeometry padding;
  final CommunityBannerBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final features = context.communityFeatures;
    if (features == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => CommunityBannersCubit(features.configService, features.bannerDismissals, maxVisible: maxVisible),
      child: BlocBuilder<CommunityBannersCubit, List<CommunityBanner>>(
        builder: (context, banners) {
          if (banners.isEmpty) return const SizedBox.shrink();
          final cubit = context.read<CommunityBannersCubit>();
          return Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final banner in banners)
                  Builder(
                    builder: (context) {
                      final link = Uri.tryParse(banner.linkUrl ?? '');
                      final onOpen = link == null || !link.hasScheme ? null : () => openCommunityLink(context, link);
                      final onDismiss = banner.dismissible ? () => cubit.dismiss(banner) : null;
                      return builder?.call(context, banner, onOpen, onDismiss) ??
                          CommunityBannerCard(banner: banner, onOpen: onOpen, onDismiss: onDismiss);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CommunityBannerCard extends StatelessWidget {
  const CommunityBannerCard({super.key, required this.banner, this.onOpen, this.onDismiss});

  final CommunityBanner banner;
  final VoidCallback? onOpen;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, icon) = switch (banner.level) {
      CommunityBannerLevel.info => (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.info_outline),
      CommunityBannerLevel.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer, Icons.warning_amber),
      CommunityBannerLevel.critical => (scheme.errorContainer, scheme.onErrorContainer, Icons.error_outline),
    };
    return Semantics(
      container: true,
      liveRegion: banner.level == CommunityBannerLevel.critical,
      child: Container(
        width: double.infinity,
        color: background,
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: foreground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(banner.title, style: theme.textTheme.titleSmall?.copyWith(color: foreground)),
                  if (banner.body.isNotEmpty)
                    Text(banner.body, style: theme.textTheme.bodySmall?.copyWith(color: foreground)),
                  if (onOpen != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onOpen,
                      child: Text(l10n.bannerOpen),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: l10n.bannerDismiss,
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: Icon(Icons.close, size: 18, color: foreground),
              ),
          ],
        ),
      ),
    );
  }
}
