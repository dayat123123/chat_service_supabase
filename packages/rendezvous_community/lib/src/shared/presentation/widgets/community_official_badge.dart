import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class CommunityOfficialBadge extends StatelessWidget {
  const CommunityOfficialBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: scheme.onPrimary),
          const SizedBox(width: 3),
          Text(
            context.communityL10n.officialAccountBadge,
            style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
