import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_official_scope.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_builders.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_official_badge.dart';

class CommunityUserName extends StatelessWidget {
  const CommunityUserName({super.key, required this.user, this.showUsername = true, this.style, this.official = false});

  final UserSummary user;
  final bool showUsername;
  final TextStyle? style;
  final bool official;

  static final _none = ValueNotifier<Set<String>>(const <String>{});

  @override
  Widget build(BuildContext context) {
    final official = CommunityOfficialScope.maybeOf(context)?..ensureLoaded();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: official ?? _none,
      builder: (context, ids, _) => _name(context, this.official || ids.contains(user.id)),
    );
  }

  Widget _name(BuildContext context, bool isOfficial) {
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
        if (isOfficial) ...[
          const SizedBox(width: 4),
          const CommunityOfficialBadge(),
        ] else if (user.isVerified) ...[
          const SizedBox(width: 4),
          _VerifiedBadge(user: user),
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

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final details = CommunityVerifiedBadgeDetails(user: user, color: Theme.of(context).colorScheme.primary);
    return buildCommunityPart(
      CommunityBadgeBuilders.of(context).verified,
      context,
      details,
      Icon(Icons.verified, size: details.size, color: details.color),
    );
  }
}
