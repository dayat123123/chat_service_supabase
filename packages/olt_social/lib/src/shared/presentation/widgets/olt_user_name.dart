import 'package:flutter/material.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

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
