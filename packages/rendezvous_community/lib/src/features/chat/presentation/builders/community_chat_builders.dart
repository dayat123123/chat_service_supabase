import 'package:flutter/widgets.dart';
import 'package:olt_social/src/features/chat/presentation/builders/olt_chat_details.dart';

typedef OltPartBuilder<T> = Widget Function(BuildContext context, T details, Widget fallback);

class OltChatBuilders {
  const OltChatBuilders({
    this.message,
    this.composer,
    this.roomHeader,
    this.typingIndicator,
    this.connectionBanner,
    this.dayDivider,
    this.roomTile,
    this.listHeader,
    this.loading,
    this.empty,
    this.error,
  });

  final OltPartBuilder<OltMessageDetails>? message;
  final OltPartBuilder<OltComposerDetails>? composer;
  final OltPartBuilder<OltRoomHeaderDetails>? roomHeader;
  final OltPartBuilder<OltTypingDetails>? typingIndicator;
  final OltPartBuilder<OltConnectionDetails>? connectionBanner;
  final OltPartBuilder<OltDayDetails>? dayDivider;
  final OltPartBuilder<OltRoomTileDetails>? roomTile;
  final OltPartBuilder<OltChatListHeaderDetails>? listHeader;
  final OltPartBuilder<OltLoadingDetails>? loading;
  final OltPartBuilder<OltEmptyDetails>? empty;
  final OltPartBuilder<OltErrorDetails>? error;

  static OltChatBuilders of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<OltChatBuildersScope>()
        : context.getInheritedWidgetOfExactType<OltChatBuildersScope>();
    return scope?.builders ?? const OltChatBuilders();
  }

  OltChatBuilders merge(OltChatBuilders? other) {
    if (other == null) return this;
    return OltChatBuilders(
      message: other.message ?? message,
      composer: other.composer ?? composer,
      roomHeader: other.roomHeader ?? roomHeader,
      typingIndicator: other.typingIndicator ?? typingIndicator,
      connectionBanner: other.connectionBanner ?? connectionBanner,
      dayDivider: other.dayDivider ?? dayDivider,
      roomTile: other.roomTile ?? roomTile,
      listHeader: other.listHeader ?? listHeader,
      loading: other.loading ?? loading,
      empty: other.empty ?? empty,
      error: other.error ?? error,
    );
  }
}

class OltChatBuildersScope extends InheritedWidget {
  const OltChatBuildersScope({super.key, required this.builders, required super.child});

  final OltChatBuilders builders;

  @override
  bool updateShouldNotify(OltChatBuildersScope oldWidget) => !identical(builders, oldWidget.builders);
}

Widget buildChatPart<T>(OltPartBuilder<T>? builder, BuildContext context, T details, Widget fallback) =>
    builder == null ? fallback : builder(context, details, fallback);

Widget Function(Widget child) carryChatBuilders(BuildContext context) {
  final builders = OltChatBuilders.of(context, listen: false);
  return (child) => OltChatBuildersScope(builders: builders, child: child);
}

Widget withChatBuilders(BuildContext context, OltChatBuilders? builders, Widget child) => builders == null
    ? child
    : OltChatBuildersScope(builders: OltChatBuilders.of(context).merge(builders), child: child);
