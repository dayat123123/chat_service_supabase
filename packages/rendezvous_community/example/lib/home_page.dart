import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import 'fake_olt_auth.dart';
import 'main.dart';
import 'sample_chart.dart';
import 'stock_directory.dart';
import 'support_notifications.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.auth});

  final FakeOltAuth auth;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  String _stock = 'BBCA';
  bool _supportOpen = false;
  bool _supportRoute = false;
  int _supportPanel = 0;
  String? _supportTopic;
  String? _supportScreen;
  late final _notifications = SupportNotifications(
    isSupportVisible: () => _supportOpen || _supportRoute,
    onOpen: () => _openSupport(),
  );

  static const _stocks = ['BBCA', 'BBRI', 'TLKM', 'GOTO', 'ADRO', 'ANTM'];
  static const _supportIndex = 5;

  @override
  void initState() {
    super.initState();
    unawaited(_notifications.start(RendezvousCommunity.instance.support.notices()));
  }

  @override
  void dispose() {
    unawaited(_notifications.stop());
    super.dispose();
  }

  Future<void> _openSupport({String? topic, String? screen}) async {
    if (CommunityBreakpoints.isWide(context)) {
      setState(() {
        _supportOpen = topic != null || !_supportOpen;
        _supportTopic = topic;
        _supportScreen = screen;
        _supportPanel++;
      });
      return;
    }
    _supportRoute = true;
    await openCommunitySupport(context, topic: topic, screen: screen);
    _supportRoute = false;
  }

  Future<void> _openAccountSettings() => openCommunityAccountSettings(
    context,
    onAccountDeleted: () {
      if (mounted) setState(() => _index = 0);
    },
  );

  Future<void> _push(String title, Widget body) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(top: false, child: body),
      ),
    ),
  );

  Future<void> _shareChart() async {
    final png = await renderSampleChart(_stock);
    if (!mounted) return;
    await showCommunityComposer(
      context,
      initialStock: _stock,
      initialImage: CommunityComposerImage(bytes: png, mimeType: 'image/png'),
    );
  }

  Future<void> _explore() async {
    final l10n = context.communityL10n;
    final entries = <(IconData, String, Future<void> Function())>[
      (Icons.search, l10n.searchTitle, () => openCommunitySearch(context)),
      (Icons.trending_up, l10n.trendingTitle, () => _push(l10n.trendingTitle, const CommunityTrending())),
      (Icons.bookmark_border, l10n.bookmarksTitle, () => _push(l10n.bookmarksTitle, const CommunityBookmarks())),
      (Icons.mark_email_unread_outlined, l10n.messageRequests, () => openCommunityMessageRequests(context)),
      (
        Icons.notifications_active_outlined,
        l10n.notificationSettings,
        () => openCommunityNotificationSettings(context),
      ),
      (Icons.gavel_outlined, l10n.myAppeals, () => openCommunityAppeals(context)),
      (Icons.drafts_outlined, l10n.draftsTitle, () => openCommunityPostDrafts(context)),
      (Icons.candlestick_chart_outlined, 'Bagikan chart \$$_stock', _shareChart),
    ];
    final action = await showModalBottomSheet<Future<void> Function()>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (icon, label, open) in entries)
              ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(sheetContext, open)),
          ],
        ),
      ),
    );
    await action?.call();
  }

  void _orderTap() {
    RendezvousCommunity.instance.trackOrderTap(stockCode: _stock, side: 'buy', source: 'stock');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Halaman order OLT · $_stock')));
  }

  Future<void> _updateRequired(BuildContext context, ClientConfig config) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.communityL10n.updateRequiredTitle),
      content: Text(dialogContext.communityL10n.updateRequiredBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(dialogContext.communityL10n.close)),
      ],
    ),
  );

  Future<void> _logout() async {
    widget.auth.logout();
    await RendezvousCommunity.instance.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final wide = CommunityBreakpoints.isWide(context);
    final l10n = context.communityL10n;
    final destinations = [
      (Icons.dynamic_feed_outlined, 'Stream'),
      (Icons.show_chart, 'Saham'),
      (Icons.chat_bubble_outline, l10n.chats),
      (Icons.notifications_none, l10n.notifications),
      (Icons.person_outline, 'Profil'),
      (Icons.support_agent_outlined, 'Bantuan'),
    ];

    Widget icon(int i) {
      final widget = Icon(destinations[i].$1);
      return switch (i) {
        2 => CommunityChatBadge(child: widget),
        3 => CommunityNotificationBadge(child: widget),
        _supportIndex => CommunitySupportBadge(child: widget),
        _ => widget,
      };
    }

    void select(int i) {
      if (i == _supportIndex) {
        unawaited(_openSupport());
        return;
      }
      setState(() => _index = i);
    }

    final page = switch (_index) {
      0 => wide ? const _TwoPaneStream() : const CommunityStreamFeed(),
      1 => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: [for (final s in _stocks) ButtonSegment(value: s, label: Text(s))],
                      selected: {_stock},
                      onSelectionChanged: (s) => setState(() => _stock = s.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openSupport(topic: 'orders', screen: 'stock_page'),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Bantuan order'),
                ),
                OutlinedButton.icon(
                  onPressed: _shareChart,
                  icon: const Icon(Icons.candlestick_chart_outlined, size: 18),
                  label: const Text('Bagikan chart'),
                ),
                FilledButton(onPressed: _orderTap, child: const Text('Beli')),
              ],
            ),
          ),
          CommunityStockSentiment(key: ValueKey('sentiment-$_stock'), stockCode: _stock),
          Expanded(
            child: CommunityStockFeed(key: ValueKey(_stock), stockCode: _stock, stockName: stockNames[_stock]),
          ),
        ],
      ),
      2 => const CommunityChatList(),
      3 => const CommunityNotificationList(),
      _ => CommunityUserProfile(
        userId: RendezvousCommunity.instance.currentUser?.id,
        username: RendezvousCommunity.instance.currentUser?.username,
      ),
    };
    final body = _index == 0
        ? page
        : Column(
            children: [
              const CommunityBannerHost(),
              Expanded(child: page),
            ],
          );
    final mobileActions = [
      IconButton(
        tooltip: context.communityL10n.supportTitle,
        onPressed: _openSupport,
        icon: const CommunitySupportBadge(child: Icon(Icons.support_agent_outlined)),
      ),
    ];

    final actions = [
      IconButton(tooltip: 'Jelajah fitur 1.3', onPressed: _explore, icon: const Icon(Icons.explore_outlined)),
      IconButton(
        tooltip: 'Tema terang/gelap',
        onPressed: () => toggleTheme(context),
        icon: const Icon(Icons.brightness_6),
      ),
      IconButton(tooltip: 'Bahasa ID/EN', onPressed: () => toggleLocale(context), icon: const Icon(Icons.translate)),
      IconButton(
        tooltip: 'Gaya chat bawaan/kustom',
        onPressed: () => toggleChatStyle(context),
        icon: const Icon(Icons.palette_outlined),
      ),
      IconButton(
        tooltip: 'Kartu post & badge bawaan/kustom',
        onPressed: () => toggleFeedStyle(context),
        icon: const Icon(Icons.style_outlined),
      ),
      IconButton(
        tooltip: context.communityL10n.accountSettingsTitle,
        onPressed: _openAccountSettings,
        icon: const Icon(Icons.privacy_tip_outlined),
      ),
      IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout)),
    ];

    if (wide) {
      return CommunityUpdateListener(
        onUpdateRequired: _updateRequired,
        child: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _supportOpen ? _supportIndex : _index,
                  onDestinationSelected: select,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: CommunityAvatar(user: RendezvousCommunity.instance.currentUser),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(mainAxisSize: MainAxisSize.min, children: actions),
                      ),
                    ),
                  ),
                  destinations: [
                    for (var i = 0; i < destinations.length; i++)
                      NavigationRailDestination(icon: icon(i), label: Text(destinations[i].$2)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
                if (_supportOpen) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 420,
                    child: CommunitySupportChat(
                      key: ValueKey(_supportPanel),
                      topic: _supportTopic,
                      screen: _supportScreen,
                      onClose: () => setState(() => _supportOpen = false),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return CommunityUpdateListener(
      onUpdateRequired: _updateRequired,
      child: Scaffold(
        appBar: AppBar(title: Text(destinations[_index].$2), actions: [...mobileActions, ...actions]),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: select,
          destinations: [
            for (var i = 0; i < _supportIndex; i++) NavigationDestination(icon: icon(i), label: destinations[i].$2),
          ],
        ),
      ),
    );
  }
}

