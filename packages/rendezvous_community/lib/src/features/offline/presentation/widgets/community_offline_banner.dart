import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_offline_scope.dart';
import 'package:rendezvous_community/src/core/network/community_connectivity.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class CommunityOfflineBanner extends StatelessWidget {
  const CommunityOfflineBanner({super.key, this.message, this.connectivity, this.builder});

  final String? message;
  final CommunityConnectivity? connectivity;
  final Widget Function(BuildContext context, String message)? builder;

  @override
  Widget build(BuildContext context) {
    final source = connectivity ?? CommunityOfflineScope.maybeOf(context)?.connectivity;
    if (source == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: source.online,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        final text = message ?? context.communityL10n.offlineBanner;
        return builder?.call(context, text) ?? CommunityOfflineNotice(message: text);
      },
    );
  }
}

class CommunityOfflineNotice extends StatelessWidget {
  const CommunityOfflineNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
