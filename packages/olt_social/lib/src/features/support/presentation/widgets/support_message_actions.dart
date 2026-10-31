import 'package:flutter/widgets.dart';

class OltSupportMessageActions extends InheritedWidget {
  const OltSupportMessageActions({
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

  static OltSupportMessageActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OltSupportMessageActions>();

  @override
  bool updateShouldNotify(OltSupportMessageActions oldWidget) =>
      onQuickReply != oldWidget.onQuickReply ||
      onOpenLink != oldWidget.onOpenLink ||
      canRate != oldWidget.canRate ||
      onRate != oldWidget.onRate;
}