class _TwoPaneStream extends StatefulWidget {
  const _TwoPaneStream();

  @override
  State<_TwoPaneStream> createState() => _TwoPaneStreamState();
}

class _TwoPaneStreamState extends State<_TwoPaneStream> {
  String? _selectedPost;

  @override
  Widget build(BuildContext context) {
    final base = RendezvousCommunity.instance;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: CommunityScope(
            dependencies: _PostTapOverride(base, (postId) => setState(() => _selectedPost = postId)),
            child: const CommunityStreamFeed(),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          child: _selectedPost == null
              ? const DetailPlaceholder()
              : CommunityPostDetail(key: ValueKey(_selectedPost), postId: _selectedPost!),
        ),
      ],
    );
  }
}

class _PostTapOverride implements CommunityDependencies {
  _PostTapOverride(this._base, this._onPost);

  final CommunityDependencies _base;
  final ValueChanged<String> _onPost;

  @override
  CommunityCallbacks get callbacks => CommunityCallbacks(
    onStockTap: _base.callbacks.onStockTap,
    onUserTap: _base.callbacks.onUserTap,
    onRoomTap: _base.callbacks.onRoomTap,
    onPostTap: (_, postId) => _onPost(postId),
    stockSearch: _base.callbacks.stockSearch,
  );

  @override
  FeedRepository get feed => _base.feed;
  @override
  CommentRepository get comments => _base.comments;
  @override
  PollRepository get polls => _base.polls;
  @override
  ProfileRepository get profiles => _base.profiles;
  @override
  StockRepository get stocks => _base.stocks;
  @override
  ChatRepository get chat => _base.chat;
  @override
  NotificationRepository get notifications => _base.notifications;
  @override
  ModerationRepository get moderation => _base.moderation;
  @override
  MediaRepository get media => _base.media;
  @override
  UserSummary? get currentUser => _base.currentUser;
  @override
  Future<UserSummary> ensureSignedIn() => _base.ensureSignedIn();
}

class DetailPlaceholder extends StatelessWidget {
  const DetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Pilih post untuk melihat diskusinya',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline),
    ),
  );
}
