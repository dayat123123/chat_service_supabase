import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/presentation/widgets/community_social_gate.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_actions.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_card.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/features/trending/presentation/cubit/trending_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

enum CommunityTrendingTab { stocks, rising, posts, hashtags }

class CommunityTrending extends StatelessWidget {
  const CommunityTrending({
    super.key,
    this.initialWindow = TrendWindow.day,
    this.initialTab = CommunityTrendingTab.stocks,
    this.tabs = CommunityTrendingTab.values,
  });

  final TrendWindow initialWindow;
  final CommunityTrendingTab initialTab;
  final List<CommunityTrendingTab> tabs;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    final features = CommunityFeatureScope.of(context);
    return CommunitySocialGate(
      feature: CommunityFlags.trending,
      child: BlocProvider(
        create: (_) => TrendingCubit(features.trending, feed: deps.feed, window: initialWindow)..load(),
        child: _TrendingView(tabs: tabs, initialTab: tabs.contains(initialTab) ? initialTab : tabs.first),
      ),
    );
  }
}

class _TrendingView extends StatefulWidget {
  const _TrendingView({required this.tabs, required this.initialTab});

  final List<CommunityTrendingTab> tabs;
  final CommunityTrendingTab initialTab;

  @override
  State<_TrendingView> createState() => _TrendingViewState();
}

class _TrendingViewState extends State<_TrendingView> {
  late CommunityTrendingTab _tab = widget.initialTab;

  String _label(CommunityLocalizations l10n, CommunityTrendingTab tab) => switch (tab) {
    CommunityTrendingTab.stocks => l10n.trendingStocks,
    CommunityTrendingTab.rising => l10n.trendingRising,
    CommunityTrendingTab.posts => l10n.trendingPosts,
    CommunityTrendingTab.hashtags => l10n.searchTabHashtags,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return BlocConsumer<TrendingCubit, TrendingState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showCommunityError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<TrendingCubit>();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<TrendWindow>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: TrendWindow.day, label: Text(l10n.trendingWindowDay)),
                          ButtonSegment(value: TrendWindow.week, label: Text(l10n.trendingWindowWeek)),
                        ],
                        selected: {state.window},
                        onSelectionChanged: (s) => cubit.load(window: s.first),
                      ),
                      if (widget.tabs.length > 1)
                        for (final tab in widget.tabs)
                          ChoiceChip(
                            label: Text(_label(l10n, tab)),
                            selected: tab == _tab,
                            onSelected: (_) => setState(() => _tab = tab),
                          ),
                    ],
                  ),
                ),
                Expanded(child: _body(context, state, cubit)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, TrendingState state, TrendingCubit cubit) {
    final l10n = context.communityL10n;
    final snapshot = state.snapshot;
    if (state.status == LoadStatus.failure) return CommunityErrorView(error: state.error!, onRetry: cubit.load);
    if (snapshot == null || state.status != LoadStatus.ready) return const CommunitySkeleton(itemCount: 4);
    final empty = CommunityEmptyView(message: l10n.trendingEmpty, icon: Icons.trending_up);
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: switch (_tab) {
        CommunityTrendingTab.stocks when snapshot.stocks.isEmpty => _scrollable(empty),
        CommunityTrendingTab.stocks => ListView(
          children: [
            for (final (index, stock) in snapshot.stocks.indexed) _TrendingStockTile(rank: index + 1, stock: stock),
          ],
        ),
        CommunityTrendingTab.rising when snapshot.rising.isEmpty => _scrollable(empty),
        CommunityTrendingTab.rising => ListView(
          children: [
            for (final (index, stock) in snapshot.rising.indexed) _RisingStockTile(rank: index + 1, stock: stock),
          ],
        ),
        CommunityTrendingTab.posts when snapshot.posts.isEmpty => _scrollable(empty),
        CommunityTrendingTab.posts => ListView(
          children: [
            for (final post in snapshot.posts) ...[
              PostCard(
                post: post,
                source: 'trending',
                onLike: () => cubit.toggleLike(post),
                onOpen: () => CommunityNavigator.openPost(context, post.id),
                onShare: sharePostAction(context, post),
              ),
              const Divider(height: 1),
            ],
          ],
        ),
        CommunityTrendingTab.hashtags when snapshot.hashtags.isEmpty => _scrollable(empty),
        CommunityTrendingTab.hashtags => ListView(
          children: [
            for (final (index, hashtag) in snapshot.hashtags.indexed)
              ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('#${hashtag.tag}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(l10n.trendingPostCount(hashtag.postCount)),
                onTap: () => CommunityNavigator.openHashtag(context, hashtag.tag),
              ),
          ],
        ),
      },
    );
  }

  Widget _scrollable(Widget child) => ListView(children: [SizedBox(height: 240, child: child)]);
}

String formatGrowth(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

class _TrendingStockTile extends StatelessWidget {
  const _TrendingStockTile({required this.rank, required this.stock});

  final int rank;
  final TrendingStock stock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final growth = stock.growthPct;
    return ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text('\$${stock.code}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.trendingPostCount(stock.posts)),
          if (stock.bullishPct != null || stock.bearishPct != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SentimentBar(bullishPct: stock.bullishPct ?? 0, bearishPct: stock.bearishPct ?? 0, height: 6),
            ),
        ],
      ),
      trailing: growth != null && growth > 0
          ? Text(
              l10n.trendingGrowth(formatGrowth(growth)),
              style: theme.textTheme.labelLarge?.copyWith(color: CommunityTheme.of(context).onBullish),
            )
          : null,
      onTap: () => CommunityNavigator.openStock(context, stock.code, source: 'trending'),
    );
  }
}

class _RisingStockTile extends StatelessWidget {
  const _RisingStockTile({required this.rank, required this.stock});

  final int rank;
  final RisingStock stock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final growth = stock.growthPct;
    return ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text('\$${stock.code}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(l10n.trendingPostCount(stock.posts)),
      trailing: growth == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, size: 18),
                const SizedBox(width: 4),
                Text(l10n.trendingGrowth(formatGrowth(growth))),
              ],
            ),
      onTap: () => CommunityNavigator.openStock(context, stock.code, source: 'trending'),
    );
  }
}

class SentimentBar extends StatelessWidget {
  const SentimentBar({super.key, required this.bullishPct, required this.bearishPct, this.height = 10});

  final int bullishPct;
  final int bearishPct;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = CommunityTheme.of(context);
    final neutral = (100 - bullishPct - bearishPct).clamp(0, 100);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (bullishPct > 0)
              Expanded(
                flex: bullishPct,
                child: ColoredBox(color: theme.onBullish),
              ),
            if (neutral > 0)
              Expanded(
                flex: neutral,
                child: ColoredBox(color: theme.neutral),
              ),
            if (bearishPct > 0)
              Expanded(
                flex: bearishPct,
                child: ColoredBox(color: theme.onBearish),
              ),
          ],
        ),
      ),
    );
  }
}
