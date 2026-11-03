import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/features/profile/presentation/builders/community_profile_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';

class CommunityProfileBuilders {
  const CommunityProfileBuilders({this.header, this.stats, this.followButton});

  final CommunityPartBuilder<CommunityProfileDetails>? header;
  final CommunityPartBuilder<CommunityProfileDetails>? stats;
  final CommunityPartBuilder<CommunityProfileDetails>? followButton;

  static CommunityProfileBuilders of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CommunityProfileBuildersScope>()
        : context.getInheritedWidgetOfExactType<CommunityProfileBuildersScope>();
    return scope?.builders ?? const CommunityProfileBuilders();
  }

  CommunityProfileBuilders merge(CommunityProfileBuilders? other) {
    if (other == null) return this;
    return CommunityProfileBuilders(
      header: other.header ?? header,
      stats: other.stats ?? stats,
      followButton: other.followButton ?? followButton,
    );
  }
}

class CommunityProfileBuildersScope extends InheritedWidget {
  const CommunityProfileBuildersScope({super.key, required this.builders, required super.child});

  final CommunityProfileBuilders builders;

  @override
  bool updateShouldNotify(CommunityProfileBuildersScope oldWidget) => !identical(builders, oldWidget.builders);
}

Widget withProfileBuilders(BuildContext context, CommunityProfileBuilders? builders, Widget child) => builders == null
    ? child
    : CommunityProfileBuildersScope(builders: CommunityProfileBuilders.of(context).merge(builders), child: child);
