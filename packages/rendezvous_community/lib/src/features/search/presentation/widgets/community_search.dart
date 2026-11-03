import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/presentation/widgets/community_social_gate.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_actions.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_card.dart';
import 'package:rendezvous_community/src/features/search/domain/entities/search_results.dart';
import 'package:rendezvous_community/src/features/search/presentation/cubit/search_cubit.dart';
import 'package:rendezvous_community/src/features/search/presentation/cubit/trending_hashtags_cubit.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_user_name.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

Future<void> openCommunitySearch(BuildContext context, {String? initialQuery}) {
  final deps = CommunityScope.of(context);
  final features = CommunityFeatureScope.of(context);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CommunityFeatureScope(
        dependencies: features,
        child: CommunityScope(
          dependencies: deps,
          child: Scaffold(
            appBar: AppBar(),
            body: SafeArea(top: false, child: CommunitySearch(initialQuery: initialQuery, autofocus: true)),
          ),
        ),
      ),
    ),
  );
}

class CommunitySearch extends StatelessWidget {
  const CommunitySearch({super.key, this.initialQuery, this.autofocus = false});

  final String? initialQuery;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    final features = CommunityFeatureScope.of(context);
    return CommunitySocialGate(
      feature: CommunityFlags.search,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) {
              final cubit = SearchCubit(
                search: features.search,
                feed: deps.feed,
                analytics: features.analytics,
                minLength: features.configService.current.searchMinLength,
              );
              final query = initialQuery;
              if (query != null && query.isNotEmpty) {
                cubit
                  ..setQuery(query)
                  ..submit();
              }
              return cubit;
            },
          ),
          BlocProvider(create: (_) => TrendingHashtagsCubit(features.search)..load()),
        ],
        child: _SearchView(initialQuery: initialQuery, autofocus: autofocus),
      ),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({this.initialQuery, required this.autofocus});

  final String? initialQuery;
  final bool autofocus;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> with SingleTickerProviderStateMixin {
  late final _controller = TextEditingController(text: widget.initialQuery);
  late final _tabs = TabController(length: SearchType.values.length, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) context.read<SearchCubit>().setType(SearchType.values[_tabs.index]);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _search(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    context.read<SearchCubit>()
      ..setQuery(query)
      ..submit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _controller,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.search,
                onChanged: context.read<SearchCubit>().setQuery,
                onSubmitted: (_) => context.read<SearchCubit>().submit(),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(tooltip: l10n.cancel, onPressed: () => _search(''), icon: const Icon(Icons.close)),
                  ),
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l10n.searchTabAll),
                Tab(text: l10n.searchTabPosts),
                Tab(text: l10n.searchTabUsers),
                Tab(text: l10n.searchTabStocks),
                Tab(text: l10n.searchTabHashtags),
              ],
            ),
            Expanded(
              child: BlocConsumer<SearchCubit, SearchState>(
                listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
                listener: (context, state) => showCommunityError(context, state.actionError!),
                builder: (context, state) => _SearchBody(
                  state: state,
                  onSeeAll: (type) => _tabs.animateTo(SearchType.values.indexOf(type)),
                  onHashtag: (tag) => _search('#$tag'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({required this.state, required this.onSeeAll, required this.onHashtag});

  final SearchState state;
  final ValueChanged<SearchType> onSeeAll;
  final ValueChanged<String> onHashtag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final cubit = context.read<SearchCubit>();
    if (state.query.trim().isEmpty) return _TrendingHashtagsView(onHashtag: onHashtag);
    if (state.tooShort) {
      return CommunityEmptyView(message: l10n.searchMinLength(cubit.minLength), icon: Icons.search);
    }
    switch (state.status) {
      case LoadStatus.initial || LoadStatus.loading:
        return const CommunitySkeleton(itemCount: 4);
      case LoadStatus.failure:
        return CommunityErrorView(error: state.error!, onRetry: cubit.retry);
      case LoadStatus.ready:
        break;
    }
    final results = state.results;
    if (results == null || results.isEmpty) {
      return CommunityEmptyView(message: l10n.searchNoResults(state.query.trim()), icon: Icons.search_off);
    }
    final children = <Widget>[
      if (state.type == SearchType.all) ...[
        if (results.posts.isNotEmpty) _Section(title: l10n.searchTabPosts, onSeeAll: () => onSeeAll(SearchType.posts)),
        for (final post in results.posts) _postTile(context, cubit, post),
        if (results.users.isNotEmpty) _Section(title: l10n.searchTabUsers, onSeeAll: () => onSeeAll(SearchType.users)),
        for (final user in results.users) _UserTile(result: user),
        if (results.stocks.isNotEmpty)
          _Section(title: l10n.searchTabStocks, onSeeAll: () => onSeeAll(SearchType.stocks)),
        for (final stock in results.stocks) _StockTile(result: stock),
        if (results.hashtags.isNotEmpty)
          _Section(title: l10n.searchTabHashtags, onSeeAll: () => onSeeAll(SearchType.hashtags)),
        for (final hashtag in results.hashtags) _HashtagTile(hashtag: hashtag),
      ] else ...[
        for (final post in results.posts) _postTile(context, cubit, post),
        for (final user in results.users) _UserTile(result: user),
        for (final stock in results.stocks) _StockTile(result: stock),
        for (final hashtag in results.hashtags) _HashtagTile(hashtag: hashtag),
      ],
      if (state.loadingMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      const SizedBox(height: 24),
    ];
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400 && state.hasMore) cubit.loadMore();
        return false;
      },
      child: ListView(children: children),
    );
  }

  Widget _postTile(BuildContext context, SearchCubit cubit, Post post) => Column(
    children: [
      PostCard(
        post: post,
        source: 'search',
        onLike: () => cubit.toggleLike(post),
        onOpen: () => CommunityNavigator.openPost(context, post.id),
        onShare: sharePostAction(context, post),
      ),
      const Divider(height: 1),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
    child: Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        TextButton(onPressed: onSeeAll, child: Text(context.communityL10n.searchSeeAll)),
      ],
    ),
  );
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.result});

  final UserSearchResult result;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CommunityAvatar(user: result.user),
    title: CommunityUserName(user: result.user, official: result.isOfficial),
    subtitle: Text(
      '@${result.user.username} · ${context.communityL10n.followers(result.followerCount)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    onTap: () => CommunityNavigator.openUser(context, result.user),
  );
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.result});

  final StockSearchResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.candlestick_chart_outlined)),
      title: Text('\$${result.code}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${l10n.postsLast7Days(result.posts7d)} · ${l10n.watchers(result.watcherCount)}'),
      trailing: result.isWatching ? Icon(Icons.visibility, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () => CommunityNavigator.openStock(context, result.code, source: 'search'),
    );
  }
}

class _HashtagTile extends StatelessWidget {
  const _HashtagTile({required this.hashtag});

  final HashtagSummary hashtag;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const CircleAvatar(child: Icon(Icons.tag)),
    title: Text('#${hashtag.tag}', style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(context.communityL10n.postsLast7Days(hashtag.postCount)),
    onTap: () => CommunityNavigator.openHashtag(context, hashtag.tag),
  );
}

class _TrendingHashtagsView extends StatelessWidget {
  const _TrendingHashtagsView({required this.onHashtag});

  final ValueChanged<String> onHashtag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return BlocBuilder<TrendingHashtagsCubit, TrendingHashtagsState>(
      builder: (context, state) {
        if (state.status != LoadStatus.ready || state.hashtags.isEmpty) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.trendingHashtags, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hashtag in state.hashtags)
                  ActionChip(
                    avatar: const Icon(Icons.tag, size: 16),
                    label: Text(hashtag.tag),
                    onPressed: () => onHashtag(hashtag.tag),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
