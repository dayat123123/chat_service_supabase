import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_builders.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/builders/community_notification_builders.dart';
import 'package:rendezvous_community/src/features/profile/presentation/builders/community_profile_builders.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_builders.dart';

class CommunityBuilders {
  const CommunityBuilders({
    this.chat = const CommunityChatBuilders(),
    this.feed = const CommunityFeedBuilders(),
    this.notifications = const CommunityNotificationBuilders(),
    this.profile = const CommunityProfileBuilders(),
    this.badges = const CommunityBadgeBuilders(),
  });

  final CommunityChatBuilders chat;
  final CommunityFeedBuilders feed;
  final CommunityNotificationBuilders notifications;
  final CommunityProfileBuilders profile;
  final CommunityBadgeBuilders badges;

  static CommunityBuilders of(BuildContext context, {bool listen = true}) => CommunityBuilders(
    chat: CommunityChatBuilders.of(context, listen: listen),
    feed: CommunityFeedBuilders.of(context, listen: listen),
    notifications: CommunityNotificationBuilders.of(context, listen: listen),
    profile: CommunityProfileBuilders.of(context, listen: listen),
    badges: CommunityBadgeBuilders.of(context, listen: listen),
  );

  CommunityBuilders merge(CommunityBuilders? other) {
    if (other == null) return this;
    return CommunityBuilders(
      chat: chat.merge(other.chat),
      feed: feed.merge(other.feed),
      notifications: notifications.merge(other.notifications),
      profile: profile.merge(other.profile),
      badges: badges.merge(other.badges),
    );
  }

  Widget wrap(Widget child) => CommunityChatBuildersScope(
    builders: chat,
    child: CommunityFeedBuildersScope(
      builders: feed,
      child: CommunityNotificationBuildersScope(
        builders: notifications,
        child: CommunityProfileBuildersScope(
          builders: profile,
          child: CommunityBadgeBuildersScope(builders: badges, child: child),
        ),
      ),
    ),
  );
}

class CommunityBuildersScope extends StatefulWidget {
  const CommunityBuildersScope({super.key, required this.builders, required this.child});

  final CommunityBuilders builders;
  final Widget child;

  @override
  State<CommunityBuildersScope> createState() => _CommunityBuildersScopeState();
}

class _CommunityBuildersScopeState extends State<CommunityBuildersScope> {
  CommunityBuilders? _parent;
  CommunityBuilders? _own;
  CommunityBuilders? _merged;

  bool _same(CommunityBuilders a, CommunityBuilders b) =>
      identical(a.chat, b.chat) &&
      identical(a.feed, b.feed) &&
      identical(a.notifications, b.notifications) &&
      identical(a.profile, b.profile) &&
      identical(a.badges, b.badges);

  @override
  Widget build(BuildContext context) {
    final parent = CommunityBuilders.of(context);
    final previous = _parent;
    var merged = _merged;
    if (merged == null || previous == null || !_same(previous, parent) || !identical(_own, widget.builders)) {
      merged = _merged = parent.merge(widget.builders);
      _parent = parent;
      _own = widget.builders;
    }
    return merged.wrap(widget.child);
  }
}

Widget Function(Widget child) carryCommunityBuilders(BuildContext context) {
  final builders = CommunityBuilders.of(context, listen: false);
  return builders.wrap;
}
