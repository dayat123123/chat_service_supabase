import 'package:flutter/material.dart';

import '../../domain/entities/post.dart';
import '../l10n/l10n.dart';
import 'feed_list.dart';

enum OltFeedTab { latest, following }

/// Stream umum: tab "Terbaru" (semua post) dan "Mengikuti".
class OltStreamFeed extends StatefulWidget {
  const OltStreamFeed({super.key, this.initialTab = OltFeedTab.latest, this.showComposePrompt = true});

  final OltFeedTab initialTab;
  final bool showComposePrompt;

  @override
  State<OltStreamFeed> createState() => _OltStreamFeedState();
}

class _OltStreamFeedState extends State<OltStreamFeed> {
  late OltFeedTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<OltFeedTab>(
            segments: [
              ButtonSegment(value: OltFeedTab.latest, label: Text(l10n.feedLatest), icon: const Icon(Icons.public)),
              ButtonSegment(value: OltFeedTab.following, label: Text(l10n.feedFollowing), icon: const Icon(Icons.people_outline)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: OltFeedList(
            key: ValueKey(_tab),
            scope: _tab == OltFeedTab.latest ? const FeedScope.global() : const FeedScope.following(),
            emptyMessage: _tab == OltFeedTab.latest ? l10n.feedEmpty : l10n.feedFollowingEmpty,
            header: widget.showComposePrompt ? const ComposePromptCard() : null,
          ),
        ),
      ],
    );
  }
}
