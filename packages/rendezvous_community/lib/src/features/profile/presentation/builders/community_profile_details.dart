import 'package:flutter/foundation.dart';
import 'package:rendezvous_community/src/features/profile/domain/entities/user_profile.dart';

class CommunityProfileDetails {
  const CommunityProfileDetails({
    required this.profile,
    required this.busy,
    required this.followersLabel,
    required this.followingLabel,
    required this.postsLabel,
    this.onToggleFollow,
    this.onMessage,
    this.onEdit,
    this.onReport,
    this.onBlock,
    this.onUnblock,
  });

  final UserProfile profile;
  final bool busy;
  final String followersLabel;
  final String followingLabel;
  final String postsLabel;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onMessage;
  final VoidCallback? onEdit;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;

  bool get isMe => profile.isMe;

  bool get isFollowing => profile.isFollowing;
}
