import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/feed/domain/entities/post.dart';
import 'package:olt_social/src/features/feed/presentation/widgets/compose_prompt_card.dart';
import 'package:olt_social/src/features/feed/presentation/widgets/olt_feed_list.dart';
import 'package:olt_social/src/features/stocks/presentation/cubit/stock_cubit.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';

class OltStockFeed extends StatelessWidget {
  const OltStockFeed({super.key, required this.stockCode, this.showHeader = true});

  final String stockCode;

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    final code = stockCode.toUpperCase();
    return BlocProvider(
      create: (_) => StockCubit(stocks: deps.stocks, chat: deps.chat, code: code)..load(),
      child: BlocListener<StockCubit, StockState>(
        listenWhen: (a, b) => a.errorId != b.errorId,
        listener: (context, state) => showOltError(context, state.error!),
        child: OltFeedList(
          scope: FeedScope.stock(code),
          emptyMessage: context.oltL10n.stockFeedEmpty(code),
          header: Column(
            children: [
              if (showHeader) const _StockHeader(),
              ComposePromptCard(initialStock: code),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockHeader extends StatelessWidget {
  const _StockHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return BlocBuilder<StockCubit, StockState>(
      builder: (context, state) {
        final cubit = context.read<StockCubit>();
        final stock = state.stock;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.show_chart),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$${cubit.code}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if (stock != null)
                      Text(
                        '${stock.name} · ${l10n.watchers(stock.watcherCount)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (state.loaded)
                      Text(l10n.stockNotFound, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (stock != null) ...[
                state.watching
                    ? FilledButton.tonalIcon(
                        onPressed: cubit.toggleWatch,
                        icon: const Icon(Icons.star),
                        label: Text(l10n.watching),
                      )
                    : OutlinedButton.icon(
                        onPressed: cubit.toggleWatch,
                        icon: const Icon(Icons.star_border),
                        label: Text(l10n.watch),
                      ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: l10n.stockDiscussion,
                  onPressed: state.joining
                      ? null
                      : () async {
                          final roomId = await cubit.joinDiscussion();
                          if (roomId != null && context.mounted) OltNavigator.openRoom(context, roomId);
                        },
                  icon: const Icon(Icons.forum_outlined),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
