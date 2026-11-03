import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/presentation/widgets/community_social_gate.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/community_feed_list.dart';
import 'package:rendezvous_community/src/features/search/domain/entities/search_results.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class CommunityHashtagFeed extends StatelessWidget {
  const CommunityHashtagFeed({super.key, required this.tag, this.header});

  final String tag;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    final features = CommunityFeatureScope.of(context);
    final normalized = normalizeHashtag(tag) ?? tag.toLowerCase();
    return CommunitySocialGate(
      feature: CommunityFlags.search,
      child: BlocProvider(
        create: (_) {
          context.trackCommunityEvent(CommunityAnalyticsEvent.feedOpen, {'scope': 'hashtag', 'hashtag': normalized});
          return FeedCubit(
            feed: deps.feed,
            scope: const FeedScope.global(),
            currentUserId: () => deps.currentUser?.id,
            loader: (cursor, limit) => features.search.hashtagFeed(normalized, cursor: cursor, limit: limit),
            bookmarks: features.bookmarks,
            edits: features.edits,
          )..load();
        },
        child: FeedPostList(
          emptyMessage: context.communityL10n.hashtagFeedEmpty(normalized),
          header: header,
          showConsentBanner: false,
          source: 'hashtag',
        ),
      ),
    );
  }
}
