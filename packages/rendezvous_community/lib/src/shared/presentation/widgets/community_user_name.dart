import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_official_scope.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_official_badge.dart';

class CommunityUserName extends StatelessWidget {
  const CommunityUserName({super.key, required this.user, this.showUsername = true, this.style});

  final UserSummary user;
  final bool showUsername;
  final TextStyle? style;

  static final _none = ValueNotifier<Set<String>>(const <String>{});

  @override
  Widget build(BuildContext context) {
    final official = CommunityOfficialScope.maybeOf(context)?..ensureLoaded();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: official ?? _none,
      builder: (context, ids, _) => _name(context, ids.contains(user.id)),
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
