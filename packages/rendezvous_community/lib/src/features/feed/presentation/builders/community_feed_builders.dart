import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_list_state_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';

class CommunityFeedBuilders {
  const CommunityFeedBuilders({
    this.postCard,
    this.postAvatar,
    this.postHeader,
    this.postBody,
    this.attachments,
    this.linkPreview,
    this.stockTags,
    this.actionBar,
    this.poll,
    this.pinnedMarker,
    this.loading,
    this.empty,
    this.error,
    this.comment,
  });

  final CommunityPartBuilder<CommunityPostDetails>? postCard;
  final CommunityPartBuilder<CommunityPostDetails>? postAvatar;
  final CommunityPartBuilder<CommunityPostDetails>? postHeader;
  final CommunityPartBuilder<CommunityPostDetails>? postBody;
  final CommunityPartBuilder<CommunityPostDetails>? attachments;
  final CommunityPartBuilder<CommunityLinkPreviewDetails>? linkPreview;
  final CommunityPartBuilder<CommunityPostDetails>? stockTags;
  final CommunityPartBuilder<CommunityPostDetails>? actionBar;
  final CommunityPartBuilder<CommunityPollDetails>? poll;
  final CommunityPartBuilder<CommunityPinnedMarkerDetails>? pinnedMarker;
  final CommunityPartBuilder<CommunityListLoadingDetails>? loading;
  final CommunityPartBuilder<CommunityListEmptyDetails>? empty;
  final CommunityPartBuilder<CommunityListErrorDetails>? error;
  final CommunityPartBuilder<CommunityCommentDetails>? comment;

  static CommunityFeedBuilders of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CommunityFeedBuildersScope>()
        : context.getInheritedWidgetOfExactType<CommunityFeedBuildersScope>();
    return scope?.builders ?? const CommunityFeedBuilders();
  }

  CommunityFeedBuilders merge(CommunityFeedBuilders? other) {
    if (other == null) return this;
    return CommunityFeedBuilders(
      postCard: other.postCard ?? postCard,
      postAvatar: other.postAvatar ?? postAvatar,
      postHeader: other.postHeader ?? postHeader,
      postBody: other.postBody ?? postBody,
      attachments: other.attachments ?? attachments,
      linkPreview: other.linkPreview ?? linkPreview,
      stockTags: other.stockTags ?? stockTags,
      actionBar: other.actionBar ?? actionBar,
      poll: other.poll ?? poll,
      pinnedMarker: other.pinnedMarker ?? pinnedMarker,
      loading: other.loading ?? loading,
      empty: other.empty ?? empty,
      error: other.error ?? error,
      comment: other.comment ?? comment,
    );
  }
}

class CommunityFeedBuildersScope extends InheritedWidget {
  const CommunityFeedBuildersScope({super.key, required this.builders, required super.child});

  final CommunityFeedBuilders builders;

  @override
  bool updateShouldNotify(CommunityFeedBuildersScope oldWidget) => !identical(builders, oldWidget.builders);
}

Widget withFeedBuilders(BuildContext context, CommunityFeedBuilders? builders, Widget child) => builders == null
    ? child
    : CommunityFeedBuildersScope(builders: CommunityFeedBuilders.of(context).merge(builders), child: child);
