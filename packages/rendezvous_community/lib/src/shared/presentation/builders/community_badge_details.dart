import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

enum CommunityBadgeKind {
  official,
  supportOfficial,
  bot,
  roomModerator,
  sentimentBullish,
  sentimentBearish,
  sentimentNeutral,
}

class CommunityLabelBadgeDetails {
  const CommunityLabelBadgeDetails({
    required this.kind,
    required this.label,
    required this.icon,
    required this.foreground,
    this.background,
    this.border,
  });

  final CommunityBadgeKind kind;
  final String label;
  final IconData icon;
  final Color foreground;
  final Color? background;
  final Color? border;
}

class CommunityVerifiedBadgeDetails {
  const CommunityVerifiedBadgeDetails({required this.user, required this.color, this.size = 16});

  final UserSummary user;
  final Color color;
  final double size;
}

enum CommunityCountKind { roomUnread, messageRequests, chatUnread, supportUnread, notificationUnread }

String communityCountLabel(int count) => count > 99 ? '99+' : '$count';

class CommunityCountBadgeDetails {
  const CommunityCountBadgeDetails({required this.kind, required this.count, this.muted = false});

  final CommunityCountKind kind;
  final int count;
  final bool muted;

  String get label => communityCountLabel(count);
}

class CommunityCountOverlayDetails {
  const CommunityCountOverlayDetails({required this.kind, required this.count, required this.child});

  final CommunityCountKind kind;
  final int count;
  final Widget child;

  String get label => communityCountLabel(count);
}
