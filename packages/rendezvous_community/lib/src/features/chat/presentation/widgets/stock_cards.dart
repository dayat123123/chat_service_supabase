import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_card.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class StockCards extends StatelessWidget {
  const StockCards({super.key, required this.codes, required this.isMine});

  final List<String> codes;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final callbacks = context.getInheritedWidgetOfExactType<CommunityScope>()?.dependencies.callbacks;
    final builder = CommunityChatBuilders.of(context).stockCard;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final code in codes)
          Builder(
            builder: (context) {
              final details = CommunityStockCardDetails(
                code: code,
                isMine: isMine,
                info: callbacks?.stockInfo?.call(code),
                onTap: () => CommunityNavigator.openStock(context, code, source: 'chat'),
              );
              return buildChatPart(builder, context, details, StockCardTile(details: details));
            },
          ),
      ],
    );
  }
}

class StockCardTile extends StatelessWidget {
  const StockCardTile({super.key, required this.details});

  final CommunityStockCardDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = details.info;
    final rising = info?.rising;
    final changeColor = rising == null
        ? theme.colorScheme.onSurfaceVariant
        : rising
        ? CommunityTheme.of(context).bullish
        : CommunityTheme.of(context).bearish;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: details.onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.candlestick_chart_outlined, size: 20, color: CommunityTheme.of(context).link),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${details.code}', style: theme.textTheme.titleSmall),
                      if (info?.name != null)
                        Text(
                          info!.name!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (info?.price != null || info?.change != null) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (info?.price != null) Text(info!.price!, style: theme.textTheme.titleSmall),
                      if (info?.change != null)
                        Text(info!.change!, style: theme.textTheme.bodySmall?.copyWith(color: changeColor)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<List<String>?> showStockCardPicker(BuildContext context) =>
    showDialog<List<String>>(context: context, builder: (_) => const StockCardPicker());

class StockCardPicker extends StatefulWidget {
  const StockCardPicker({super.key});

  @override
  State<StockCardPicker> createState() => _StockCardPickerState();
}

class _StockCardPickerState extends State<StockCardPicker> {
  final _controller = TextEditingController();
  final _codes = <String>[];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _add() {
    final l10n = context.communityL10n;
    final raw = _controller.text.split(RegExp('[,;]')).where((part) => part.trim().isNotEmpty).toList();
    if (raw.isEmpty) return true;
    final codes = [for (final part in raw) normalizeStockCardCode(part)];
    if (codes.contains(null)) {
      setState(() => _error = l10n.stockCardInvalid);
      return false;
    }
    final next = <String>{..._codes, ...codes.whereType<String>()};
    if (next.length > maxStockCards) {
      setState(() => _error = l10n.stockCardLimit(maxStockCards));
      return false;
    }
    setState(() {
      _codes
        ..clear()
        ..addAll(next);
      _error = null;
      _controller.clear();
    });
    return true;
  }

  void _send() {
    if (!_add() || _codes.isEmpty) return;
    Navigator.pop(context, List<String>.of(_codes));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return AlertDialog(
      title: Text(l10n.stockCardSend),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: l10n.stockCardHint,
              errorText: _error,
              suffixIcon: IconButton(tooltip: l10n.stockCardAdd, onPressed: _add, icon: const Icon(Icons.add)),
            ),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final code in _codes)
                InputChip(label: Text('\$$code'), onDeleted: () => setState(() => _codes.remove(code))),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _send, child: Text(l10n.composeSubmit)),
      ],
    );
  }
}
