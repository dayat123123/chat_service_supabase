import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/analytics/domain/services/community_analytics.dart';
import 'package:rendezvous_community/src/features/appeals/domain/repositories/appeal_repository.dart';
import 'package:rendezvous_community/src/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_extras_repository.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/domain/services/banner_dismissals.dart';
import 'package:rendezvous_community/src/features/config/domain/services/client_config_service.dart';
import 'package:rendezvous_community/src/features/drafts/domain/services/community_drafts.dart';
import 'package:rendezvous_community/src/features/edit/domain/repositories/content_edit_repository.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/services/link_preview_loader.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:rendezvous_community/src/features/notifications/domain/services/notification_reporter.dart';
import 'package:rendezvous_community/src/features/search/domain/repositories/search_repository.dart';
import 'package:rendezvous_community/src/features/trending/domain/repositories/trending_repository.dart';

abstract interface class CommunityFeatureDependencies {
  ClientConfigService get configService;
  SearchRepository get search;
  TrendingRepository get trending;
  BookmarkRepository get bookmarks;
  ContentEditRepository get edits;
  ChatExtrasRepository get chatExtras;
  MessageRequestRepository get messageRequests;
  AppealRepository get appeals;
  NotificationPreferencesRepository get notificationPreferences;
  LinkPreviewLoader get linkPreviews;
  CommunityAnalytics get analytics;
  NotificationReporter get notificationReporter;
  BannerDismissals get bannerDismissals;
  CommunityDrafts get drafts;
}

class CommunityFeatureScope extends InheritedWidget {
  const CommunityFeatureScope({super.key, required this.dependencies, required super.child});

  final CommunityFeatureDependencies dependencies;

  static CommunityFeatureDependencies of(BuildContext context) =>
      maybeOf(context) ??
      (throw StateError('No CommunityFeatureScope found and RendezvousCommunity is not initialized'));

  static CommunityFeatureDependencies? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityFeatureScope>()?.dependencies ??
      (RendezvousCommunity.isInitialized ? RendezvousCommunity.instance : null);

  @override
  bool updateShouldNotify(CommunityFeatureScope oldWidget) => !identical(dependencies, oldWidget.dependencies);
}

extension CommunityFeatureContext on BuildContext {
  CommunityFeatureDependencies? get communityFeatures => CommunityFeatureScope.maybeOf(this);

  ClientConfig get communityConfig => communityFeatures?.configService.current ?? const ClientConfig();

  bool communityFeature(String flag) {
    final features = communityFeatures;
    return features != null && features.configService.current.feature(flag);
  }

  void trackCommunityEvent(String event, [Map<String, Object?> props = const {}]) =>
      communityFeatures?.analytics.record(event, props);
}
