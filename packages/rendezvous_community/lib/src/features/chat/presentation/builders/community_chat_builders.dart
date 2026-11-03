import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';

class CommunityChatBuilders {
  const CommunityChatBuilders({
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
    this.stockCard,
  });

  final CommunityPartBuilder<CommunityMessageDetails>? message;
  final CommunityPartBuilder<CommunityComposerDetails>? composer;
  final CommunityPartBuilder<CommunityRoomHeaderDetails>? roomHeader;
  final CommunityPartBuilder<CommunityTypingDetails>? typingIndicator;
  final CommunityPartBuilder<CommunityConnectionDetails>? connectionBanner;
  final CommunityPartBuilder<CommunityDayDetails>? dayDivider;
  final CommunityPartBuilder<CommunityRoomTileDetails>? roomTile;
  final CommunityPartBuilder<CommunityChatListHeaderDetails>? listHeader;
  final CommunityPartBuilder<CommunityLoadingDetails>? loading;
  final CommunityPartBuilder<CommunityEmptyDetails>? empty;
  final CommunityPartBuilder<CommunityErrorDetails>? error;
  final CommunityPartBuilder<CommunityStockCardDetails>? stockCard;

  static CommunityChatBuilders of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CommunityChatBuildersScope>()
        : context.getInheritedWidgetOfExactType<CommunityChatBuildersScope>();
    return scope?.builders ?? const CommunityChatBuilders();
  }

  CommunityChatBuilders merge(CommunityChatBuilders? other) {
    if (other == null) return this;
    return CommunityChatBuilders(
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
      stockCard: other.stockCard ?? stockCard,
    );
  }
}

class CommunityChatBuildersScope extends InheritedWidget {
  const CommunityChatBuildersScope({super.key, required this.builders, required super.child});

  final CommunityChatBuilders builders;

  @override
  bool updateShouldNotify(CommunityChatBuildersScope oldWidget) => !identical(builders, oldWidget.builders);
}

Widget buildChatPart<T>(CommunityPartBuilder<T>? builder, BuildContext context, T details, Widget fallback) =>
    buildCommunityPart(builder, context, details, fallback);

Widget withChatBuilders(BuildContext context, CommunityChatBuilders? builders, Widget child) => builders == null
    ? child
    : CommunityChatBuildersScope(builders: CommunityChatBuilders.of(context).merge(builders), child: child);
