library;

export 'package:logging/logging.dart' show Level, LogRecord;

export 'src/app/community_dependencies.dart';
export 'src/app/community_official_scope.dart';
export 'src/app/community_scope.dart';
export 'src/app/community_support_scope.dart';
export 'src/app/rendezvous_community.dart';
export 'src/core/auth/social_session.dart';
export 'src/core/error/community_exception.dart';
export 'src/core/logging/community_logger.dart'
    show CommunityLogEvent, CommunityLogHandler, debugConsoleLogHandler, formatLogRecord, redactedValue;
export 'src/core/network/authorized_image.dart';
export 'src/core/network/realtime_status.dart';
export 'src/core/paging/paged.dart';
export 'src/core/text/social_text_parser.dart'
    show
        CashtagSegment,
        MentionSegment,
        PlainSegment,
        SocialTextSegment,
        extractCashtags,
        extractMentions,
        parseSocialText;
export 'src/features/chat/domain/entities/chat_events.dart';
export 'src/features/chat/domain/entities/chat_message.dart';
export 'src/features/chat/domain/entities/chat_room.dart';
export 'src/features/chat/domain/entities/receipt.dart';
export 'src/features/chat/domain/repositories/chat_repository.dart';
export 'src/features/chat/presentation/builders/community_chat_builders.dart'
    show CommunityChatBuilders, CommunityChatBuildersScope, CommunityPartBuilder;
export 'src/features/chat/presentation/builders/community_chat_details.dart';
export 'src/features/chat/presentation/cubit/chat_room_cubit.dart' show ChatRoomCubit, ChatRoomState;
export 'src/features/chat/presentation/widgets/community_chat_badge.dart' show CommunityChatBadge;
export 'src/features/chat/presentation/widgets/community_chat_list.dart' show CommunityChatList;
export 'src/features/chat/presentation/widgets/community_chat_room.dart' show CommunityChatRoom;
export 'src/features/chat/presentation/widgets/receipt_icon.dart';
export 'src/features/chat/presentation/widgets/room_visuals.dart' show CommunityRoomAvatar;
export 'src/features/compose/presentation/widgets/community_compose_post.dart'
    show CommunityComposePost, showCommunityComposer;
export 'src/features/feed/domain/entities/pinned_post.dart';
export 'src/features/feed/domain/entities/post.dart';
export 'src/features/feed/domain/repositories/feed_repository.dart';
export 'src/features/feed/presentation/widgets/community_feed_list.dart' show CommunityFeedList;
export 'src/features/feed/presentation/widgets/community_stream_feed.dart' show CommunityFeedTab, CommunityStreamFeed;
export 'src/features/feed/presentation/widgets/sentiment_badge.dart';
export 'src/features/media/domain/repositories/media_repository.dart';
export 'src/features/media/presentation/widgets/attachment_grid.dart';
export 'src/features/moderation/domain/entities/report.dart';
export 'src/features/moderation/domain/repositories/moderation_repository.dart';
export 'src/features/notifications/domain/entities/app_notification.dart';
export 'src/features/notifications/domain/repositories/notification_repository.dart';
export 'src/features/notifications/presentation/widgets/community_notifications.dart'
    show CommunityNotificationBadge, CommunityNotificationList;
export 'src/features/poll/domain/entities/poll.dart';
export 'src/features/poll/domain/repositories/poll_repository.dart';
export 'src/features/poll/presentation/widgets/community_poll_view.dart' show CommunityPollView;
export 'src/features/post/domain/entities/thread_comment.dart';
export 'src/features/post/domain/repositories/comment_repository.dart';
export 'src/features/post/presentation/widgets/community_post_detail.dart' show CommunityPostDetail;
export 'src/features/profile/domain/entities/user_profile.dart';
export 'src/features/profile/domain/repositories/profile_repository.dart';
export 'src/features/profile/presentation/widgets/community_user_profile.dart' show CommunityUserProfile;
export 'src/features/stocks/domain/entities/stock.dart';
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
export 'src/shared/domain/entities/attachment.dart';
export 'src/shared/domain/entities/user.dart';
export 'src/shared/domain/official_accounts.dart';
export 'src/shared/presentation/l10n/l10n.dart' show CommunityErrorText, CommunityL10nContext, CommunityLocalizations;
export 'src/shared/presentation/load_status.dart';
export 'src/shared/presentation/theme/community_theme.dart';
export 'src/shared/presentation/widgets/community_avatar.dart';
export 'src/shared/presentation/widgets/community_composer_field.dart';
export 'src/shared/presentation/widgets/community_count_badge.dart';
export 'src/shared/presentation/widgets/community_disclaimer.dart';
export 'src/shared/presentation/widgets/social_text.dart';
