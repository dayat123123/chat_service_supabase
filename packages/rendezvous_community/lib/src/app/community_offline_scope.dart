import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/network/community_connectivity.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_cache_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/message_outbox.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_cache_repository.dart';

abstract interface class CommunityOfflineDependencies {
  CommunityConnectivity get connectivity;

  ChatCacheRepository? get chatCache;

  FeedCacheRepository? get feedCache;

  MessageOutbox? get outbox;
}

class CommunityOfflineScope extends InheritedWidget {
  const CommunityOfflineScope({super.key, required this.dependencies, required super.child});

  final CommunityOfflineDependencies dependencies;

  static CommunityOfflineDependencies? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityOfflineScope>()?.dependencies ??
      (RendezvousCommunity.isInitialized ? RendezvousCommunity.instance : null);

  @override
  bool updateShouldNotify(CommunityOfflineScope oldWidget) => !identical(dependencies, oldWidget.dependencies);
}
