library;

export 'package:logging/logging.dart' show Level, LogRecord;

export 'src/app/community_account_scope.dart';
export 'src/app/community_builders.dart' show CommunityBuilders, CommunityBuildersScope;
export 'src/app/community_dependencies.dart';
export 'src/app/community_feature_scope.dart';
export 'src/app/community_image_scope.dart';
export 'src/app/community_official_scope.dart';
export 'src/app/community_offline_scope.dart';
export 'src/app/community_scope.dart';
export 'src/app/community_support_scope.dart';
export 'src/app/rendezvous_community.dart';
export 'src/core/auth/social_session.dart';
export 'src/core/error/community_exception.dart';
export 'src/core/logging/community_logger.dart'
    show CommunityLogEvent, CommunityLogHandler, debugConsoleLogHandler, formatLogRecord, redactedValue;
export 'src/core/network/authorized_image.dart';
export 'src/core/network/community_connectivity.dart' show CommunityConnectivity;
export 'src/core/network/realtime_status.dart';
export 'src/core/paging/paged.dart';
export 'src/core/storage/image_disk_cache.dart' show CommunityImageCacheConfig;
export 'src/core/text/social_text_parser.dart'
    show
        CashtagSegment,
        HashtagSegment,
        LinkSegment,
        MentionSegment,
        PlainSegment,
        SocialTextSegment,
        extractCashtags,
        extractHashtags,
        extractLinks,
        extractMentions,
        parseSocialText;
export 'src/features/account/domain/entities/community_data_export.dart';
export 'src/features/account/domain/repositories/account_repository.dart';
export 'src/features/account/presentation/export_saver.dart' show CommunityExportSaver, saveCommunityDataExport;
export 'src/features/account/presentation/widgets/community_account_settings.dart'
    show CommunityAccountSettings, openCommunityAccountSettings;
export 'src/features/analytics/domain/entities/analytics_event.dart'
    show AnalyticsEvent, AnalyticsResult, CommunityAnalyticsEvent;
export 'src/features/analytics/domain/repositories/analytics_repository.dart';
export 'src/features/analytics/domain/services/community_analytics.dart';
export 'src/features/appeals/domain/entities/appeal.dart';
export 'src/features/appeals/domain/repositories/appeal_repository.dart';
export 'src/features/appeals/presentation/widgets/community_appeals.dart'
    show CommunityAppeals, openCommunityAppeals, showCommunityAppealDialog;
export 'src/features/bookmarks/domain/repositories/bookmark_repository.dart';
export 'src/features/bookmarks/presentation/widgets/community_bookmarks.dart';
export 'src/features/chat/domain/entities/chat_events.dart';
export 'src/features/chat/domain/entities/chat_message.dart';
export 'src/features/chat/domain/entities/chat_room.dart';
export 'src/features/chat/domain/entities/message_extras.dart';
export 'src/features/chat/domain/entities/outbox_message.dart';
export 'src/features/chat/domain/entities/receipt.dart';
export 'src/features/chat/domain/entities/room_moderation.dart';
export 'src/features/chat/domain/entities/stock_card.dart'
    show maxStockCards, normalizeStockCardCode, normalizeStockCardCodes;
export 'src/features/chat/domain/entities/stock_room_state.dart';
export 'src/features/chat/domain/repositories/chat_cache_repository.dart';
export 'src/features/chat/domain/repositories/chat_extras_repository.dart';
export 'src/features/chat/domain/repositories/chat_repository.dart';
export 'src/features/chat/domain/repositories/message_index_repository.dart';
export 'src/features/chat/domain/services/message_outbox.dart'
    show
        MessageOutbox,
        OutboxBusy,
        OutboxChanged,
        OutboxDelivered,
        OutboxEvent,
        OutboxFailed,
        OutboxGuard,
        OutboxQueued,
        OutboxRemoved,
        OutboxResult,
        OutboxSent;
export 'src/features/chat/presentation/builders/community_chat_builders.dart'
    show CommunityChatBuilders, CommunityChatBuildersScope;
export 'src/features/chat/presentation/builders/community_chat_details.dart';
export 'src/features/chat/presentation/cubit/chat_room_cubit.dart' show ChatRoomCubit, ChatRoomState;
export 'src/features/chat/presentation/widgets/community_chat_badge.dart' show CommunityChatBadge;
export 'src/features/chat/presentation/widgets/community_chat_list.dart' show CommunityChatList;
export 'src/features/chat/presentation/widgets/community_chat_room.dart' show CommunityChatRoom;
export 'src/features/chat/presentation/widgets/message_bubble.dart'
    show MessageDeliveryNotice, ReactionChips, ReactionPicker;
