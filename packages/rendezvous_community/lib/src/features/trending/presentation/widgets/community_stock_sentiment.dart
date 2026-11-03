import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/presentation/widgets/community_social_gate.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/features/trending/presentation/cubit/stock_sentiment_cubit.dart';
import 'package:rendezvous_community/src/features/trending/presentation/widgets/community_trending.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class CommunityStockSentiment extends StatelessWidget {
  const CommunityStockSentiment({
    super.key,
    required this.stockCode,
    this.initialWindow = TrendWindow.day,
    this.padding = const EdgeInsets.all(16),
  });

  final String stockCode;
  final TrendWindow initialWindow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final features = CommunityFeatureScope.of(context);
    return CommunitySocialGate(
      feature: CommunityFlags.trending,
      unavailableBuilder: (_, _, _) => const SizedBox.shrink(),
      child: BlocProvider(
        key: ValueKey(stockCode.toUpperCase()),
        create: (_) =>
            StockSentimentCubit(features.trending, stockCode: stockCode.toUpperCase(), window: initialWindow)..load(),
        child: _SentimentView(padding: padding),
      ),
    );
  }
}

class _SentimentView extends StatelessWidget {
  const _SentimentView({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final colors = CommunityTheme.of(context);
    return BlocBuilder<StockSentimentCubit, StockSentimentState>(
      builder: (context, state) {
        final cubit = context.read<StockSentimentCubit>();
        final current = state.current;
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.sentimentTitle, style: theme.textTheme.titleSmall)),
                  SegmentedButton<TrendWindow>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(value: TrendWindow.day, label: Text(l10n.trendingWindowDay)),
                      ButtonSegment(value: TrendWindow.week, label: Text(l10n.trendingWindowWeek)),
                    ],
                    selected: {state.window},
                    onSelectionChanged: (s) => cubit.setWindow(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              switch (state.status) {
                LoadStatus.initial || LoadStatus.loading => const LinearProgressIndicator(),
                LoadStatus.failure => Row(
                  children: [
                    Expanded(child: Text(l10n.errorMessage(state.error!), style: theme.textTheme.bodySmall)),
                    TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
                  ],
                ),
                LoadStatus.ready when current == null || !current.hasLabels => Text(
                  l10n.sentimentNoData,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                LoadStatus.ready => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SentimentBar(bullishPct: current!.bullishPct ?? 0, bearishPct: current.bearishPct ?? 0),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${l10n.sentimentBullish} ${current.bullishPct ?? 0}%',
                          style: theme.textTheme.labelMedium?.copyWith(color: colors.onBullish),
                        ),
                        const Spacer(),
                        Text(
                          l10n.sentimentBasedOn(current.posts),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                        const Spacer(),
                        Text(
                          '${l10n.sentimentBearish} ${current.bearishPct ?? 0}%',
                          style: theme.textTheme.labelMedium?.copyWith(color: colors.onBearish),
                        ),
                      ],
                    ),
                  ],
                ),
              },
            ],
          ),
        );
      },
    );
  }
}
