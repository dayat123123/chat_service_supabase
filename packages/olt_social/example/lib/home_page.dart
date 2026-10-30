import 'package:flutter/material.dart';
import 'package:olt_social/olt_social.dart';

import 'fake_olt_auth.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.auth});

  final FakeOltAuth auth;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  String _stock = 'BBCA';

  static const _stocks = ['BBCA', 'BBRI', 'TLKM', 'GOTO', 'ADRO', 'ANTM'];

  Future<void> _logout() async {
    widget.auth.logout();
    await OltSocial.instance.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final wide = OltBreakpoints.isWide(context);
    final l10n = context.oltL10n;
    final destinations = [
      (Icons.dynamic_feed_outlined, 'Stream'),
      (Icons.show_chart, 'Saham'),
      (Icons.chat_bubble_outline, l10n.chats),
      (Icons.notifications_none, l10n.notifications),
      (Icons.person_outline, 'Profil'),
    ];

    Widget icon(int i) {
      final widget = Icon(destinations[i].$1);
      return switch (i) {
        2 => OltChatBadge(child: widget),
        3 => OltNotificationBadge(child: widget),
        _ => widget,
      };
    }

    final body = switch (_index) {
      0 => wide ? const _TwoPaneStream() : const OltStreamFeed(),
      1 => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<String>(
              segments: [for (final s in _stocks) ButtonSegment(value: s, label: Text(s))],
              selected: {_stock},
              onSelectionChanged: (s) => setState(() => _stock = s.first),
            ),
          ),
          Expanded(child: OltStockFeed(key: ValueKey(_stock), stockCode: _stock)),
        ],
      ),
      2 => const OltChatList(),
      3 => const OltNotificationList(),
      _ => OltUserProfile(userId: OltSocial.instance.currentUser?.id, username: OltSocial.instance.currentUser?.username),
    };

    final actions = [
      IconButton(tooltip: 'Tema terang/gelap', onPressed: () => toggleTheme(context), icon: const Icon(Icons.brightness_6)),
      IconButton(tooltip: 'Bahasa ID/EN', onPressed: () => toggleLocale(context), icon: const Icon(Icons.translate)),
      IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout)),
    ];

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OltAvatar(user: OltSocial.instance.currentUser),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(mainAxisSize: MainAxisSize.min, children: actions)),
                  ),
                ),
                destinations: [
                  for (var i = 0; i < destinations.length; i++)
                    NavigationRailDestination(icon: icon(i), label: Text(destinations[i].$2)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(destinations[_index].$2), actions: actions),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (var i = 0; i < destinations.length; i++) NavigationDestination(icon: icon(i), label: destinations[i].$2),
        ],
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
    final base = OltSocial.instance;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: OltSocialScope(
            dependencies: _PostTapOverride(base, (postId) => setState(() => _selectedPost = postId)),
            child: const OltStreamFeed(),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          child: _selectedPost == null
              ? const OltEmptyHint()
              : OltPostDetail(key: ValueKey(_selectedPost), postId: _selectedPost!),
        ),
      ],
    );
  }
}

class _PostTapOverride implements OltSocialDependencies {
  _PostTapOverride(this._base, this._onPost);

  final OltSocialDependencies _base;
  final ValueChanged<String> _onPost;

  @override
  OltSocialCallbacks get callbacks => OltSocialCallbacks(
    onStockTap: _base.callbacks.onStockTap,
    onUserTap: _base.callbacks.onUserTap,
    onRoomTap: _base.callbacks.onRoomTap,
    onPostTap: (_, postId) => _onPost(postId),
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

class OltEmptyHint extends StatelessWidget {
  const OltEmptyHint({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Pilih post untuk melihat diskusinya',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline),
    ),
  );
}
