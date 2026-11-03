import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';

class CommunityBadgeBuilders {
  const CommunityBadgeBuilders({
    this.label,
    this.official,
    this.supportOfficial,
    this.bot,
    this.roomModerator,
    this.sentiment,
    this.verified,
    this.count,
    this.countOverlay,
  });

  final CommunityPartBuilder<CommunityLabelBadgeDetails>? label;
  final CommunityPartBuilder<CommunityLabelBadgeDetails>? official;
  final CommunityPartBuilder<CommunityLabelBadgeDetails>? supportOfficial;
  final CommunityPartBuilder<CommunityLabelBadgeDetails>? bot;
  final CommunityPartBuilder<CommunityLabelBadgeDetails>? roomModerator;
  final CommunityPartBuilder<CommunityLabelBadgeDetails>? sentiment;
  final CommunityPartBuilder<CommunityVerifiedBadgeDetails>? verified;
  final CommunityPartBuilder<CommunityCountBadgeDetails>? count;
  final CommunityPartBuilder<CommunityCountOverlayDetails>? countOverlay;

  CommunityPartBuilder<CommunityLabelBadgeDetails>? labelFor(CommunityBadgeKind kind) =>
      switch (kind) {
        CommunityBadgeKind.official => official,
        CommunityBadgeKind.supportOfficial => supportOfficial,
        CommunityBadgeKind.bot => bot,
        CommunityBadgeKind.roomModerator => roomModerator,
        CommunityBadgeKind.sentimentBullish ||
        CommunityBadgeKind.sentimentBearish ||
        CommunityBadgeKind.sentimentNeutral => sentiment,
      } ??
      label;

  static CommunityBadgeBuilders of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CommunityBadgeBuildersScope>()
        : context.getInheritedWidgetOfExactType<CommunityBadgeBuildersScope>();
    return scope?.builders ?? const CommunityBadgeBuilders();
  }

  CommunityBadgeBuilders merge(CommunityBadgeBuilders? other) {
    if (other == null) return this;
    return CommunityBadgeBuilders(
      label: other.label ?? label,
      official: other.official ?? official,
      supportOfficial: other.supportOfficial ?? supportOfficial,
      bot: other.bot ?? bot,
      roomModerator: other.roomModerator ?? roomModerator,
      sentiment: other.sentiment ?? sentiment,
      verified: other.verified ?? verified,
      count: other.count ?? count,
      countOverlay: other.countOverlay ?? countOverlay,
    );
  }
}

class CommunityBadgeBuildersScope extends InheritedWidget {
  const CommunityBadgeBuildersScope({super.key, required this.builders, required super.child});

  final CommunityBadgeBuilders builders;

  @override
  bool updateShouldNotify(CommunityBadgeBuildersScope oldWidget) => !identical(builders, oldWidget.builders);
}

Widget buildLabelBadge(BuildContext context, CommunityLabelBadgeDetails details, Widget fallback) =>
    buildCommunityPart(CommunityBadgeBuilders.of(context).labelFor(details.kind), context, details, fallback);