export 'src/features/chat/presentation/widgets/receipt_icon.dart';
export 'src/features/chat/presentation/widgets/room_moderation.dart' show RoomModerationBanner, RoomModeratorBadge;
export 'src/features/chat/presentation/widgets/room_visuals.dart' show CommunityRoomAvatar;
export 'src/features/chat/presentation/widgets/share_post_sheet.dart' show showSharePostToChat;
export 'src/features/chat/presentation/widgets/shared_post_card.dart' show SharedPostCard;
export 'src/features/chat/presentation/widgets/stock_cards.dart' show StockCardTile, StockCards, showStockCardPicker;
export 'src/features/compose/presentation/widgets/community_compose_post.dart'
    show CommunityComposePost, CommunityComposerImage, showCommunityComposer;
export 'src/features/config/domain/entities/client_config.dart';
export 'src/features/config/domain/repositories/banner_dismissal_repository.dart';
export 'src/features/config/domain/repositories/client_config_repository.dart';
export 'src/features/config/domain/services/banner_dismissals.dart';
export 'src/features/config/domain/services/client_config_service.dart';
export 'src/features/config/presentation/widgets/community_banner_host.dart';
export 'src/features/config/presentation/widgets/community_social_gate.dart';
export 'src/features/drafts/domain/entities/post_draft.dart';
export 'src/features/drafts/domain/repositories/post_draft_repository.dart';
export 'src/features/drafts/domain/services/community_drafts.dart';
export 'src/features/drafts/presentation/widgets/community_post_drafts.dart';
export 'src/features/edit/domain/repositories/content_edit_repository.dart';
export 'src/features/feed/domain/entities/pinned_post.dart';
export 'src/features/feed/domain/entities/post.dart';
export 'src/features/feed/domain/repositories/feed_cache_repository.dart' show FeedCacheRepository;
export 'src/features/feed/domain/repositories/feed_repository.dart';
export 'src/features/feed/presentation/builders/community_feed_builders.dart'
    show CommunityFeedBuilders, CommunityFeedBuildersScope;
export 'src/features/feed/presentation/builders/community_feed_details.dart';
export 'src/features/feed/presentation/widgets/community_feed_list.dart' show CommunityFeedList;
export 'src/features/feed/presentation/widgets/community_stream_feed.dart' show CommunityFeedTab, CommunityStreamFeed;
export 'src/features/feed/presentation/widgets/sentiment_badge.dart';
export 'src/features/legal/domain/entities/legal_document.dart';
export 'src/features/legal/domain/repositories/legal_repository.dart';
export 'src/features/legal/domain/services/community_consent.dart';
export 'src/features/legal/domain/services/consent_gate.dart'
    show ConsentGate, ConsentGateRun, consentDeclinedCode, consentRequiredCode, isConsentRequired;
export 'src/features/legal/presentation/widgets/community_consent_banner.dart';
export 'src/features/legal/presentation/widgets/community_consent_flow.dart'
    show CommunityConsentView, communityConsentGate, showCommunityConsent;
export 'src/features/legal/presentation/widgets/community_legal_document_reader.dart'
    show CommunityLegalDocumentReader, showCommunityLegalDocument;
export 'src/features/link_preview/domain/entities/link_preview.dart';
export 'src/features/link_preview/domain/repositories/link_preview_repository.dart';
export 'src/features/link_preview/domain/services/link_preview_loader.dart';
export 'src/features/link_preview/presentation/widgets/link_preview_card.dart';
export 'src/features/media/domain/repositories/media_repository.dart';
export 'src/features/media/presentation/widgets/attachment_grid.dart';
export 'src/features/message_requests/domain/entities/message_request.dart';
export 'src/features/message_requests/domain/repositories/message_request_repository.dart';
export 'src/features/message_requests/presentation/widgets/community_dm_policy_settings.dart';
export 'src/features/message_requests/presentation/widgets/community_message_requests.dart'
    show CommunityMessageRequests, MessageRequestsEntry, openCommunityMessageRequests;
export 'src/features/moderation/domain/entities/report.dart';
export 'src/features/moderation/domain/repositories/moderation_repository.dart';
export 'src/features/notifications/domain/entities/app_notification.dart';
export 'src/features/notifications/domain/entities/notification_event.dart';
export 'src/features/notifications/domain/entities/notification_preferences.dart';
export 'src/features/notifications/domain/repositories/notification_event_repository.dart';
export 'src/features/notifications/domain/repositories/notification_preferences_repository.dart';
export 'src/features/notifications/domain/repositories/notification_repository.dart';
export 'src/features/notifications/domain/services/notification_reporter.dart';
export 'src/features/notifications/presentation/builders/community_notification_builders.dart'
    show CommunityNotificationBuilders, CommunityNotificationBuildersScope;
export 'src/features/notifications/presentation/builders/community_notification_details.dart';
export 'src/features/notifications/presentation/widgets/community_notification_settings.dart'
    show CommunityNotificationSettings, openCommunityNotificationSettings;
