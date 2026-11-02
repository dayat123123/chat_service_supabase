import 'package:flutter/widgets.dart';

class CommunitySupportMessageActions extends InheritedWidget {
  const CommunitySupportMessageActions({
    super.key,
    this.onQuickReply,
    this.onOpenLink,
    this.canRate,
    this.onRate,
    required super.child,
  });

  final void Function(String option)? onQuickReply;
  final void Function(Uri url)? onOpenLink;
  final bool Function(String ticketId)? canRate;
  final void Function(String ticketId)? onRate;

  static CommunitySupportMessageActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommunitySupportMessageActions>();

  @override
  bool updateShouldNotify(CommunitySupportMessageActions oldWidget) =>
      onQuickReply != oldWidget.onQuickReply ||
      onOpenLink != oldWidget.onOpenLink ||
      canRate != oldWidget.canRate ||
      onRate != oldWidget.onRate;
}
