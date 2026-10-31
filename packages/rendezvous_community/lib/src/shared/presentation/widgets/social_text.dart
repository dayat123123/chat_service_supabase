import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/core/text/social_text_parser.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';

class SocialText extends StatefulWidget {
  const SocialText(this.text, {super.key, this.validStockCodes, this.style, this.maxLines});

  final String text;
  final Set<String>? validStockCodes;
  final TextStyle? style;
  final int? maxLines;

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
    final link = TextStyle(color: OltSocialTheme.of(context).link, fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[
      for (final segment in parseSocialText(widget.text, validStockCodes: widget.validStockCodes))
        switch (segment) {
          PlainSegment() => TextSpan(text: segment.text),
          CashtagSegment(:final code) => TextSpan(
            text: segment.text,
            style: link,
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => OltNavigator.openStock(context, code)),
          ),
          MentionSegment(:final username) => TextSpan(
            text: segment.text,
            style: link,
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(() => OltNavigator.openUsername(context, username)),
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
