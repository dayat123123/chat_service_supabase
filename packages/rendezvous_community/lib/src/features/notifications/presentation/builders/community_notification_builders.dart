import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/builders/community_notification_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_list_state_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';

class CommunityNotificationBuilders {
  const CommunityNotificationBuilders({this.item, this.header, this.loading, this.empty, this.error});

  final CommunityPartBuilder<CommunityNotificationDetails>? item;
  final CommunityPartBuilder<CommunityNotificationHeaderDetails>? header;
  final CommunityPartBuilder<CommunityListLoadingDetails>? loading;
  final CommunityPartBuilder<CommunityListEmptyDetails>? empty;
  final CommunityPartBuilder<CommunityListErrorDetails>? error;

  static CommunityNotificationBuilders of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CommunityNotificationBuildersScope>()
        : context.getInheritedWidgetOfExactType<CommunityNotificationBuildersScope>();
    return scope?.builders ?? const CommunityNotificationBuilders();
  }

  CommunityNotificationBuilders merge(CommunityNotificationBuilders? other) {
    if (other == null) return this;
    return CommunityNotificationBuilders(
      item: other.item ?? item,
      header: other.header ?? header,
      loading: other.loading ?? loading,
      empty: other.empty ?? empty,
      error: other.error ?? error,
    );
  }
}

class CommunityNotificationBuildersScope extends InheritedWidget {
  const CommunityNotificationBuildersScope({super.key, required this.builders, required super.child});

  final CommunityNotificationBuilders builders;

  @override
  bool updateShouldNotify(CommunityNotificationBuildersScope oldWidget) => !identical(builders, oldWidget.builders);
}

Widget withNotificationBuilders(BuildContext context, CommunityNotificationBuilders? builders, Widget child) =>
    builders == null
    ? child
    : CommunityNotificationBuildersScope(
        builders: CommunityNotificationBuilders.of(context).merge(builders),
        child: child,
      );
