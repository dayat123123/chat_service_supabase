import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/link_opener.dart';

class SocialText extends StatefulWidget {
  const SocialText(
    this.text, {
    super.key,
    this.validStockCodes,
    this.style,
    this.maxLines,
    this.links = true,
    this.hashtags = true,
    this.source,
  });

  final String text;
  final Set<String>? validStockCodes;
  final TextStyle? style;
  final int? maxLines;
  final bool links;
  final bool hashtags;
  final String? source;

  @override
  State<SocialText> createState() => _SocialTextState();
}

class _SocialTextState extends State<SocialText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final link = TextStyle(color: CommunityTheme.of(context).link, fontWeight: FontWeight.w600);
    final hashtagsActive =
        widget.hashtags &&
        (CommunityScope.of(context).callbacks.onHashtagTap != null || context.communityFeature(CommunityFlags.search));
    final segments = parseSocialText(
      widget.text,
      validStockCodes: widget.validStockCodes,
      hashtags: hashtagsActive,
      links: widget.links,
    );
    final spans = <InlineSpan>[
      for (final segment in segments)
        switch (segment) {
          PlainSegment() => TextSpan(text: segment.text),
          CashtagSegment(:final code) => TextSpan(
            text: segment.text,
            style: link,
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => CommunityNavigator.openStock(context, code, source: widget.source)),
          ),
          MentionSegment(:final username) => TextSpan(
            text: segment.text,
            style: link,
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => CommunityNavigator.openUsername(context, username)),
          ),
          HashtagSegment(:final tag) => TextSpan(
            text: segment.text,
            style: link,
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => CommunityNavigator.openHashtag(context, tag)),
          ),
          LinkSegment(:final uri) => TextSpan(
            text: segment.text,
            style: link.copyWith(decoration: TextDecoration.underline, fontWeight: FontWeight.w500),
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => openCommunityLink(context, uri)),
          ),
        },
    ];
    return Text.rich(
      TextSpan(children: spans),
      style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }

  TapGestureRecognizer _recognizer(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }
}
