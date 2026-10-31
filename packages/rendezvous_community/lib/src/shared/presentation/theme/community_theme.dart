import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class CommunityTheme extends ThemeExtension<CommunityTheme> {
  const CommunityTheme({
    required this.bullish,
    required this.onBullish,
    required this.bearish,
    required this.onBearish,
    required this.neutral,
    required this.onNeutral,
    required this.link,
    required this.threadLine,
    required this.myBubble,
    required this.onMyBubble,
    required this.otherBubble,
    required this.onOtherBubble,
    required this.unreadBadge,
    required this.onUnreadBadge,
    required this.onlineIndicator,
    this.readReceipt = const Color(0xFF34B7F1),
    this.threadIndent = 16,
    this.maxThreadIndentLevels = 4,
  });

  factory CommunityTheme.fallback(ThemeData theme) {
    final scheme = theme.colorScheme;
    final positive = ColorScheme.fromSeed(
      seedColor: Color.lerp(Colors.green, scheme.primary, 0.15)!,
      brightness: theme.brightness,
    );
    return CommunityTheme(
      bullish: positive.primaryContainer,
      onBullish: positive.onPrimaryContainer,
      bearish: scheme.errorContainer,
      onBearish: scheme.onErrorContainer,
      neutral: scheme.surfaceContainerHighest,
      onNeutral: scheme.onSurfaceVariant,
      link: scheme.primary,
      threadLine: scheme.outlineVariant,
      myBubble: scheme.primaryContainer,
      onMyBubble: scheme.onPrimaryContainer,
      otherBubble: scheme.surfaceContainerHigh,
      onOtherBubble: scheme.onSurface,
      unreadBadge: scheme.error,
      onUnreadBadge: scheme.onError,
      onlineIndicator: positive.primary,
      readReceipt: theme.brightness == Brightness.dark ? const Color(0xFF53BDEB) : const Color(0xFF1F9BDE),
    );
  }

  static CommunityTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<CommunityTheme>() ?? CommunityTheme.fallback(theme);
  }

  final Color bullish;
  final Color onBullish;
  final Color bearish;
  final Color onBearish;
  final Color neutral;
  final Color onNeutral;

  final Color link;

  final Color threadLine;
  final Color myBubble;
  final Color onMyBubble;
  final Color otherBubble;
  final Color onOtherBubble;
  final Color unreadBadge;
  final Color onUnreadBadge;
  final Color onlineIndicator;
  final Color readReceipt;

  final double threadIndent;

  final int maxThreadIndentLevels;

  @override
  CommunityTheme copyWith({
    Color? bullish,
    Color? onBullish,
    Color? bearish,
    Color? onBearish,
    Color? neutral,
    Color? onNeutral,
    Color? link,
    Color? threadLine,
    Color? myBubble,
    Color? onMyBubble,
    Color? otherBubble,
    Color? onOtherBubble,
    Color? unreadBadge,
    Color? onUnreadBadge,
    Color? onlineIndicator,
    Color? readReceipt,
    double? threadIndent,
    int? maxThreadIndentLevels,
  }) => CommunityTheme(
    bullish: bullish ?? this.bullish,
    onBullish: onBullish ?? this.onBullish,
    bearish: bearish ?? this.bearish,
    onBearish: onBearish ?? this.onBearish,
    neutral: neutral ?? this.neutral,
    onNeutral: onNeutral ?? this.onNeutral,
    link: link ?? this.link,
    threadLine: threadLine ?? this.threadLine,
    myBubble: myBubble ?? this.myBubble,
    onMyBubble: onMyBubble ?? this.onMyBubble,
    otherBubble: otherBubble ?? this.otherBubble,
    onOtherBubble: onOtherBubble ?? this.onOtherBubble,
    unreadBadge: unreadBadge ?? this.unreadBadge,
    onUnreadBadge: onUnreadBadge ?? this.onUnreadBadge,
    onlineIndicator: onlineIndicator ?? this.onlineIndicator,
    readReceipt: readReceipt ?? this.readReceipt,
    threadIndent: threadIndent ?? this.threadIndent,
    maxThreadIndentLevels: maxThreadIndentLevels ?? this.maxThreadIndentLevels,
  );

  @override
  CommunityTheme lerp(covariant CommunityTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return CommunityTheme(
      bullish: c(bullish, other.bullish),
      onBullish: c(onBullish, other.onBullish),
      bearish: c(bearish, other.bearish),
      onBearish: c(onBearish, other.onBearish),
      neutral: c(neutral, other.neutral),
      onNeutral: c(onNeutral, other.onNeutral),
      link: c(link, other.link),
      threadLine: c(threadLine, other.threadLine),
      myBubble: c(myBubble, other.myBubble),
      onMyBubble: c(onMyBubble, other.onMyBubble),
      otherBubble: c(otherBubble, other.otherBubble),
      onOtherBubble: c(onOtherBubble, other.onOtherBubble),
      unreadBadge: c(unreadBadge, other.unreadBadge),
      onUnreadBadge: c(onUnreadBadge, other.onUnreadBadge),
      onlineIndicator: c(onlineIndicator, other.onlineIndicator),
      readReceipt: c(readReceipt, other.readReceipt),
      threadIndent: lerpDouble(threadIndent, other.threadIndent, t)!,
      maxThreadIndentLevels: t < 0.5 ? maxThreadIndentLevels : other.maxThreadIndentLevels,
    );
  }
}

abstract final class CommunityBreakpoints {
  static const double wide = 840;

  static const double contentMaxWidth = 720;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wide;
}

bool isDesktopPlatform(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
  _ => false,
};
