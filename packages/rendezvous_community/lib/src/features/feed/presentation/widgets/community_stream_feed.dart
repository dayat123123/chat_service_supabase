import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_builders.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/community_feed_list.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/compose_prompt_card.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

enum CommunityFeedTab { latest, following }

class CommunityStreamFeed extends StatefulWidget {
  const CommunityStreamFeed({
    super.key,
    this.initialTab = CommunityFeedTab.latest,
    this.showComposePrompt = true,
    this.builders,
  });

  final CommunityFeedTab initialTab;
  final bool showComposePrompt;
  final CommunityFeedBuilders? builders;

  @override
  State<CommunityStreamFeed> createState() => _CommunityStreamFeedState();
}

class _CommunityStreamFeedState extends State<CommunityStreamFeed> {
  late CommunityFeedTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<CommunityFeedTab>(
            segments: [
              ButtonSegment(
                value: CommunityFeedTab.latest,
                label: Text(l10n.feedLatest),
                icon: const Icon(Icons.public),
              ),
              ButtonSegment(
                value: CommunityFeedTab.following,
                label: Text(l10n.feedFollowing),
                icon: const Icon(Icons.people_outline),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: CommunityFeedList(
            key: ValueKey(_tab),
            scope: _tab == CommunityFeedTab.latest ? const FeedScope.global() : const FeedScope.following(),
            emptyMessage: _tab == CommunityFeedTab.latest ? l10n.feedEmpty : l10n.feedFollowingEmpty,
            header: widget.showComposePrompt ? const ComposePromptCard() : null,
            builders: widget.builders,
          ),
        ),
      ],
    );
  }
}