export 'src/features/notifications/presentation/widgets/community_notifications.dart'
    show CommunityNotificationBadge, CommunityNotificationList, openCommunityNotification;
export 'src/features/offline/presentation/widgets/community_offline_banner.dart';
export 'src/features/poll/domain/entities/poll.dart';
export 'src/features/poll/domain/repositories/poll_repository.dart';
export 'src/features/poll/presentation/widgets/community_poll_view.dart' show CommunityPollView;
export 'src/features/post/domain/entities/thread_comment.dart';
export 'src/features/post/domain/repositories/comment_repository.dart';
export 'src/features/post/presentation/widgets/community_post_detail.dart' show CommunityPostDetail;
export 'src/features/profile/domain/entities/user_profile.dart';
export 'src/features/profile/domain/repositories/profile_repository.dart';
export 'src/features/profile/presentation/builders/community_profile_builders.dart'
    show CommunityProfileBuilders, CommunityProfileBuildersScope;
export 'src/features/profile/presentation/builders/community_profile_details.dart';
export 'src/features/profile/presentation/widgets/community_user_profile.dart' show CommunityUserProfile;
export 'src/features/push/domain/entities/community_push_message.dart';
export 'src/features/push/presentation/open_community_push.dart' show isCommunityPush, isOltPush, openCommunityPush;
export 'src/features/search/domain/entities/search_results.dart'
    show SearchResults, SearchType, StockSearchResult, UserSearchResult, normalizeHashtag;
export 'src/features/search/domain/repositories/search_repository.dart';
export 'src/features/search/presentation/widgets/community_hashtag_feed.dart';
export 'src/features/search/presentation/widgets/community_search.dart' show CommunitySearch, openCommunitySearch;
export 'src/features/stocks/domain/entities/stock.dart';
export 'src/features/stocks/domain/entities/stock_info.dart';
export 'src/features/stocks/domain/entities/stock_suggestion.dart';
export 'src/features/stocks/domain/repositories/stock_repository.dart';
export 'src/features/stocks/presentation/widgets/community_stock_feed.dart' show CommunityStockFeed;
export 'src/features/support/domain/entities/support_ticket.dart';
export 'src/features/support/domain/repositories/support_repository.dart';
export 'src/features/support/presentation/widgets/community_support_badge.dart' show CommunitySupportBadge;
export 'src/features/support/presentation/widgets/community_support_chat.dart'
    show CommunitySupportChat, CommunitySupportPage, openCommunitySupport;
export 'src/features/support/presentation/widgets/community_support_tickets.dart' show CommunitySupportTickets;
export 'src/features/support/presentation/widgets/support_message_actions.dart';
export 'src/features/support/presentation/widgets/support_message_parts.dart' show OfficialBadge;
export 'src/features/trending/domain/entities/trending.dart';
export 'src/features/trending/domain/repositories/trending_repository.dart';
export 'src/features/trending/presentation/widgets/community_stock_sentiment.dart';
export 'src/features/trending/presentation/widgets/community_trending.dart'
    show CommunityTrending, CommunityTrendingTab, SentimentBar;
export 'src/shared/domain/entities/attachment.dart';
export 'src/shared/domain/entities/moderation_status.dart';
export 'src/shared/domain/entities/user.dart';
export 'src/shared/domain/official_accounts.dart';
export 'src/shared/presentation/builders/community_badge_builders.dart'
    show CommunityBadgeBuilders, CommunityBadgeBuildersScope;
export 'src/shared/presentation/builders/community_badge_details.dart' hide communityCountLabel;
export 'src/shared/presentation/builders/community_list_state_details.dart';
export 'src/shared/presentation/builders/community_part_builder.dart' show CommunityPartBuilder;
export 'src/shared/presentation/images/community_image_loader.dart'
    show CommunityImageLoadException, CommunityImageLoader;
export 'src/shared/presentation/images/community_image_provider.dart' show CommunityImageProvider;
export 'src/shared/presentation/l10n/l10n.dart' show CommunityErrorText, CommunityL10nContext, CommunityLocalizations;
export 'src/shared/presentation/load_status.dart';
export 'src/shared/presentation/theme/community_theme.dart';
export 'src/shared/presentation/widgets/community_avatar.dart';
export 'src/shared/presentation/widgets/community_composer_field.dart';
export 'src/shared/presentation/widgets/community_count_badge.dart';
export 'src/shared/presentation/widgets/community_disclaimer.dart';
export 'src/shared/presentation/widgets/community_network_image.dart' show CommunityNetworkImage;
export 'src/shared/presentation/widgets/link_opener.dart' show openCommunityLink;
export 'src/shared/presentation/widgets/moderation_notice.dart';
export 'src/shared/presentation/widgets/social_text.dart';
